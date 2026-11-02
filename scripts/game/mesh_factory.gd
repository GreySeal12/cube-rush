class_name MeshFactory
extends RefCounted
## Fabrique de maillages et de matériaux partagés.
##
## Tout le jeu est construit à partir de primitives (BoxMesh, CylinderMesh,
## SphereMesh). Pour économiser la mémoire et les changements d'état du GPU,
## les maillages et matériaux identiques sont mis en cache et réutilisés.

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


## Matériau opaque à couleur unie. L'éclairage est calculé par sommet
## (moins coûteux sur mobile, et identique pour des faces planes).
static func material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var key := "m_%s_%.2f" % [color.to_html(), emission]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mat.metallic_specular = 0.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat


## Matériau sans éclairage (fond de lave, ombre portée…).
static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "u_%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_materials[key] = mat
	return mat


static func box(size: Vector3) -> BoxMesh:
	var key := "box_%.3f_%.3f_%.3f" % [size.x, size.y, size.z]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_meshes[key] = mesh
	return mesh


static func sphere(radius: float, segments: int = 8) -> SphereMesh:
	var key := "sph_%.3f_%d" % [radius, segments]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 3)
	_meshes[key] = mesh
	return mesh


## Cône (ou pyramide si `sides` = 4).
static func cone(radius: float, height: float, sides: int = 4) -> CylinderMesh:
	var key := "cone_%.3f_%.3f_%d" % [radius, height, sides]
	if _meshes.has(key):
		return _meshes[key]
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mesh.cap_top = false
	_meshes[key] = mesh
	return mesh


## Cube aux arêtes arrondies, calculé à partir d'un BoxMesh subdivisé :
## chaque sommet est ramené vers une « boîte intérieure » puis repoussé
## à distance `radius` (technique classique du « rounded box »).
static func rounded_box(size: float, radius: float, subdivisions: int = 6) -> ArrayMesh:
	var key := "rbox_%.3f_%.3f_%d" % [size, radius, subdivisions]
	if _meshes.has(key):
		return _meshes[key]
	var src := BoxMesh.new()
	src.size = Vector3.ONE * size
	src.subdivide_width = subdivisions
	src.subdivide_height = subdivisions
	src.subdivide_depth = subdivisions
	var arrays := src.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inner := size * 0.5 - radius
	var lo := Vector3(-inner, -inner, -inner)
	var hi := Vector3(inner, inner, inner)
	for i in verts.size():
		var v := verts[i]
		var core := v.clamp(lo, hi)
		var n := (v - core).normalized()
		verts[i] = core + n * radius
		normals[i] = n
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_meshes[key] = mesh
	return mesh


## Groupe de 4 pointes (pyramides) fusionnées en un seul maillage,
## pour une case de 1×1. Un seul appel de dessin par case.
static func spike_cluster(height: float) -> ArrayMesh:
	var key := "spikes_%.3f" % height
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	var one := cone(0.17, height, 4)
	for ox in [-0.22, 0.22]:
		for oz in [-0.22, 0.22]:
			var xf := Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(ox, height * 0.5, oz))
			st.append_from(one, 0, xf)
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


## Crée un MeshInstance3D sans ombre (les ombres dynamiques sont désactivées
## partout pour tenir 60 FPS sur les petits téléphones).
static func instance(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
