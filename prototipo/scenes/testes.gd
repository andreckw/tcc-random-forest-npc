extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO

	# Movimento usando WASD
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	# Normaliza para não andar mais rápido na diagonal
	if direction != Vector2.ZERO:
		direction = direction.normalized()

	velocity = direction * SPEED

	move_and_slide()
