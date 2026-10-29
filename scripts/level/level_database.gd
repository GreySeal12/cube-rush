class_name LevelDatabase
extends RefCounted
## Lecture de data/levels.json (configuration des 10 niveaux et des thèmes).
## Utilisé par GameManager en jeu et par le script de validation.

const PATH := "res://data/levels.json"

static var _cache: Dictionary = {}


static func load_data() -> Dictionary:
	if not _cache.is_empty():
		return _cache
	var text := FileAccess.get_file_as_string(PATH)
	if text.is_empty():
		push_error("Impossible de lire %s" % PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("%s : JSON invalide" % PATH)
		return {}
	_cache = parsed
	return _cache


static func levels() -> Array:
	return load_data().get("levels", [])


static func level_count() -> int:
	return levels().size()


## Configuration du niveau `number` (1 à N).
static func get_level(number: int) -> Dictionary:
	var all := levels()
	if number < 1 or number > all.size():
		return {}
	return all[number - 1]


## Palette d'un thème, avec les couleurs converties en Color.
static func get_theme(theme_name: String) -> Dictionary:
	var raw: Dictionary = load_data().get("themes", {}).get(theme_name, {})
	var out := {}
	for key in raw:
		var value: Variant = raw[key]
		if typeof(value) == TYPE_STRING and String(value).begins_with("#"):
			out[key] = Color(String(value))
		else:
			out[key] = value
	return out
