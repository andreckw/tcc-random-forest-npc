extends Node2D


func spawnar_npc():
	var npc = NPC_SCENE.instantiate()
	npc.set("GerarDataset", false)
	npc.position = Vector2(590, 228)
	add_child(npc)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_N:
		spawnar_npc()
