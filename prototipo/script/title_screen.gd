extends Control

@export var panel_benchmark:PanelContainer
@export var lineEditQtdNpcs:LineEdit

@export var line_edit_min_bench:LineEdit

func _ready() -> void:
	panel_benchmark.visible = false

func _on_game_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_game.tscn")
	
func _on_rfw_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_random_forest.tscn")


func _on_dtw_btn_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_decision_tree.tscn")


func _on_benchmark_button_up() -> void:
	panel_benchmark.visible = !panel_benchmark.visible


func _on_button_button_up() -> void:
	GameManager.qtd_npcs = int(lineEditQtdNpcs.text)
	GameManager.min_bench = float(line_edit_min_bench.text)
	get_tree().change_scene_to_file("res://scenes/benchmark_world.tscn")
