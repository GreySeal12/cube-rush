class_name LevelButton
extends Button
## Bouton d'un niveau dans la grille : numéro, étoiles obtenues, ou cadenas.

signal level_chosen(number: int)

var number := 1


func setup(n: int, unlocked: bool, stars: int, world_color: Color) -> void:
	number = n
	custom_minimum_size = Vector2(196, 212)
	focus_mode = FOCUS_NONE
	disabled = not unlocked
	text = ""

	var col := world_color if unlocked else Color(0.72, 0.74, 0.8)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = col.darkened(0.12) if state == "pressed" else col
		box.border_color = col.darkened(0.3)
		box.border_width_bottom = 4 if state == "pressed" else 10
		box.set_corner_radius_all(30)
		add_theme_stylebox_override(state, box)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_bottom = -10
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 6)
	add_child(content)

	if unlocked:
		var label := Label.new()
		label.text = str(n)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 84)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", col.darkened(0.35))
		label.add_theme_constant_override("outline_size", 14)
		content.add_child(label)
		var star_row := StarDisplay.new()
		star_row.star_size = 40.0
		star_row.spacing = 4.0
		star_row.set_stars(stars)
		star_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(star_row)
	else:
		var lock := IconDraw.new()
		lock.shape = "lock"
		lock.color = Color(1, 1, 1, 0.95)
		lock.custom_minimum_size = Vector2(96, 96)
		lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(lock)

	pressed.connect(func() -> void: level_chosen.emit(number))
