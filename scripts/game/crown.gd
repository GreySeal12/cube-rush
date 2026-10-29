class_name Crown
extends Node3D
## Couronne dorée low-poly, assemblée à partir de primitives :
## un anneau (cylindre à 8 côtés), 5 pointes (pyramides) et des gemmes.

const GOLD := Color(1.0, 0.78, 0.18)

var _model: Node3D
var _time := 0.0
var _collected := false
var _collect_time := 0.0


func _ready() -> void:
	_model = Node3D.new()
	add_child(_model)
	var gold := MeshFactory.material(GOLD, 0.35)

	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.34
	ring_mesh.bottom_radius = 0.3
	ring_mesh.height = 0.22
	ring_mesh.radial_segments = 8
	ring_mesh.rings = 1
	var ring := MeshFactory.instance(ring_mesh, gold)
	_model.add_child(ring)

	var gem_colors := [Color(1, 0.3, 0.45), Color(0.3, 0.75, 1.0)]
	for i in 5:
		var angle := TAU * i / 5.0
		var dir := Vector3(cos(angle), 0, sin(angle))
		var spike := MeshFactory.instance(MeshFactory.cone(0.1, 0.26, 4), gold)
		spike.position = dir * 0.29 + Vector3.UP * 0.24
		_model.add_child(spike)
		var gem := MeshFactory.instance(MeshFactory.sphere(0.045, 6),
			MeshFactory.material(gem_colors[i % 2], 0.4))
		gem.position = dir * 0.29 + Vector3.UP * 0.39
		_model.add_child(gem)
		var band_gem := MeshFactory.instance(MeshFactory.sphere(0.05, 6),
			MeshFactory.material(gem_colors[(i + 1) % 2], 0.4))
		band_gem.position = dir * 0.335
		_model.add_child(band_gem)
	_model.position.y = 0.75


func _process(delta: float) -> void:
	_time += delta
	if _collected:
		# La couronne s'envole en tournant puis disparaît.
		_collect_time += delta
		_model.position.y = 0.75 + _collect_time * 2.2
		_model.rotation.y += delta * 12.0
		var s := maxf(1.0 + _collect_time * 0.6 - _collect_time * _collect_time * 0.9, 0.0)
		_model.scale = Vector3.ONE * s
		return
	_model.rotation.y += delta * 1.8
	_model.position.y = 0.75 + sin(_time * 2.5) * 0.08


func collect() -> void:
	_collected = true
	_collect_time = 0.0


func reset() -> void:
	_collected = false
	_model.scale = Vector3.ONE
