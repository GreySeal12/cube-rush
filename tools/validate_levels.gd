extends SceneTree
## Validation en ligne de commande de tous les niveaux.
##
## Utilisation (depuis le dossier du projet) :
##   godot --headless --path . --import            (une seule fois, après un clone)
##   godot --headless --path . --script res://tools/validate_levels.gd
##
## Code de sortie : 0 si tous les niveaux sont jouables, 1 sinon.


func _init() -> void:
	var levels := LevelDatabase.levels()
	if levels.is_empty():
		printerr("Aucun niveau trouvé dans data/levels.json")
		quit(1)
		return

	print("Validation de %d niveaux (jitter des taps : ±%.2f s)\n" % [levels.size(), LevelValidator.TAP_JITTER])
	print("Niv | Vitesse | Larg. | Virages | Fenêtre | Durée  | Détails")
	print("----+---------+-------+---------+---------+--------+--------")
	var all_ok := true
	var previous_speed := 0.0
	for i in levels.size():
		var number := i + 1
		var cfg: Dictionary = levels[i]
		var theme := LevelDatabase.get_theme(String(cfg.get("theme", "ciel")))
		var result := LevelValidator.validate(number, cfg, theme)
		var stats: Dictionary = result.stats
		var details := _describe(stats)
		print("%3d | %7.1f | %5d | %7d | %5.2f s | %5.1f s | %s %s" % [
			number, float(cfg.speed), int(cfg.width), int(stats.turns),
			result.turn_window, result.time, "OK " if result.ok else "ÉCHEC", details])
		for e in result.errors:
			print("      ✗ ", e)
		if float(cfg.speed) < previous_speed:
			print("      ! la vitesse baisse par rapport au niveau précédent")
		previous_speed = float(cfg.speed)
		all_ok = all_ok and result.ok

	print("")
	if all_ok:
		print("RÉSULTAT : tous les niveaux sont jouables.")
	else:
		print("RÉSULTAT : au moins un niveau est infaisable -> corriger le générateur ou la config.")
	quit(0 if all_ok else 1)


func _describe(stats: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in stats:
		if key in ["segments", "turns", "path_tiles"]:
			continue
		if int(stats[key]) > 0:
			parts.append("%s=%d" % [key, int(stats[key])])
	return ", ".join(parts)
