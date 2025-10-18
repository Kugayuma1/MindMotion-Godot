extends Control

func _on_retry_pressed() -> void:
	AudioManager.play_sound("button_click")
	
	# Get the parent game scene and load next word
	var game_scene = get_parent()
	if game_scene and game_scene.has_method("next_word"):
		game_scene.next_word()
		queue_free()  # Remove the popup
	else:
		# Fallback: reload current scene if something goes wrong
		SceneTransition.reload_with_fade()
