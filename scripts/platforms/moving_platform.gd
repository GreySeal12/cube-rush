class_name MovingPlatform
extends PlatformBase
## Plateforme mobile (va-et-vient) : un pont qui coulisse sur le côté du chemin
## puis revient se placer au-dessus du vide. Le générateur règle son cycle pour
## qu'elle soit en place quand le cube arrive (s'il suit bien le centre du chemin).

## Déplacement (x, z) entre la position « en place » et la position écartée.
var displacement := Vector2.ZERO

var _block: MeshInstance3D


func is_animated() -> bool:
	return true


## Avancement du mouvement : 0 = en place, 1 = écartée (avec accélération douce).
func _amount(t: float) -> float:
	return smoothstep(0.0, 1.0, cycle_amount(t))


func get_rect_at(t: float) -> Rect2:
	var r := rect
	r.position += displacement * _amount(t)
	return r


func get_velocity(t: float) -> Vector2:
	# Dérivée numérique de la position : le cube posé dessus est entraîné.
	var h := 0.005
	return displacement * (_amount(t + h) - _amount(t - h)) / (2.0 * h)


func build_visual() -> void:
	_block = make_block(rect.size - Vector2(0.04, 0.04), BLOCK_HEIGHT * 0.5, color)
	# Un dessus plus clair pour la distinguer des sols fixes.
	var stripe := MeshFactory.instance(
		MeshFactory.box(Vector3(rect.size.x * 0.8, 0.03, rect.size.y * 0.8)),
		MeshFactory.material(color.lightened(0.35)))
	stripe.position.y = BLOCK_HEIGHT * 0.25
	_block.add_child(stripe)


func update_visual(t: float) -> void:
	var offset := displacement * _amount(t)
	var c := rect.get_center()
	position = Vector3(c.x + offset.x, 0.0, c.y + offset.y)
