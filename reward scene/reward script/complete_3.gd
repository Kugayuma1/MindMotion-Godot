extends Control

const RandomMotionSelector = preload("res://scripts/RandomMotionSelector.gd")

func _on_quit_pressed() -> void:
	AudioManager.stop_music(false)
	AudioManager.resume_previous_music()
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"  # adjust this to your letter's main scene
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)


func _on_next_item_pressed() -> void:
	AudioManager.stop_music(false)
	var scene_path = RandomMotionSelector.get_random_motion_scene_path()
	
	if ResourceLoader.exists(scene_path):
		print("Loading random motion activity: ", scene_path)
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Scene not found: " + scene_path)
		# Fallback to clap scene
		var clap_path = "res://scenes/Clap.tscn"
		if ResourceLoader.exists(clap_path):
			print("Fallback: Loading clap scene")
			get_tree().change_scene_to_file(clap_path)


func _on_retry_pressed() -> void:
	SceneTransition.reload_with_fade()
