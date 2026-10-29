extends Control
## Écran de fin de niveau : « NIVEAU TERMINÉ ! », étoiles, bouton Suivant.

signal next_requested
signal replay_requested
signal menu_requested

@onready var title: Label = $Panel/Column/Title
@onready var stars: StarDisplay = $Panel/Column/Stars
@onready var info: Label = $Panel/Column/Info
@onready var next_button: Button = $Panel/Column/NextButton
@onready var replay_button: Button = $Panel/Column/Row/ReplayButton
@onready var menu_button: Button = $Panel/Column/Row/MenuButton


func _ready() -> void:
	theme = UiStyle.get_theme()
	title.add_theme_color_override("font_color", UiStyle.PRIMARY_DARK)
	UiStyle.make_secondary(replay_button)
	UiStyle.make_secondary(menu_button)
	next_button.pressed.connect(func() -> void: next_requested.emit())
	replay_button.pressed.connect(func() -> void: replay_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())


## Affiche le résultat. `is_last` : plus de niveau suivant.
func present(star_count: int, deaths: int, is_last: bool) -> void:
	stars.set_stars(star_count, true)
	var tries := "Du premier coup !" if deaths == 0 else ("%d chute%s" % [deaths, "s" if deaths > 1 else ""])
	info.text = tries
	if is_last:
		info.text += "\nBravo, vous avez fini tous les niveaux !"
		next_button.text = "Menu"
	# Petit effet d'apparition.
	var panel := $Panel as Control
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.7, 0.7)
	var tween := create_tween()
	tween.tween_property(panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
