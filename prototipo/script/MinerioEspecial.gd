
extends Area2D

@export var cliques_maximos: int = 3
@export var recompensa: int = 10000

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio = get_node_or_null("AudioStreamPlayer2D")

var cliques: int = 0
var processando: bool = false
var destruindo: bool = false


func _ready() -> void:
	sprite.play("default")


func _input_event(_viewport, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			minerar()

func minerar() -> void:
	if processando or destruindo:
		return

	processando = true
	cliques += 1

	print("Minério especial: ", cliques, "/", cliques_maximos)

	if audio != null and audio.stream != null:
		audio.play()

	if cliques >= cliques_maximos:
		destruir_minerio()
		return

	sprite.play("hit")
	await sprite.animation_finished

	sprite.play("default")
	processando = false


func destruir_minerio() -> void:
	destruindo = true
	sprite.play("destroy")

	var dinheiro_ganho: int = recompensa * GameManager.fortuna
	GameManager.adicionar_dinheiro(dinheiro_ganho)

	print("Minério especial destruído!")
	print("Dinheiro recebido: ", dinheiro_ganho)

	await sprite.animation_finished
	queue_free()
