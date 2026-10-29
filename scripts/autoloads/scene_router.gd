extends Node

## Scene changes are deferred. Milestone 1 stays on the flight scene.


func goto_flight() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var current := tree.current_scene
	if current and current.scene_file_path == "res://scenes/main.tscn":
		return
	tree.change_scene_to_file("res://scenes/main.tscn")
