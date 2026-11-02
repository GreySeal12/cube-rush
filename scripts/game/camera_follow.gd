class_name CameraFollow
extends Camera3D
## Caméra 3/4 fixe (orthographique) qui suit le cube en douceur.
##
## L'angle ne change jamais : seule la position glisse. Le chemin progresse
## toujours vers le haut de l'écran (-Z), avec des détours à gauche et à droite.
## La caméra est légèrement tournée pour montrer le dessus, l'avant et un
## côté des blocs (effet 3D low-poly).

## Largeur visible du monde (en cases), quel que soit le ratio de l'écran.
@export var view_width := 10.5
## Vitesse de suivi (plus grand = plus réactif).
@export var follow_speed := 5.0
## On regarde un peu devant le cube pour voir arriver les obstacles.
@export var look_ahead := 3.5
## Anticipation dans la direction du cube quand il part sur le côté.
@export var side_look := 1.8

## Rotation de la caméra autour de la verticale (degrés) et inclinaison.
const YAW_DEGREES := 20.0
const PITCH_DEGREES := 45.0
## Direction « vers l'avant » du chemin.
const FORWARD := Vector3(0.0, 0.0, -1.0)

var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_WIDTH
	size = view_width
	near = 0.5
	far = 60.0


## Direction (unitaire) du point visé vers la caméra.
static func back_direction() -> Vector3:
	var yaw := deg_to_rad(YAW_DEGREES)
	var pitch := deg_to_rad(PITCH_DEGREES)
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


## Regarde devant (haut de l'écran) et un peu dans la direction du cube.
func _target_for(p: Vector3, heading: Vector2 = Vector2.ZERO) -> Vector3:
	# On ignore la hauteur du cube (sauts, chute) pour une caméra stable.
	return Vector3(p.x, 0.0, p.z) + FORWARD * look_ahead + Vector3(heading.x, 0.0, heading.y) * side_look


## Place immédiatement la caméra (début de niveau, redémarrage).
func snap_to(p: Vector3, heading: Vector2 = Vector2.ZERO) -> void:
	_focus = _target_for(p, heading)
	_apply()


func follow(p: Vector3, delta: float, heading: Vector2 = Vector2.ZERO) -> void:
	_focus = _focus.lerp(_target_for(p, heading), 1.0 - exp(-follow_speed * delta))
	_apply()


func _apply() -> void:
	global_position = _focus + back_direction() * 30.0
	look_at(_focus, Vector3.UP)
