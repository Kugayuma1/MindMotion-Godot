extends Control

var is_transitioning = false

func _ready():
	LoadingScreen.hide_loading()

func _on_play_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	Global.change_scene_with_cache_wait("res://scenes/LevelSelection.tscn")

func _on_setting_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_quit_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	
	# Disconnect signals before logout to prevent flickering
	_disconnect_global_signals()
	
	# Clear user data
	Global.logout()
	
	# Use deferred call to ensure clean transition
	call_deferred("_change_to_user_selection")

func _disconnect_global_signals():
	# Disconnect any connected signals to prevent updates during transition
	if Global.letter_cache_updated.is_connected(_on_cache_updated):
		Global.letter_cache_updated.disconnect(_on_cache_updated)
	if Global.stage_cache_updated.is_connected(_on_stage_cache_updated):
		Global.stage_cache_updated.disconnect(_on_stage_cache_updated)

func _change_to_user_selection():
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")

# Placeholder functions in case they're connected
func _on_cache_updated():
	pass

func _on_stage_cache_updated(_letter: String):
	pass
	
func _exit_tree():
	_disconnect_global_signals()
