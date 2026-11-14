
extends Area2D

@export_group("Cenas")
@export var cena_minerio: PackedScene

@export_group("Posições")
@export var posicao_inicial: Vector2 = Vector2(640, -150)
@export var posicao_extracao: Vector2 = Vector2(640, 300)
@export var posicao_spawn_minerio: Vector2 = Vector2(640, 450)

@export_group("Movimento")
@export var velocidade_descida: float = 2.0
@export var velocidade_subida: float = 2.0

@export_group("Susto dos NPCs")
@export var raio_susto: float = 350.0
@export var duracao_fuga: float = 3.0

var npcs_ja_assustados: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var audio: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	if audio.stream != null:
		audio.play()

	await iniciar_sequencia()


func iniciar_sequencia() -> void:
	# Nave aparece acima da tela.
	global_position = posicao_inicial
	sprite.play("default")

	# Desce até o ponto de extração.
	var tween_descida := create_tween()
	tween_descida.tween_property(
		self,
		"global_position",
		posicao_extracao,
		velocidade_descida
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await monitorar_npcs_durante_movimento(tween_descida)
	
	

	# Inicia a extração.
	sprite.play("extraction")
	await sprite.animation_finished

	# Cria o minério no local da extração.
	print("Nave chegou ao ponto de extração!")

	if cena_minerio != null:
		print("Cena do minério configurada!")

		var minerio := cena_minerio.instantiate() as Node2D
		get_parent().add_child(minerio)
		minerio.global_position = posicao_spawn_minerio

		print("Minério criado em: ", minerio.global_position)
	else:
		push_error("Cena do minério não foi configurada!")

	# Nave sobe novamente.
	sprite.play("default")

	var tween_subida := create_tween()
	tween_subida.tween_property(
		self,
		"global_position",
		posicao_inicial,
		velocidade_subida
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await monitorar_npcs_durante_movimento(tween_subida)

	# Remove a nave.
	queue_free()
	
func assustar_npcs() -> void:
	var container_npcs = get_parent().get_node_or_null("Npcs")

	if container_npcs == null:
		return

	for npc in container_npcs.get_children():
		if not npc.has_method("FugirDeExplosao"):
			continue

		var id: int = npc.get_instance_id()

		if npcs_ja_assustados.has(id):
			continue

		var distancia: float = global_position.distance_to(npc.global_position)

		if distancia <= raio_susto:
			npc.call("FugirDeExplosao", global_position, duracao_fuga)
			npcs_ja_assustados[id] = true

			print("NPC assustado pelo UFO: ", id)


func monitorar_npcs_durante_movimento(tween: Tween) -> void:
	while tween.is_running():
		assustar_npcs()
		await get_tree().create_timer(0.15).timeout
