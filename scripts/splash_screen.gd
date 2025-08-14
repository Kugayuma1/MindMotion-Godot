extends Control

func _on_timer_timeout():
	# Replace this with the scene you want to go to (like Login.tscn)
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
