class_name LevelBot
extends RefCounted
## Joueur automatique, utilisé par le validateur (et les outils de test).
##
## Deux styles de jeu :
## - EXPERT : garde le doigt appuyé et tape (avec l'autre pouce) aux points
##   d'action du parcours idéal, éventuellement décalés de quelques centièmes
##   de seconde pour simuler l'imprécision humaine. Comme un humain, après
##   chaque virage il regarde la suite et relâche le doigt si un élément à
##   cycle n'est pas prêt (pont écarté, pointes sorties…) ;
## - PRUDENT : joue avec UN SEUL doigt. Il s'arrête à chaque virage (relâcher,
##   taper, ré-appuyer), s'arrête avant de sauter quand le sol le permet, et,
##   avant de repartir d'un virage, « essaie » mentalement la suite : si elle
##   le tue (pont absent, pointes sorties…), il attend un peu et réessaie.
##
## Le bot pilote un PlayerMotor : avant chaque pas, appeler control(motor).

enum Mode { EXPERT, PRUDENT }

## Durée d'un arrêt à un virage : relâcher, taper à gauche/droite (s).
const CORNER_PAUSE := 0.3
## Arrêt avant un saut pris à l'arrêt (s).
const JUMP_PAUSE := 0.2
## Le bot prudent réévalue la situation toutes les N étapes quand il attend.
const DECIDE_EVERY := 6
## Au-delà de cette attente (s) au même endroit, le bot abandonne.
const MAX_WAIT := 20.0
## Horizon maximal d'un essai mental (s).
const LOOKAHEAD := 10.0
## On ne repart que si la suite réussit aussi en partant ce nombre de pas
## plus tard (marge de sécurité, comme un joueur qui ne part pas « au ras »).
const SAFETY_STEPS := 6

var data: LevelData
var mode := Mode.EXPERT
## Décalage (s) de l'action n° i : négatif = en avance, positif = en retard.
var offset_for: Callable = func(_i: int) -> float: return 0.0
## Indice du prochain point d'action.
var next := 0
## Temps total passé à attendre (statistique).
var waited := 0.0
## true si le bot a abandonné (bloqué trop longtemps).
var gave_up := false

var _phase := "decide"
var _timer := 0
var _pending := ""
var _cooldown := 0
var _wait_here := 0.0
# Pendant un essai mental : on s'arrête dès qu'on atteint le virage suivant.
var _trial := false
var _reached_corner := false


func _init(level_data: LevelData, bot_mode: Mode = Mode.EXPERT) -> void:
	data = level_data
	mode = bot_mode


## Décide des commandes pour le prochain pas.
func control(motor: PlayerMotor) -> void:
	if mode == Mode.EXPERT:
		_expert(motor)
	else:
		_prudent(motor)
	if motor.holding:
		motor.start()


func _expert(motor: PlayerMotor) -> void:
	if _phase == "decide" and not _decide(motor):
		return
	motor.holding = true
	if next >= data.waypoints.size():
		return
	var wp: Dictionary = data.waypoints[next]
	if _distance_past(motor, wp) >= float(offset_for.call(next)) * data.speed:
		if _trial and wp.action != "jump":
			_reached_corner = true
			return
		if _act(motor, String(wp.action)):
			next += 1
			if wp.action != "jump":
				_phase = "decide"
				_decide(motor)


## Phase « décision » : on repart si l'essai mental réussit, sinon on attend
## (doigt relâché). Renvoie true si le cube peut avancer.
func _decide(motor: PlayerMotor) -> bool:
	motor.holding = false
	if _cooldown > 0:
		_cooldown -= 1
		_count_wait()
		return false
	if _trial or (_try_ahead(motor, 0) and _try_ahead(motor, SAFETY_STEPS)):
		_phase = "go"
		_wait_here = 0.0
		motor.holding = true
		return true
	_cooldown = DECIDE_EVERY
	_count_wait()
	if _wait_here > MAX_WAIT:
		gave_up = true
		_phase = "go"
	return false


func _prudent(motor: PlayerMotor) -> void:
	match _phase:
		"stop":
			motor.holding = false
			_timer -= 1
			if _timer <= 0:
				_after_stop(motor)
			return
		"decide":
			if not _decide(motor):
				return
	# Phase « go » : on avance jusqu'au prochain point d'action.
	motor.holding = true
	if next >= data.waypoints.size():
		return
	var wp: Dictionary = data.waypoints[next]
	if _distance_past(motor, wp) < 0.0:
		return
	if wp.action == "jump":
		if not motor.grounded:
			return
		if motor.ground is StaticPlatform:
			_stop(motor, JUMP_PAUSE, "jump")
		elif _act(motor, "jump"):
			next += 1
	else:
		if _trial:
			_reached_corner = true
		_stop(motor, CORNER_PAUSE, String(wp.action))


func _stop(motor: PlayerMotor, seconds: float, pending: String) -> void:
	motor.holding = false
	_phase = "stop"
	_timer = maxi(int(round(seconds / PlayerMotor.STEP)), 1)
	_pending = pending


func _after_stop(motor: PlayerMotor) -> void:
	match _pending:
		"jump":
			if _act(motor, "jump"):
				next += 1
			_phase = "go"
		"left", "right":
			if _act(motor, _pending):
				next += 1
			# Ré-appuyer : le mouvement ne démarre qu'après le délai d'appui long.
			_stop(motor, TouchControls.HOLD_DELAY, "hold")
		_:
			_phase = "decide"


func _count_wait() -> void:
	_wait_here += PlayerMotor.STEP
	waited += PlayerMotor.STEP


## Essai mental : on rejoue la suite (jusqu'au prochain virage) sur une copie
## du cube, après `delay` pas d'attente, puis on remet le niveau dans son
## état d'origine.
func _try_ahead(motor: PlayerMotor, delay: int) -> bool:
	var saved := data.save_state()
	var ghost := PlayerMotor.new(data)
	ghost.copy_from(motor)
	ghost.holding = false
	for i in delay:
		if ghost.state == PlayerMotor.State.RUNNING:
			ghost.step()
	if ghost.state == PlayerMotor.State.DEAD:
		data.load_state(saved)
		return false
	var trial := LevelBot.new(data, mode)
	trial.offset_for = offset_for
	trial.next = next
	trial._trial = true
	trial._phase = "go"
	var ok := false
	for i in int(LOOKAHEAD / PlayerMotor.STEP):
		trial.control(ghost)
		if trial._reached_corner:
			ok = true
			break
		ghost.step()
		if ghost.state == PlayerMotor.State.WON:
			ok = true
			break
		if ghost.state == PlayerMotor.State.DEAD:
			break
	data.load_state(saved)
	return ok


func _act(motor: PlayerMotor, action: String) -> bool:
	match action:
		"jump":
			return motor.jump()
		"left":
			return motor.turn(-1)
		"right":
			return motor.turn(1)
	return false


## Distance (cases) parcourue au-delà du point d'action, dans sa direction.
func _distance_past(motor: PlayerMotor, wp: Dictionary) -> float:
	var fwd: Vector2 = PlayerMotor.DIRECTIONS[int(wp.dir)]
	return (Vector2(motor.pos.x, motor.pos.z) - Vector2(wp.pos)).dot(fwd)
