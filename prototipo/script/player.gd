extends CharacterBody2D

@export var move_speed: float = 400.0
@export var zoom_speed: float = 0.1
@export var zoom_min: float = 0.5
@export var zoom_max: float = 3.0
@export var camera: Camera2D
@export var camera_limits = {
    "left": 0,
    "right": 0,
    "top": 0,
    "bottom": 0,
}

var npc_alvo = null

func _ready() -> void:
    camera.limit_top = camera_limits["top"]
    camera.limit_bottom = camera_limits["bottom"]
    camera.limit_right = camera_limits["right"]
    camera.limit_left = camera_limits["left"]

func _physics_process(delta: float) -> void:
    if npc_alvo != null and is_instance_valid(npc_alvo):
        position = position.lerp(npc_alvo.position, 5.0 * delta)
    else:

        var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
        
        position += direction * move_speed * delta

func _unhandled_input(event):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.zoom += Vector2(zoom_speed, zoom_speed)
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.zoom -= Vector2(zoom_speed, zoom_speed)
        camera.zoom.x = clamp(camera.zoom.x, zoom_min, zoom_max)
        camera.zoom.y = clamp(camera.zoom.y, zoom_min, zoom_max)