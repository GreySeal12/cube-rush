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
@onready var pause_layer: CanvasLayer = $PauseMenu
@onready var pause_menu: Control = $PauseMenu/Root
@onready var complete_layer: CanvasLayer = $LevelComplete
@onready var complete_menu: Control = $LevelComplete/Root

var level_number := 1
var level: LevelData
var motor: PlayerMotor
var crown: Crown
var deaths := 0
## Commandes tactiles / clavier.
var controls: TouchControls
## Pilote automatique (outils de test, future démo). null en jeu normal.
var autopilot: LevelBot = null

var _lava_glow: TextureRect
var _time := 0.0
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
	camera.snap_to(motor.pos, _side_heading())
	hud.set_level(level_number)
	hud.set_deaths(deaths)
	hud.show_hint(true)

	controls = TouchControls.new()
	add_child(controls)
	controls.action.connect(_on_action)
	# Un toucher sur le bouton pause ne doit pas faire tourner le cube.
	_update_ignore_rects.call_deferred()

	hud.pause_pressed.connect(pause_game)
	pause_menu.resume_requested.connect(resume_game)
	pause_menu.restart_requested.connect(func() -> void: GameManager.start_level(level_number))
	pause_menu.menu_requested.connect(GameManager.go_to_menu)
	complete_menu.next_requested.connect(_on_next)
	complete_menu.replay_requested.connect(func() -> void: GameManager.start_level(level_number))
	complete_menu.menu_requested.connect(GameManager.go_to_level_select)


func _apply_theme(theme: Dictionary) -> void:
	background.texture = UiStyle.gradient_texture(
		theme.get("bg_top", Color.SKY_BLUE), theme.get("bg_bottom", Color.WHITE))

	if theme.get("lava", false):
		_add_lava(theme.get("lava_color", Color.ORANGE_RED))

	# Lumière unique, sans ombre : le dessus des blocs est le plus clair,
	# les deux faces visibles (avant et côté) ont chacune leur teinte.
	$Sun.look_at_from_position(Vector3(1.5, 4, 3), Vector3.ZERO)
	var env := environment.environment
	env.ambient_light_color = theme.get("ambient", Color(0.75, 0.8, 0.9))


## Volcan : une lueur de lave qui pulse en bas de l'écran et des braises qui
## montent. Tout est dessiné en 2D dans le fond : presque gratuit pour le GPU.
func _add_lava(lava: Color) -> void:
	var layer := $Background as CanvasLayer
	_lava_glow = TextureRect.new()
	var transparent := lava
	transparent.a = 0.0
	_lava_glow.texture = UiStyle.gradient_texture(transparent, lava)
	_lava_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_lava_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_lava_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lava_glow.anchor_left = 0.0
	_lava_glow.anchor_right = 1.0
	_lava_glow.anchor_top = 0.55
	_lava_glow.anchor_bottom = 1.0
	layer.add_child(_lava_glow)

	var embers := CPUParticles2D.new()
	embers.amount = 24
	embers.lifetime = 4.0
	embers.preprocess = 4.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	var view := get_viewport().get_visible_rect().size
	embers.position = Vector2(view.x * 0.5, view.y + 20.0)
	embers.emission_rect_extents = Vector2(view.x * 0.55, 10.0)
	embers.direction = Vector2(0, -1)
	embers.spread = 15.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 80.0
	embers.initial_velocity_max = 180.0
	embers.scale_amount_min = 3.0
	embers.scale_amount_max = 7.0
	embers.color = lava.lightened(0.3)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	embers.color_ramp = fade
	layer.add_child(embers)


