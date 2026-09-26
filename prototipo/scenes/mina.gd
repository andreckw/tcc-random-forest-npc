extends Area2D

@export var cliques_maximos: int = 10
@export var tempo_recuperacao: float = 20.0

var cliques: int = 0
var esgotada: bool = false
var tempo_passado: float = 0.0

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var efeito: AnimatedSprite2D = $"../AnimatedEffect"

func _ready():
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(recuperar_mina)

	efeito.play("default")
	
	

func _input_event(viewport, event, shape_idx):
	if esgotada:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			minerar(event.position)

func minerar(posicao_clique):
	cliques += 1

	GameManager.adicionar_dinheiro(1)

	print("Cliques:", cliques, "/", cliques_maximos)

	# Coloca o efeito exatamente onde o jogador clicou
	efeito.position = posicao_clique
	efeito.play("click")
	await get_tree().create_timer(0.5).timeout # Espera 0.5 segundos
	efeito.play("default")

	# 3 cliques → estado médio
	if cliques == 3:
		sprite.play("media")

	# 7 cliques → estado baixo
	if cliques == 7:
		sprite.play("baixa")

	# 10 cliques → estado vazio
	if cliques == 10:
		sprite.play("vazia")

	if cliques >= cliques_maximos:
		esgotar_mina()



func esgotar_mina():
	esgotada = true
	tempo_passado = 0.0

	print("Mina esgotada!")

	timer.start()

func recuperar_mina():
	tempo_passado += 1.0

	# Depois de 6 segundos → estado baixo
	if tempo_passado == 6:
		sprite.play("baixa")
		print("Mina voltou para baixa!")

	# Depois de 14 segundos → estado médio
	if tempo_passado == 14:
		sprite.play("media")
		print("Mina voltou para media!")

	# Depois de 20 segundos → estado cheia
	if tempo_passado >= tempo_recuperacao:
		sprite.play("cheia")

		cliques = 0
		esgotada = false
		timer.stop()

		print("Mina recuperada!")
