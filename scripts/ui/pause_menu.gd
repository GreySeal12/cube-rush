extends Control
## Menu pause : Reprendre / Recommencer / Menu.
## Ce nœud continue de fonctionner quand l'arbre de scène est en pause
## (process_mode = Always sur le CanvasLayer parent).

signal resume_requested
signal restart_requested
signal menu_requested

@onready var resume_button: Button = $Panel/Column/ResumeButton
@onready var restart_button: Button = $Panel/Column/RestartButton
@onready var menu_button: Button = $Panel/Column/MenuButton


func _ready() -> void:
	theme = UiStyle.get_theme()
	UiStyle.make_secondary(restart_button)
	UiStyle.make_secondary(menu_button)
	resume_button.pressed.connect(func() -> void: resume_requested.emit())
	restart_button.pressed.connect(func() -> void: restart_requested.emit())
	menu_button.pressed.connect(func() -> void: menu_requested.emit())
