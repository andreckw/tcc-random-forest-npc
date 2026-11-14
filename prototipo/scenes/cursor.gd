extends Control

@onready var picareta_cursor: TextureRect = $PicaretaCursor

var animando: bool = false
var rotacao_original: float
var textura_picareta_atual: Texture2D


func _ready():
	picareta_cursor.visible = false
	picareta_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE

	rotacao_original = 0.0
	picareta_cursor.rotation = rotacao_original
	picareta_cursor.scale.x = -1

	# Picareta inicial
	textura_picareta_atual = load("res://imagens/pickaxes/iron_pickaxe.png")
	picareta_cursor.texture = textura_picareta_atual
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(_delta):
	if picareta_cursor.visible:
		var mouse_pos = get_global_mouse_position()

		picareta_cursor.global_position = mouse_pos - picareta_cursor.size / 2

		# Ajuste da posição da picareta em relação ao mouse
		picareta_cursor.position.x -= -42
		picareta_cursor.position.y -= 5

func ativar_cursor_picareta():
	picareta_cursor.visible = true

	# Esconde o cursor normal
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func desativar_cursor_picareta():
	picareta_cursor.visible = false

	# Mostra o cursor normal novamente
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Garante que a picareta volte ao estado normal
	picareta_cursor.rotation = rotacao_original


func alterar_skin_picareta(nova_textura: Texture2D):
	textura_picareta_atual = nova_textura
	picareta_cursor.texture = textura_picareta_atual


func animar_picareta():
	if animando:
		return

	animando = true

	picareta_cursor.rotation = rotacao_original

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# Levanta a picareta
	tween.tween_property(
		picareta_cursor,
		"rotation",
		deg_to_rad(-35),
		0.08
	)

	# Bate
	tween.tween_property(
		picareta_cursor,
		"rotation",
		deg_to_rad(25),
		0.10
	)

	# Volta
	tween.tween_property(
		picareta_cursor,
		"rotation",
		rotacao_original,
		0.10
	)

	await tween.finished

	animando = false
