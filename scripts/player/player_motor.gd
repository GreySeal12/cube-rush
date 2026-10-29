class_name PlayerMotor
extends RefCounted
## « Moteur » du cube : déplacement manuel et déterministe, sans moteur physique.
##
## Le cube avance tout seul à vitesse constante, soit vers +X, soit vers -Z
## (les deux diagonales de l'écran). Un tap alterne entre ces deux axes.
## La simulation avance par pas FIXES de STEP secondes : avec les mêmes taps
## aux mêmes pas, on obtient toujours exactement le même résultat. Le jeu et le
## script de validation utilisent tous les deux cette classe.

enum State { WAITING, RUNNING, DEAD, WON }
enum Death { NONE, FALL, HIT }

## Pas de simulation (120 pas par seconde).
const STEP := 1.0 / 120.0
## Gravité en cases/s² (une case = 1 unité).
const GRAVITY := 25.0
## Demi-taille visuelle du cube (le cube fait 0,6 case de côté).
const HALF_SIZE := 0.3
## Demi-taille utilisée pour les pièges : un peu plus petite que le cube
## visible, pour être indulgent (« ça m'a à peine frôlé ! »).
const HAZARD_HALF := 0.22
## En dessous de cette hauteur, le cube ne peut plus remonter sur un bloc : chute.
const FALL_LIMIT := -0.25

## Directions possibles, en (x, z).
const DIRECTIONS := [Vector2(1, 0), Vector2(0, -1)]

var level: LevelData
var state := State.WAITING
var death := Death.NONE
var pos := Vector3.ZERO
var dir := 0
var vy := 0.0
var grounded := true
var ground: PlatformBase = null
## Temps du niveau (s) depuis le départ du cube.
var t := 0.0
## Nombre de pas simulés depuis le départ.
var steps := 0

# Événements du dernier pas (lus par le jeu pour les animations).
var just_jumped := false
var just_landed := false
var just_turned := false


func _init(level_data: LevelData) -> void:
	level = level_data
	reset()


func reset() -> void:
	state = State.WAITING
	death = Death.NONE
	pos = level.start_position
	dir = level.start_direction
	vy = 0.0
	grounded = true
	ground = null
	t = 0.0
	steps = 0


func start() -> void:
	if state == State.WAITING:
		state = State.RUNNING


## Changement de direction. Impossible en l'air (règle simple et lisible).
## Renvoie true si le virage a été pris en compte.
func tap() -> bool:
	if state != State.RUNNING or not grounded:
		return false
	dir = 1 - dir
	just_turned = true
	return true


func forward() -> Vector2:
	return DIRECTIONS[dir]


## Avance la simulation d'un pas fixe.
func step() -> void:
	just_jumped = false
	just_landed = false
	just_turned = false
	if state != State.RUNNING:
		return
	t += STEP
	steps += 1

	# 1) Déplacement horizontal : vitesse constante + éventuel entraînement
	#    par une plateforme mobile.
	var vel := forward() * level.speed
	if grounded and ground != null:
		vel += ground.get_velocity(t)
	pos.x += vel.x * STEP
	pos.z += vel.y * STEP
	var p := Vector2(pos.x, pos.z)

	# 2) Sol / saut / chute.
	if grounded:
		var g := level.ground_at(p, t)
		if g == null:
			# Plus rien sous le centre du cube : il commence à tomber.
			grounded = false
			ground = null
			vy = 0.0
		else:
			ground = g
			g.on_touch(t)
			var jump := g.get_jump_velocity()
			if jump > 0.0:
				vy = jump
				grounded = false
				ground = null
				just_jumped = true
	else:
		vy -= GRAVITY * STEP
		pos.y += vy * STEP
		if pos.y <= 0.0 and vy <= 0.0 and pos.y > FALL_LIMIT:
			var g := level.ground_at(p, t)
			if g != null:
				pos.y = 0.0
				vy = 0.0
				grounded = true
				ground = g
				g.on_touch(t)
				just_landed = true
		if not grounded and pos.y <= FALL_LIMIT:
			state = State.DEAD
			death = Death.FALL
			return

	# 3) Pièges.
	if level.is_deadly(pos, HAZARD_HALF, t):
		state = State.DEAD
		death = Death.HIT
		return

	# 4) Arrivée.
	if grounded and level.goal_rect.has_point(p):
		state = State.WON
