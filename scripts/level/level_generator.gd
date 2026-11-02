class_name LevelGenerator
extends RefCounted
## Génère un niveau à partir de sa configuration (voir data/levels.json).
##
## Le générateur est DÉTERMINISTE : il n'utilise que son propre
## RandomNumberGenerator initialisé avec la `seed` du niveau. Même seed et
## même configuration => exactement le même niveau, sur toutes les machines.
##
## Forme du chemin (vue de dessus, l'« avant » = haut de l'écran = -Z) :
##
##                     [arrivée + couronne]
##                          ↑
##          [angle]←←←←←[angle]           Le chemin alterne :
##             ↑                           - un segment vers l'AVANT,
##          [angle]→→→→[angle]             - un segment vers la DROITE ou la
##                        ↑                  GAUCHE (selon `side_bias`).
##   [départ]→→→→→→→→→[angle]             Le départ se fait vers la droite, la
##                                         gauche ou l'avant (`start`).
##
## Comme le chemin ne revient jamais vers l'arrière, il ne peut pas se croiser.
## - Chaque « angle » est un bloc carré de `width` × `width` cases.
## - Entre deux angles, un « segment » droit de L rangées (1 rangée = 1 case
##   de long sur `width` cases de large).
## - Chaque segment peut recevoir UNE « particularité » (trou à sauter, etc.),
##   tirée selon les probabilités de la configuration.

const NORTH := PlayerMotor.NORTH
const EAST := PlayerMotor.EAST
const WEST := PlayerMotor.WEST

## Tolérance minimale (s) garantie face aux piliers et pointes latéraux : un
## virage pris jusqu'à ce retard (ou cette avance) ne touche jamais un piège
## de côté. Le couloir libre s'élargit donc avec la vitesse du niveau.
const SIDE_TRAP_TOLERANCE := 0.1
## Marge habituelle entre le bord d'une case et un pilier.
const PILLAR_INSET := 0.25
## Durée minimale (s) de la « zone d'appel » d'un saut pour un cube lancé :
## les trous trop grands pour la vitesse du niveau sont raccourcis.
const MIN_JUMP_WINDOW := 0.2
## Le centre du cube doit retomber au moins à cette distance après le trou.
const LANDING_MARGIN := 0.1
## Temps minimal (s) entre deux actions du parcours idéal (virage puis saut…).
const MIN_ACTION_GAP := 0.45


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
	var side_bias := float(cfg.get("side_bias", 0.5))

	# Bloc de départ.
	var block := Rect2(0, 0, w, w)
	_add_static(data, block, _color(data, "platform_b"))
	var start_center := block.get_center()
	data.start_position = Vector3(start_center.x, 0.0, start_center.y)
	var heading := start_heading(String(cfg.get("start", "forward")))
	data.start_direction = heading

	# Distance parcourue (sur l'axe du chemin) jusqu'au centre du bloc courant.
	var dist := 0.0
	var total := 0
	var seg_index := 0
	var gauges := {}
	while true:
		var length := rng.randi_range(seg_min, seg_max)
		var feature := {"type": "none"}
		if seg_index == 0:
			length = maxi(length, 3)  # ligne droite d'élan, sans difficulté
		else:
			feature = _choose_feature(cfg, rng, gauges, heading == NORTH)
			if feature.type == "gap":
				feature.size = clampi(int(feature.size), 1, max_gap_for_speed(data.speed))
			length = maxi(length, _feature_min_length(feature, data.speed, w))
		_build_segment(data, block, heading, length, feature, rng, dist)
		total += length + w
		data.stats.segments += 1

		var next := next_block(block, heading, length)
		var next_dist := dist + w + length
		if total >= path_length:
			_build_goal(data, next, heading, next_dist)
			break
		_add_static(data, next, _color(data, "platform_b"))
		# Après un segment vers l'avant on part sur le côté, et inversement.
		var new_heading := NORTH
		if heading == NORTH:
			new_heading = EAST if rng.randf() < side_bias else WEST
		var action := "right" if new_heading == posmod(heading + 1, 4) else "left"
		data.waypoints.append({"pos": next.get_center(), "dir": heading,
			"action": action, "time": next_dist / data.speed})
		heading = new_heading
		block = next
		dist = next_dist
		seg_index += 1

	data.stats.turns = data.waypoints.filter(func(wp: Dictionary) -> bool: return wp.action != "jump").size()
	data.stats.path_tiles = total
	return data


