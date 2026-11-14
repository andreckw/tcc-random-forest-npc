extends Area2D

@export var cliques_maximos: int = 10
@export var cliques_maximos_diamante: int = 300

@export var valor_total: int = 10
@export var tempo_recuperacao: float = 20.0

var cliques: int = 0
var esgotada: bool = false
var tempo_passado: float = 0.0

var npc_reservado: Node = null

var diamante_ativo: bool = false

@onready var timer: Timer = $Timer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var efeito: AnimatedSprite2D = $"../AnimatedEffect"
@onready var cursor_manager = $"../../UI/CursorManager"

func _ready():
	add_to_group("minas")
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

	var durabilidade := get_durabilidade_atual()
	var restante: int = durabilidade - cliques
	var dano_real: int = min(max(dano, 0), restante)

	if dano_real <= 0:
		return

	cliques += dano_real

	
	var valor_por_clique: float = float(valor_total) / cliques_maximos
	var dinheiro_base: int = roundi(valor_por_clique * dano_real)

	var dinheiro_ganho: int

	## AQUI ALTERA O VALOR DA MINA DINHEIRO_BASE
	if diamante_ativo:
		dinheiro_ganho = 200 * dano_real * multiplicador_fortuna
	else:
		dinheiro_ganho = dinheiro_base * multiplicador_fortuna

	GameManager.adicionar_dinheiro(dinheiro_ganho)

	print("Dano recebido:", dano_real)
	print("Progresso:", cliques, "/", durabilidade)
	print("Dinheiro recebido:", dinheiro_ganho)

	var porcentagem_minerada: float = float(cliques) / durabilidade

	if porcentagem_minerada >= 1.0:
		tocar_estado("vazia")
	elif porcentagem_minerada >= 0.7:
		tocar_estado("baixa")
	elif porcentagem_minerada >= 0.3:
		tocar_estado("media")

	if cliques >= durabilidade:
		esgotar_mina()

func esgotar_mina():
	esgotada = true
	tempo_passado = 0.0

	print("Mina esgotada!")

	timer.start()

func recuperar_mina():
	tempo_passado += 1.0

	if tempo_passado == 6:
		tocar_estado("baixa")
		print("Mina voltou para baixa!")

	if tempo_passado == 14:
		tocar_estado("media")
		print("Mina voltou para media!")

	if tempo_passado >= tempo_recuperacao:
		tocar_estado("cheia")

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
		
func definir_diamante(ativo: bool) -> void:
	if diamante_ativo == ativo:
		return

	var durabilidade_antiga := get_durabilidade_atual()
	var progresso := float(cliques) / durabilidade_antiga

	diamante_ativo = ativo

	var durabilidade_nova := get_durabilidade_atual()
	cliques = roundi(progresso * durabilidade_nova)
	cliques = clampi(cliques, 0, durabilidade_nova)

	var porcentagem := float(cliques) / durabilidade_nova

	if porcentagem >= 1.0:
		tocar_estado("vazia")
	elif porcentagem >= 0.7:
		tocar_estado("baixa")
	elif porcentagem >= 0.3:
		tocar_estado("media")
	else:
		tocar_estado("cheia")


func tocar_estado(estado: String) -> void:
	if diamante_ativo:
		sprite.play(estado + "_diamante")
	else:
		sprite.play(estado)		

func get_durabilidade_atual() -> int:
	if diamante_ativo:
		return cliques_maximos_diamante
	return cliques_maximos
