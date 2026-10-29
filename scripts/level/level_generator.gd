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
	var gauges := {}
	while true:
		var length := rng.randi_range(seg_min, seg_max)
		var feature := {"type": "none"}
		if seg_index == 0:
			length = maxi(length, 3)  # ligne droite d'élan, sans difficulté
		else:
			feature = _choose_feature(cfg, rng, gauges)
			length = maxi(length, _feature_min_length(feature))
		_build_segment(data, block, dir, length, feature, rng)
		total += length + w
		data.stats.segments += 1

		block = _next_block(block, dir, length, w)
		var block_rect := Rect2(block, Vector2(w, w))
		if total >= path_length:
			_build_goal(data, block_rect, dir)
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

## Choisit la particularité d'un segment.
##
## Plutôt qu'un tirage indépendant à chaque segment (qui peut donner 0 trou
## dans un niveau à « 50 % de trous »), chaque mécanique remplit une jauge de
## `chance` (± 40 % d'aléa) à chaque segment ; quand une jauge dépasse 1, la
## particularité apparaît et la jauge redescend. Résultat : la proportion
## moyenne de segments concernés est bien `chance`, avec un rythme régulier
## mais pas mécanique. Les mécaniques absentes de la config n'apparaissent jamais.
static func _choose_feature(cfg: Dictionary, rng: RandomNumberGenerator, gauges: Dictionary) -> Dictionary:
	var gaps: Dictionary = cfg.get("gaps", {})
	var moving: Dictionary = cfg.get("moving", {})
	var inter: Dictionary = cfg.get("intermittent", {})
	var spikes: Dictionary = cfg.get("spikes", {})
	var chances := {
		"gap": float(gaps.get("chance", 0.0)),
		"moving": float(moving.get("chance", 0.0)),
		"intermittent": float(inter.get("chance", 0.0)),
		"spikes": float(spikes.get("row_chance", 0.0)),
	}
	var chosen := "none"
	var best := 1.0
	for type in chances:
		if chances[type] <= 0.0:
			continue
		if not gauges.has(type):
			gauges[type] = rng.randf()  # départ décalé : pas tous au même segment
		gauges[type] += chances[type] * rng.randf_range(0.6, 1.4)
		if gauges[type] >= best:
			best = gauges[type]
			chosen = type
	if chosen != "none":
		gauges[chosen] -= 1.0
	match chosen:
		"gap":
			return {"type": "gap", "size": rng.randi_range(int(gaps.get("min", 1)), int(gaps.get("max", 1)))}
		"moving":
			return {"type": "moving", "size": int(moving.get("length", 2))}
		"intermittent":
			var types: Array = inter.get("types", ["retract"])
			return {"type": "intermittent",
				"size": rng.randi_range(int(inter.get("rows_min", 1)), int(inter.get("rows_max", 1))),
				"variant": String(types[rng.randi_range(0, types.size() - 1)])}
		"spikes":
			return {"type": "spikes", "size": 1}
	return {"type": "none"}


## Longueur minimale d'un segment pour accueillir la particularité.
static func _feature_min_length(feature: Dictionary) -> int:
	match feature.type:
		"gap":
			# 1 rangée d'approche + tremplin + trou + 2 rangées d'atterrissage.
			return int(feature.size) + 4
		"moving":
			return int(feature.size) + 3
		"intermittent":
			return int(feature.size) + 2
		"spikes":
			return 3
	return 1