static func start_heading(start: String) -> int:
	match start:
		"right":
			return EAST
		"left":
			return WEST
	return NORTH


# ---------------------------------------------------------------------------
# Géométrie du chemin
# ---------------------------------------------------------------------------

## Bloc d'angle qui suit un segment de `length` rangées.
static func next_block(block: Rect2, heading: int, length: int) -> Rect2:
	var w := block.size.x
	match heading:
		EAST:
			return Rect2(block.end.x + length, block.position.y, w, w)
		WEST:
			return Rect2(block.position.x - length - w, block.position.y, w, w)
		PlayerMotor.SOUTH:
			return Rect2(block.position.x, block.end.y + length, w, w)
	return Rect2(block.position.x, block.position.y - length - w, w, w)


## Emprise de la rangée i (0 = la plus proche du bloc de départ du segment).
static func row_rect(block: Rect2, heading: int, i: int) -> Rect2:
	var w := block.size.x
	match heading:
		EAST:
			return Rect2(block.end.x + i, block.position.y, 1, w)
		WEST:
			return Rect2(block.position.x - 1 - i, block.position.y, 1, w)
		PlayerMotor.SOUTH:
			return Rect2(block.position.x, block.end.y + i, w, 1)
	return Rect2(block.position.x, block.position.y - 1 - i, w, 1)


## Emprise couvrant les rangées i0 à i1 (incluses).
static func rows_rect(block: Rect2, heading: int, i0: int, i1: int) -> Rect2:
	return row_rect(block, heading, i0).merge(row_rect(block, heading, i1))


static func travel_vector(heading: int) -> Vector2:
	return PlayerMotor.DIRECTIONS[heading]


## Longueur d'un saut (cases) : le cube avance à la vitesse du niveau
## pendant toute la durée du saut.
static func jump_distance(speed: float) -> float:
	return speed * PlayerMotor.JUMP_AIRTIME


## Plus grand trou franchissable avec une zone d'appel d'au moins
## MIN_JUMP_WINDOW secondes pour un cube lancé.
static func max_gap_for_speed(speed: float) -> int:
	return maxi(int(floor(jump_distance(speed) - MIN_JUMP_WINDOW * speed - LANDING_MARGIN)), 1)


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
static func _choose_feature(cfg: Dictionary, rng: RandomNumberGenerator, gauges: Dictionary,
		allow_moving: bool) -> Dictionary:
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
		# Les ponts mobiles coulissent sur le côté : seulement sur les segments
		# vers l'avant (la jauge reste pleine pour le prochain).
		if type == "moving" and not allow_moving:
			continue
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
static func _feature_min_length(feature: Dictionary, speed: float, width: int) -> int:
	match feature.type:
		"gap":
			var g := _gap_layout(int(feature.size), speed, width)
			return g.first_min + int(feature.size) + g.landing_rows
		"moving":
			return int(feature.size) + 3
		"intermittent":
			return int(feature.size) + 2
		"spikes":
			return 3
	return 1


## Placement d'un trou de `size` cases :
## - first_min : première rangée de vide possible, pour que toute la zone
##   d'appel soit dans le segment (après le virage) et que le saut idéal
##   vienne au moins MIN_ACTION_GAP secondes après le virage ;
## - landing_rows : rangées après le trou, pour qu'un saut pris au tout dernier
##   moment retombe encore dans le segment.
static func _gap_layout(size: int, speed: float, width: int) -> Dictionary:
	var d := jump_distance(speed)
	# Décollage idéal (milieu de la zone d'appel) = first + (size + marge - d - 0.02) / 2,
	# à placer au moins à `min_takeoff` cases du bord du segment.
	var min_takeoff := MIN_ACTION_GAP * speed - width * 0.5
	var first_for_gap := ceili(min_takeoff - (size + LANDING_MARGIN - d - 0.02) * 0.5)
	return {
		"first_min": maxi(1, maxi(ceili(d - size - LANDING_MARGIN), first_for_gap)),
		"landing_rows": maxi(2, ceili(d - size)),
	}


