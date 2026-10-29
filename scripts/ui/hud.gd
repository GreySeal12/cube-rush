extends Control
## Interface en jeu : numéro du niveau, nombre de chutes, bouton pause, aide.

signal pause_pressed

@onready var level_label: Label = $TopBar/Row/Info/LevelLabel
@onready var deaths_label: Label = $TopBar/Row/Info/DeathsLabel
@onready var pause_button: Button = $TopBar/Row/PauseButton
@onready var hint: Label = $Hint
@onready var top_bar: MarginContainer = $TopBar

var _hint_time := 0.0


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


func _process(delta: float) -> void:
	if hint.visible:
		_hint_time += delta
		hint.modulate.a = 0.65 + 0.35 * sin(_hint_time * 4.0)


func set_level(n: int) -> void:
	level_label.text = "Niveau %d" % n


func set_deaths(n: int) -> void:
	deaths_label.text = "Chutes : %d" % n


func show_hint(on: bool) -> void:
	hint.visible = on
	_hint_time = 0.0


func show_complete(_stars: int) -> void:
	hint.text = "NIVEAU TERMINÉ !"
	hint.visible = true
