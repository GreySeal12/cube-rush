class_name LevelValidator
extends RefCounted
## Vérifie qu'un niveau généré est jouable.
##
## Deux familles de contrôles :
## 1) des règles « géométriques » simples (fenêtre de virage assez longue,
##    temps entre deux actions suffisant, zone d'appel des sauts…) ;
## 2) des SIMULATIONS complètes avec le vrai PlayerMotor, par un LevelBot :
##    - « expert » : appui continu et taps au bon endroit, puis avec des taps
##      volontairement en avance / en retard / aléatoires de TAP_JITTER secondes ;
##    - « prudent » : un seul doigt, arrêt à chaque virage, attente devant les
##      éléments à cycle. Le niveau doit être réussi dans tous les cas.
##
## Si un niveau échoue, c'est le GÉNÉRATEUR (ou la config) qu'il faut corriger,
## pas ce validateur.

## Fenêtre minimale (s) pendant laquelle un virage peut être pris en roulant.
const MIN_TURN_WINDOW := 0.3
## Temps minimal (s) entre deux actions successives du parcours idéal.
const MIN_TAP_INTERVAL := 0.4
## Zone d'appel minimale (s) d'un saut pour un cube lancé.
const MIN_JUMP_WINDOW := 0.2
## Hauteur maximale (cases) d'un saut.
const MAX_JUMP_APEX := 3.0
## Imprécision simulée sur le moment des taps (s).
const TAP_JITTER := 0.06
## Durée maximale simulée (s) avant d'abandonner.
const MAX_SIM_TIME := 400.0
## Le niveau 1 doit pouvoir être fini en 20 secondes.
const LEVEL1_MAX_TIME := 20.0


## Valide un niveau. Renvoie { ok, errors: [], time, careful_time, runs: [...] }.
static func validate(number: int, cfg: Dictionary, theme: Dictionary) -> Dictionary:
	var errors: PackedStringArray = []
	var data := LevelGenerator.generate(cfg, theme)

	# --- Déterminisme : même config => même niveau.
	var again := LevelGenerator.generate(cfg, theme)
	if LevelGenerator.signature(data) != LevelGenerator.signature(again):
		errors.append("génération non déterministe")
	again.free_nodes()

	# --- Virages et actions : fenêtre et rythme.
	var turn_window := data.width / data.speed
	if turn_window < MIN_TURN_WINDOW:
		errors.append("fenêtre de virage trop courte : %.2f s" % turn_window)
	var prev_time := 0.0
	for wp in data.waypoints:
		if float(wp.time) - prev_time < MIN_TAP_INTERVAL:
			errors.append("actions trop rapprochées en %s : %.2f s" % [wp.pos, float(wp.time) - prev_time])
		prev_time = float(wp.time)
		if wp.action == "jump" and float(wp.window) < MIN_JUMP_WINDOW:
			errors.append("zone d'appel trop courte en %s : %.2f s" % [wp.pos, float(wp.window)])

	# --- Saut : hauteur raisonnable.
	var apex := PlayerMotor.JUMP_VELOCITY * PlayerMotor.JUMP_VELOCITY / (2.0 * PlayerMotor.GRAVITY)
	if apex > MAX_JUMP_APEX:
		errors.append("saut trop haut : %.2f cases" % apex)

	# --- Simulations.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345 + number
	var random_offsets: Array[float] = []
	for i in data.waypoints.size():
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
		var bot := LevelBot.new(data, LevelBot.Mode.EXPERT)
		bot.offset_for = scenarios[scenario_name]
		var result := simulate(data, bot)
		result["name"] = scenario_name
		runs.append(result)
		if not result.won:
			errors.append("expert « %s » : échec (%s) à t=%.2f s en (%.2f, %.2f)" % [
				scenario_name, result.reason, result.time, result.pos.x, result.pos.z])
		elif scenario_name == "parfait":
			ideal_time = result.time

	var careful := simulate(data, LevelBot.new(data, LevelBot.Mode.PRUDENT))
	careful["name"] = "prudent"
	runs.append(careful)
	if not careful.won:
		errors.append("prudent (un doigt) : échec (%s) à t=%.2f s en (%.2f, %.2f)" % [
			careful.reason, careful.time, careful.pos.x, careful.pos.z])

	if number == 1 and ideal_time > LEVEL1_MAX_TIME:
		errors.append("niveau 1 trop long : %.1f s (max %.0f s)" % [ideal_time, LEVEL1_MAX_TIME])

	var stats := data.stats.duplicate()
	data.free_nodes()
	return {"ok": errors.is_empty(), "errors": errors, "time": ideal_time,
		"careful_time": careful.time, "runs": runs, "stats": stats, "turn_window": turn_window}


## Fait jouer un bot jusqu'à la victoire, la mort ou le temps maximal.
static func simulate(data: LevelData, bot: LevelBot) -> Dictionary:
	data.reset()
	var motor := PlayerMotor.new(data)
	var max_steps := int(MAX_SIM_TIME / PlayerMotor.STEP)
	var guard := 0
	while motor.state != PlayerMotor.State.DEAD and motor.state != PlayerMotor.State.WON \
			and motor.steps < max_steps and guard < max_steps * 2:
		bot.control(motor)
		motor.step()
		guard += 1
	var reason := ""
	match motor.state:
		PlayerMotor.State.WON:
			reason = "gagné"
		PlayerMotor.State.DEAD:
			reason = "chute" if motor.death == PlayerMotor.Death.FALL else "piège"
		_:
			reason = "bloqué" if bot.gave_up else "temps dépassé"
	data.reset()
	return {"won": motor.state == PlayerMotor.State.WON, "reason": reason,
		"time": motor.t, "pos": motor.pos, "waited": bot.waited}