static func _build_segment(data: LevelData, block: Rect2, heading: int, length: int,
		feature: Dictionary, rng: RandomNumberGenerator, dist: float) -> void:
	if length <= 0:
		return
	var cfg := data.config
	var w := data.width
	# Distance (sur l'axe du chemin) jusqu'au bord de départ du segment.
	var seg_dist := dist + w * 0.5
	# 1) On décrit d'abord le contenu de chaque rangée…
	var kinds: Array[String] = []
	kinds.resize(length)
	kinds.fill("floor")

	var size := int(feature.get("size", 0))
	match feature.type:
		"gap":
			var layout := _gap_layout(size, data.speed, w)
			var first := rng.randi_range(layout.first_min, length - size - layout.landing_rows)
			for i in range(first, first + size):
				kinds[i] = "void"
			_add_jump_waypoint(data, block, heading, first, size, seg_dist)
			data.stats.gaps += 1
			data.stats.max_gap = maxi(data.stats.max_gap, size)
		"moving":
			var first := rng.randi_range(1, length - size - 2)
			for i in range(first, first + size):
				kinds[i] = "moving"
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			_add_moving(data, block, heading, first, first + size - 1, seg_dist, side)
		"intermittent":
			var first := rng.randi_range(1, length - size - 1)
			for i in range(first, first + size):
				kinds[i] = "intermittent"
				_add_intermittent(data, block, heading, i, String(feature.variant), seg_dist)
		"spikes":
			var row := rng.randi_range(1, length - 2)
			kinds[row] = "spikes"
			_add_spikes(data, row_rect(block, heading, row), true, seg_dist + row + 0.5)

	# Sol fragile : tout le segment (hors particularité) s'effondre derrière le cube.
	var crumble: Dictionary = cfg.get("crumble", {})
	var crumbling := rng.randf() < float(crumble.get("chance", 0.0))

	# Décorations dangereuses sur les côtés (largeur >= 3 : le couloir central reste libre).
	if w >= 3 and not crumbling:
		_add_side_traps(data, block, heading, kinds, rng)

	# 2) … puis on construit. Les rangées de sol fixe consécutives forment un
	#    seul bloc (moins d'objets à dessiner).
	var i := 0
	while i < length:
		var kind := kinds[i]
		if kind == "floor" and crumbling:
			var c := CrumblePlatform.new()
			c.setup(row_rect(block, heading, i), _color(data, "crumble"))
			c.delay = float(crumble.get("delay", 0.6))
			_register(data, c)
			data.stats.crumble = data.stats.get("crumble", 0) + 1
		elif kind == "floor" or kind == "spikes":
			var j := i
			while j + 1 < length and (kinds[j + 1] == "spikes" or (kinds[j + 1] == "floor" and not crumbling)):
				j += 1
			_add_static(data, rows_rect(block, heading, i, j), _color(data, "platform_a"))
			i = j + 1
			continue
		i += 1


## Point de saut idéal : au milieu de la zone d'appel, c'est-à-dire des
## positions de décollage qui font retomber le cube après le trou.
static func _add_jump_waypoint(data: LevelData, block: Rect2, heading: int, first: int, size: int,
		seg_dist: float) -> void:
	var d := jump_distance(data.speed)
	var earliest := first + size + LANDING_MARGIN - d   # décollage au plus tôt
	var latest := first - 0.02                          # au plus tard : bord du trou
	var takeoff := (earliest + latest) * 0.5
	var fwd := travel_vector(heading)
	var edge := block.get_center() + fwd * (data.width * 0.5)
	data.waypoints.append({"pos": edge + fwd * takeoff, "dir": heading, "action": "jump",
		"time": (seg_dist + takeoff) / data.speed, "window": (latest - earliest) / data.speed})


