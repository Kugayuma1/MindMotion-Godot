extends Control
const RandomMotionSelector = preload("res://scripts/RandomMotionSelector.gd")

func _on_quit_pressed() -> void:
	AudioManager.play_sound("button_click")
	AudioManager.stop_music(false)
	AudioManager.resume_previous_music()
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
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
	
	var game_scene = get_parent()
	var use_restart_method = false
	
	# Only use restart_game() if the game has ALL required functions for proper restart
	if game_scene and game_scene.has_method("restart_game"):
		# Check if game has proper restart support (must have both helper functions)
		if game_scene.has_method("stop_timer") and game_scene.has_method("reset_time_tracking"):
			use_restart_method = true
			print("Game has complete restart support - using restart_game()")
		else:
			print("Game has restart_game() but missing helper functions - using scene reload instead")
	
	if use_restart_method:
		# Game has complete restart implementation - use it
		game_scene.restart_game()
		queue_free()  # Remove the popup
	else:
		# Game doesn't have restart_game() OR it's incomplete - reload the scene
		print("Reloading current scene for safe retry")
		SceneTransition.reload_with_fade()