static func _build_segment(data: LevelData, block: Vector2, dir: int, length: int,
		feature: Dictionary, rng: RandomNumberGenerator) -> void:
	if length <= 0:
		return
	var cfg := data.config
	var w := data.width
	# 1) On décrit d'abord le contenu de chaque rangée…
	var kinds: Array[String] = []
	kinds.resize(length)
	kinds.fill("floor")

	var size := int(feature.get("size", 0))
	match feature.type:
		"gap":
			var pad := rng.randi_range(1, length - size - 3)
			kinds[pad] = "pad"
			for i in range(pad + 1, pad + 1 + size):
				kinds[i] = "void"
			data.stats.gaps += 1
			data.stats.max_gap = maxi(data.stats.max_gap, size)
		"moving":
			var first := rng.randi_range(1, length - size - 2)
			for i in range(first, first + size):
				kinds[i] = "moving"
			_add_moving(data, block, dir, first, first + size - 1)
		"intermittent":
			var first := rng.randi_range(1, length - size - 1)
			for i in range(first, first + size):
				kinds[i] = "intermittent"
				_add_intermittent(data, block, dir, i, String(feature.variant))
		"spikes":
			var row := rng.randi_range(1, length - 2)
			kinds[row] = "spikes"
			_add_spikes(data, row_rect(block, dir, row, w), true, w)

	# Sol fragile : tout le segment (hors particularité) s'effondre derrière le cube.
	var crumble: Dictionary = cfg.get("crumble", {})
	var crumbling := rng.randf() < float(crumble.get("chance", 0.0))

	# Décorations dangereuses sur les côtés (largeur >= 3 : le couloir central reste libre).
	if w >= 3 and not crumbling:
		_add_side_traps(data, block, dir, kinds, rng)

	# 2) … puis on construit. Les rangées de sol fixe consécutives forment un
	#    seul bloc (moins d'objets à dessiner).
	var i := 0
	while i < length:
		var kind := kinds[i]
		if kind == "floor" and crumbling:
			var c := CrumblePlatform.new()
			c.setup(row_rect(block, dir, i, w), _color(data, "crumble"))
			c.delay = float(crumble.get("delay", 0.6))
			_register(data, c)
			data.stats.crumble = data.stats.get("crumble", 0) + 1
		elif kind == "floor" or kind == "spikes":
			var j := i
			while j + 1 < length and (kinds[j + 1] == "spikes" or (kinds[j + 1] == "floor" and not crumbling)):
				j += 1
			_add_static(data, rows_rect(block, dir, i, j, w), _color(data, "platform_a"))
			i = j + 1
			continue
		elif kind == "pad":
			var gap := 0
			while i + 1 + gap < length and kinds[i + 1 + gap] == "void":
				gap += 1
			var pad := JumpPad.new()
			pad.setup(row_rect(block, dir, i, w), _color(data, "pad"))
			pad.travel = travel_vector(dir)
			pad.accent = _color(data, "pad_accent")
			pad.jump_velocity = jump_velocity_for_gap(gap, data.speed)
			_register(data, pad)
		i += 1


# ---------------------------------------------------------------------------
# Éléments synchronisés
# ---------------------------------------------------------------------------
# Le cube arrive en un point à un instant qui ne dépend que de ce point (voir
# LevelData.progress_of). On règle donc chaque cycle pour que l'élément soit
# « sûr » pendant le passage du cube SUR LE CENTRE DU CHEMIN, avec une marge
# `timing_margin` (en secondes) de chaque côté. Un joueur décalé sur le côté
# (virage pris trop tôt ou trop tard) arrive en avance ou en retard : plus la
# marge est petite, plus il faut être précis.

## Fenêtre de passage [début, fin] (s) du centre du cube sur les rangées
## i0..i1, pour un cube qui suit le centre du chemin.
static func _passage_window(data: LevelData, block: Vector2, dir: int, i0: int, i1: int) -> Vector2:
	var r := rows_rect(block, dir, i0, i1, data.width)
	var center_time := data.ideal_time_at(r.get_center())
	var rows := i1 - i0 + 1
	# Pendant rows/vitesse secondes le centre est au-dessus ; on ajoute une
	# demi-case de chaque côté pour la taille du cube.
	var half := (rows + 0.5) / data.speed * 0.5
	return Vector2(center_time - half, center_time + half)


static func _margin(data: LevelData) -> float:
	return float(data.config.get("timing_margin", 0.25))


static func _add_moving(data: LevelData, block: Vector2, dir: int, i0: int, i1: int) -> void:
	var m: Dictionary = data.config.get("moving", {})
	var p := MovingPlatform.new()
	p.setup(rows_rect(block, dir, i0, i1, data.width), _color(data, "moving"))
	# Le pont s'écarte « vers l'arrière » du chemin (+Z ou -X) : zone toujours
	# vide, car le chemin ne fait qu'avancer vers +X et -Z.
	var away := Vector2(0, 1) if dir == DIR_X else Vector2(-1, 0)
	p.displacement = away * (data.width + 0.6)
	var win := _passage_window(data, block, dir, i0, i1)
	var safe := (win.y - win.x) + 2.0 * _margin(data)
	p.setup_cycle((win.x + win.y) * 0.5, safe, float(m.get("away_time", 0.9)), float(m.get("travel_time", 0.5)))
	_register(data, p)
	data.stats.moving = data.stats.get("moving", 0) + 1


