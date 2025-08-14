# LetterCarousel.gd
extends Control

# Letter data - you can modify this array to change the letters
var letters = []
var current_index = 0
var selected_letter = ""

# Button references (using your existing scene nodes)
@onready var left_button: TextureButton = $LeftButton
@onready var center_button: TextureButton = $CenterButton
@onready var right_button: TextureButton = $RightButton

# Labels for the letters (using your existing scene nodes)
@onready var left_label: Label = $LeftButton/LeftLabel
@onready var center_label: Label = $CenterButton/CenterLabel
@onready var right_label: Label = $RightButton/RightLabel

# Animation variables
var tween: Tween
var is_animating = false

# Store initial positions and scales - PROPERLY DECLARED
var left_initial_pos: Vector2
var center_initial_pos: Vector2
var right_initial_pos: Vector2
var small_scale = Vector2(1.1, 1.1)  # Increased from 0.8 to make buttons bigger
var large_scale = Vector2(1.4, 1.4)  # Increased from 1.0 to make center button bigger

# Swipe/Touch variables
var is_swiping = false
var swipe_start_pos: Vector2
var swipe_min_distance = 50.0  # Minimum distance for a swipe
var swipe_max_time = 0.5  # Maximum time for a swipe (in seconds)
var swipe_start_time: float

# Animation distances - NEW VARIABLES FOR CUSTOMIZATION
var slide_out_distance = 100.0  # Reduced from 200 - how far buttons move when sliding out
var button_spacing_adjustment = 30.0  # How much closer to bring side buttons to center

func _ready():
		for i in range(26):
			letters.append(String.chr(65 + i))
		
		setup_carousel()
		current_index = Global.current_index 
		update_letters()
		
		left_button.pressed.connect(_on_any_button_pressed.bind(left_button))
		center_button.pressed.connect(_on_any_button_pressed.bind(center_button))
		right_button.pressed.connect(_on_any_button_pressed.bind(right_button))

func setup_carousel():
	# Store initial positions AFTER nodes are ready
	left_initial_pos = left_button.position
	center_initial_pos = center_button.position
	right_initial_pos = right_button.position
	
	# Shift center button to the left by 20 pixels
	var center_offset_x = -50
	center_button.position.x += center_offset_x
	center_initial_pos.x += center_offset_x
	
	# Set initial scales
	left_button.scale = small_scale
	center_button.scale = large_scale
	right_button.scale = small_scale
	
	# Set z_index to prevent overlap issues
	left_button.z_index = 1
	center_button.z_index = 3  # Center button should be on top
	right_button.z_index = 2
	

func update_letters():
	# Update the letters displayed
	var prev_index = (current_index - 1 + letters.size()) % letters.size()
	var next_index = (current_index + 1) % letters.size()
	
	left_label.text = letters[prev_index]
	center_label.text = letters[current_index]
	right_label.text = letters[next_index]


func slide_left():
	if is_animating:
		return
		
	is_animating = true
	current_index = (current_index + 1) % letters.size()
	
	# Create new tween for this animation
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations at once
	
	# Animate positions and scales
	var duration = 0.3
	
	# Left button moves out to the left and fades
	var left_exit_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	tween.tween_property(left_button, "position", left_exit_pos, duration)
	tween.tween_property(left_button, "modulate:a", 0.0, duration)
	
	# Center button moves to left position (closer to center) and scales down
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween.tween_property(center_button, "position", adjusted_left_pos, duration)
	tween.tween_property(center_button, "scale", small_scale, duration)
	tween.tween_property(center_button, "z_index", 1, duration)  # Lower z-index when moving to side
	
	# Right button moves to center and scales up
	tween.tween_property(right_button, "position", center_initial_pos, duration)
	tween.tween_property(right_button, "scale", large_scale, duration)
	tween.tween_property(right_button, "z_index", 3, duration)  # Higher z-index when moving to center
	
	# Wait for animation to complete, then update
	await tween.finished
	finish_slide_left()

func finish_slide_left():
	# Swap button references
	var temp = left_button
	left_button = center_button
	center_button = right_button
	right_button = temp
	
	# Update label references
	left_label = left_button.get_node("LeftLabel") if left_button.has_node("LeftLabel") else left_button.get_node("CenterLabel") if left_button.has_node("CenterLabel") else left_button.get_node("RightLabel")
	center_label = center_button.get_node("CenterLabel") if center_button.has_node("CenterLabel") else center_button.get_node("LeftLabel") if center_button.has_node("LeftLabel") else center_button.get_node("RightLabel")
	right_label = right_button.get_node("RightLabel") if right_button.has_node("RightLabel") else right_button.get_node("CenterLabel") if right_button.has_node("CenterLabel") else right_button.get_node("LeftLabel")
	
	# Reset the new right button (former left) position and create new letter
	var right_enter_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	right_button.position = right_enter_pos
	right_button.modulate.a = 0.0
	right_button.z_index = 2  # Set proper z-index for right position
	
	# Update letters
	update_letters()
	
	# Animate new right button sliding in (closer to center)
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
	
	# Create new tween for this animation
	tween = create_tween()
	tween.set_parallel(true)  # Allow multiple animations at once
	
	# Animate positions and scales
	var duration = 0.3
	
	# Right button moves out to the right and fades
	var right_exit_pos = Vector2(right_initial_pos.x + slide_out_distance, right_initial_pos.y)
	tween.tween_property(right_button, "position", right_exit_pos, duration)
	tween.tween_property(right_button, "modulate:a", 0.0, duration)
	
	# Center button moves to right position (closer to center) and scales down
	var adjusted_right_pos = Vector2(right_initial_pos.x - button_spacing_adjustment, right_initial_pos.y)
	tween.tween_property(center_button, "position", adjusted_right_pos, duration)
	tween.tween_property(center_button, "scale", small_scale, duration)
	tween.tween_property(center_button, "z_index", 2, duration)  # Lower z-index when moving to side
	
	# Left button moves to center and scales up
	tween.tween_property(left_button, "position", center_initial_pos, duration)
	tween.tween_property(left_button, "scale", large_scale, duration)
	tween.tween_property(left_button, "z_index", 3, duration)  # Higher z-index when moving to center
	
	# Wait for animation to complete, then update
	await tween.finished
	finish_slide_right()

