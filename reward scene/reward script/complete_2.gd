extends Control


func _on_quit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Categories.tscn")


func _on_next_item_pressed() -> void:
	pass # Replace with function body.


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
