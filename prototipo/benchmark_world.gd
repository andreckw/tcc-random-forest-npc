extends Node2D

@export var npc_scene: PackedScene
@export var node_childs: Node
@export var area_x: int = 0
@export var area_y: int = 0
@export var timer: Timer
@export var panel: PanelContainer
@export var lbl_fps: Label
@export var lbl_ram: Label
@export var lbl_latencia: Label
@export var grid_actions: GridContainer

var ram = []
var fps = []
var latencia = []
var action = []

func _ready() -> void:
	panel.visible = false
	for i in range(GameManager.qtd_npcs):
		var npc = npc_scene.instantiate()
		npc.position = Vector2(
			randf_range(50, area_x - 50),
			randf_range(50, area_y - 50)
		)
		node_childs.add_child(npc)
	timer.start(GameManager.min_bench * 60)

func _on_timer_timeout() -> void:
	for c in node_childs.get_children():
		c.queue_free()

	var ram_media = 0
	var fps_medio = 0
	var latencia_media = 0
	for r in ram:
		ram_media += r
	print(ram_media)
	print(len(ram))
	ram_media /= len(ram)

	for f in fps:
		fps_medio += f
	fps_medio /= len(fps)

	for l in latencia:
		latencia_media += l
	latencia_media /= len(latencia)

	var qtd_actions = {}
	for a in action:
		if qtd_actions.has(a):
			qtd_actions[a] += 1
		else:
			qtd_actions[a] = 1

	lbl_fps.text = "%d" % fps_medio
	lbl_latencia.text = "%.2f ms" % latencia_media
	lbl_ram.text = "%.2f MB" % ram_media

	for k in qtd_actions:
		var lblK = Label.new()
		var lblV = Label.new()

		lblK.text = str(k)
		lblV.text = str(qtd_actions[k]) 

		grid_actions.add_child(lblK)
		grid_actions.add_child(lblV)

	panel.visible = true

func adicionar_inferencia(lat, act):
	ram.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1024 / 1024)
	fps.append(Engine.get_frames_per_second())
	latencia.append(lat)
	action.append(act)
