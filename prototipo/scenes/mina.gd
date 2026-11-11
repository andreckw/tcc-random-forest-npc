extends Area2D

@export var cliques_maximos: int = 10
@export var valor_total: int = 10
@export var tempo_recuperacao: float = 20.0

var cliques: int = 0
var esgotada: bool = false
var tempo_passado: float = 0.0

var npc_reservado: Node = null

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var efeito: AnimatedSprite2D = $"../AnimatedEffect"
@onready var cursor_manager = $"../../UI/CursorManager"

func _ready():
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(recuperar_mina)

	# Configura o efeito do clique
	efeito.visible = false
	efeito.sprite_frames.set_animation_loop("click", false)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	efeito.animation_finished.connect(_on_efeito_animation_finished)

func _input_event(viewport, event, shape_idx):
	if esgotada:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			cursor_manager.animar_picareta()

			# Posiciona o efeito exatamente onde o mouse está
			efeito.global_position = get_global_mouse_position()

			# Mostra e executa a animação
			efeito.visible = true
			efeito.play("click")

			minerar(event.position)

func _on_mouse_entered():
	if not esgotada:
		cursor_manager.ativar_cursor_picareta()


func _on_mouse_exited():
	cursor_manager.desativar_cursor_picareta()
	
func _on_efeito_animation_finished():
	if efeito.animation == "click":
		efeito.visible = false
		efeito.play("default")
		
func minerar(posicao_clique):
	var dano: int = GameManager.eficiencia
	var multiplicador_fortuna: int = GameManager.fortuna
	receber_dano(dano, multiplicador_fortuna)
	
func receber_dano(dano: int, multiplicador_fortuna: int = 1):
	if esgotada:
		return

	var restante: int = cliques_maximos - cliques
	var dano_real: int = min(max(dano, 0), restante)

	if dano_real <= 0:
		return

	cliques += dano_real

	var valor_por_clique: float = float(valor_total) / cliques_maximos
	var dinheiro_base: int = roundi(valor_por_clique * dano_real)
	var dinheiro_ganho: int = dinheiro_base * multiplicador_fortuna

	GameManager.adicionar_dinheiro(dinheiro_ganho)

	print("Dano recebido:", dano_real)
	print("Progresso:", cliques, "/", cliques_maximos)
	print("Dinheiro recebido:", dinheiro_ganho)

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

func esta_disponivel_para_npc(npc: Node) -> bool:
	if esgotada:
		return false

	if npc_reservado == null:
		return true

	if not is_instance_valid(npc_reservado):
		npc_reservado = null
		return true

	return npc_reservado == npc


func reservar_para_npc(npc: Node) -> bool:
	if not esta_disponivel_para_npc(npc):
		return false

	npc_reservado = npc
	print("Mina ", name, " reservada pelo NPC: ", npc.name)

	return true


func liberar_reserva_npc(npc: Node):
	if npc_reservado == npc:
		npc_reservado = null
		print("Mina ", name, " liberada pelo NPC: ", npc.name)
