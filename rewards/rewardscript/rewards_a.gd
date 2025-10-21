extends Control

@onready var sticker_grid = $StickerContainer/StickerGrid
@onready var board = $Board

# NEW: Define which stickers are unlocked by which letters
@export var sticker_data: Array[Dictionary] = []

func _ready():
	add_to_group("main")
	
	# Connect to Global's letter completion updates
	if Global:
		Global.letter_cache_updated.connect(_on_letter_cache_updated)
	
	# Initialize sticker data if empty
	if sticker_data.is_empty():
		setup_default_sticker_data()
	
	# Wait for letter cache to load, then setup stickers
	if Global.is_letter_cache_loaded:
		setup_stickers()
	else:
		# Wait for cache to load
		await Global.letter_cache_updated
		setup_stickers()

func setup_default_sticker_data():
	# Example sticker configuration - customize this for your game
	sticker_data = [
		
		# Letter A stickers
		{"texture_path": "res://rewards/Sticker/A.png", "letter": "A"},
		# Letter B stickers
		{"texture_path": "res://rewards/Sticker/B.png", "letter": "B"},
		{"texture_path": "res://rewards/Sticker/C.png", "letter": "C"},
		{"texture_path": "res://rewards/Sticker/D.png", "letter": "D"},
		{"texture_path": "res://rewards/Sticker/E.png", "letter": "E"},
		{"texture_path": "res://rewards/Sticker/F.png", "letter": "F"},
		{"texture_path": "res://rewards/Sticker/G.png", "letter": "G"},
		{"texture_path": "res://rewards/Sticker/H.png", "letter": "H"},
		{"texture_path": "res://rewards/Sticker/I.png", "letter": "I"},
		{"texture_path": "res://rewards/Sticker/J.png", "letter": "J"},
		{"texture_path": "res://rewards/Sticker/K.png", "letter": "K"},
		{"texture_path": "res://rewards/Sticker/L.png", "letter": "L"},
		{"texture_path": "res://rewards/Sticker/M.png", "letter": "M"},
		{"texture_path": "res://rewards/Sticker/N.png", "letter": "N"},
		{"texture_path": "res://rewards/Sticker/O.png", "letter": "O"},
		{"texture_path": "res://rewards/Sticker/P.png", "letter": "P"},
		{"texture_path": "res://rewards/Sticker/Q.png", "letter": "Q"},
		{"texture_path": "res://rewards/Sticker/R.png", "letter": "R"},
		{"texture_path": "res://rewards/Sticker/S.png", "letter": "S"},
		{"texture_path": "res://rewards/Sticker/T.png", "letter": "T"},
		{"texture_path": "res://rewards/Sticker/U.png", "letter": "U"},
		{"texture_path": "res://rewards/Sticker/V.png", "letter": "V"},
		{"texture_path": "res://rewards/Sticker/W.png", "letter": "W"},
		{"texture_path": "res://rewards/Sticker/X.png", "letter": "X"},
		{"texture_path": "res://rewards/Sticker/Y.png", "letter": "Y"},
		{"texture_path": "res://rewards/Sticker/Z.png", "letter": "Z"},
		\
		
		# Add more as needed...
	]

func setup_stickers():
	# Clear existing stickers
	for child in sticker_grid.get_children():
		child.queue_free()
	
	# Create stickers based on data
	for sticker_info in sticker_data:
		create_sticker_from_data(sticker_info)

func create_sticker_from_data(sticker_info: Dictionary):
	var texture_path = sticker_info.get("texture_path", "")
	var letter = sticker_info.get("letter", "")
	
	# Load texture
	var texture = load(texture_path) as Texture2D
	if not texture:
		push_warning("Could not load sticker texture: " + texture_path)
		return
	
	# Create sticker instance
	var sticker_scene = preload("res://rewards/rewardscript/Sticker.tscn")
	var sticker = sticker_scene.instantiate()
	
	# Set sticker data
	sticker.set_sticker_data(texture, letter)
	
	# Add to grid
	sticker_grid.add_child(sticker)

