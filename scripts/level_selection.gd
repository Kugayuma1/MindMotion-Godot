# LetterCarousel.gd - Optimized version using Global cache
extends Control

# Letter data and completion tracking
var letters = []
var current_index = 0
var selected_letter = ""

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

func _ready():
	for i in range(26):
		letters.append(String.chr(65 + i))
	
	setup_carousel()
	current_index = Global.current_index 
	
	# 🚀 Since data is preloaded at login, it should be instant
	if Global.is_letter_cache_loaded:
		# Data already loaded - instant display!
		update_letters_with_lock_status()
		print("✅ Letter carousel loaded instantly from cache!")
	else:
		# Fallback: Load data now (shouldn't happen if preload works correctly)
		print("⚠️ Cache not loaded yet, loading now...")
		if Global.is_logged_in:
			Global.load_all_letter_completion_data()
			await wait_for_cache_load_quick()
		else:
			# User not logged in, default to A only
			Global.set_default_letter_cache()
		update_letters_with_lock_status()
	
	# Connect button signals
	left_button.pressed.connect(_on_any_button_pressed.bind(left_button))
	center_button.pressed.connect(_on_any_button_pressed.bind(center_button))
	right_button.pressed.connect(_on_any_button_pressed.bind(right_button))

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

# 🚀 QUICK WAIT FOR CACHE (only if needed as fallback)
func wait_for_cache_load_quick():
	var max_wait_time = 3.0  # Maximum 3 seconds
	var wait_time = 0.0
	
	while not Global.is_letter_cache_loaded and wait_time < max_wait_time and is_inside_tree():
		await get_tree().process_frame
		wait_time += get_process_delta_time()
	
	if not Global.is_letter_cache_loaded and is_inside_tree():
		print("⚠️ Cache loading timed out, using default (A only)")
		Global.set_default_letter_cache()

# 🔒 CHECK IF LETTER IS UNLOCKED (Now uses Global cache)
func is_letter_unlocked(letter: String) -> bool:
	return Global.is_letter_unlocked(letter)

# 🎨 UPDATE LETTERS WITH LOCK STATUS
func update_letters_with_lock_status():
	# Update the letters displayed
	var prev_index = (current_index - 1 + letters.size()) % letters.size()
	var next_index = (current_index + 1) % letters.size()
	
	var left_letter = letters[prev_index]
	var center_letter = letters[current_index]
	var right_letter = letters[next_index]
	
	left_label.text = left_letter
	center_label.text = center_letter
	right_label.text = right_letter
	
	# Apply lock visual effects
	apply_lock_visual(left_button, left_lock, left_letter)
	apply_lock_visual(center_button, center_lock, center_letter)
	apply_lock_visual(right_button, right_lock, right_letter)

func apply_lock_visual(button: TextureButton, lock_icon: TextureRect, letter: String):
	var is_unlocked = is_letter_unlocked(letter)
	
	if is_unlocked:
		button.modulate = unlocked_modulate
		if lock_icon:
			lock_icon.visible = false
	else:
		button.modulate = locked_modulate
		if lock_icon:
			lock_icon.visible = true

func update_letters():
	update_letters_with_lock_status()

# 🔒 BUTTON PRESS HANDLER WITH LOCK CHECK
func _on_any_button_pressed(clicked_button: TextureButton):
	if is_animating:
		return
	
	# Check which button is currently in the center position
	if clicked_button.scale == large_scale:
		# This is the center button - check if it's unlocked
		var center_letter = letters[current_index]
		
		if is_letter_unlocked(center_letter):
			# Letter is unlocked - proceed to categories
			Global.current_index = current_index
			Global.current_letter = center_letter
			var categories_scene = load("res://scenes/Categories.tscn").instantiate()
			get_tree().root.add_child(categories_scene)
			queue_free()
		else:
			# Letter is locked - show lock message
			show_lock_message(center_letter)
	else:
		# This is a side button - animate to center
		if clicked_button == left_button:
			slide_right()
		elif clicked_button == right_button:
			slide_left()

# 🔒 SHOW LOCK MESSAGE
func show_lock_message(letter: String):
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return
	
	var previous_letter = letters[letter_index - 1]
	var lock_message = "Complete letter %s first to unlock %s!" % [previous_letter, letter]
	
	print("🔒 " + lock_message)
	# You can enhance this with a proper dialog/toast UI

# [Keep all your existing animation functions - slide_left, slide_right, etc.]
# [Keep all your existing input handling functions]

func slide_left():
	if is_animating:
		return
		
	is_animating = true
	current_index = (current_index + 1) % letters.size()
	
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
	
	left_label = left_button.get_node("LeftLabel") if left_button.has_node("LeftLabel") else left_button.get_node("CenterLabel") if left_button.has_node("CenterLabel") else left_button.get_node("RightLabel")
	center_label = center_button.get_node("CenterLabel") if center_button.has_node("CenterLabel") else center_button.get_node("LeftLabel") if center_button.has_node("LeftLabel") else center_button.get_node("RightLabel")
	right_label = right_button.get_node("RightLabel") if right_button.has_node("RightLabel") else right_button.get_node("CenterLabel") if right_button.has_node("CenterLabel") else right_button.get_node("LeftLabel")
	
	left_lock = left_button.get_node("LockIcon") if left_button.has_node("LockIcon") else null
	center_lock = center_button.get_node("LockIcon") if center_button.has_node("LockIcon") else null
	right_lock = right_button.get_node("LockIcon") if right_button.has_node("LockIcon") else null
	
	var right_enter_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	right_button.position = right_enter_pos
	right_button.modulate.a = 0.0
	right_button.z_index = 2
	
	update_letters()
	
	var adjusted_right_pos = Vector2(right_initial_pos.x - button_spacing_adjustment, right_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(right_button, "position", adjusted_right_pos, 0.2)
	tween.tween_property(right_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

func slide_right():
	if is_animating:
		return
		
	is_animating = true
	current_index = (current_index - 1 + letters.size()) % letters.size()
	
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
	
	left_label = left_button.get_node("LeftLabel") if left_button.has_node("LeftLabel") else left_button.get_node("CenterLabel") if left_button.has_node("CenterLabel") else left_button.get_node("RightLabel")
	center_label = center_button.get_node("CenterLabel") if center_button.has_node("CenterLabel") else center_button.get_node("LeftLabel") if center_button.has_node("LeftLabel") else center_button.get_node("RightLabel")
	right_label = right_button.get_node("RightLabel") if right_button.has_node("RightLabel") else right_button.get_node("CenterLabel") if right_button.has_node("CenterLabel") else right_button.get_node("LeftLabel")
	
	left_lock = left_button.get_node("LockIcon") if left_button.has_node("LockIcon") else null
	center_lock = center_button.get_node("LockIcon") if center_button.has_node("LockIcon") else null
	right_lock = right_button.get_node("LockIcon") if right_button.has_node("LockIcon") else null
	
	var left_enter_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	left_button.position = left_enter_pos
	left_button.modulate.a = 0.0
	left_button.z_index = 1
	
	update_letters()
	
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_button, "position", adjusted_left_pos, 0.2)
	tween.tween_property(left_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

func _input(event):
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
	if is_animating:
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
	if is_animating:
		return

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
