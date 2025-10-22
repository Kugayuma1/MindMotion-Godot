extends Control

const RandomMotionSelector = preload("res://scripts/RandomMotionSelector.gd")

func _on_quit_pressed() -> void:
	AudioManager.play_sound("button_click")
	AudioManager.stop_music(false)
	AudioManager.resume_previous_music()
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"  # adjust this to your letter's main scene
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)


func _on_next_item_pressed() -> void:
	AudioManager.play_sound("button_click")
	AudioManager.stop_music(false)
	
	# Next Item always goes to motion activity
	var scene_path = RandomMotionSelector.get_random_motion_scene_path()
	if ResourceLoader.exists(scene_path):
		print("Loading random motion activity: ", scene_path)
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Scene not found: " + scene_path)

func _on_retry_pressed() -> void:
	AudioManager.play_sound("button_click")
	
	# Retry restarts the entire game with NEW random choices
	var game_scene = get_parent()
	if game_scene and game_scene.has_method("restart_game"):
		game_scene.restart_game()
		queue_free()  # Remove the popup
	else:
		# Fallback: reload current scene if something goes wrong
		SceneTransition.reload_with_fade()
