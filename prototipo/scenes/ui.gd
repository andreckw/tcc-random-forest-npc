extends Control

@onready var menu_lateral: Panel = $MenuLateral
@onready var menu_button: Button = $Menu
@onready var back_button: Button = $MenuLateral/BackButton


func _ready():
	menu_lateral.visible = false
	menu_button.pressed.connect(abrir_fechar_menu)
	back_button.pressed.connect(abrir_fechar_menu)


func abrir_fechar_menu():
	menu_lateral.visible = !menu_lateral.visible
