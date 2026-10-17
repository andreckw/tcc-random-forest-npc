extends Control

@onready var menu_lateral: Panel = $MenuLateral
@onready var shop: Control = $"../CanvasLayer/Shop"

@onready var menu_button: Button = $Menu
@onready var back_button: Button = $MenuLateral/BackButton
@onready var loja_button: Button = $MenuLateral/LojaButton


func _ready():
	# Inicialização
	menu_lateral.visible = false
	shop.visible = false

	# Menu lateral
	menu_button.pressed.connect(open_menu)
	back_button.pressed.connect(open_menu)

	# Loja
	loja_button.pressed.connect(open_loja)

func open_menu():
	menu_lateral.visible = !menu_lateral.visible

	if shop.visible:
		shop.visible = false

func open_loja():
	if menu_lateral.visible:
		menu_lateral.visible = false
	shop.visible = true
