extends Camera2D

@export var move_speed: float = 400.0
@export var zoom_speed: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0

var npc_alvo = null

func _ready():
	await get_tree().process_frame
	_conectar_npcs()

func _conectar_npcs():
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().get_nodes_in_group("npcs"):
		if node.has_signal("NpcClicked"):
			node.NpcClicked.connect(_on_npc_clicked)

func _on_node_added(node):
	if node.has_signal("NpcClicked"):
		node.NpcClicked.connect(_on_npc_clicked)

func _on_npc_clicked(npc):
	if npc_alvo == npc:
		npc_alvo = null
	else:
		npc_alvo = npc

func _process(delta):
	if npc_alvo != null and is_instance_valid(npc_alvo):
		position = position.lerp(npc_alvo.position, 5.0 * delta)
	else:
		var direction = Vector2.ZERO
		if Input.is_action_pressed("ui_left"):
			direction.x -= 1
		if Input.is_action_pressed("ui_right"):
			direction.x += 1
		if Input.is_action_pressed("ui_up"):
			direction.y -= 1
		if Input.is_action_pressed("ui_down"):
			direction.y += 1
		position += direction * move_speed * delta

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(zoom_speed, zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(zoom_speed, zoom_speed)
		zoom.x = clamp(zoom.x, zoom_min, zoom_max)
		zoom.y = clamp(zoom.y, zoom_min, zoom_max)
