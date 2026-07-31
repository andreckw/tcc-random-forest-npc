extends Node2D

@export var npc_scene: PackedScene
@export var quantidade: int = 40
@export var area_x: float = 1280.0
@export var area_y: float = 960.0

var npcs = []

func _ready():
	for i in quantidade:
		var npc = npc_scene.instantiate()

		npc.position = Vector2(
			randf_range(50, area_x - 50),
			randf_range(50, area_y - 50)
		)

		add_child(npc)

		npcs.append(npc)
