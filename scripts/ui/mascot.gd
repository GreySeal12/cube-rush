class_name Mascot
extends Control
## Le cube kawaii du menu principal, dessiné en 2D : il rebondit et cligne des yeux.

var _time := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) * 0.7
	var bounce := absf(sin(_time * 3.0))
	var squash := 1.0 - (1.0 - bounce) * 0.12
	var w := s * (2.0 - squash)
	var h := s * squash
	var base := Vector2(size.x * 0.5, size.y * 0.92)
	# Ombre au sol.
	var shadow_w := w * (0.9 - bounce * 0.25)
	draw_set_transform(base, 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, shadow_w * 0.5, Color(0, 0, 0, 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top_left := base + Vector2(-w * 0.5, -h - bounce * s * 0.35)
	var body := Rect2(top_left, Vector2(w, h))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.99, 0.99, 1.0)
	box.set_corner_radius_all(int(s * 0.22))
	box.border_color = Color(0.82, 0.86, 0.95)
	box.border_width_bottom = int(s * 0.06)
	draw_style_box(box, body)
	# Yeux (clignent toutes les 3 secondes) et joues.
	var eye_y := body.position.y + h * 0.42
	var blink := fmod(_time, 3.0) < 0.12
	for side in [-1.0, 1.0]:
		var eye := Vector2(body.get_center().x + side * w * 0.18, eye_y)
		if blink:
			draw_line(eye + Vector2(-s * 0.05, 0), eye + Vector2(s * 0.05, 0), Color(0.1, 0.1, 0.15), s * 0.03, true)
		else:
			draw_circle(eye, s * 0.055, Color(0.1, 0.1, 0.15))
			draw_circle(eye + Vector2(-s * 0.018, -s * 0.02), s * 0.017, Color.WHITE)
		draw_set_transform(Vector2(body.get_center().x + side * w * 0.3, eye_y + h * 0.15), 0.0, Vector2(1.0, 0.6))
		draw_circle(Vector2.ZERO, s * 0.06, Color(1.0, 0.6, 0.72, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Petite bouche.
	var mouth := Vector2(body.get_center().x, eye_y + h * 0.12)
	draw_arc(mouth, s * 0.05, 0.2, PI - 0.2, 10, Color(0.1, 0.1, 0.15), s * 0.022, true)
