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
	get_tree().paused = false
	get_tree().change_scene_to_file(SCENE_GAME)


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