static func _add_intermittent(data: LevelData, block: Vector2, dir: int, i: int, variant: String) -> void:
	var m: Dictionary = data.config.get("intermittent", {})
	var p: PlatformBase
	if variant == "rotate":
		var rot := RotatingPlatform.new()
		rot.travel = travel_vector(dir)
		rot.accent = _color(data, "pad_accent")
		p = rot
	else:
		p = RetractingPlatform.new()
	p.setup(row_rect(block, dir, i, data.width), _color(data, "special"))
	var win := _passage_window(data, block, dir, i, i)
	var safe := (win.y - win.x) + 2.0 * _margin(data)
	p.setup_cycle((win.x + win.y) * 0.5, safe, float(m.get("hidden_time", 0.9)), 0.25)
	_register(data, p)
	data.stats[variant] = data.stats.get(variant, 0) + 1


static func _add_spikes(data: LevelData, r: Rect2, periodic: bool, _w: int) -> void:
	var s := SpikeTrap.new()
	s.setup(r, _color(data, "hazard"))
	s.periodic = periodic
	s.plate_color = _color(data, "platform_a").darkened(0.45)
	if periodic:
		var m: Dictionary = data.config.get("spikes", {})
		var center_time := data.ideal_time_at(r.get_center())
		# Les pointes touchent le cube sur 1 case + 2 demi-largeurs de cube.
		var half := (1.0 + 2.0 * PlayerMotor.HAZARD_HALF) / data.speed * 0.5
		var safe := 2.0 * half + 2.0 * _margin(data)
		s.setup_cycle(center_time, safe, float(m.get("up_time", 0.8)), 0.15)
		data.stats.spike_rows = data.stats.get("spike_rows", 0) + 1
	else:
		data.stats.spikes = data.stats.get("spikes", 0) + 1
	_register(data, s)


## Piliers et pointes fixes sur les couloirs latéraux (jamais au centre).
static func _add_side_traps(data: LevelData, block: Vector2, dir: int, kinds: Array[String],
		rng: RandomNumberGenerator) -> void:
	var w := data.width
	var pillar_chance := float(data.config.get("pillars", {}).get("chance", 0.0))
	var spike_chance := float(data.config.get("spikes", {}).get("static_chance", 0.0))
	if pillar_chance <= 0.0 and spike_chance <= 0.0:
		return
	for i in range(1, kinds.size() - 1):
		# Uniquement au milieu d'une zone de sol simple, loin des autres pièges.
		if kinds[i - 1] != "floor" or kinds[i] != "floor" or kinds[i + 1] != "floor":
			continue
		var roll := rng.randf()
		if roll >= pillar_chance + spike_chance:
			continue
		var lane := 0 if rng.randf() < 0.5 else w - 1
		var cell := _cell_rect(block, dir, i, lane, w)
		if roll < pillar_chance:
			var p := PillarTrap.new()
			p.setup(cell.grow(-0.25), _color(data, "pillar"))
			p.top_color = _color(data, "platform_b")
			_register(data, p)
			data.stats.pillars = data.stats.get("pillars", 0) + 1
		else:
			_add_spikes(data, cell, false, w)


## Emprise d'une case : rangée i, couloir latéral `lane` (0 = côté arrière).
static func _cell_rect(block: Vector2, dir: int, i: int, lane: int, w: int) -> Rect2:
	var r := row_rect(block, dir, i, w)
	if dir == DIR_X:
		return Rect2(r.position.x, r.end.y - 1 - lane, 1, 1)
	return Rect2(r.position.x + lane, r.position.y, 1, 1)


static func _build_goal(data: LevelData, block_rect: Rect2, dir: int) -> void:
	_add_static(data, block_rect, _color(data, "goal"))
	# On gagne en atteignant le cœur du bloc (là où trône la couronne), sur
	# toute sa largeur : même un cube décalé sur le côté gagne.
	var depth := block_rect.size.x * 0.3
	if dir == DIR_X:
		data.goal_rect = Rect2(block_rect.position.x + depth, block_rect.position.y,
			block_rect.size.x - depth, block_rect.size.y)
	else:
		data.goal_rect = Rect2(block_rect.position.x, block_rect.position.y,
			block_rect.size.x, block_rect.size.y - depth)
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
