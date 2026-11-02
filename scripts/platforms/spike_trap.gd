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
	# Les pointes latérales peuvent être rognées (cases de moins d'1×1) :
	# chaque grappe est mise à l'échelle de sa case pour coller à la zone mortelle.
	var cells_x := maxi(int(round(rect.size.x)), 1)
	var cells_z := maxi(int(round(rect.size.y)), 1)
	var cell := Vector2(rect.size.x / cells_x, rect.size.y / cells_z)
	for ix in cells_x:
		for iz in cells_z:
			var s := MeshFactory.instance(MeshFactory.spike_cluster(HEIGHT), MeshFactory.material(color))
			s.position = Vector3((ix + 0.5) * cell.x - rect.size.x * 0.5, 0.0,
				(iz + 0.5) * cell.y - rect.size.y * 0.5)
			s.scale = Vector3(cell.x, 1.0, cell.y)
			add_child(s)
			_spikes.append(s)


func update_visual(t: float) -> void:
	var k := smoothstep(0.0, 1.0, extension(t))
	for s in _spikes:
		s.position.y = -HEIGHT * (1.0 - k) - 0.02 * (1.0 - k)
