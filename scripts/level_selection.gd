extends Control

# Letter data and completion tracking
var letters = []
var current_index = 0
var selected_letter = ""
var dialog_theme = preload("res://assets/main_theme.tres")
var is_transitioning = false  # Prevent updates during scene transition

# Button references
@onready var left_button: TextureButton = $LeftButton
@onready var center_button: TextureButton = $CenterButton
@onready var right_button: TextureButton = $RightButton

# Labels for the letters
@onready var left_label: Label = $LeftButton/LeftLabel
@onready var center_label: Label = $CenterButton/CenterLabel
@onready var right_label: Label = $RightButton/RightLabel

# Lock indicators
@onready var left_lock: TextureRect = $LeftButton/LockIcon if has_node("$LeftButton/LockIcon") else null
@onready var center_lock: TextureRect = $CenterButton/LockIcon if has_node("$CenterButton/LockIcon") else null
@onready var right_lock: TextureRect = $RightButton/LockIcon if has_node("$RightButton/LockIcon") else null

# Animation variables
var tween: Tween
var is_animating = false

# Store initial positions and scales
var left_initial_pos: Vector2
var center_initial_pos: Vector2
var right_initial_pos: Vector2
var small_scale = Vector2(1.1, 1.1)
var large_scale = Vector2(1.4, 1.4)

# Swipe/Touch variables
var is_swiping = false
var swipe_start_pos: Vector2
var swipe_min_distance = 50.0
var swipe_max_time = 0.5
var swipe_start_time: float

# Animation distances
var slide_out_distance = 100.0
var button_spacing_adjustment = 30.0

# Lock visual settings
var locked_modulate = Color(0.5, 0.5, 0.5, 0.8)
var unlocked_modulate = Color(1.0, 1.0, 1.0, 1.0)

# Simple debug helper - just consolidates print statements
func debug_print(message: String, icon: String = "📚"):
	print("%s %s" % [icon, message])

func _ready():
	for i in range(26):
		letters.append(String.chr(65 + i))
	
	setup_carousel()
	current_index = Global.current_index 
	
	# FIREBASE-ONLY: Always connect to the signal FIRST
	if not Global.letter_cache_updated.is_connected(_on_letter_cache_updated):
		Global.letter_cache_updated.connect(_on_letter_cache_updated)
		debug_print("Connected to Firebase letter cache signal", "🔗")
	
	# Show immediate safe UI
	update_letters_with_safe_defaults()
	
	# Then handle Firebase cache properly
	handle_firebase_cache_and_update_ui()
	
	# Connect button signals
	left_button.pressed.connect(_on_any_button_pressed.bind(left_button))
	center_button.pressed.connect(_on_any_button_pressed.bind(center_button))
	right_button.pressed.connect(_on_any_button_pressed.bind(right_button))

# Enhanced signal handler for Firebase updates
func _on_letter_cache_updated():
	# Don't update UI if we're transitioning away
	if is_transitioning:
		return
	update_letters_with_lock_status()

# FIREBASE-ONLY: Handle cache and UI updates
func handle_firebase_cache_and_update_ui():
	debug_print("Letter Carousel: Initializing with Firebase-only cache handling...")
	
	# Show safe defaults first (A unlocked, others based on actual cache)
	update_letters_with_safe_defaults()
	
	if Global.is_letter_cache_loaded:
		debug_print("Firebase cache already loaded - updating UI immediately", "✅")
		update_letters_with_lock_status()
	else:
		debug_print("Firebase cache not ready - waiting for signal", "⏳")
		
		# For authenticated users, Firebase cache will load via signal
		# For unauthenticated users, set defaults (A unlocked only)
		if not Global.is_authenticated():
			Global.set_default_letter_cache()
			update_letters_with_lock_status()

# Fix the safe defaults function  
func update_letters_with_safe_defaults():
	if is_transitioning:
		return
		
	debug_print("Updating with safe defaults...")
	
	# Update letter text
	var prev_index = (int(current_index) - 1 + letters.size()) % letters.size()
	var next_index = (int(current_index) + 1) % letters.size()
	
	left_label.text = letters[prev_index]
	center_label.text = letters[current_index]
	right_label.text = letters[next_index]
	
	# Apply safe visual defaults - A is always unlocked, others check Firebase cache or default to locked
	apply_safe_button_visual(left_button, left_lock, letters[prev_index])
	apply_safe_button_visual(center_button, center_lock, letters[current_index])
	apply_safe_button_visual(right_button, right_lock, letters[next_index])

# FIREBASE-ONLY: Safe visual application
func apply_safe_button_visual(button: TextureButton, lock_icon: TextureRect, letter: String):
	if not button or is_transitioning:
		return
	
	var is_unlocked = false
	
	if letter == "A":
		is_unlocked = true  # A is ALWAYS unlocked
	elif Global.is_letter_cache_loaded:
		is_unlocked = Global.is_letter_unlocked(letter)
	else:
		# Firebase cache not loaded - default to locked unless it's A
		is_unlocked = false
	
	button.modulate = unlocked_modulate if is_unlocked else locked_modulate
	if lock_icon and is_instance_valid(lock_icon):
		lock_icon.visible = not is_unlocked
	
	debug_print("Visual applied: %s = %s" % [letter, "unlocked" if is_unlocked else "locked"])