func finish_slide_right():
	# Swap button references
	var temp = right_button
	right_button = center_button
	center_button = left_button
	left_button = temp
	
	# Update label references
	left_label = left_button.get_node("LeftLabel") if left_button.has_node("LeftLabel") else left_button.get_node("CenterLabel") if left_button.has_node("CenterLabel") else left_button.get_node("RightLabel")
	center_label = center_button.get_node("CenterLabel") if center_button.has_node("CenterLabel") else center_button.get_node("LeftLabel") if center_button.has_node("LeftLabel") else center_button.get_node("RightLabel")
	right_label = right_button.get_node("RightLabel") if right_button.has_node("RightLabel") else right_button.get_node("CenterLabel") if right_button.has_node("CenterLabel") else right_button.get_node("LeftLabel")
	
	# Reset the new left button (former right) position and create new letter
	var left_enter_pos = Vector2(left_initial_pos.x - slide_out_distance, left_initial_pos.y)
	left_button.position = left_enter_pos
	left_button.modulate.a = 0.0
	left_button.z_index = 1  # Set proper z-index for left position
	
	# Update letters
	update_letters()
	
	# Animate new left button sliding in (closer to center)
	var adjusted_left_pos = Vector2(left_initial_pos.x + button_spacing_adjustment, left_initial_pos.y)
	tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_button, "position", adjusted_left_pos, 0.2)
	tween.tween_property(left_button, "modulate:a", 1.0, 0.2)
	
	await tween.finished
	is_animating = false

# Optional: Add keyboard and swipe controls
func _input(event):
	
	# Handle mouse/touch swipe controls
	if event is InputEventScreenTouch:
		handle_touch(event)
	elif event is InputEventScreenDrag:
		handle_drag(event)
	elif event is InputEventMouseButton:
		# Treat mouse as touch for PC testing
		if event.button_index == MOUSE_BUTTON_LEFT:
			var touch_event = InputEventScreenTouch.new()
			touch_event.position = event.position
			touch_event.pressed = event.pressed
			touch_event.index = 0
			handle_touch(touch_event)
	elif event is InputEventMouseMotion:
		# Treat mouse drag as touch drag for PC testing
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var drag_event = InputEventScreenDrag.new()
			drag_event.position = event.position
			drag_event.index = 0
			handle_drag(drag_event)

func handle_touch(event: InputEventScreenTouch):
	if is_animating:
		return
		
	if event.pressed:
		# Start swipe detection
		is_swiping = true
		swipe_start_pos = event.position
		swipe_start_time = Time.get_ticks_msec() / 1000.0
	else:
		# End swipe detection
		if is_swiping:
			var swipe_end_pos = event.position
			var swipe_distance = swipe_end_pos - swipe_start_pos
			var current_time = Time.get_ticks_msec() / 1000.0
			var swipe_time = current_time - swipe_start_time
			
			# Check if it's a valid swipe
			if abs(swipe_distance.x) > swipe_min_distance and swipe_time < swipe_max_time:
				if swipe_distance.x > 0:
					# Swipe right (show previous letter)
					slide_right()
				else:
					# Swipe left (show next letter)
					slide_left()
			
			is_swiping = false

func handle_drag(event: InputEventScreenDrag):
	if is_animating:
		return
	# You can add visual feedback during drag here if desired
	# For now, we'll just update the swipe detection
	pass


func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")


func _on_any_button_pressed(clicked_button: TextureButton):
	if is_animating:
		return
	
	# Check which button is currently in the center position (has large scale)
	if clicked_button.scale == large_scale:
		# This is the center button - proceed to categories
		Global.current_index = current_index
		Global.current_letter = letters[current_index]
		var categories_scene = load("res://scenes/Categories.tscn").instantiate()
		get_tree().root.add_child(categories_scene)
		queue_free()
	else:
		# This is a side button - animate to center
		if clicked_button == left_button:
			slide_right()  # Move left button to center
		elif clicked_button == right_button:
			slide_left()   # Move right button to center
