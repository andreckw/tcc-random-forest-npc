extends Node2D

@export var npc_scene: PackedScene

func spawnar_npc():
	if npc_scene == null:
		push_error("Nenhuma cena de NPC foi configurada!")
		return

	var npc = npc_scene.instantiate()
	npc.set("GerarDataset", false) ## 228
	npc.position = Vector2(590, 240)

	add_child(npc)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		spawnar_npc()
