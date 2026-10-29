extends Control
## Menu principal : logo, gros bouton Jouer, accès à la sélection des niveaux.

@onready var background: TextureRect = $Background
@onready var title: Label = $Center/Title
@onready var subtitle: Label = $Center/Subtitle
@onready var play_button: Button = $Center/PlayButton
@onready var levels_button: Button = $Center/LevelsButton
@onready var progress: Label = $Center/Progress

var _time := 0.0


func _ready() -> void:
	theme = UiStyle.get_theme()
	background.texture = UiStyle.gradient_texture(Color("6ec3f5"), Color("fde7f3"))
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", UiStyle.PRIMARY_DARK)
	title.add_theme_constant_override("outline_size", 26)
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.2, 0.4, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 10)
	subtitle.add_theme_color_override("font_color", Color(0.18, 0.25, 0.45))
	UiStyle.make_secondary(levels_button)
	play_button.pressed.connect(_on_play)
	levels_button.pressed.connect(GameManager.go_to_level_select)
	progress.text = "%d / %d étoiles" % [SaveManager.total_stars(), GameManager.level_count() * 3]
	progress.add_theme_color_override("font_color", Color(0.18, 0.25, 0.45))


func _process(delta: float) -> void:
	# Le bouton Jouer « respire » doucement pour attirer le pouce.
	_time += delta
	var s := 1.0 + sin(_time * 3.0) * 0.03
	play_button.pivot_offset = play_button.size * 0.5
	play_button.scale = Vector2(s, s)


func _on_play() -> void:
	GameManager.start_level(GameManager.next_level_to_play())


func _notification(what: int) -> void:
	# Bouton « retour » d'Android sur le menu principal : on quitte le jeu.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()
