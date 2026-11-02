class_name PlayerMotor
extends RefCounted
## « Moteur » du cube : déplacement manuel et déterministe, sans moteur physique.
##
## Commandes (fournies à chaque pas par le jeu ou par le bot du validateur) :
##   - `holding` : vrai tant que le joueur maintient le doigt -> le cube avance ;
##   - turn(-1 / +1) : quart de tour à gauche / à droite (au sol uniquement) ;
##   - jump() : bond vers l'avant, de longueur fixe (au sol uniquement).
## La simulation avance par pas FIXES de STEP secondes : avec les mêmes
## commandes aux mêmes pas, on obtient toujours exactement le même résultat.
## Le jeu et le script de validation utilisent tous les deux cette classe.

enum State { WAITING, RUNNING, DEAD, WON }
enum Death { NONE, FALL, HIT }

## Pas de simulation (120 pas par seconde).
const STEP := 1.0 / 120.0
## Gravité en cases/s² (une case = 1 unité).
const GRAVITY := 25.0
## Durée d'un saut (s). Pendant le saut, le cube avance à la vitesse du
## niveau : il parcourt donc `vitesse × JUMP_AIRTIME` cases, même s'il était
## arrêté au moment du saut (c'est un « bond » vers l'avant).
const JUMP_AIRTIME := 0.75
## Vitesse verticale au décollage : un tir qui retombe au bout de T vérifie vy = g·T/2.
const JUMP_VELOCITY := GRAVITY * JUMP_AIRTIME * 0.5
## Demi-taille visuelle du cube (le cube fait 0,6 case de côté).
const HALF_SIZE := 0.3
## Demi-taille utilisée pour les pièges : un peu plus petite que le cube
## visible, pour être indulgent (« ça m'a à peine frôlé ! »).
const HAZARD_HALF := 0.22
## En dessous de cette hauteur, le cube ne peut plus remonter sur un bloc : chute.
const FALL_LIMIT := -0.25

## Directions possibles, en (x, z), dans le sens des aiguilles d'une montre
## vu du dessus : 0 = « avant » (-Z, haut de l'écran), 1 = droite (+X),
## 2 = arrière (+Z), 3 = gauche (-X).
const DIRECTIONS := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
const NORTH := 0
const EAST := 1
const SOUTH := 2
const WEST := 3

var level: LevelData
var state := State.WAITING
var death := Death.NONE
var pos := Vector3.ZERO
var dir := NORTH
var vy := 0.0
var grounded := true
var ground: PlatformBase = null
## Vitesse horizontale (x, z) pendant un saut ou une chute.
var air_velocity := Vector2.ZERO
## Commande « avancer » pour le prochain pas.
var holding := false
## Temps du niveau (s) depuis le départ.
var t := 0.0
## Nombre de pas simulés depuis le départ.
var steps := 0

# Événements du dernier pas / de la dernière commande (pour les animations).
var just_jumped := false
var just_landed := false
var just_turned := false
## Le cube a avancé pendant le dernier pas.
var moving := false


func _init(level_data: LevelData) -> void:
	level = level_data
	reset()


func reset() -> void:
	state = State.WAITING
	death = Death.NONE
	pos = level.start_position
	dir = level.start_direction
	vy = 0.0
	grounded = true
	ground = null
	air_velocity = Vector2.ZERO
	holding = false
	t = 0.0
	steps = 0
	moving = false


## Copie complète de l'état (utilisée par le bot pour « essayer » un coup).
func copy_from(other: PlayerMotor) -> void:
	state = other.state
	death = other.death
	pos = other.pos
	dir = other.dir
	vy = other.vy
	grounded = other.grounded
	ground = other.ground
	air_velocity = other.air_velocity
	holding = other.holding
	t = other.t
	steps = other.steps


## Le temps du niveau démarre au premier mouvement ou à la première action.
func start() -> void:
	if state == State.WAITING:
		state = State.RUNNING


## Quart de tour : side = -1 (gauche) ou +1 (droite). Impossible en l'air.
func turn(side: int) -> bool:
	start()
	if state != State.RUNNING or not grounded:
		return false
	dir = posmod(dir + side, 4)
	just_turned = true
	return true


## Bond vers l'avant. Impossible en l'air.
func jump() -> bool:
	start()
	if state != State.RUNNING or not grounded:
		return false
	vy = JUMP_VELOCITY
	air_velocity = forward() * level.speed
	grounded = false
	ground = null
	just_jumped = true
	return true


func forward() -> Vector2:
	return DIRECTIONS[dir]


## Avance la simulation d'un pas fixe.
func step() -> void:
	just_landed = false
	if state != State.RUNNING:
		return
	t += STEP
	steps += 1

	# 1) Déplacement horizontal.
	var vel := air_velocity
	if grounded:
		vel = forward() * level.speed if holding else Vector2.ZERO
		if ground != null:
			vel += ground.get_velocity(t)
	moving = vel.length_squared() > 0.0
	pos.x += vel.x * STEP
	pos.z += vel.y * STEP
	var p := Vector2(pos.x, pos.z)

	# 2) Sol / chute.
	if grounded:
		var g := level.ground_at(p, t)
		if g == null:
			# Plus rien sous le centre du cube : il tombe en gardant son élan.
			grounded = false
			ground = null
			vy = 0.0
			air_velocity = vel
		else:
			ground = g
			g.on_touch(t)
	else:
		vy -= GRAVITY * STEP
		pos.y += vy * STEP
		if pos.y <= 0.0 and vy <= 0.0 and pos.y > FALL_LIMIT:
			var g := level.ground_at(p, t)
			if g != null:
				pos.y = 0.0
				vy = 0.0
				grounded = true
				ground = g
				air_velocity = Vector2.ZERO
				g.on_touch(t)
				just_landed = true
		if not grounded and pos.y <= FALL_LIMIT:
			state = State.DEAD
			death = Death.FALL
			return

	# 3) Pièges.
	if level.is_deadly(pos, HAZARD_HALF, t):
		state = State.DEAD
		death = Death.HIT
		return

	# 4) Arrivée.
	if grounded and level.goal_rect.has_point(p):
		state = State.WON


## Efface les événements « instantanés » (appelé par le jeu après les animations).
func clear_events() -> void:
	just_jumped = false
	just_turned = false