# FIREBASE-ONLY: Apply button visual from Firebase cache
func apply_button_visual(button: TextureButton, lock_icon: TextureRect, letter: String):
	if not button or is_transitioning:
		return
	
	var is_unlocked = Global.is_letter_unlocked(letter)
	
	button.modulate = unlocked_modulate if is_unlocked else locked_modulate
	if lock_icon and is_instance_valid(lock_icon):
		lock_icon.visible = not is_unlocked
	
	debug_print("Applied visual: %s = %s" % [letter, "unlocked" if is_unlocked else "locked"], "🎨")

func setup_carousel():
	# Store initial positions AFTER nodes are ready
	left_initial_pos = left_button.position
	center_initial_pos = center_button.position
	right_initial_pos = right_button.position
	
	# Shift center button to the left by 50 pixels
	var center_offset_x = -50
	center_button.position.x += center_offset_x
	center_initial_pos.x += center_offset_x
	
	# Set initial scales
	left_button.scale = small_scale
	center_button.scale = large_scale
	right_button.scale = small_scale
	
	# Set z_index to prevent overlap issues
	left_button.z_index = 1
	center_button.z_index = 3
	right_button.z_index = 2

func is_letter_unlocked(letter: String) -> bool:
	if letter == "A":
		return true
	return Global.is_letter_unlocked(letter)

# FIREBASE-ONLY: Update letters with lock status from Firebase cache
func update_letters_with_lock_status():
	if is_transitioning:
		return
		
	debug_print("Updating letters with lock status from Firebase cache...")
	
	# Update the letters displayed
	var prev_index = (int(current_index) - 1 + letters.size()) % letters.size()
	var next_index = (int(current_index) + 1) % letters.size()
	
	var left_letter = letters[prev_index]
	var center_letter = letters[current_index]
	var right_letter = letters[next_index]
	
	left_label.text = left_letter
	center_label.text = center_letter
	right_label.text = right_letter
	
	# Update lock icon references before applying visuals
	update_lock_references()
	
	# Apply lock visual effects using consolidated function
	apply_button_visual(left_button, left_lock, left_letter)
	apply_button_visual(center_button, center_lock, center_letter)
	apply_button_visual(right_button, right_lock, right_letter)
	
	debug_print("UI updated: Left=%s(%s), Center=%s(%s), Right=%s(%s)" % [
		left_letter, "unlocked" if Global.is_letter_unlocked(left_letter) else "locked",
		center_letter, "unlocked" if Global.is_letter_unlocked(center_letter) else "locked", 
		right_letter, "unlocked" if Global.is_letter_unlocked(right_letter) else "locked"
	])

func update_lock_references():
	left_lock = left_button.get_node("LockIcon") if left_button.has_node("LockIcon") else null
	center_lock = center_button.get_node("LockIcon") if center_button.has_node("LockIcon") else null
	right_lock = right_button.get_node("LockIcon") if right_button.has_node("LockIcon") else null

func update_label_references():
	for child in left_button.get_children():
		if child is Label:
			left_label = child
			break
	
	for child in center_button.get_children():
		if child is Label:
			center_label = child
			break
			
	for child in right_button.get_children():
		if child is Label:
			right_label = child
			break

# Simplified update function
func update_letters():
	if is_transitioning:
		return
	update_letters_with_lock_status()

func _on_any_button_pressed(clicked_button: TextureButton):
	if is_animating or is_transitioning:
		return
	
	if clicked_button.scale == large_scale:
		var center_letter = letters[current_index]
		
		if is_letter_unlocked(center_letter):
			is_transitioning = true
			_disconnect_signals()
			
			Global.current_index = current_index
			Global.current_letter = center_letter
			# FIREBASE-ONLY: Preload stage data for smoother transition
			Global.preload_letter_stages(center_letter)
			
			get_tree().change_scene_to_file("res://scenes/Categories.tscn")
		else:
			show_lock_message(center_letter)
	else:
		if clicked_button == left_button:
			slide_right()
		elif clicked_button == right_button:
			slide_left()

func show_lock_message(letter: String):
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return
	
	var previous_letter = letters[letter_index - 1]
	var lock_message = "Complete letter %s first to unlock %s!" % [previous_letter, letter]
	
	# Create a simple dialog
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.theme = dialog_theme
	dialog.dialog_text = "🔒 Letter Locked!\n\n" + lock_message
	dialog.title = "Unlock Required"
	dialog.min_size = Vector2(350, 150)
	dialog.size = Vector2(350, 150)	
	dialog.popup_centered()
	
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

