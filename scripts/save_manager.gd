extends Node
## Autoload « SaveManager » : sauvegarde locale (ConfigFile dans user://).
## On ne stocke QUE : le dernier niveau débloqué et les étoiles par niveau.

const SAVE_PATH := "user://save.cfg"

## Plus haut niveau jouable (1 au départ).
var unlocked := 1
## Meilleur nombre d'étoiles par niveau : { numéro (int) : étoiles (int) }.
var stars: Dictionary = {}


func _ready() -> void:
	load_save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # Première partie : rien à charger.
	unlocked = int(cfg.get_value("progress", "unlocked", 1))
	stars.clear()
	var saved: Variant = cfg.get_value("progress", "stars", {})
	if typeof(saved) == TYPE_DICTIONARY:
		for key in saved:
			stars[int(key)] = clampi(int(saved[key]), 0, 3)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "stars", stars)
	cfg.save(SAVE_PATH)


func get_stars(level: int) -> int:
	return int(stars.get(level, 0))


func total_stars() -> int:
	var sum := 0
	for key in stars:
		sum += int(stars[key])
	return sum


func is_unlocked(level: int) -> bool:
	return level <= unlocked


## Enregistre un niveau terminé : garde le meilleur score, débloque le suivant.
func record_level(level: int, new_stars: int) -> void:
	stars[level] = maxi(get_stars(level), new_stars)
	unlocked = maxi(unlocked, level + 1)
	save()