# ---------------------------------------------------------------------------
# Éléments synchronisés
# ---------------------------------------------------------------------------
# Les éléments à cycle (ponts mobiles, plateformes intermittentes, pointes)
# ont une phase « sûre » assez longue pour être traversée d'une traite, plus
# une marge `timing_margin` (s) de chaque côté. Le joueur peut toujours
# s'arrêter et attendre le bon moment ; la phase est en plus calée sur le
# parcours idéal (cube maintenu en continu, actions parfaites) : le joueur qui
# ne s'arrête jamais passe pile au bon moment.

## Fenêtre de passage [début, fin] (s) du centre du cube sur des rangées dont
## le milieu est à `center_dist` cases du départ, sur le parcours idéal.
static func _passage_window(data: LevelData, rows: int, center_dist: float) -> Vector2:
	var center_time := center_dist / data.speed
	# Pendant rows/vitesse secondes le centre est au-dessus ; on ajoute une
	# demi-case de chaque côté pour la taille du cube.
	var half := (rows + 0.5) / data.speed * 0.5
	return Vector2(center_time - half, center_time + half)


static func _margin(data: LevelData) -> float:
	return float(data.config.get("timing_margin", 0.25))


static func _add_moving(data: LevelData, block: Rect2, heading: int, i0: int, i1: int,
		seg_dist: float, side: float) -> void:
	var m: Dictionary = data.config.get("moving", {})
	var p := MovingPlatform.new()
	p.setup(rows_rect(block, heading, i0, i1), _color(data, "moving"))
	# Le pont s'écarte sur le côté d'un segment « vers l'avant » : à cette
	# hauteur, il n'y a jamais d'autre morceau de chemin.
	p.displacement = Vector2(side * (data.width + 0.6), 0)
	var win := _passage_window(data, i1 - i0 + 1, seg_dist + (i0 + i1 + 1) * 0.5)
	var safe := (win.y - win.x) + 2.0 * _margin(data)
	p.setup_cycle((win.x + win.y) * 0.5, safe, float(m.get("away_time", 0.9)), float(m.get("travel_time", 0.5)))
	_register(data, p)
	data.stats.moving = data.stats.get("moving", 0) + 1


static func _add_intermittent(data: LevelData, block: Rect2, heading: int, i: int, variant: String,
		seg_dist: float) -> void:
	var m: Dictionary = data.config.get("intermittent", {})
	var p: PlatformBase
	if variant == "rotate":
		var rot := RotatingPlatform.new()
		rot.travel = travel_vector(heading)
		rot.accent = _color(data, "pad_accent")
		p = rot
	else:
		p = RetractingPlatform.new()
	p.setup(row_rect(block, heading, i), _color(data, "special"))
	var win := _passage_window(data, 1, seg_dist + i + 0.5)
	var safe := (win.y - win.x) + 2.0 * _margin(data)
	p.setup_cycle((win.x + win.y) * 0.5, safe, float(m.get("hidden_time", 0.9)), 0.25)
	_register(data, p)
	data.stats[variant] = data.stats.get(variant, 0) + 1


## Pointes : périodiques (rangée entière, `center_dist` = distance de son
## milieu sur le parcours idéal) ou fixes (case latérale).
static func _add_spikes(data: LevelData, r: Rect2, periodic: bool, center_dist: float = 0.0) -> void:
	var s := SpikeTrap.new()
	s.setup(r, _color(data, "hazard"))
	s.periodic = periodic
	s.plate_color = _color(data, "platform_a").darkened(0.45)
	if periodic:
		var m: Dictionary = data.config.get("spikes", {})
		var center_time := center_dist / data.speed
		# Les pointes touchent le cube sur 1 case + 2 demi-largeurs de cube.
		var half := (1.0 + 2.0 * PlayerMotor.HAZARD_HALF) / data.speed * 0.5
		var safe := 2.0 * half + 2.0 * _margin(data)
		s.setup_cycle(center_time, safe, float(m.get("up_time", 0.8)), 0.15)
		data.stats.spike_rows = data.stats.get("spike_rows", 0) + 1
	else:
		data.stats.spikes = data.stats.get("spikes", 0) + 1
	_register(data, s)


