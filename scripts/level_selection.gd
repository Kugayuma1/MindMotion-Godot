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
	
	# Cache should already be loaded by Global.change_scene_with_cache_wait()
	# But add a small safety check
	if not Global.is_letter_cache_loaded:
		print("⚠️ Cache still not loaded, using defaults")
		Global.set_default_letter_cache()
	
	# Update UI immediately since cache is ready
	update_letters_with_lock_status()
	
	# Connect button signals
	left_button.pressed.connect(_on_any_button_pressed.bind(left_button))
	center_button.pressed.connect(_on_any_button_pressed.bind(center_button))
	right_button.pressed.connect(_on_any_button_pressed.bind(right_button))

# NEW: Signal handler for when cache updates
func _on_letter_cache_updated():
	print("🔄 Letter cache updated - refreshing UI...")
	update_letters_with_lock_status()
	
# IMPROVED: Better cache handling
func handle_cache_and_update_ui():
	print("📚 Letter Carousel: Initializing with proper cache handling...")
	
	# Always show safe defaults first
	update_letters_with_safe_defaults()
	
	if Global.is_letter_cache_loaded:
		# Cache is ready, update immediately
		print("✅ Cache already loaded - updating UI immediately")
		update_letters_with_lock_status()
	else:
		print("⏳ Cache not loaded - will update when ready via signal")
		
		if Global.is_logged_in:
			# Don't wait here - let the signal handle it
			# The cache loading is already triggered in Global._ready()
			pass
		else:
			# Set default cache for offline users
			Global.set_default_letter_cache()
		
		# Update UI with real cache data
		update_letters_with_lock_status()
		print("✅ UI updated after cache load")

# NEW: Show safe defaults immediately (A unlocked, others grayed out)
func update_letters_with_safe_defaults():
	# Update letter text
	var prev_index = (current_index - 1 + letters.size()) % letters.size()
	var next_index = (current_index + 1) % letters.size()
	
	left_label.text = letters[prev_index]
	center_label.text = letters[current_index]
	right_label.text = letters[next_index]
	
	# Apply safe visual defaults
	apply_safe_default_visual(left_button, left_lock, letters[prev_index])
	apply_safe_default_visual(center_button, center_lock, letters[current_index])
	apply_safe_default_visual(right_button, right_lock, letters[next_index])

# NEW: Apply safe defaults (only A unlocked)
func apply_safe_default_visual(button: TextureButton, lock_icon: TextureRect, letter: String):
	if not button:
		return
	
	# Only A is unlocked by default
	var is_unlocked = (letter == "A")
	
	if is_unlocked:
		button.modulate = unlocked_modulate
		if lock_icon and is_instance_valid(lock_icon):
			lock_icon.visible = false
	else:
		button.modulate = locked_modulate
		if lock_icon and is_instance_valid(lock_icon):
			lock_icon.visible = true

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
	
	# Update lock icon references before applying visuals
	update_lock_references()
	
	# Apply lock visual effects
	apply_lock_visual(left_button, left_lock, left_letter)
	apply_lock_visual(center_button, center_lock, center_letter)
	apply_lock_visual(right_button, right_lock, right_letter)
	
	print("🎨 UI updated: Left=%s, Center=%s, Right=%s" % [left_letter, center_letter, right_letter])

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

func apply_lock_visual(button: TextureButton, lock_icon: TextureRect, letter: String):
	if not button:
		return
		
	var is_unlocked = is_letter_unlocked(letter)
	
	if is_unlocked:
		button.modulate = unlocked_modulate
		if lock_icon and is_instance_valid(lock_icon):
			lock_icon.visible = false
	else:
		button.modulate = locked_modulate
		if lock_icon and is_instance_valid(lock_icon):
			lock_icon.visible = true

# FIXED: Always update UI after letters change
func update_letters():
	update_letters_with_lock_status()

func _on_any_button_pressed(clicked_button: TextureButton):
	if is_animating:
		return
	
	if clicked_button.scale == large_scale:
		var center_letter = letters[current_index]
		
		if is_letter_unlocked(center_letter):
			Global.current_index = current_index
			Global.current_letter = center_letter
			# Preload stage data for smoother transition
			Global.preload_letter_stages(center_letter)
			var categories_scene = load("res://scenes/Categories.tscn").instantiate()
			get_tree().root.add_child(categories_scene)
			queue_free()
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
	dialog.dialog_text = "🔒 Letter Locked!\n\n" + lock_message
	dialog.title = "Unlock Required"
	dialog.popup_centered()
	
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

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
	
	update_label_references()
	
	var right_enter_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	right_button.position = right_enter_pos
	right_button.modulate.a = 0.0
	right_button.z_index = 2
	
	# FIXED: Update letters immediately after reference swap
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
	
	update_label_references()
	
	var left_enter_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	left_button.position = left_enter_pos
	left_button.modulate.a = 0.0
	left_button.z_index = 1
	
	# FIXED: Update letters immediately after reference swap
	update_letters()
	
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_button, "position", adjusted_left_pos, 0.2)
	tween.tween_property(left_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

# NEW: Call this when returning from a completed letter to refresh the carousel
func refresh_carousel():
	print("🔄 Refreshing letter carousel after letter completion...")
	
	# Reload letter cache
	if Global.is_logged_in:
		Global.load_all_letter_completion_data()

	
	# Update UI with new states
	update_letters_with_lock_status()

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
	
func _exit_tree():
	if Global.letter_cache_updated.is_connected(_on_letter_cache_updated):
		Global.letter_cache_updated.disconnect(_on_letter_cache_updated)
