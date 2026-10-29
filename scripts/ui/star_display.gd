class_name StarDisplay
extends Control
## Affiche une rangée d'étoiles dessinées (pas d'image ni de police spéciale).

@export var total := 3
@export var filled := 0
@export var star_size := 48.0
@export var spacing := 8.0

var _anim_time := -1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_update_size()


func _update_size() -> void:
	custom_minimum_size = Vector2(total * star_size + (total - 1) * spacing, star_size)


## Change le nombre d'étoiles pleines ; `animate` les fait apparaître une à une.
func set_stars(n: int, animate: bool = false) -> void:
	filled = clampi(n, 0, total)
	_anim_time = 0.0 if animate else -1.0
	_update_size()
	queue_redraw()


func _process(delta: float) -> void:
	if _anim_time >= 0.0:
		_anim_time += delta
		queue_redraw()
		if _anim_time > total * 0.3 + 0.6:
			_anim_time = -1.0


func _draw() -> void:
	var start_x := (size.x - custom_minimum_size.x) * 0.5
	for i in total:
		var center := Vector2(start_x + i * (star_size + spacing) + star_size * 0.5, size.y * 0.5)
		var on := i < filled
		var pop := 1.0
		if on and _anim_time >= 0.0:
			# Effet « pop » : chaque étoile grossit puis se pose, l'une après l'autre.
			var k := clampf((_anim_time - i * 0.3) / 0.35, 0.0, 1.0)
			pop = 1.0 + sin(k * PI) * 0.45
			if k <= 0.0:
				_draw_star(center, star_size * 0.5, UiStyle.STAR_OFF)
				continue
		var col := UiStyle.STAR_ON if on else UiStyle.STAR_OFF
		_draw_star(center, star_size * 0.5 * pop, col)


func _draw_star(center: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var r := radius if k % 2 == 0 else radius * 0.48
		var a := -PI / 2.0 + k * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, col.darkened(0.25), maxf(radius * 0.08, 1.5), true)