func _on_letter_cache_updated():
	# Refresh all sticker unlock status when letter completion changes
	refresh_all_stickers()

func refresh_all_stickers():
	# Update unlock status for all stickers
	var stickers = get_tree().get_nodes_in_group("stickers")
	for sticker in stickers:
		if sticker.has_method("refresh_unlock_status"):
			sticker.refresh_unlock_status()

# NEW: Method to unlock stickers for a specific letter (call this when letter completed)
func unlock_stickers_for_letter(letter: String):
	Global.debug_print("Unlocking stickers for letter: %s" % letter, "Stickers", "🎁")
	
	# This will be handled automatically by the letter_cache_updated signal
	# but you can call this for immediate feedback
	refresh_all_stickers()
	
	# Optional: Show unlock animation/notification
	show_unlock_notification(letter)

func show_unlock_notification(letter: String):
	# Optional: Create a popup or animation showing new stickers unlocked
	# Example implementation:
	var notification = Label.new()
	notification.text = "New stickers unlocked for letter %s!" % letter
	notification.add_theme_font_size_override("font_size", 24)
	notification.add_theme_color_override("font_color", Color.YELLOW)
	notification.anchors_preset = Control.PRESET_CENTER
	add_child(notification)
	
	# Animate and remove
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, 2.0)
	tween.tween_callback(notification.queue_free)


# Addition to your Global.gd - Add this method to trigger sticker updates
# Add this to your existing Global.gd file:

func trigger_sticker_refresh():
	"""Call this whenever letter completion status changes"""
	# This will automatically trigger the refresh through the signal system
	Global.letter_cache_updated.emit()

# Update your refresh_everything_after_stage_completion method in Global.gd
func refresh_everything_after_stage_completion(stage_name: String, completed: bool):
	"""Enhanced version that includes sticker refresh"""
	
	if not completed:
		print("Stage failed: %s - no cache updates needed" % stage_name)
		return
	
	var current_letter = Global.current_letter
	
	# 1. Update stage completion immediately
	if not Global.stage_completion_cache.has(current_letter):
		Global.stage_completion_cache[current_letter] = Global.get_default_stage_data()
	
	Global.stage_completion_cache[current_letter][stage_name] = true
	print("Stage completed: %s.%s" % [current_letter, stage_name])
	
	# 2. Check if letter is now complete
	var required_stages = ["reading", "fine_motor", "math", "art"]
	var completed_count = 0
	
	for stage in required_stages:
		if Global.stage_completion_cache[current_letter].get(stage, false):
			completed_count += 1
	
	print("Letter progress: %d/4 stages" % completed_count)
	
	# 3. If all stages complete, update letter completion
	var letter_was_just_completed = false
	if completed_count == 4:
		if not Global.letter_completion_cache.get(current_letter, false):
			letter_was_just_completed = true
		Global.letter_completion_cache[current_letter] = true
		print("Letter completed: %s" % current_letter)
	
	# 4. Refresh ALL UI immediately (including stickers)
	Global.letter_cache_updated.emit()
	Global.stage_cache_updated.emit(current_letter)
	
	# 5. Force refresh current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		if current_scene.has_method("update_button_states"):
			current_scene.update_button_states()
		elif current_scene.has_method("refresh_carousel"):
			current_scene.refresh_carousel()
		elif current_scene.has_method("update_letters_with_lock_status"):
			current_scene.update_letters_with_lock_status()
		
		# NEW: If letter was just completed, trigger sticker unlock celebration
		if letter_was_just_completed and current_scene.has_method("unlock_stickers_for_letter"):
			current_scene.unlock_stickers_for_letter(current_letter)
	
	print("Cache and UI refresh complete")


func _on_quitbtn_pressed() -> void:
		get_tree().change_scene_to_file("res://scenes/LevelSelection.tscn")
