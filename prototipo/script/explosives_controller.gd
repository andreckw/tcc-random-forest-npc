extends Node

@export var cena_explosivo: PackedScene
@export var cena_explosao: PackedScene

@export var ponto_explosao: Vector2 = Vector2(640, 480)

@export_group("Dinamite")
@export var raio_dinamite: float = 180.0
@export var dano_dinamite: int = 10

@export_group("TNT")
@export var raio_tnt: float = 350.0
@export var dano_tnt: int = 20

@onready var loja = $"../CanvasLayer/Shop"

var explosivo_em_espera: bool = false
var explosivo_atual: Node2D

func _ready() -> void:
	if loja == null:
		push_error("ExplosivosController: loja não encontrada!")
		return

	if not loja.has_signal("item_purchased"):
		push_error("ExplosivosController: sinal item_purchased não encontrado!")
		return

	if not loja.is_connected("item_purchased", _on_item_purchased):
		loja.connect("item_purchased", _on_item_purchased)

	print("ExplosivosController iniciado!")


func _on_item_purchased(tipo: String, id: String) -> void:
	if tipo != "extra":
		return

	if id != "dynamite" and id != "tnt":
		return

	if explosivo_em_espera:
		return

	if not loja.use_extra(id):
		push_warning("Não foi possível consumir o explosivo: " + id)
		return

	explosivo_em_espera = true
	loja.hide()

	var mundo := get_parent() as Node2D
	var posicao := mundo.to_global(ponto_explosao)

	mostrar_bomba(posicao)

	print("Explosivo comprado: ", id)
	print("Explosivo será acionado em 2 segundos...")

	await get_tree().create_timer(2.0).timeout

	if is_instance_valid(explosivo_atual):
		explosivo_atual.queue_free()

	explosivo_atual = null

	mostrar_explosao(posicao, id)

	_executar_explosao(id)

	explosivo_em_espera = false


func _executar_explosao(id: String) -> void:
	var mundo := get_parent() as Node2D

	if mundo == null:
		push_error("ExplosivosController precisa estar dentro de um Node2D!")
		return

	var posicao_global: Vector2 = mundo.to_global(ponto_explosao)

	var raio: float
	var dano: int

	if id == "dynamite":
		raio = raio_dinamite
		dano = dano_dinamite
	elif id == "tnt":
		raio = raio_tnt
		dano = dano_tnt
	else:
		return

	print("EXPLOSÃO: ", id)
	print("Posição: ", posicao_global)
	print("Raio: ", raio)
	print("Dano: ", dano)

	var minas_atingidas: int = 0

	for node in get_tree().get_nodes_in_group("minas"):
		if not node is Node2D:
			continue

		if not node.has_method("receber_dano"):
			continue

		var distancia: float = posicao_global.distance_to(
			node.global_position
		)

		if distancia <= raio:
			node.call("receber_dano", dano, 1)
			minas_atingidas += 1

	print("Minas atingidas: ", minas_atingidas)
	
		# Verifica os NPCs próximos da explosão.
	var container_npcs = mundo.get_node_or_null("Npcs")

	if container_npcs == null:
		push_warning("Container Npcs não encontrado!")
		return

	var npcs_afetados: int = 0

	for npc in container_npcs.get_children():

		if not npc.has_method("FugirDeExplosao"):
			continue

		var distancia: float = posicao_global.distance_to(npc.global_position)

		if distancia <= raio:
			npc.call("FugirDeExplosao", posicao_global, 3.0)
			npcs_afetados += 1

	print("NPCs que começaram a fugir: ", npcs_afetados)

func mostrar_bomba(posicao: Vector2) -> void:
	if cena_explosivo == null:
		push_error("Cena do explosivo não foi configurada!")
		return

	explosivo_atual = cena_explosivo.instantiate() as Node2D

	get_parent().add_child(explosivo_atual)
	explosivo_atual.global_position = posicao
	
	var animacao = explosivo_atual.get_node("AnimatedSprite2D") as AnimatedSprite2D
	animacao.play("default")	
	
func mostrar_explosao(posicao: Vector2, id: String) -> void:
	if cena_explosao == null:
		push_error("Cena da explosão não foi configurada!")
		return

	var explosao = cena_explosao.instantiate() as Node2D

	get_parent().add_child(explosao)
	explosao.global_position = posicao

	var animacao = explosao.get_node("AnimatedSprite2D") as AnimatedSprite2D

	if animacao == null:
		push_error("AnimatedSprite2D não encontrado na cena Explosion!")
		explosao.queue_free()
		return

	# TNT terá uma explosão visual maior.
	if id == "tnt":
		explosao.scale = Vector2(2.0, 2.0)

	animacao.animation_finished.connect(explosao.queue_free)
	animacao.play("default")	
	var audio = explosao.get_node("AudioStreamPlayer2D") as AudioStreamPlayer2D
	audio.play()
