class_name SpikeTrap
extends PlatformBase
## Pointes : fixes (toujours sorties) ou périodiques (elles sortent et rentrent).
## Le cube meurt s'il touche une case dont les pointes sont sorties.

const HEIGHT := 0.42
const INSET := 0.12

## true = pointes qui sortent et rentrent selon le cycle ; false = toujours sorties.
var periodic := false
var plate_color := Color(0.15, 0.15, 0.2)

var _spikes: Array[MeshInstance3D] = []


func _init() -> void:
	provides_ground = false


func is_animated() -> bool:
	return periodic


## 0 = pointes rentrées, 1 = sorties.
func extension(t: float) -> float:
	return cycle_amount(t) if periodic else 1.0


func is_deadly(center: Vector3, half: float, t: float) -> bool:
	if extension(t) < 0.5 or center.y > HEIGHT:
		return false
	return PlatformBase.overlaps(center, half, rect.grow(-INSET))


func build_visual() -> void:
	# Une plaque sombre signale l'emplacement, puis une grappe de 4 pointes par case.
	var plate := MeshFactory.instance(
		MeshFactory.box(Vector3(rect.size.x - 0.1, 0.02, rect.size.y - 0.1)),
		MeshFactory.material(plate_color))
	plate.position.y = 0.01
	add_child(plate)
	var cells_x := int(round(rect.size.x))
	var cells_z := int(round(rect.size.y))
	for ix in cells_x:
		for iz in cells_z:
			var s := MeshFactory.instance(MeshFactory.spike_cluster(HEIGHT), MeshFactory.material(color))
			s.position = Vector3(ix + 0.5 - rect.size.x * 0.5, 0.0, iz + 0.5 - rect.size.y * 0.5)
			add_child(s)
			_spikes.append(s)


func update_visual(t: float) -> void:
	var k := smoothstep(0.0, 1.0, extension(t))
	for s in _spikes:
		s.position.y = -HEIGHT * (1.0 - k) - 0.02 * (1.0 - k)
