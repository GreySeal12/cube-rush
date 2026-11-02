class_name TouchControls
extends Node
## Transforme les touchers en commandes de jeu.
##
##   - appui LONG (n'importe où)       : le cube avance tant que le doigt reste posé ;
##   - appui COURT à gauche de l'écran : quart de tour à gauche ;
##   - appui COURT à droite            : quart de tour à droite ;
##   - appui COURT au milieu           : saut.
## Plusieurs doigts sont gérés : on peut maintenir d'un pouce et taper de l'autre.
##
## Sur PC : clic maintenu = avancer, clic court = selon la zone ;
## clavier : ↑ / W (maintenu) = avancer, ← / A et → / D = tourner, Espace = sauter.

signal action(name: String)

## Un appui devient « long » (le cube avance) après ce délai (s).
const HOLD_DELAY := 0.15
## Au-delà de ce déplacement (pixels), un appui n'est plus un tap.
const TAP_MAX_MOVE := 60.0
## Largeur relative des zones gauche et droite (le reste = zone « saut »).
const SIDE_ZONE := 0.36

## Zones à ignorer (boutons de l'interface), en coordonnées d'écran.
var ignore_rects: Array[Rect2] = []

# Doigts posés : index -> { time: float, start: Vector2, pos: Vector2, hold: bool }
var _touches: Dictionary = {}
var _key_hold := false
var _time := 0.0


## Vrai si au moins un doigt est maintenu depuis plus de HOLD_DELAY (ou ↑ / W).
func is_holding() -> bool:
	if _key_hold:
		return true
	for t in _touches.values():
		if t.hold:
			return true
	return false


## Oublie tous les doigts (après une pause, un redémarrage…).
func clear() -> void:
	_touches.clear()
	_key_hold = false


func _process(delta: float) -> void:
	_time += delta
	for t in _touches.values():
		if not t.hold and _time - t.time >= HOLD_DELAY:
			t.hold = true


## Traite un évènement. Renvoie true s'il a été utilisé.
func handle(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		return _pointer(touch.index, touch.pressed, touch.position)
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _touches.has(drag.index):
			_touches[drag.index].pos = drag.position
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# Les clics « émulés » à partir des touchers sont ignorés : on traite
		# déjà les touchers eux-mêmes (sinon chaque tap compterait deux fois).
		if mb.device == InputEvent.DEVICE_ID_EMULATION or mb.button_index != MOUSE_BUTTON_LEFT:
			return false
		return _pointer(-1, mb.pressed, mb.position)
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.device != InputEvent.DEVICE_ID_EMULATION and _touches.has(-1):
			_touches[-1].pos = mm.position
		return false
	if event is InputEventKey:
		return _key(event as InputEventKey)
	return false


func _pointer(index: int, pressed: bool, pos: Vector2) -> bool:
	if pressed:
		for r in ignore_rects:
			if r.has_point(pos):
				return false
		_touches[index] = {"time": _time, "start": pos, "pos": pos, "hold": false}
		return true
	if not _touches.has(index):
		return false
	var t: Dictionary = _touches[index]
	_touches.erase(index)
	# Relâché avant de devenir un appui long, sans glisser : c'est un tap.
	if not t.hold and t.start.distance_to(pos) <= TAP_MAX_MOVE:
		action.emit(_zone_action(t.start))
	return true


func _zone_action(pos: Vector2) -> String:
	var width := get_viewport().get_visible_rect().size.x
	if pos.x < width * SIDE_ZONE:
		return "left"
	if pos.x > width * (1.0 - SIDE_ZONE):
		return "right"
	return "jump"


func _key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	match key.keycode:
		KEY_UP, KEY_W, KEY_Z:
			_key_hold = key.pressed
			return true
		KEY_LEFT, KEY_A, KEY_Q:
			if key.pressed:
				action.emit("left")
			return true
		KEY_RIGHT, KEY_D:
			if key.pressed:
				action.emit("right")
			return true
		KEY_SPACE:
			if key.pressed:
				action.emit("jump")
			return true
	return false
