extends Node

@export_group("Cenas")
@export var cena_pandora: PackedScene
@export var cena_festive: PackedScene
@export var cena_nave: PackedScene

@export_group("Pandora")
@export var posicao_pandora: Vector2 = Vector2(640, 300)

@export_group("Festive")
@export var area_festive: Rect2 = Rect2(
	Vector2(100, 100),
	Vector2(1000, 500)
)
@export var distancia_minima_festive: float = 80.0

@export_group("Recompensas")
@export var dinheiro_minimo: int = 500
@export var dinheiro_maximo: int = 1500

@onready var loja = get_node_or_null("../CanvasLayer/Shop")
@onready var npcs = get_node_or_null("../Npcs")
@onready var explosivos = get_node_or_null("../ExplosivesController")

@onready var canvas_layer = get_node_or_null("../CanvasLayer")

var timer_pedra: Timer
var timer_notificacao: Timer
var notificacao_pedra: Label

var pandora_instanciada: Area2D = null


func _ready() -> void:
	randomize()

	if loja == null:
		push_error("RewardItemsController: loja não encontrada!")
		return

	loja.item_purchased.connect(_on_item_purchased)

	print("RewardItemsController iniciado!")
	
		
	timer_pedra = Timer.new()
	timer_pedra.one_shot = true
	timer_pedra.wait_time = 120.0
	add_child(timer_pedra)
	timer_pedra.timeout.connect(_desativar_pedra_filosofal)

	_criar_notificacao()

func _on_item_purchased(tipo: String, id: String) -> void:
	if tipo != "extra":
		return

	match id:
		"pandoras_box":
			if pandora_instanciada != null:
				return

			if cena_pandora == null:
				push_error("Cena da Pandora não configurada!")
				return

			if not loja.use_extra(id):
				return
			
			_spawnar_pandora()

		"festive_cosmetics":
			if cena_festive == null:
				push_error("Cena Festive não configurada!")
				return

			if not loja.use_extra(id):
				return

			_spawnar_festives()
			
		"philosophers_stone":
			_ativar_pedra_filosofal()
			
		"mirror":
			_ativar_mirror()
			
		"pyramid_eye":
			_spawnar_nave()
			

func _spawnar_pandora() -> void:
	var mundo := get_parent() as Node2D
	if mundo == null:
		push_error("RewardItemsController precisa estar dentro de um Node2D!")
		return

	pandora_instanciada = cena_pandora.instantiate() as Area2D

	if pandora_instanciada == null:
		push_error("A raiz da Pandora precisa ser Area2D!")
		return

	mundo.add_child(pandora_instanciada)
	pandora_instanciada.position = posicao_pandora
	iniciar_animacao_item(pandora_instanciada)

	pandora_instanciada.input_event.connect(
		_on_item_clicado.bind(pandora_instanciada, "pandora")
	)

	loja.set_pandora_ativa(true)

	print("Caixa de Pandora apareceu!")


func _spawnar_festives() -> void:
	var mundo := get_parent() as Node2D
	if mundo == null:
		push_error("RewardItemsController precisa estar dentro de um Node2D!")
		return

	var quantidade := randi_range(5, 6)
	var posicoes: Array[Vector2] = []

	for i in range(quantidade):
		var posicao := _sortear_posicao_festive(posicoes)

		if posicao == Vector2.INF:
			push_warning("Não foi possível encontrar espaço para outro Festive.")
			continue

		posicoes.append(posicao)

		var festive := cena_festive.instantiate() as Area2D

		if festive == null:
			push_error("A raiz do Festive precisa ser Area2D!")
			continue

		mundo.add_child(festive)
		festive.position = posicao
		iniciar_animacao_item(festive)

		festive.input_event.connect(
			_on_item_clicado.bind(festive, "festive")
		)

	print("Evento Festive iniciado! Quantidade: ", posicoes.size())


func _sortear_posicao_festive(posicoes_existentes: Array[Vector2]) -> Vector2:
	for tentativa in range(50):
		var posicao := Vector2(
			randf_range(area_festive.position.x, area_festive.end.x),
			randf_range(area_festive.position.y, area_festive.end.y)
		)

		var distancia_valida := true

		for existente in posicoes_existentes:
			if posicao.distance_to(existente) < distancia_minima_festive:
				distancia_valida = false
				break

		if distancia_valida:
			return posicao

	return Vector2.INF


func _on_item_clicado(
	_viewport: Node,
	event: InputEvent,
	_shape_idx: int,
	item: Area2D,
	tipo: String
) -> void:
	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return

	if not is_instance_valid(item) or not item.input_pickable:
		return

	# Impede que o mesmo objeto entregue mais de uma recompensa.
	item.input_pickable = false

	if tipo == "pandora":
		pandora_instanciada = null
		loja.set_pandora_ativa(false)

	print("Objeto aberto: ", tipo)

	# Reproduz o som do objeto.
	var audio := item.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D

	if audio != null and audio.stream != null:
		audio.play()

	# Entrega a recompensa.
	await _entregar_recompensa()

	# Aguarda o som terminar antes de remover o objeto.
	if audio != null and audio.playing:
		await audio.finished

	if is_instance_valid(item):
		item.queue_free()

	


