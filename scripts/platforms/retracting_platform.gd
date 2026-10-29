class_name RetractingPlatform
extends PlatformBase
## Plateforme qui se rétracte par intermittence : elle s'enfonce dans le vide
## puis remonte. Praticable uniquement quand elle est en haut.

var _block: MeshInstance3D


func is_animated() -> bool:
	return true


func is_solid(t: float) -> bool:
	return cycle_amount(t) < 0.15


func build_visual() -> void:
	_block = make_block(rect.size - Vector2(0.05, 0.05), BLOCK_HEIGHT * 0.6, color)


func update_visual(t: float) -> void:
	if _block == null:
		return
	var k := smoothstep(0.0, 1.0, cycle_amount(t))
	_block.position.y = -BLOCK_HEIGHT * 0.3 - k * 1.6
	var s := 1.0 - 0.35 * k
	_block.scale = Vector3(s, 1.0, s)
