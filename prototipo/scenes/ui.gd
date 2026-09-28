extends Control

@onready var menu_lateral: Panel = $MenuLateral

@onready var shop: Panel = $Shop
@onready var skins: Panel = $Shop/Skins
@onready var eficiencia: Panel = $Shop/Eficiencia
@onready var fortune: Panel = $Shop/Fortune
@onready var extras: Panel = $Shop/Extras

@onready var menu_button: Button = $Menu
@onready var back_button: Button = $MenuLateral/BackButton

@onready var loja_button: Button = $MenuLateral/LojaButton
@onready var skin_button: Button = $Shop/SkinButton
@onready var eficiencia_button: Button = $Shop/EficienciaButton
@onready var fortune_button: Button = $Shop/FortuneButton
@onready var extras_button: Button = $Shop/ExtrasButton
@onready var exit_button: Button = $Shop/ExitButton


func _ready():
	# Inicialização
	menu_lateral.visible = false
	shop.visible = false

	skins.visible = false
	eficiencia.visible = false
	fortune.visible = false
	extras.visible = false

	# Menu lateral
	menu_button.pressed.connect(open_menu)
	back_button.pressed.connect(open_menu)

	# Loja
	loja_button.pressed.connect(open_loja)
	skin_button.pressed.connect(open_skins)
	eficiencia_button.pressed.connect(open_eficiencia)
	fortune_button.pressed.connect(open_fortune)
	extras_button.pressed.connect(open_extras)
	exit_button.pressed.connect(exit_shop)

func open_menu():
	menu_lateral.visible = !menu_lateral.visible


func open_loja():
	if menu_lateral.visible:
		menu_lateral.visible = false

	shop.visible = !shop.visible
	if shop.visible:
		abrir_categoria(skins)
		

func open_skins():
	abrir_categoria(skins)


func open_eficiencia():
	abrir_categoria(eficiencia)


func open_fortune():
	abrir_categoria(fortune)


func open_extras():
	abrir_categoria(extras)


func abrir_categoria(categoria: Panel):
	shop.visible = true

	var estava_aberta = categoria.visible

	skins.visible = false
	eficiencia.visible = false
	fortune.visible = false
	extras.visible = false

	if !estava_aberta:
		categoria.visible = true
		
func exit_shop():
	shop.visible = false
	skins.visible = false
	eficiencia.visible = false
	fortune.visible = false
	extras.visible = false
