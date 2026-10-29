class_name CrumblePlatform
extends PlatformBase
## Sol fragile : une rangée qui tremble dès que le cube la touche, puis
## s'effondre `delay` secondes plus tard. Impossible de revenir en arrière !

var delay := 0.6
## Temps du niveau au premier contact (-1 = jamais touchée).
var touch_time := -1.0

var _block: MeshInstance3D


func is_animated() -> bool:
	return true


func reset() -> void:
	touch_time = -1.0


func on_touch(t: float) -> void:
	if touch_time < 0.0:
		touch_time = t


func is_solid(t: float) -> bool:
	return touch_time < 0.0 or t < touch_time + delay


func build_visual() -> void:
	# Bloc un peu plus fin et légèrement espacé : on devine qu'il est fragile.
	_block = make_block(rect.size - Vector2(0.06, 0.06), BLOCK_HEIGHT * 0.6, color)


func update_visual(t: float) -> void:
	if _block == null:
		return
	var base_y := -BLOCK_HEIGHT * 0.3
	if touch_time < 0.0 or t < touch_time:
		_block.position = Vector3(0, base_y, 0)
		_block.visible = true
		_block.scale = Vector3.ONE
		return
	var since := t - touch_time
	if since < delay:
		# Tremblement de plus en plus fort.
		var k := since / delay
		var shake := 0.05 * k
		_block.position = Vector3(sin(t * 70.0) * shake, base_y - 0.04 * k, cos(t * 63.0) * shake)
	else:
		# Chute accélérée puis disparition.
		var fall := since - delay
		_block.position = Vector3(0, base_y - 12.0 * fall * fall, 0)
		_block.scale = Vector3.ONE * maxf(1.0 - fall * 1.2, 0.05)
		_block.visible = fall < 0.9
