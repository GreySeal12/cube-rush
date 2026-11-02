class_name IconDraw
extends Control
## Petites icônes dessinées en code (cadenas, flèche retour…).

@export_enum("lock", "back", "star", "turn_left", "turn_right", "jump") var shape := "lock"
@export var color := Color.WHITE
## Dessine d'abord une version sombre décalée (lisible sur fond clair).
@export var outline := false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	if outline:
		_draw_shape(size * 0.5 + Vector2(2, 3), Color(0.1, 0.1, 0.2, 0.6))
	_draw_shape(size * 0.5, color)


func _draw_shape(c: Vector2, col: Color) -> void:
	var s := minf(size.x, size.y)
	match shape:
		"lock":
			var body := Rect2(c + Vector2(-s * 0.32, -s * 0.05), Vector2(s * 0.64, s * 0.45))
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 16, col, s * 0.09, true)
			draw_rect(body, col)
			draw_circle(body.get_center() + Vector2(0, -s * 0.03), s * 0.06, col.darkened(0.5))
		"back":
			var w := s * 0.11
			draw_line(c + Vector2(s * 0.12, -s * 0.28), c + Vector2(-s * 0.16, 0), col, w, true)
			draw_line(c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.12, s * 0.28), col, w, true)
			draw_circle(c + Vector2(-s * 0.16, 0), w * 0.5, col)
		"turn_left", "turn_right":
			# Flèche coudée : on avance puis on tourne.
			var sx := -1.0 if shape == "turn_left" else 1.0
			var w := s * 0.12
			var a := c + Vector2(-sx * s * 0.12, s * 0.38)
			var b := c + Vector2(-sx * s * 0.12, -s * 0.05)
			var tip := c + Vector2(sx * s * 0.34, -s * 0.05)
			draw_polyline(PackedVector2Array([a, b, tip]), col, w, true)
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(sx * s * 0.12, 0), tip + Vector2(-sx * s * 0.1, -s * 0.18),
				tip + Vector2(-sx * s * 0.1, s * 0.18)]), col)
		"jump":
			# Arc de saut terminé par une flèche.
			var w := s * 0.11
			draw_arc(c + Vector2(0, s * 0.25), s * 0.36, PI + 0.35, TAU - 0.35, 16, col, w, true)
			draw_circle(c + Vector2(-s * 0.34, s * 0.37), w * 0.7, col)
			var tip := c + Vector2(s * 0.36, s * 0.16)
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(0.0, s * 0.2), tip + Vector2(-s * 0.16, -s * 0.04),
				tip + Vector2(s * 0.14, -s * 0.06)]), col)
		"star":
			var pts := PackedVector2Array()
			for k in 10:
				var r := s * 0.48 if k % 2 == 0 else s * 0.23
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, col)
