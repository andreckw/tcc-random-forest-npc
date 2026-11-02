extends Area2D

@export var cliques_maximos: int = 10
@export var valor_total: int = 10
@export var tempo_recuperacao: float = 20.0

var cliques: int = 0
var esgotada: bool = false
var tempo_passado: float = 0.0

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var efeito: AnimatedSprite2D = $"../AnimatedEffect"
@onready var cursor_manager = $"../../UI/CursorManager"

func _ready():
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(recuperar_mina)

	efeito.play("default")

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	



func _input_event(viewport, event, shape_idx):
	if esgotada:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			cursor_manager.animar_picareta()
			minerar(event.position)

func _on_mouse_entered():
	if not esgotada:
		cursor_manager.ativar_cursor_picareta()


func _on_mouse_exited():
	cursor_manager.desativar_cursor_picareta()
	
	
func minerar(posicao_clique):
	# Eficiência 0 = 3 dano
	# Eficiência 1 = 4 dano
	# Eficiência 2 = 5 dano
	# etc.
	var dano: int = GameManager.eficiencia

	# Quanto da mina ainda faltava minerar
	var restante: int = cliques_maximos - cliques

	# O dano pode passar do limite da mina,
	# mas o dinheiro considera somente o que faltava.
	var dano_real: int = min(dano, restante)

	cliques += dano

	# Valor de cada ponto de mineração
	var valor_por_clique: float = float(valor_total) / cliques_maximos

	# Dinheiro base correspondente ao que realmente foi minerado
	var dinheiro_base: int = roundi(valor_por_clique * dano_real)

	# Fortuna aumenta o dinheiro recebido
	# Fortuna 0 = x1
	# Fortuna 1 = x2
	# Fortuna 2 = x3
	# etc.
	var multiplicador_fortuna: int = GameManager.fortuna

	var dinheiro_ganho: int = dinheiro_base * multiplicador_fortuna

	GameManager.adicionar_dinheiro(dinheiro_ganho)

	print("Dano:", dano)
	print("Dano real:", dano_real)
	print("Progresso:", cliques, "/", cliques_maximos)
	print("Dinheiro base:", dinheiro_base)
	print("Fortuna:", GameManager.fortuna)
	print("Multiplicador:", multiplicador_fortuna)
	print("Dinheiro ganho:", dinheiro_ganho)

	# Atualiza o estágio visual da mina
	var porcentagem_minerada: float = float(cliques) / cliques_maximos

	if porcentagem_minerada >= 1.0:
		sprite.play("vazia")
	elif porcentagem_minerada >= 0.7:
		sprite.play("baixa")
	elif porcentagem_minerada >= 0.3:
		sprite.play("media")

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
