class_name CameraFollow
extends Camera3D
## Caméra isométrique fixe (orthographique) qui suit le cube en douceur.
##
## L'angle ne change jamais : seule la position glisse. Le chemin monte
## toujours vers le haut de l'écran (diagonale +X / -Z).

## Largeur visible du monde (en cases), quel que soit le ratio de l'écran.
@export var view_width := 10.5
## Vitesse de suivi (plus grand = plus réactif).
@export var follow_speed := 5.0
## On regarde un peu devant le cube pour voir arriver les obstacles.
@export var look_ahead := 3.2

## Position de la caméra par rapport au point visé : vue isométrique (45°, ~35°).
const OFFSET := Vector3(-12.0, 12.0, 12.0)
const FORWARD := Vector3(0.7071, 0.0, -0.7071)

var _focus := Vector3.ZERO


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	keep_aspect = KEEP_WIDTH
	size = view_width
	near = 0.5
	far = 60.0


func _target_for(p: Vector3) -> Vector3:
	# On ignore la hauteur du cube (sauts, chute) pour une caméra stable.
	return Vector3(p.x, 0.0, p.z) + FORWARD * look_ahead


## Place immédiatement la caméra (début de niveau, redémarrage).
func snap_to(p: Vector3) -> void:
	_focus = _target_for(p)
	_apply()


func follow(p: Vector3, delta: float) -> void:
	_focus = _focus.lerp(_target_for(p), 1.0 - exp(-follow_speed * delta))
	_apply()


func _apply() -> void:
	global_position = _focus + OFFSET.normalized() * 30.0
	look_at(_focus, Vector3.UP)
