extends Control
## Interface en jeu : numéro du niveau, nombre de chutes, bouton pause, aide.

signal pause_pressed

@onready var level_label: Label = $TopBar/Row/Info/LevelLabel
@onready var deaths_label: Label = $TopBar/Row/Info/DeathsLabel
@onready var pause_button: Button = $TopBar/Row/PauseButton
@onready var hint: Label = $Hint
@onready var top_bar: MarginContainer = $TopBar

var _hint_time := 0.0
## Barre du bas : une case par zone tactile (gauche / milieu / droite).
var _zones: Dictionary = {}
var _zone_flash: Dictionary = {}

const ZONE_ALPHA := 0.75


func _ready() -> void:
	theme = UiStyle.get_theme()
	for label in [level_label, deaths_label, hint]:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2, 0.75))
		label.add_theme_constant_override("outline_size", 12)
	UiStyle.make_secondary(pause_button)
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	# Décale la barre du haut sous l'encoche éventuelle.
	var safe := UiStyle.safe_margins(self)
	top_bar.add_theme_constant_override("margin_top", 24 + int(safe.top))
	top_bar.add_theme_constant_override("margin_left", 28 + int(safe.left))
	top_bar.add_theme_constant_override("margin_right", 28 + int(safe.right))
	_build_zone_bar(safe.bottom)
	show_hint(true)


## Rappel des commandes en bas de l'écran, aligné sur les zones tactiles
## (voir TouchControls.SIDE_ZONE).
func _build_zone_bar(safe_bottom: float) -> void:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -150.0 - safe_bottom
	bar.offset_bottom = -12.0 - safe_bottom
	bar.add_theme_constant_override("separation", 0)
	add_child(bar)
	var specs := [["left", "turn_left", "Tourner", TouchControls.SIDE_ZONE],
		["jump", "jump", "Sauter", 1.0 - 2.0 * TouchControls.SIDE_ZONE],
		["right", "turn_right", "Tourner", TouchControls.SIDE_ZONE]]
	for spec in specs:
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = spec[3]
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		var icon := IconDraw.new()
		icon.shape = spec[1]
		icon.outline = true
		icon.custom_minimum_size = Vector2(70, 70)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		var label := Label.new()
		label.text = spec[2]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 26)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2, 0.85))
		label.add_theme_constant_override("outline_size", 10)
		box.add_child(label)
		box.modulate.a = ZONE_ALPHA
		bar.add_child(box)
		_zones[spec[0]] = box
		_zone_flash[spec[0]] = 0.0


## Illumine brièvement la zone utilisée.
func flash_zone(zone: String) -> void:
	if _zone_flash.has(zone):
		_zone_flash[zone] = 1.0


## Rectangle du bouton pause, en coordonnées d'écran.
func pause_button_rect() -> Rect2:
	return pause_button.get_global_rect().grow(12)


func _process(delta: float) -> void:
	for zone in _zone_flash:
		_zone_flash[zone] = maxf(_zone_flash[zone] - delta * 3.0, 0.0)
		_zones[zone].modulate.a = lerpf(ZONE_ALPHA, 1.0, _zone_flash[zone])
		var s: float = 1.0 + 0.15 * _zone_flash[zone]
		_zones[zone].pivot_offset = _zones[zone].size * 0.5
		_zones[zone].scale = Vector2(s, s)
	if hint.visible:
		_hint_time += delta
		hint.modulate.a = 0.65 + 0.35 * sin(_hint_time * 4.0)


func set_level(n: int) -> void:
	level_label.text = "Niveau %d" % n


func set_deaths(n: int) -> void:
	deaths_label.text = "Chutes : %d" % n


func show_hint(on: bool, text: String = "Maintenez le doigt pour avancer") -> void:
	hint.text = text
	hint.visible = on
	_hint_time = 0.0


func set_pause_visible(on: bool) -> void:
	pause_button.visible = on
	for zone in _zones.values():
		zone.visible = on
