class_name PlatformBase
extends Node3D
## Classe de base de tous les éléments d'un niveau (sols, tremplins, pièges…).
##
## Principe important : la logique de jeu ne dépend PAS des nœuds affichés.
## Chaque élément répond à des questions « analytiques » à partir du temps
## du niveau `t` (en secondes depuis le départ du cube) :
##   - est-ce que je porte le cube au point p ?  -> is_ground_at()
##   - est-ce que je tue le cube ?               -> is_deadly()
## Le même code sert donc au jeu ET au script de validation (simulation sans
## affichage), ce qui rend tout le niveau déterministe.
##
## Coordonnées : le sol est un plan (x, z). On stocke les emprises au sol dans
## des Rect2 où `Vector2.x` = x du monde et `Vector2.y` = z du monde.
## Le dessus des plateformes est à y = 0.

## Épaisseur visuelle des blocs (purement décoratif).
const BLOCK_HEIGHT := 1.2
## Petite tolérance pour éviter les « fentes » entre deux rectangles voisins.
const EPSILON := 0.002

## Emprise au sol (x, z) au repos.
var rect: Rect2
var color: Color = Color.WHITE
## false pour les obstacles posés sur un autre sol (piliers, pointes).
var provides_ground := true

# --- Cycle temporel (plateformes intermittentes, pointes, plateformes mobiles)
# Un cycle se compose de : phase « sûre » (durée cycle_safe), transition,
# phase « dangereuse/absente » (cycle_hidden), transition retour.
var cycle_period := 0.0
var cycle_offset := 0.0
var cycle_safe := 0.0
var cycle_hidden := 0.0
var cycle_transition := 0.2


# ---------------------------------------------------------------------------
# API utilisée par le moteur du cube et le validateur
# ---------------------------------------------------------------------------

## Remet l'élément dans son état initial (appelé à chaque redémarrage).
func reset() -> void:
	pass


## Emprise au sol au temps t (les plateformes mobiles la déplacent).
func get_rect_at(_t: float) -> Rect2:
	return rect


## L'élément est-il « praticable » au temps t ?
func is_solid(_t: float) -> bool:
	return true


func is_ground_at(p: Vector2, t: float) -> bool:
	return provides_ground and is_solid(t) and get_rect_at(t).grow(EPSILON).has_point(p)


## Vitesse (x, z) transmise au cube posé dessus (plateformes mobiles).
func get_velocity(_t: float) -> Vector2:
	return Vector2.ZERO


## Vitesse verticale donnée au cube quand il arrive dessus (tremplins). 0 = rien.
func get_jump_velocity() -> float:
	return 0.0


## Appelé à chaque pas de simulation où le cube est posé sur cet élément.
func on_touch(_t: float) -> void:
	pass


## Le cube (centre `center`, demi-largeur `half`) est-il tué au temps t ?
func is_deadly(_center: Vector3, _half: float, _t: float) -> bool:
	return false


## true si l'affichage change avec le temps (seuls ces éléments sont mis à
## jour chaque image, pour économiser du temps de calcul).
func is_animated() -> bool:
	return false


## Met à jour l'affichage pour le temps t (appelé chaque image en jeu).
func update_visual(_t: float) -> void:
	pass


## Construit les maillages. Appelé seulement quand le nœud entre dans la
## scène : le validateur, qui n'ajoute rien à l'arbre, ne crée aucun maillage.
func build_visual() -> void:
	pass


func _ready() -> void:
	build_visual()
	update_visual(0.0)


# ---------------------------------------------------------------------------
# Outils communs
# ---------------------------------------------------------------------------

func setup(r: Rect2, c: Color) -> void:
	rect = r
	color = c
	# Le nœud est placé au centre de son emprise, au niveau du sol.
	var center := r.get_center()
	position = Vector3(center.x, 0.0, center.y)


## Configure le cycle pour que le milieu de la phase sûre tombe à `safe_center_time`.
func setup_cycle(safe_center_time: float, safe_duration: float, hidden_duration: float, transition: float) -> void:
	cycle_safe = safe_duration
	cycle_hidden = hidden_duration
	cycle_transition = transition
	cycle_period = safe_duration + hidden_duration + 2.0 * transition
	cycle_offset = safe_center_time - safe_duration * 0.5


func cycle_phase(t: float) -> float:
	if cycle_period <= 0.0:
		return 0.0
	return fposmod(t - cycle_offset, cycle_period)


## Vrai pendant toute la phase sûre du cycle.
func cycle_is_safe(t: float) -> bool:
	return cycle_phase(t) < cycle_safe


## 0 = position « sûre », 1 = position « cachée/dangereuse », avec transitions.
func cycle_amount(t: float) -> float:
	var ph := cycle_phase(t)
	if ph < cycle_safe:
		return 0.0
	ph -= cycle_safe
	if ph < cycle_transition:
		return ph / cycle_transition
	ph -= cycle_transition
	if ph < cycle_hidden:
		return 1.0
	ph -= cycle_hidden
	return clampf(1.0 - ph / cycle_transition, 0.0, 1.0)


## Bloc coloré de taille `size_xz`, centré sous le nœud, dessus à y = 0.
func make_block(size_xz: Vector2, height: float, c: Color) -> MeshInstance3D:
	var mi := MeshFactory.instance(
		MeshFactory.box(Vector3(size_xz.x, height, size_xz.y)), MeshFactory.material(c))
	mi.position.y = -height * 0.5
	add_child(mi)
	return mi


## Test de recouvrement entre le cube (carré de demi-largeur `half`) et un rectangle.
static func overlaps(center: Vector3, half: float, r: Rect2) -> bool:
	return center.x + half > r.position.x and center.x - half < r.end.x \
		and center.z + half > r.position.y and center.z - half < r.end.y
