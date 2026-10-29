class_name LevelValidator
extends RefCounted
## Vérifie qu'un niveau généré est jouable.
##
## Deux familles de contrôles :
## 1) des règles « géométriques » simples (fenêtre de virage assez longue,
##    temps entre deux taps suffisant, sauts pas trop hauts…) ;
## 2) une SIMULATION complète avec le vrai PlayerMotor, par un « bot » qui
##    tape au centre de chaque virage (taps parfaits), puis avec des taps
##    volontairement en avance / en retard / aléatoires de TAP_JITTER secondes.
##    Le niveau doit être réussi dans tous les cas.
##
## Si un niveau échoue, c'est le GÉNÉRATEUR (ou la config) qu'il faut corriger,
## pas ce validateur.

## Fenêtre minimale (s) pendant laquelle un virage peut être pris.
const MIN_TURN_WINDOW := 0.3
## Temps minimal (s) entre deux virages successifs sur le chemin idéal.
const MIN_TAP_INTERVAL := 0.4
## Hauteur maximale (cases) d'un saut de tremplin.
const MAX_JUMP_APEX := 3.0
## Durée maximale (s) d'un saut.
const MAX_AIRTIME := 1.2
## Imprécision simulée sur le moment des taps (s).
const TAP_JITTER := 0.06
## Durée maximale simulée (s) avant d'abandonner.
const MAX_SIM_TIME := 180.0
## Le niveau 1 doit pouvoir être fini en 20 secondes.
const LEVEL1_MAX_TIME := 20.0


## Valide un niveau. Renvoie { ok, errors: [], time, runs: [...] }.
static func validate(number: int, cfg: Dictionary, theme: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []
	var data := LevelGenerator.generate(cfg, theme)

	# --- Déterminisme : même config => même niveau.
	var again := LevelGenerator.generate(cfg, theme)
	if LevelGenerator.signature(data) != LevelGenerator.signature(again):
		errors.append("génération non déterministe")
	again.free_nodes()

	# --- Virages : fenêtre et rythme.
	var turn_window := data.width / data.speed
	if turn_window < MIN_TURN_WINDOW:
		errors.append("fenêtre de virage trop courte : %.2f s" % turn_window)
	var prev_time := 0.0
	for tp in data.turn_points:
		var tt := data.ideal_time_at(tp)
		if tt - prev_time < MIN_TAP_INTERVAL:
			errors.append("virages trop rapprochés en %s : %.2f s" % [tp, tt - prev_time])
		prev_time = tt

	# --- Sauts : hauteur et durée raisonnables.
	for p in data.platforms:
		var vy := p.get_jump_velocity()
		if vy > 0.0:
			var apex := vy * vy / (2.0 * PlayerMotor.GRAVITY)
			var airtime := 2.0 * vy / PlayerMotor.GRAVITY
			if apex > MAX_JUMP_APEX:
				errors.append("saut trop haut (%.2f cases) en %s" % [apex, p.rect.position])
			if airtime > MAX_AIRTIME:
				errors.append("saut trop long (%.2f s) en %s" % [airtime, p.rect.position])

	# --- Simulations du bot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + number
	var random_offsets: Array[float] = []
	for i in data.turn_points.size():
		random_offsets.append(rng.randf_range(-TAP_JITTER, TAP_JITTER))
	var scenarios := {
		"parfait": func(_i: int) -> float: return 0.0,
		"en avance": func(_i: int) -> float: return -TAP_JITTER,
		"en retard": func(_i: int) -> float: return TAP_JITTER,
		"aléatoire": func(i: int) -> float: return random_offsets[i],
	}
	var runs := []
	var ideal_time := 0.0
	for scenario_name in scenarios:
		data.reset()
		var result := simulate(data, scenarios[scenario_name])
		result["name"] = scenario_name
		runs.append(result)
		if not result.won:
			errors.append("bot « %s » : échec (%s) à t=%.2f s en (%.2f, %.2f)" % [
				scenario_name, result.reason, result.time, result.pos.x, result.pos.z])
		elif scenario_name == "parfait":
			ideal_time = result.time

	if number == 1 and ideal_time > LEVEL1_MAX_TIME:
		errors.append("niveau 1 trop long : %.1f s (max %.0f s)" % [ideal_time, LEVEL1_MAX_TIME])

	var stats := data.stats.duplicate()
	data.free_nodes()
	return {"ok": errors.is_empty(), "errors": errors, "time": ideal_time,
		"runs": runs, "stats": stats, "turn_window": turn_window}


## Simule une partie : le bot tape quand son centre dépasse le centre du bloc
## d'angle, décalé de offset_for_turn(i) secondes (négatif = en avance).
static func simulate(data: LevelData, offset_for_turn: Callable) -> Dictionary:
	var motor := PlayerMotor.new(data)
	motor.start()
	var next_turn := 0
	var max_steps := int(MAX_SIM_TIME / PlayerMotor.STEP)
	while motor.state == PlayerMotor.State.RUNNING and motor.steps < max_steps:
		if next_turn < data.turn_points.size():
			var target: Vector2 = data.turn_points[next_turn]
			# Distance parcourue au-delà du point de virage, le long de la direction.
			var along := motor.pos.x - target.x if motor.dir == 0 else target.y - motor.pos.z
			var offset_dist := float(offset_for_turn.call(next_turn)) * data.speed
			if along >= offset_dist and motor.tap():
				next_turn += 1
		motor.step()
	var reason := ""
	match motor.state:
		PlayerMotor.State.WON:
			reason = "gagné"
		PlayerMotor.State.DEAD:
			reason = "chute" if motor.death == PlayerMotor.Death.FALL else "piège"
		_:
			reason = "temps dépassé"
	return {"won": motor.state == PlayerMotor.State.WON, "reason": reason,
		"time": motor.t, "pos": motor.pos}
