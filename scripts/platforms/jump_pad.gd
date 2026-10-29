class_name JumpPad
extends PlatformBase
## Tremplin : dès que le centre du cube arrive dessus, il est propulsé vers le
## haut et franchit le trou qui suit. La vitesse verticale est calculée par le
## générateur pour que le cube retombe au milieu de la première rangée après
## le trou (voir LevelGenerator.jump_velocity_for_gap()).

var jump_velocity := 0.0
## Direction du chemin (x, z), pour orienter les chevrons.
var travel := Vector2(1, 0)
var accent := Color.WHITE

var _chevrons: Array[MeshInstance3D] = []


func get_jump_velocity() -> float:
	return jump_velocity


func build_visual() -> void:
	make_block(rect.size, BLOCK_HEIGHT, color)
	# Deux chevrons qui « pointent » vers le trou.
	var yaw := atan2(-travel.x, -travel.y)
	for i in 2:
		var c := MeshFactory.instance(MeshFactory.chevron(), MeshFactory.material(accent, 0.3))
		c.rotation.y = yaw
		var along := -0.18 + 0.36 * i
		c.position = Vector3(travel.x * along, 0.03, travel.y * along)
		add_child(c)
		_chevrons.append(c)


func update_visual(t: float) -> void:
	# Petite pulsation pour attirer l'œil.
	for i in _chevrons.size():
		var s := 1.0 + 0.12 * sin(t * 8.0 - i * 1.5)
		_chevrons[i].scale = Vector3(s, 1, s)
