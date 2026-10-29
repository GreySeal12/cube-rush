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
##                        [arrivée + couronne]
##                            ↑
##               [angle]→→→→[angle]
##                  ↑
##   [départ]→→→→[angle]          (les segments alternent +X et -Z)
##
## - Chaque « angle » est un bloc carré de `width` × `width` cases.
## - Entre deux angles, un « segment » droit de L rangées (1 rangée = 1 case
##   de long sur `width` cases de large).
## - Chaque segment peut recevoir UNE « particularité » (trou + tremplin, etc.),
##   tirée au hasard selon les probabilités de la configuration.

const DIR_X := 0   # le cube avance vers +X
const DIR_Z := 1   # le cube avance vers -Z

## Distance entre le bord d'entrée du tremplin et le point d'atterrissage
## visé, en plus de la longueur du trou : 1 case de tremplin + une demi-case
## pour retomber au milieu de la première rangée après le trou.
const JUMP_EXTRA_DISTANCE := 1.5


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
	data.stats = {"segments": 0, "turns": 0, "gaps": 0, "max_gap": 0}
	var w := data.width

	var path_length := int(cfg.get("path_length", 50))
	var seg_min := int(cfg.get("segment_min", 4))
	var seg_max := int(cfg.get("segment_max", 8))

	# Bloc de départ. On mémorise le coin (x min, z min) du bloc courant.
	var block := Vector2(0, -w)
	var start_rect := Rect2(block, Vector2(w, w))
	_add_static(data, start_rect, _color(data, "platform_b"))
	var start_center := start_rect.get_center()
	data.start_position = Vector3(start_center.x, 0.0, start_center.y)
	data.start_direction = DIR_X

	var dir := DIR_X
	var total := 0
	var seg_index := 0
	while true:
		var length := rng.randi_range(seg_min, seg_max)
		var feature := {"type": "none"}
		if seg_index == 0:
			length = maxi(length, 3)  # ligne droite d'élan, sans difficulté
		else:
			feature = _choose_feature(cfg, rng)
			length = maxi(length, _feature_min_length(feature))
		_build_segment(data, block, dir, length, feature, rng)
		total += length + w
		data.stats.segments += 1

		block = _next_block(block, dir, length, w)
		var block_rect := Rect2(block, Vector2(w, w))
		if total >= path_length:
			_build_goal(data, block_rect)
			break
		_add_static(data, block_rect, _color(data, "platform_b"))
		data.turn_points.append(block_rect.get_center())
		dir = 1 - dir
		seg_index += 1

	data.stats.turns = data.turn_points.size()
	data.stats.path_tiles = total
	return data


# ---------------------------------------------------------------------------
# Géométrie du chemin
# ---------------------------------------------------------------------------

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


static func travel_vector(dir: int) -> Vector2:
	return Vector2(1, 0) if dir == DIR_X else Vector2(0, -1)


## Vitesse verticale à donner au cube pour franchir un trou de `gap` cases :
## temps de vol T = distance / vitesse, et un tir parabolique qui retombe à
## sa hauteur de départ au bout de T vérifie vy = g * T / 2.
static func jump_velocity_for_gap(gap: int, speed: float) -> float:
	var airtime := (gap + JUMP_EXTRA_DISTANCE) / speed
	return PlayerMotor.GRAVITY * airtime * 0.5


# ---------------------------------------------------------------------------
# Particularités des segments
# ---------------------------------------------------------------------------

## Tire au sort la particularité d'un segment selon les probabilités de la
## configuration. Les mécaniques absentes de la config ne sont jamais tirées.
static func _choose_feature(cfg: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	var gap: Dictionary = cfg.get("gaps", {})
	var gap_chance := float(gap.get("chance", 0.0))
	if roll < gap_chance:
		return {"type": "gap", "size": rng.randi_range(int(gap.get("min", 1)), int(gap.get("max", 1)))}
	return {"type": "none"}


## Longueur minimale d'un segment pour accueillir la particularité.
static func _feature_min_length(feature: Dictionary) -> int:
	match feature.type:
		"gap":
			# 1 rangée d'approche + tremplin + trou + 2 rangées d'atterrissage.
			return int(feature.size) + 4
	return 1


static func _build_segment(data: LevelData, block: Vector2, dir: int, length: int,
		feature: Dictionary, rng: RandomNumberGenerator) -> void:
	if length <= 0:
		return
	var w := data.width
	# On décrit d'abord le contenu de chaque rangée, puis on construit.
	var kinds: Array[String] = []
	kinds.resize(length)
	kinds.fill("floor")

	match feature.type:
		"gap":
			var size := int(feature.size)
			var pad := rng.randi_range(1, length - size - 3)
			kinds[pad] = "pad"
			for i in range(pad + 1, pad + 1 + size):
				kinds[i] = "void"
			data.stats.gaps += 1
			data.stats.max_gap = maxi(data.stats.max_gap, size)

	# Construction : les rangées de sol consécutives forment un seul bloc.
	var i := 0
	while i < length:
		var kind := kinds[i]
		if kind == "floor":
			var j := i
			while j + 1 < length and kinds[j + 1] == "floor":
				j += 1
			_add_static(data, rows_rect(block, dir, i, j, w), _color(data, "platform_a"))
			i = j + 1
			continue
		if kind == "pad":
			var size := 0
			while i + 1 + size < length and kinds[i + 1 + size] == "void":
				size += 1
			var pad := JumpPad.new()
			pad.setup(row_rect(block, dir, i, w), _color(data, "pad"))
			pad.travel = travel_vector(dir)
			pad.accent = _color(data, "pad_accent")
			pad.jump_velocity = jump_velocity_for_gap(size, data.speed)
			_register(data, pad)
		i += 1


static func _build_goal(data: LevelData, block_rect: Rect2) -> void:
	_add_static(data, block_rect, _color(data, "goal"))
	# On gagne en atteignant le cœur du bloc, là où trône la couronne.
	data.goal_rect = block_rect.grow(-block_rect.size.x * 0.3)
	var c := block_rect.get_center()
	data.crown_position = Vector3(c.x, 0.0, c.y)


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

static func _color(data: LevelData, key: String) -> Color:
	return data.theme.get(key, Color.WHITE)


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


## Empreinte textuelle du niveau (sert à vérifier le déterminisme).
static func signature(data: LevelData) -> String:
	var parts: PackedStringArray = []
	for p in data.platforms + data.obstacles:
		parts.append("%s:%s:%.4f:%.4f:%.4f" % [
			p.get_script().get_global_name(), p.rect, p.get_jump_velocity(),
			p.cycle_offset, p.cycle_period])
	parts.append(str(data.goal_rect))
	return "|".join(parts)