func slide_left():
	if is_animating or is_transitioning:
		return
		
	is_animating = true
	current_index = (int(current_index) + 1) % letters.size()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	var duration = 0.3
	
	var left_exit_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	tween.tween_property(left_button, "position", left_exit_pos, duration)
	tween.tween_property(left_button, "modulate:a", 0.0, duration)
	
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween.tween_property(center_button, "position", adjusted_left_pos, duration)
	tween.tween_property(center_button, "scale", small_scale, duration)
	tween.tween_property(center_button, "z_index", 1, duration)
	
	tween.tween_property(right_button, "position", center_initial_pos, duration)
	tween.tween_property(right_button, "scale", large_scale, duration)
	tween.tween_property(right_button, "z_index", 3, duration)
	
	await tween.finished
	finish_slide_left()

func finish_slide_left():
	var temp = left_button
	left_button = center_button
	center_button = right_button
	right_button = temp
	
	update_label_references()
	
	var right_enter_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	right_button.position = right_enter_pos
	right_button.modulate.a = 0.0
	right_button.z_index = 2
	
	# Update letters immediately after reference swap
	update_letters()
	
	var adjusted_right_pos = Vector2(right_initial_pos.x - button_spacing_adjustment, right_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(right_button, "position", adjusted_right_pos, 0.2)
	tween.tween_property(right_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

func slide_right():
	if is_animating or is_transitioning:
		return
		
	is_animating = true
	current_index = (int(current_index) - 1 + letters.size()) % letters.size()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	var duration = 0.3
	
	var right_exit_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	tween.tween_property(right_button, "position", right_exit_pos, duration)
	tween.tween_property(right_button, "modulate:a", 0.0, duration)
	
	var adjusted_right_pos = Vector2(right_initial_pos.x - button_spacing_adjustment, right_initial_pos.y)
	tween.tween_property(center_button, "position", adjusted_right_pos, duration)
	tween.tween_property(center_button, "scale", small_scale, duration)
	tween.tween_property(center_button, "z_index", 2, duration)
	
	tween.tween_property(left_button, "position", center_initial_pos, duration)
	tween.tween_property(left_button, "scale", large_scale, duration)
	tween.tween_property(left_button, "z_index", 3, duration)
	
	await tween.finished
	finish_slide_right()

func finish_slide_right():
	var temp = right_button
	right_button = center_button
	center_button = left_button
	left_button = temp
	
	update_label_references()
	
	var left_enter_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	left_button.position = left_enter_pos
	left_button.modulate.a = 0.0
	left_button.z_index = 1
	
	# Update letters immediately after reference swap
	update_letters()
	
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_button, "position", adjusted_left_pos, 0.2)
	tween.tween_property(left_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

# FIREBASE-ONLY: Call this when returning from a completed letter to refresh the carousel
func refresh_carousel():
	if is_transitioning:
		return
		
	debug_print("Refreshing letter carousel after letter completion...", "🔄")
	
	# FIREBASE-ONLY: Reload from Firebase instead of local storage
	if Global.is_authenticated():
		Global.load_all_letter_completion_data()
	else:
		# For offline users, just use defaults
		Global.set_default_letter_cache()
	
	# Update UI with new states
	update_letters_with_lock_status()

func _input(event):
	if is_transitioning:
		return
		
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var touch_event = InputEventScreenTouch.new()
			touch_event.position = event.position
			touch_event.pressed = event.pressed
			touch_event.index = 0
			handle_touch(touch_event)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag_event = InputEventScreenDrag.new()
			drag_event.position = event.position
			drag_event.index = 0
			handle_drag(drag_event)

func handle_touch(event: InputEventScreenTouch):
	if is_animating or is_transitioning:
		return
		
	if event.pressed:
		is_swiping = true
		swipe_start_pos = event.position
		swipe_start_time = Time.get_ticks_msec() / 1000.0
	else:
		if is_swiping:
			var swipe_end_pos = event.position
			var swipe_distance = swipe_end_pos - swipe_start_pos
			var current_time = Time.get_ticks_msec() / 1000.0
			var swipe_time = current_time - swipe_start_time
			
			if abs(swipe_distance.x) > swipe_min_distance and swipe_time < swipe_max_time:
				if swipe_distance.x > 0:
					slide_right()
				else:
					slide_left()
			
			is_swiping = false

func handle_drag(event: InputEventScreenDrag):
	if is_animating or is_transitioning:
		return

func _on_back_pressed():
	is_transitioning = true
	_disconnect_signals()
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")

func _on_trophy_pressed():
	is_transitioning = true
	_disconnect_signals()
	get_tree().change_scene_to_file("res://reward scene/rewards_a.tscn")

func _disconnect_signals():
	if Global.letter_cache_updated.is_connected(_on_letter_cache_updated):
		Global.letter_cache_updated.disconnect(_on_letter_cache_updated)
		debug_print("Disconnected Firebase signals", "🔌")
	
func _exit_tree():
	_disconnect_signals()
