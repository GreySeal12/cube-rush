class_name RotatingPlatform
extends PlatformBase
## Plateforme rotative : un panneau qui pivote d'un demi-tour autour de l'axe
## du chemin. Praticable seulement quand il est à plat.

## Direction du chemin (x, z) : axe de rotation du panneau.
var travel := Vector2(1, 0)
var accent := Color.WHITE

const THICKNESS := 0.35

var _pivot: Node3D


func is_animated() -> bool:
	return true


## Angle du panneau (0 = à plat, PI = retourné, donc à plat aussi).
func angle_at(t: float) -> float:
	var ph := cycle_phase(t)
	if ph < cycle_safe:
		return 0.0
	var progress := (ph - cycle_safe) / (cycle_period - cycle_safe)
	return PI * smoothstep(0.0, 1.0, progress)


func is_solid(t: float) -> bool:
	var a := angle_at(t)
	return a < 0.15 or a > PI - 0.15


func build_visual() -> void:
	_pivot = Node3D.new()
	_pivot.position.y = -THICKNESS * 0.5
	add_child(_pivot)
	var slab := MeshFactory.instance(
		MeshFactory.box(Vector3(rect.size.x - 0.05, THICKNESS, rect.size.y - 0.05)),
		MeshFactory.material(color))
	_pivot.add_child(slab)
	# Une bande sur chaque face pour bien voir la rotation.
	for side in [1.0, -1.0]:
		var band := MeshFactory.instance(
			MeshFactory.box(Vector3(maxf(rect.size.x - 0.5, 0.2), 0.02, maxf(rect.size.y - 0.5, 0.2))),
			MeshFactory.material(accent))
		band.position.y = side * (THICKNESS * 0.5 + 0.005)
		_pivot.add_child(band)


func update_visual(t: float) -> void:
	if _pivot == null:
		return
	_pivot.rotation = Vector3.ZERO
	_pivot.rotate(Vector3(travel.x, 0, travel.y), angle_at(t))
