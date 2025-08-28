extends Control


func _on_quit_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"  # adjust this to your letter's main scene
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)


func _on_next_item_pressed() -> void:
	pass # Replace with function body.


func _on_retry_pressed() -> void:
	get_tree().reload_current_scene()