## Piliers et pointes fixes sur les couloirs latéraux (jamais au centre).
static func _add_side_traps(data: LevelData, block: Rect2, heading: int, kinds: Array[String],
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
		var cell := _cell_rect(row_rect(block, heading, i), heading, lane)
		# Distance minimale entre le centre du chemin et la partie mortelle du
		# piège : décalage latéral toléré + demi-largeur du cube.
		var clearance := SIDE_TRAP_TOLERANCE * data.speed + PlayerMotor.HAZARD_HALF
		# Distance entre le centre du chemin et le bord intérieur de la case.
		var lane_edge := w * 0.5 - 1.0
		if roll < pillar_chance:
			var trim := maxf(clearance - lane_edge - PILLAR_INSET, 0.0)
			var p := PillarTrap.new()
			p.setup(_trim_inner(cell.grow(-PILLAR_INSET), heading, lane, trim), _color(data, "pillar"))
			p.top_color = _color(data, "platform_b")
			_register(data, p)
			data.stats.pillars = data.stats.get("pillars", 0) + 1
		else:
			var trim := maxf(clearance - lane_edge - SpikeTrap.INSET, 0.0)
			_add_spikes(data, _trim_inner(cell, heading, lane, trim), false)


## Les rangées vers l'avant sont horizontales (couloirs le long de x), les
## rangées vers la droite / gauche sont verticales (couloirs le long de z).
static func _lateral_is_x(heading: int) -> bool:
	return heading == NORTH or heading == PlayerMotor.SOUTH


## Emprise d'une case : couloir latéral `lane` (0 = x ou z le plus petit) d'une rangée.
static func _cell_rect(row: Rect2, heading: int, lane: int) -> Rect2:
	if _lateral_is_x(heading):
		return Rect2(row.position.x + lane, row.position.y, 1, 1)
	return Rect2(row.position.x, row.position.y + lane, 1, 1)


## Rogne `amount` sur le côté de la case tourné vers le centre du chemin.
static func _trim_inner(cell: Rect2, heading: int, lane: int, amount: float) -> Rect2:
	var r := cell
	var axis := 0 if _lateral_is_x(heading) else 1
	# Couloir 0 : le centre du chemin est du côté des coordonnées croissantes.
	if lane != 0:
		r.position[axis] += amount
	r.size[axis] -= amount
	return r


static func _build_goal(data: LevelData, block: Rect2, heading: int, block_dist: float) -> void:
	_add_static(data, block, _color(data, "goal"))
	# On gagne en atteignant le cœur du bloc (là où trône la couronne), sur
	# toute sa largeur : même un cube décalé sur le côté gagne.
	var depth := block.size.x * 0.3
	var r := block
	match heading:
		EAST:
			r.position.x += depth
			r.size.x -= depth
		WEST:
			r.size.x -= depth
		PlayerMotor.SOUTH:
			r.position.y += depth
			r.size.y -= depth
		_:
			r.size.y -= depth
	data.goal_rect = r
	var c := block.get_center()
	data.crown_position = Vector3(c.x, 0.0, c.y)
	data.ideal_duration = (block_dist - block.size.x * 0.5 + depth) / data.speed


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
		parts.append("%s:%s:%.4f:%.4f" % [
			p.get_script().get_global_name(), p.rect, p.cycle_offset, p.cycle_period])
	for wp in data.waypoints:
		parts.append("%s:%s" % [wp.action, wp.pos])
	parts.append(str(data.goal_rect))
	return "|".join(parts)
