extends Node3D
## Scène de jeu : construit le niveau, fait avancer la simulation à pas fixes,
## gère chutes, redémarrages, pause et fin de niveau.

## Durée de l'animation de chute avant le redémarrage (< 1 s exigé).
const RESTART_DELAY := 0.7
## Au-delà de ce retard (téléphone qui rame, appli en arrière-plan), on ne
## rattrape pas tout : évite une avalanche de pas d'un coup.
const MAX_FRAME_TIME := 0.1

@onready var camera: CameraFollow = $Camera
@onready var level_root: Node3D = $LevelRoot
@onready var player: Player = $Player
@onready var environment: WorldEnvironment = $WorldEnvironment
@onready var background: TextureRect = $Background/Gradient
@onready var hud: Control = $HUD/Root

var level_number := 1
var level: LevelData
var motor: PlayerMotor
var crown: Crown
var deaths := 0

var _accumulator := 0.0
var _restart_timer := -1.0
var _finished := false


func _ready() -> void:
	level_number = GameManager.current_level
	var cfg := LevelDatabase.get_level(level_number)
	var theme := LevelDatabase.get_theme(String(cfg.get("theme", "ciel")))
	level = LevelGenerator.generate(cfg, theme)
	level_root.add_child(level.root)

	crown = Crown.new()
	crown.position = level.crown_position
	level_root.add_child(crown)

	_apply_theme(theme)
	motor = PlayerMotor.new(level)
	player.reset_visual(motor)
	camera.snap_to(motor.pos)
	hud.set_level(level_number)
	hud.set_deaths(deaths)
	hud.show_hint(true)


func _apply_theme(theme: Dictionary) -> void:
	background.texture = UiStyle.gradient_texture(
		theme.get("bg_top", Color.SKY_BLUE), theme.get("bg_bottom", Color.WHITE))

	# Lumière unique, sans ombre : le dessus des blocs est le plus clair,
	# les deux faces visibles ont chacune leur teinte (effet isométrique).
	$Sun.look_at_from_position(Vector3(-1, 4, 2), Vector3.ZERO)
	var env := environment.environment
	env.ambient_light_color = theme.get("ambient", Color(0.75, 0.8, 0.9))


func _process(delta: float) -> void:
	if _finished:
		player.sync_with(motor, delta)
		return
	if _restart_timer >= 0.0:
		_restart_timer -= delta
		player.sync_with(motor, delta)
		if _restart_timer < 0.0:
			_restart()
		return

	if motor.state == PlayerMotor.State.RUNNING:
		# Simulation à pas fixes : identique quelle que soit la fréquence d'affichage.
		_accumulator += minf(delta, MAX_FRAME_TIME)
		while _accumulator >= PlayerMotor.STEP and motor.state == PlayerMotor.State.RUNNING:
			motor.step()
			_accumulator -= PlayerMotor.STEP
			_on_step_events()

	level.update_visuals(motor.t)
	player.sync_with(motor, delta)
	if motor.state != PlayerMotor.State.DEAD:
		camera.follow(motor.pos, delta)

	match motor.state:
		PlayerMotor.State.DEAD:
			_on_death()
		PlayerMotor.State.WON:
			_on_win()


func _on_step_events() -> void:
	# Réservé aux effets liés aux pas de simulation (sons plus tard, etc.).
	pass


func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		tapped = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var key := event as InputEventKey
		tapped = key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_UP, KEY_ENTER]
	if not tapped:
		return
	get_viewport().set_input_as_handled()
	_on_tap()


func _on_tap() -> void:
	if _finished or _restart_timer >= 0.0:
		return
	if motor.state == PlayerMotor.State.WAITING:
		motor.start()
		_accumulator = 0.0
		hud.show_hint(false)
	else:
		motor.tap()


func _on_death() -> void:
	deaths += 1
	hud.set_deaths(deaths)
	player.play_death(motor, level.theme.get("platform_a", Color.WHITE))
	# Tant que ce minuteur tourne, _process ne relance pas _on_death().
	_restart_timer = RESTART_DELAY
	_accumulator = 0.0


func _restart() -> void:
	_restart_timer = -1.0
	level.reset()
	motor.reset()
	crown.reset()
	player.reset_visual(motor)
	camera.snap_to(motor.pos)
	level.update_visuals(0.0)
	hud.show_hint(true)


func _on_win() -> void:
	_finished = true
	crown.collect()
	player.play_win(Crown.GOLD)
	var stars := GameManager.compute_stars(deaths, level.config)
	GameManager.on_level_completed(level_number, stars)
	hud.show_hint(false)
	await get_tree().create_timer(0.8).timeout
	hud.show_complete(stars)
