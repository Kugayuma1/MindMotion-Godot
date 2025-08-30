extends Control


func _on_play_pressed():
	Global.change_scene_with_cache_wait("res://scenes/LevelSelection.tscn")


func _on_setting_pressed():
	print("Settings feature is coming soon!")


func _on_quit_pressed():
	Global.logout()  # Clear user info
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
