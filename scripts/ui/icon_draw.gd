class_name IconDraw
extends Control
## Petites icônes dessinées en code (cadenas, flèche retour…).

@export_enum("lock", "back", "star") var shape := "lock"
@export var color := Color.WHITE


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match shape:
		"lock":
			var body := Rect2(c + Vector2(-s * 0.32, -s * 0.05), Vector2(s * 0.64, s * 0.45))
			draw_arc(c + Vector2(0, -s * 0.08), s * 0.2, PI, TAU, 16, color, s * 0.09, true)
			draw_rect(body, color)
			draw_circle(body.get_center() + Vector2(0, -s * 0.03), s * 0.06, color.darkened(0.5))
		"back":
			var w := s * 0.11
			draw_line(c + Vector2(s * 0.12, -s * 0.28), c + Vector2(-s * 0.16, 0), color, w, true)
			draw_line(c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.12, s * 0.28), color, w, true)
			draw_circle(c + Vector2(-s * 0.16, 0), w * 0.5, color)
		"star":
			var pts := PackedVector2Array()
			for k in 10:
				var r := s * 0.48 if k % 2 == 0 else s * 0.23
				var a := -PI / 2.0 + k * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, color)
