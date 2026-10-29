class_name LevelData
extends RefCounted
## Résultat du générateur : tout ce qu'il faut pour jouer (ou simuler) un niveau.

## Configuration d'origine (une entrée de data/levels.json).
var config: Dictionary = {}
## Palette du thème visuel.
var theme: Dictionary = {}
## Nœud racine contenant tous les éléments (à ajouter à la scène pour l'afficher).
var root: Node3D

## Éléments qui portent le cube (sols, tremplins, plateformes spéciales).
var platforms: Array[PlatformBase] = []
## Éléments qui ne portent pas le cube mais peuvent le tuer (piliers, pointes).
var obstacles: Array[PlatformBase] = []

var speed := 4.0
var width := 3
var start_position := Vector3.ZERO
## Direction de départ : 0 = +X, 1 = -Z (voir PlayerMotor).
var start_direction := 0
## Zone d'arrivée : le niveau est gagné quand le centre du cube y entre.
var goal_rect: Rect2
var crown_position := Vector3.ZERO

## Points de virage « idéaux » (centre de chaque bloc d'angle), dans l'ordre.
## Utilisés par le validateur pour simuler des taps parfaits.
var turn_points: Array[Vector2] = []
## Statistiques de génération (affichées par le validateur).
var stats: Dictionary = {}


## Renvoie l'élément qui porte le point p (x, z) au temps t, ou null (vide).
func ground_at(p: Vector2, t: float) -> PlatformBase:
	for plat in platforms:
		if plat.is_ground_at(p, t):
			return plat
	return null


## Vrai si un piège ou un obstacle touche le cube.
func is_deadly(center: Vector3, half: float, t: float) -> bool:
	for obs in obstacles:
		if obs.is_deadly(center, half, t):
			return true
	return false


func reset() -> void:
	for plat in platforms:
		plat.reset()
	for obs in obstacles:
		obs.reset()


var _animated: Array[PlatformBase] = []
var _animated_progress: PackedFloat32Array = []
var _animated_ready := false

## Seuls les éléments animés situés dans cette fenêtre de progression autour
## du cube (en cases, derrière / devant) sont mis à jour chaque image.
const VISUAL_BEHIND := 12.0
const VISUAL_AHEAD := 40.0


## Met à jour l'affichage des éléments animés. Si `around` est fourni (position
## du cube), on ignore les éléments trop loin (hors écran) : économie de CPU.
func update_visuals(t: float, around: Variant = null) -> void:
	if not _animated_ready:
		for p in platforms + obstacles:
			if p.is_animated():
				_animated.append(p)
				_animated_progress.append(progress_of(p.rect.get_center()))
		_animated_ready = true
	var focus := 0.0
	if around != null:
		focus = progress_of(Vector2(around.x, around.z))
	for i in _animated.size():
		if around != null:
			var d := _animated_progress[i] - focus
			if d < -VISUAL_BEHIND or d > VISUAL_AHEAD:
				continue
		_animated[i].update_visual(t)


## Distance « de Manhattan » parcourue depuis le départ pour atteindre p.
## Le cube avance toujours à vitesse constante soit vers +X soit vers -Z :
## la quantité (x - z) augmente donc exactement de `speed` par seconde, quel
## que soit le moment des virages. Le temps d'arrivée en un point ne dépend
## donc QUE de sa position : c'est ce qui permet de synchroniser les pièges.
func progress_of(p: Vector2) -> float:
	return (p.x - p.y) - (start_position.x - start_position.z)


func ideal_time_at(p: Vector2) -> float:
	return progress_of(p) / speed


## Libère les nœuds (utile pour le validateur).
func free_nodes() -> void:
	if is_instance_valid(root):
		root.free()
