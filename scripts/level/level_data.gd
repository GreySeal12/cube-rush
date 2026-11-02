class_name LevelData
extends RefCounted
## Résultat du générateur : tout ce qu'il faut pour jouer (ou simuler) un niveau.

## Configuration d'origine (une entrée de data/levels.json).
var config: Dictionary = {}
## Palette du thème visuel.
var theme: Dictionary = {}
## Nœud racine contenant tous les éléments (à ajouter à la scène pour l'afficher).
var root: Node3D

## Éléments qui portent le cube (sols, plateformes spéciales).
var platforms: Array[PlatformBase] = []
## Éléments qui ne portent pas le cube mais peuvent le tuer (piliers, pointes).
var obstacles: Array[PlatformBase] = []

var speed := 4.0
var width := 3
var start_position := Vector3.ZERO
## Direction de départ (voir PlayerMotor.DIRECTIONS).
var start_direction := PlayerMotor.NORTH
## Zone d'arrivée : le niveau est gagné quand le centre du cube y entre.
var goal_rect: Rect2
var crown_position := Vector3.ZERO

## « Points d'action » du parcours idéal, dans l'ordre : virages au centre de
## chaque bloc d'angle et sauts au milieu de la zone d'appel de chaque trou.
## Chaque entrée : { pos: Vector2, dir: int (direction en arrivant),
## action: "left" | "right" | "jump", time: float (instant idéal) }.
## Utilisés par le bot du validateur.
var waypoints: Array[Dictionary] = []
## Statistiques de génération (affichées par le validateur).
var stats: Dictionary = {}
## Durée du parcours idéal (cube maintenu en continu, actions parfaites).
var ideal_duration := 0.0


# --- Découpage spatial -------------------------------------------------------
# Plutôt que de tester tous les éléments à chaque pas, on les range dans une
# grille de cases de BUCKET_SIZE × BUCKET_SIZE : le cube ne teste que la case
# où il se trouve. Indispensable pour les longs niveaux sur les petits téléphones.
const BUCKET_SIZE := 4.0

var _ground_buckets: Dictionary = {}
var _obstacle_buckets: Dictionary = {}
var _buckets_ready := false


func _build_buckets() -> void:
	_fill_buckets(platforms, _ground_buckets)
	_fill_buckets(obstacles, _obstacle_buckets)
	_buckets_ready = true


## Range chaque élément dans toutes les cases de grille que son emprise touche
## (l'ordre d'origine est conservé à l'intérieur d'une case).
func _fill_buckets(items: Array[PlatformBase], buckets: Dictionary) -> void:
	for item in items:
		var b := item.get_bounds().grow(PlatformBase.EPSILON)
		var lo := _cell_of(b.position)
		var hi := _cell_of(b.end)
		for cx in range(lo.x, hi.x + 1):
			for cz in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cz)
				if not buckets.has(key):
					buckets[key] = [] as Array[PlatformBase]
				buckets[key].append(item)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / BUCKET_SIZE), floori(p.y / BUCKET_SIZE))


## Renvoie l'élément qui porte le point p (x, z) au temps t, ou null (vide).
func ground_at(p: Vector2, t: float) -> PlatformBase:
	if not _buckets_ready:
		_build_buckets()
	var candidates: Array = _ground_buckets.get(_cell_of(p), [])
	for plat in candidates:
		if plat.is_ground_at(p, t):
			return plat
	return null


## Vrai si un piège ou un obstacle touche le cube.
func is_deadly(center: Vector3, half: float, t: float) -> bool:
	if not _buckets_ready:
		_build_buckets()
	var lo := _cell_of(Vector2(center.x - half, center.z - half))
	var hi := _cell_of(Vector2(center.x + half, center.z + half))
	for cx in range(lo.x, hi.x + 1):
		for cz in range(lo.y, hi.y + 1):
			for obs in _obstacle_buckets.get(Vector2i(cx, cz), []):
				if obs.is_deadly(center, half, t):
					return true
	return false


func reset() -> void:
	for plat in platforms:
		plat.reset()
	for obs in obstacles:
		obs.reset()


## État interne des éléments (sol fragile déjà touché…), pour que le bot puisse
## essayer une manœuvre puis revenir en arrière.
func save_state() -> Array:
	var out := []
	for plat in platforms:
		out.append(plat.get_state())
	return out


func load_state(saved: Array) -> void:
	for i in platforms.size():
		platforms[i].set_state(saved[i])


# --- Affichage ---------------------------------------------------------------

var _animated: Array[PlatformBase] = []
var _animated_ready := false

## Seuls les éléments animés à moins de cette distance (en cases) du cube sont
## mis à jour chaque image : les autres sont hors de l'écran.
const VISUAL_RADIUS := 26.0


## Met à jour l'affichage des éléments animés. Si `around` est fourni (position
## du cube), on ignore les éléments trop loin (hors écran) : économie de CPU.
func update_visuals(t: float, around: Variant = null) -> void:
	if not _animated_ready:
		for p in platforms + obstacles:
			if p.is_animated():
				_animated.append(p)
		_animated_ready = true
	for p in _animated:
		if around != null:
			var c := p.rect.get_center()
			if absf(c.x - around.x) > VISUAL_RADIUS or absf(c.y - around.z) > VISUAL_RADIUS:
				continue
		p.update_visual(t)


## Libère les nœuds (utile pour le validateur).
func free_nodes() -> void:
	if is_instance_valid(root):
		root.free()
