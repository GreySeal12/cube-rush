extends Control
## Sélection des niveaux : grille des 10 niveaux, étoiles, niveaux verrouillés.

@onready var background: TextureRect = $Background
@onready var margin: MarginContainer = $Margin
@onready var scroll: ScrollContainer = $Margin/Column/Scroll
@onready var grid: GridContainer = $Margin/Column/Scroll/Grid
@onready var back_button: Button = $Margin/Column/Header/BackButton
@onready var title: Label = $Margin/Column/Header/Title
@onready var star_count: Label = $Margin/Column/Header/StarCount


func _ready() -> void:
	theme = UiStyle.get_theme()
	background.texture = UiStyle.gradient_texture(Color("6ec3f5"), Color("fde7f3"))
	for label in [title, star_count]:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.15, 0.2, 0.4, 0.6))
		label.add_theme_constant_override("outline_size", 12)
	UiStyle.make_secondary(back_button)
	back_button.pressed.connect(GameManager.go_to_menu)

	var safe := UiStyle.safe_margins(self)
	margin.add_theme_constant_override("margin_top", 24 + int(safe.top))
	margin.add_theme_constant_override("margin_bottom", 24 + int(safe.bottom))

	star_count.text = "%d/%d" % [SaveManager.total_stars(), GameManager.level_count() * 3]
	# Au doigt : un petit glissement fait défiler la grille au lieu d'appuyer.
	scroll.scroll_deadzone = 16
	var focus_level := GameManager.next_level_to_play()
	var focus_button: Control = null
	for n in range(1, GameManager.level_count() + 1):
		var cfg := LevelDatabase.get_level(n)
		var world := LevelDatabase.get_theme(String(cfg.get("theme", "ciel")))
		var button := LevelButton.new()
		button.setup(n, SaveManager.is_unlocked(n), SaveManager.get_stars(n),
			world.get("platform_a", UiStyle.SECONDARY))
		button.level_chosen.connect(GameManager.start_level)
		grid.add_child(button)
		if n == focus_level:
			focus_button = button

	# Avec 30 niveaux la grille défile : on amène le prochain niveau à l'écran.
	if focus_button != null:
		await get_tree().process_frame
		scroll.ensure_control_visible(focus_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		GameManager.go_to_menu()
