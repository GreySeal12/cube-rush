class_name LevelGenerator
extends RefCounted
## Génère un niveau à partir de sa configuration (voir data/levels.json).
##
## Le générateur est DÉTERMINISTE : il n'utilise que son propre
## RandomNumberGenerator initialisé avec la `seed` du niveau. Même seed et
## même configuration => exactement le même niveau, sur toutes les machines.
##
## Forme du chemin (vue de dessus, x vers la droite, z vers le bas) :
##
##   [départ]→→→→[angle]
##                  ↑
##                  ↑   (les segments alternent +X et -Z)
##               [angle]→→→[angle] …→ [arrivée + couronne]
##
## - Chaque « angle » est un bloc carré de `width` × `width` cases.
## - Entre deux angles, un « segment » droit de L rangées (1 rangée = 1 case
##   de long sur `width` cases de large).

const DIR_X := 0   # le cube avance vers +X
const DIR_Z := 1   # le cube avance vers -Z


static func generate(cfg: Dictionary, theme: Dictionary) -> LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.get("seed", 1))

	var data := LevelData.new()
	data.config = cfg
	data.theme = theme
	data.root = Node3D.new()
	data.root.name = "Level"
	data.speed = float(cfg.get("speed", 4.0))
	data.width = int(cfg.get("width", 3))
	var w := data.width

	var path_length := int(cfg.get("path_length", 50))
	var seg_min := int(cfg.get("segment_min", 4))
	var seg_max := int(cfg.get("segment_max", 8))

	# Bloc de départ. On mémorise le coin (x min, z min) du bloc courant.
	var block := Vector2(0, -w)
	var start_rect := Rect2(block, Vector2(w, w))
	_add_static(data, start_rect, theme.get("platform_b", Color.WHITE))
	var start_center := start_rect.get_center()
	data.start_position = Vector3(start_center.x, 0.0, start_center.y)
	data.start_direction = DIR_X

	var dir := DIR_X
	var total := 0
	var seg_index := 0
	while true:
		var length := rng.randi_range(seg_min, seg_max)
		if seg_index == 0:
			length = maxi(length, 3)  # petite ligne droite d'élan
		_build_segment(data, block, dir, length, seg_index, rng)
		total += length + w
		block = _next_block(block, dir, length, w)
		var block_rect := Rect2(block, Vector2(w, w))
		if total >= path_length:
			_build_goal(data, block_rect)
			break
		_add_static(data, block_rect, theme.get("platform_b", Color.WHITE))
		data.turn_points.append(block_rect.get_center())
		dir = 1 - dir
		seg_index += 1

	data.stats["segments"] = seg_index + 1
	data.stats["turns"] = data.turn_points.size()
	data.stats["path_tiles"] = total
	return data


## Coin du bloc d'angle qui suit un segment.
static func _next_block(block: Vector2, dir: int, length: int, w: int) -> Vector2:
	if dir == DIR_X:
		return Vector2(block.x + w + length, block.y)
	return Vector2(block.x, block.y - length - w)


## Emprise de la rangée i (0 = la plus proche du bloc précédent) d'un segment.
static func row_rect(block: Vector2, dir: int, i: int, w: int) -> Rect2:
	if dir == DIR_X:
		return Rect2(block.x + w + i, block.y, 1, w)
	return Rect2(block.x, block.y - 1 - i, w, 1)


## Emprise couvrant les rangées i0 à i1 (incluses).
static func rows_rect(block: Vector2, dir: int, i0: int, i1: int, w: int) -> Rect2:
	return row_rect(block, dir, i0, w).merge(row_rect(block, dir, i1, w))


static func _build_segment(data: LevelData, block: Vector2, dir: int, length: int,
		_seg_index: int, _rng: RandomNumberGenerator) -> void:
	var w := data.width
	if length <= 0:
		return
	_add_static(data, rows_rect(block, dir, 0, length - 1, w), data.theme.get("platform_a", Color.WHITE))


static func _build_goal(data: LevelData, block_rect: Rect2) -> void:
	# Le bloc d'arrivée est un peu plus long, la couronne trône au milieu.
	_add_static(data, block_rect, data.theme.get("goal", Color.WHITE))
	# On gagne en atteignant le cœur du bloc, là où se trouve la couronne.
	data.goal_rect = block_rect.grow(-block_rect.size.x * 0.3)
	var c := block_rect.get_center()
	data.crown_position = Vector3(c.x, 0.0, c.y)


static func _add_static(data: LevelData, r: Rect2, c: Color) -> StaticPlatform:
	var p := StaticPlatform.new()
	p.setup(r, c)
	_register(data, p)
	return p


static func _register(data: LevelData, p: PlatformBase) -> void:
	data.root.add_child(p)
	if p.provides_ground:
		data.platforms.append(p)
	else:
		data.obstacles.append(p)
