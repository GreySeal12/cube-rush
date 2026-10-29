class_name StaticPlatform
extends PlatformBase
## Sol fixe : un simple bloc coloré, toujours praticable.
## Les rangées consécutives de sol fixe sont fusionnées en un seul bloc
## par le générateur (moins d'objets à dessiner).


func build_visual() -> void:
	make_block(rect.size, BLOCK_HEIGHT, color)
