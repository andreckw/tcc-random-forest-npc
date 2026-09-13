extends Control


func _on_rfw_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_random_forest.tscn")


func _on_dtw_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_decision_tree.tscn")
