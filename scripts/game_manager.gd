extends Node
## Autoload « GameManager » : niveau courant, changements d'écran, étoiles.

const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_MENU := "res://scenes/main_menu.tscn"
const SCENE_LEVEL_SELECT := "res://scenes/level_select.tscn"

var current_level := 1


func level_count() -> int:
	return LevelDatabase.level_count()


func start_level(n: int) -> void:
	current_level = clampi(n, 1, level_count())
	_change_scene(SCENE_GAME)


func go_to_menu() -> void:
	_change_scene(SCENE_MENU)


func go_to_level_select() -> void:
	_change_scene(SCENE_LEVEL_SELECT)


func has_next_level(n: int) -> bool:
	return n < level_count()


## Niveau proposé par le bouton « Jouer » : le premier niveau débloqué
## pas encore terminé, sinon le dernier niveau.
func next_level_to_play() -> int:
	for n in range(1, level_count() + 1):
		if SaveManager.is_unlocked(n) and SaveManager.get_stars(n) == 0:
			return n
	return level_count()


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


## Règle des étoiles (simple et documentée) :
##   le temps de parcours est toujours le même (le cube avance à vitesse
##   constante), on note donc le nombre de CHUTES avant de réussir :
##   - 3 étoiles : chutes <= stars_max_deaths[0]  (par défaut 0 : du premier coup)
##   - 2 étoiles : chutes <= stars_max_deaths[1]  (par défaut 3)
##   - 1 étoile  : sinon (niveau terminé, c'est déjà bien !)
## Les seuils sont réglables pour chaque niveau dans data/levels.json.
func compute_stars(deaths: int, cfg: Dictionary) -> int:
	var limits: Array = cfg.get("stars_max_deaths", [0, 3])
	if deaths <= int(limits[0]):
		return 3
	if deaths <= int(limits[1]):
		return 2
	return 1


func on_level_completed(n: int, stars: int) -> void:
	SaveManager.record_level(n, stars)
