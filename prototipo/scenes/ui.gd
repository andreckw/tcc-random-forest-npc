extends Control

@onready var menu_lateral: Panel = $MenuLateral
@onready var shop: Control = $"../CanvasLayer/Shop"
@onready var roleta: Control = $"../CanvasLayer/Roleta"
@onready var npc: Control = $"../CanvasLayer/NPC"

@onready var menu_button: Button = $Menu
@onready var back_button: Button = $MenuLateral/BackButton
@onready var loja_button: Button = $MenuLateral/LojaButton
@onready var roleta_button: Button = $MenuLateral/RoletaButton
@onready var NPCbutton: Button = $MenuLateral/NPCButton
@onready var exit_button: Button = $"../CanvasLayer/Roleta/ExitButton"

func _ready():
	# Inicialização
	menu_lateral.visible = false
	shop.visible = false
	roleta.visible = false
	npc.visible = false	
	
	# Menu lateral
	menu_button.pressed.connect(open_menu)
	back_button.pressed.connect(open_menu)

	# Loja
	loja_button.pressed.connect(open_loja)
	roleta_button.pressed.connect(open_roleta)
	NPCbutton.pressed.connect(open_NPC)
	
	exit_button.pressed.connect(open_roleta)

func open_menu():
	menu_lateral.visible = !menu_lateral.visible

	if shop.visible:
		shop.visible = false

func open_loja():
	if menu_lateral.visible:
		menu_lateral.visible = false
	shop.visible = true
	
func open_roleta():
	if roleta.visible == false:
		if menu_lateral.visible:
			menu_lateral.visible = false
		roleta.visible = true	
	else:
		roleta.visible = false			

func open_NPC():
	if menu_lateral.visible:
		menu_lateral.visible = false
	npc.visible = true	
