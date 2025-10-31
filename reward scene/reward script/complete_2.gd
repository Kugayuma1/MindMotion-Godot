extends Control

const RandomMotionSelector = preload("res://scripts/RandomMotionSelector.gd")

# Motivational messages for different stages
var partial_completion_messages = [
	"You did a great job!",
	"Amazing work!",
	"Keep it up!",
	"Fantastic effort!",
	"You're doing wonderfully!",
	"Super job!",
	"Excellent work!",
	"Way to go!"
]

var full_completion_messages = [
	"You completed everything!",
	"Perfect! All done!",
	"Outstanding achievement!",
	"You're a superstar!",
	"Magnificent! All Complete!",
	"Bravo! All tasks completed!",
	"Spectacular work! All done!"
]

@onready var praise_label = $TextureRect/PraiseLabel if has_node("TextureRect/PraiseLabel") else null
@onready var reward_title = $TextureRect/RewardTitle if has_node("TextureRect/RewardTitle") else null
@onready var sticker = $TextureRect/Sticker if has_node("TextureRect/Sticker") else null

# Track if this is a completion popup (not timeout)
var is_completion_popup = true

func _ready():
	# Initialize the popup based on completion status
	# Only show completion-based content if this is NOT a timeout popup
	if is_completion_popup:
		update_popup_content()
	
func update_popup_content():
	# Get stage completion status for current letter
	var stage_completion = Global.get_stage_cache(Global.current_letter)
	
	# Default to all incomplete if no data
	if not stage_completion or stage_completion.is_empty():
		stage_completion = {"reading": false, "fine_motor": false, "math": false, "art": false}
	
	# Check if all stages are complete
	var all_complete = (
		stage_completion.get("reading", false) and 
		stage_completion.get("fine_motor", false) and 
		stage_completion.get("math", false) and 
		stage_completion.get("art", false)
	)
	
	# Check if the next letter is unlocked (better indicator that this letter was completed before)
	var current_letter_index = Global.current_letter.unicode_at(0) - 65  # A=0, B=1, etc.
	var already_had_sticker = false
	
	if current_letter_index < 25:  # Not Z (last letter)
		var next_letter = char(65 + current_letter_index + 1)  # Get next letter
		# Check if next letter's stages are accessible (reading stage unlocked)
		var next_stage_data = Global.get_stage_cache(next_letter)
		if next_stage_data:
			# If next letter has any stage completion data, current letter was completed before
			already_had_sticker = true
		else:
			# Also check letter completion cache
			already_had_sticker = Global.letter_completion_cache.get(Global.current_letter, false)
	else:
		# For letter Z, just check its own completion status
		already_had_sticker = Global.letter_completion_cache.get(Global.current_letter, false)
	
	# Update UI based on completion status
	if all_complete:
		setup_full_completion_ui(already_had_sticker)
	else:
		setup_partial_completion_ui()
	
	# Update sticker preview
	update_sticker_display(all_complete)

func setup_full_completion_ui(already_obtained: bool = false):
	# Update PraiseLabel with motivational message
	if praise_label:
		var message = full_completion_messages[randi() % full_completion_messages.size()]
		praise_label.text = message
	
	# Update RewardTitle based on whether sticker was already obtained
	if reward_title:
		if already_obtained:
			reward_title.text = "You obtained a Sticker!"
		else:
			reward_title.text = "You obtained a new Sticker!"
	
	# Update sticker with full opacity (unlocked)
	update_sticker_display(true)

func setup_partial_completion_ui():
	# Update PraiseLabel with motivational message
	if praise_label:
		var message = partial_completion_messages[randi() % partial_completion_messages.size()]
		praise_label.text = message
	
	# Update RewardTitle for partial completion
	if reward_title:
		reward_title.text = "Complete all to unlock the sticker"
	
	# Update sticker with low opacity (locked)
	update_sticker_display(false)

func update_sticker_display(is_unlocked: bool):
	if not sticker:
		return
	
	# Try to load the sticker for current letter (UPPERCASE to match A.png, B.png, etc.)
	var letter_upper = Global.current_letter.to_upper()
	var sticker_path = "res://rewards/Sticker/" + letter_upper + ".png"
	
	# Check if sticker exists
	if ResourceLoader.exists(sticker_path):
		var sticker_texture = load(sticker_path)
		if sticker_texture and sticker is TextureRect:
			sticker.texture = sticker_texture
			
			# Set opacity based on unlock status
			if is_unlocked:
				sticker.modulate = Color(1, 1, 1, 1)  # Full opacity - unlocked (all 4 stages done)
			else:
				sticker.modulate = Color(1, 1, 1, 0.3)  # Low opacity - locked (not all stages done)
	else:
		# If sticker doesn't exist, use current texture with appropriate opacity
		if sticker:
			if is_unlocked:
				sticker.modulate = Color(1, 1, 1, 1)
			else:
				sticker.modulate = Color(1, 1, 1, 0.3)

func _on_quit_pressed() -> void:
	AudioManager.play_sound("button_click")
	AudioManager.stop_music(false)
	AudioManager.resume_previous_music()
	
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
