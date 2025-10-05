extends Control

func _on_retry_pressed() -> void:
	SceneTransition.reload_with_fade()