func _process(delta: float) -> void:
	_time += delta
	if _lava_glow != null:
		_lava_glow.modulate.a = 0.75 + 0.25 * sin(_time * 1.7)
	if _finished:
		player.sync_with(motor, delta)
		return
	if _restart_timer >= 0.0:
		_restart_timer -= delta
		player.sync_with(motor, delta)
		if _restart_timer < 0.0:
			_restart()
		return

	# Le niveau démarre au premier appui long (ou à la première action).
	if motor.state == PlayerMotor.State.WAITING and _wants_to_move():
		_begin()

	if motor.state == PlayerMotor.State.RUNNING:
		# Simulation à pas fixes : identique quelle que soit la fréquence d'affichage.
		_accumulator += minf(delta, MAX_FRAME_TIME)
		while _accumulator >= PlayerMotor.STEP and motor.state == PlayerMotor.State.RUNNING:
			if autopilot != null:
				autopilot.control(motor)
			else:
				motor.holding = controls.is_holding()
			motor.step()
			_accumulator -= PlayerMotor.STEP
			_on_step_events()

	level.update_visuals(motor.t, motor.pos)
	player.sync_with(motor, delta)
	motor.clear_events()
	if motor.state != PlayerMotor.State.DEAD:
		camera.follow(motor.pos, delta, _side_heading())

	match motor.state:
		PlayerMotor.State.DEAD:
			_on_death()
		PlayerMotor.State.WON:
			_on_win()


func _on_step_events() -> void:
	# Réservé aux effets liés aux pas de simulation (sons plus tard, etc.).
	pass


func _unhandled_input(event: InputEvent) -> void:
	if controls.handle(event):
		get_viewport().set_input_as_handled()


## Direction latérale du cube (zéro s'il va vers l'avant), pour la caméra.
func _side_heading() -> Vector2:
	var f := motor.forward()
	return Vector2(f.x, 0.0)


func _wants_to_move() -> bool:
	if autopilot != null:
		return true
	return controls.is_holding()


func _begin() -> void:
	motor.start()
	_accumulator = 0.0
	hud.show_hint(false)


## Tap court : tourner à gauche / à droite, ou sauter.
func _on_action(action_name: String) -> void:
	if _finished or _restart_timer >= 0.0 or get_tree().paused or autopilot != null:
		return
	if motor.state == PlayerMotor.State.WAITING:
		_begin()
	match action_name:
		"left":
			motor.turn(-1)
		"right":
			motor.turn(1)
		"jump":
			motor.jump()
	hud.flash_zone(action_name)


func _update_ignore_rects() -> void:
	controls.ignore_rects = [hud.pause_button_rect()]


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
	camera.snap_to(motor.pos, _side_heading())
	level.update_visuals(0.0)
	# Il faut reposer le doigt pour repartir (pas de départ involontaire).
	controls.clear()
	hud.show_hint(true, "Maintenez pour repartir")


func _on_win() -> void:
	_finished = true
	crown.collect()
	player.play_win(Crown.GOLD)
	var stars := GameManager.compute_stars(deaths, level.config)
	GameManager.on_level_completed(level_number, stars)
	hud.show_hint(false)
	hud.set_pause_visible(false)
	await get_tree().create_timer(0.8).timeout
	complete_layer.visible = true
	complete_menu.present(stars, deaths, not GameManager.has_next_level(level_number))


func _on_next() -> void:
	if GameManager.has_next_level(level_number):
		GameManager.start_level(level_number + 1)
	else:
		GameManager.go_to_menu()


# ---------------------------------------------------------------------------
# Pause
# ---------------------------------------------------------------------------

func pause_game() -> void:
	if _finished or get_tree().paused:
		return
	get_tree().paused = true
	pause_layer.visible = true


func resume_game() -> void:
	pause_layer.visible = false
	get_tree().paused = false
	controls.clear()
	# On ne rattrape pas le temps passé en pause.
	_accumulator = 0.0


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Bouton « retour » d'Android : pause, ou reprise si déjà en pause.
			if get_tree().paused:
				resume_game()
			elif _finished:
				GameManager.go_to_level_select()
			else:
				pause_game()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Appel entrant, appli en arrière-plan… : pause automatique en cours de partie.
			if motor != null and motor.state == PlayerMotor.State.RUNNING:
				pause_game()
