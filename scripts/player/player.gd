class_name Player
extends Node3D
## Affichage du cube kawaii (blanc, arrondi, deux yeux noirs et des joues roses).
##
## Ce nœud ne décide de rien : il recopie l'état du PlayerMotor et ajoute des
## animations (rebond, étirement au saut, chute spectaculaire).

const SIZE := 0.6

var _pivot: Node3D        # rotation de « regard » (direction)
var _body: Node3D         # écrasement / étirement / culbute
var _shadow: MeshInstance3D
var _burst: CPUParticles3D

var _yaw := 0.0
var _squash := 0.0
var _bob_time := 0.0

# Animation de mort / victoire (indépendante de la simulation).
var _anim := ""
var _anim_time := 0.0
var _anim_velocity := Vector3.ZERO
var _anim_spin := Vector3.ZERO


func _ready() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_body = Node3D.new()
	_body.position.y = SIZE * 0.5
	_pivot.add_child(_body)

	var cube := MeshFactory.instance(
		MeshFactory.rounded_box(SIZE, 0.14), MeshFactory.material(Color(0.98, 0.98, 1.0)))
	_body.add_child(cube)

	# Le visage est sur la face -Z locale. Voir _face_yaw() pour son orientation.
	var eye_mat := MeshFactory.material(Color(0.08, 0.08, 0.12))
	var cheek_mat := MeshFactory.material(Color(1.0, 0.62, 0.74))
	for side in [-1.0, 1.0]:
		var eye := MeshFactory.instance(MeshFactory.sphere(0.055, 8), eye_mat)
		eye.position = Vector3(0.12 * side, 0.05, -SIZE * 0.5 + 0.01)
		eye.scale = Vector3(1.0, 1.25, 0.6)
		_body.add_child(eye)
		var cheek := MeshFactory.instance(MeshFactory.sphere(0.05, 8), cheek_mat)
		cheek.position = Vector3(0.2 * side, -0.06, -SIZE * 0.5 + 0.005)
		cheek.scale = Vector3(1.3, 0.7, 0.3)
		_body.add_child(cheek)

	# Ombre « blob » : un simple carré sombre semi-transparent (pas d'ombre dynamique).
	_shadow = MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.62, 0.62)
	_shadow.mesh = quad
	_shadow.material_override = MeshFactory.unshaded(Color(0, 0, 0, 0.28))
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadow)

	# Éclats de petits cubes pour la chute et la victoire.
	_burst = CPUParticles3D.new()
	_burst.emitting = false
	_burst.one_shot = true
	_burst.amount = 14
	_burst.lifetime = 0.7
	_burst.explosiveness = 1.0
	_burst.mesh = MeshFactory.box(Vector3.ONE * 0.1)
	_burst.direction = Vector3.UP
	_burst.spread = 70.0
	_burst.initial_velocity_min = 3.0
	_burst.initial_velocity_max = 5.5
	_burst.gravity = Vector3(0, -14, 0)
	_burst.scale_amount_min = 0.6
	_burst.scale_amount_max = 1.2
	var burst_mat := StandardMaterial3D.new()
	burst_mat.vertex_color_use_as_albedo = true
	burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_burst.material_override = burst_mat
	_burst.local_coords = false
	add_child(_burst)


## Recopie l'état du moteur (appelé chaque image).
func sync_with(motor: PlayerMotor, delta: float) -> void:
	if _anim != "":
		_update_anim(delta)
		return
	position = motor.pos
	# Rotation douce : le cube « tourne la tête » à chaque virage.
	_yaw = lerp_angle(_yaw, _face_yaw(motor.dir), 1.0 - exp(-22.0 * delta))
	_pivot.rotation = Vector3(0, _yaw, 0)

	if motor.just_jumped:
		_squash = -0.35
	elif motor.just_landed:
		_squash = 0.4
	elif motor.just_turned:
		_squash = 0.12
	_squash = lerpf(_squash, 0.0, 1.0 - exp(-10.0 * delta))

	# Petit dandinement quand il roule au sol.
	var wobble := 0.0
	if motor.state == PlayerMotor.State.RUNNING and motor.grounded:
		_bob_time += delta
		wobble = absf(sin(_bob_time * 14.0)) * 0.035
	var sy := 1.0 - _squash * 0.35
	var sxz := 1.0 + _squash * 0.2
	_body.scale = Vector3(sxz, sy, sxz)
	_body.position.y = SIZE * 0.5 * sy + wobble
	_body.rotation = Vector3.ZERO

	_shadow.visible = true
	_shadow.global_position = Vector3(position.x, 0.012, position.z)
	var h := clampf(1.0 - motor.pos.y * 0.3, 0.3, 1.0)
	_shadow.scale = Vector3(h, 1, h)
	if motor.pos.y < -0.05:
		_shadow.visible = false


## Le cube regarde vers la caméra (pour qu'on voie son visage), en tournant
## un peu la tête vers sa direction de déplacement.
func _face_yaw(dir: int) -> float:
	var back := CameraFollow.back_direction()
	var heading: Vector2 = PlayerMotor.DIRECTIONS[dir]
	var look := Vector2(back.x, back.z).normalized() + heading * 0.9
	if look.length_squared() < 0.01:
		look = heading
	# La face « visage » est la face -Z locale.
	return atan2(-look.x, -look.y)


## Remet le cube à l'état de départ (après une chute).
func reset_visual(motor: PlayerMotor) -> void:
	_anim = ""
	_squash = 0.0
	_yaw = _face_yaw(motor.dir)
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE
	_body.position = Vector3(0, SIZE * 0.5, 0)
	visible = true
	sync_with(motor, 0.0)


## Chute spectaculaire : le cube part en tournoyant.
func play_death(motor: PlayerMotor, burst_color: Color) -> void:
	var fwd := motor.forward()
	var dir3 := Vector3(fwd.x, 0, fwd.y)
	_anim_time = 0.0
	if motor.death == PlayerMotor.Death.HIT:
		_anim = "hit"
		_anim_velocity = -dir3 * 2.5 + Vector3.UP * 7.0
		_emit_burst(burst_color)
	else:
		_anim = "fall"
		_anim_velocity = dir3 * motor.level.speed * 0.8 + Vector3.UP * minf(motor.vy, 1.0)
	# Axe de rotation perpendiculaire à la direction : il « bascule ».
	_anim_spin = dir3.cross(Vector3.UP) * -9.0 + Vector3.UP * 4.0


func play_win(burst_color: Color) -> void:
	_anim = "win"
	_anim_time = 0.0
	_emit_burst(burst_color)


func _emit_burst(c: Color) -> void:
	_burst.color = c
	_burst.global_position = global_position + Vector3.UP * 0.3
	_burst.restart()
	_burst.emitting = true


func _update_anim(delta: float) -> void:
	_anim_time += delta
	match _anim:
		"fall", "hit":
			_anim_velocity.y -= 28.0 * delta
			position += _anim_velocity * delta
			_body.rotation += _anim_spin * delta
			_shadow.visible = false
		"win":
			# Petits sauts de joie.
			var hop := absf(sin(_anim_time * 7.0)) * 0.6 * exp(-_anim_time * 0.8)
			_body.position.y = SIZE * 0.5 + hop
			_pivot.rotation.y += delta * 6.0 * exp(-_anim_time)
			_shadow.global_position = Vector3(position.x, 0.012, position.z)
