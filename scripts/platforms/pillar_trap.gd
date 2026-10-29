class_name PillarTrap
extends PlatformBase
## Pilier : obstacle fixe posé sur le côté du chemin. Le toucher = échec.
## (Dans la forêt, il ressemble à un petit arbre cubique.)

const HEIGHT := 1.6

var top_color := Color.WHITE


func _init() -> void:
	provides_ground = false


func is_deadly(center: Vector3, half: float, _t: float) -> bool:
	return center.y < HEIGHT and PlatformBase.overlaps(center, half, rect)


func build_visual() -> void:
	var trunk := MeshFactory.instance(
		MeshFactory.box(Vector3(rect.size.x, HEIGHT, rect.size.y)), MeshFactory.material(color))
	trunk.position.y = HEIGHT * 0.5
	add_child(trunk)
	var cap := MeshFactory.instance(
		MeshFactory.box(Vector3(rect.size.x + 0.2, 0.5, rect.size.y + 0.2)), MeshFactory.material(top_color))
	cap.position.y = HEIGHT - 0.1
	add_child(cap)
