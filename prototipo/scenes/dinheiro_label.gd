extends Label

func _process(delta):
	text = "💰 $" + str(GameManager.dinheiro)