func _entregar_recompensa() -> void:
	var recompensas := [
		"dinheiro",
		"npc",
		"dynamite",
		"tnt"
	]

	var recompensa: String = recompensas.pick_random()

	print("Recompensa sorteada: ", recompensa)

	match recompensa:
		"dinheiro":
			var valor := randi_range(dinheiro_minimo, dinheiro_maximo)
			GameManager.adicionar_dinheiro(valor)
			print("Você recebeu $", valor)

		"npc":
			if npcs != null and npcs.has_method("spawnar_npc_aleatorio"):
				npcs.spawnar_npc_aleatorio()
			else:
				push_warning("Método spawnar_npc_aleatorio não encontrado no Npcs!")

		"dynamite", "tnt":
			if explosivos != null and explosivos.has_method("executar_recompensa_explosivo"):
				await explosivos.executar_recompensa_explosivo(recompensa)
			else:
				push_warning("Método executar_recompensa_explosivo não encontrado!")
				
func iniciar_animacao_item(item: Area2D) -> void:
		var sprite := item.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

		if sprite != null:
			sprite.play("default")
		
func _criar_notificacao() -> void:
	if canvas_layer == null:
		push_error("CanvasLayer não encontrado!")
		return
		
	notificacao_pedra = Label.new()
	notificacao_pedra.name = "NotificacaoPedraFilosofal"
	notificacao_pedra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	
	notificacao_pedra.offset_top = 30
	notificacao_pedra.offset_bottom = 90
	notificacao_pedra.offset_left = 0
	notificacao_pedra.offset_right = 0
	
	notificacao_pedra.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notificacao_pedra.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	notificacao_pedra.add_theme_font_size_override("font_size", 26)
	notificacao_pedra.add_theme_color_override("font_color", Color("ffd54a"))
	notificacao_pedra.add_theme_color_override("font_outline_color", Color.BLACK)
	notificacao_pedra.add_theme_constant_override("outline_size", 6)
	
	notificacao_pedra.visible = false
	canvas_layer.add_child(notificacao_pedra)
	
	timer_notificacao = Timer.new()
	timer_notificacao.one_shot = true
	timer_notificacao.wait_time = 4.0
	add_child(timer_notificacao)
	timer_notificacao.timeout.connect(func():
		notificacao_pedra.visible = false
	)
	
func _mostrar_notificacao(texto: String) -> void:
	notificacao_pedra.text = texto
	notificacao_pedra.visible = true
	
	timer_notificacao.start()
	
func _ativar_pedra_filosofal() -> void:
	if not loja.use_extra("philosophers_stone"):
		return
		
	loja.close_shop()
	
	for mina in get_tree().get_nodes_in_group("minas"):
		if mina.has_method("definir_diamante"):
			mina.definir_diamante(true)
			
	timer_pedra.start(120.0)
	
	_mostrar_notificacao("PEDRA FILOSOFAL COMPRADA! DIAMANTES ATIVADOS POR 2 MINUTOS!")
	
	print("Pedra Filosofal ativada por 120 segundos!")
	
func _desativar_pedra_filosofal() -> void:
	for mina in get_tree().get_nodes_in_group("minas"):
		if mina.has_method("definir_diamante"):
			mina.definir_diamante(false)
	_mostrar_notificacao("O efeito da Pedra Filosofal acabou!")
	print("Pedra Filosofal desativada!")		
	
func _ativar_mirror() -> void:
	if npcs == null:
		push_error("Nó Npcs não encontrado!")
		return

	var npcs_originais := npcs.get_children()

	if npcs_originais.is_empty():
		_mostrar_notificacao("NENHUM NPC PARA MULTIPLICAR!")
		return

	if not loja.use_extra("mirror"):
		return

	loja.close_shop()

	var quantidade := 0

	for i in range(npcs_originais.size()):
		var npc_original = npcs_originais[i]
		var copia = npc_original.duplicate()

		npcs.add_child(copia)

		if npc_original is Node2D and copia is Node2D:
			copia.position = npc_original.position + Vector2(40, 40)

		quantidade += 1

	_mostrar_notificacao("MIRROR ATIVADO! TODOS OS NPCs FORAM MULTIPLICADOS!")

	print("Mirror ativado! NPCs duplicados: ", quantidade)	


func _spawnar_nave() -> void:
	if is_instance_valid(pandora_instanciada):
		_mostrar_notificacao("A CAIXA DE PANDORA AINDA ESTÁ NO MAPA!")
		print("UFO bloqueado: Pandora está ativa!")
		return

	if cena_nave == null:
		push_error("Cena da nave não configurada!")
		return

	var mundo := get_parent() as Node2D

	if mundo == null:
		push_error("RewardItemsController precisa estar dentro de um Node2D!")
		return

	if not loja.use_extra("pyramid_eye"):
		return

	loja.close_shop()

	var nave := cena_nave.instantiate()
	mundo.add_child(nave)

	_mostrar_notificacao("OLHO DA PIRÂMIDE AVISTADO! UM MINÉRIO ESPECIAL ESTÁ CHEGANDO!")

	print("Olho da Pirâmide ativado!")
