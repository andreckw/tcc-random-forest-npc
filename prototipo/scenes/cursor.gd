
extends Control

var cursor_picareta: Texture2D

func _ready():
	cursor_picareta = load("res://images/skin.png")

func ativar_cursor_picareta():
	Input.set_custom_mouse_cursor(
		cursor_picareta,
		Input.CURSOR_ARROW,
		Vector2(0, 0)
	)

func desativar_cursor_picareta():
	Input.set_custom_mouse_cursor(null)
