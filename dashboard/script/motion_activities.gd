extends Control

# Node references
@onready var student_name_label = $Activities
@onready var back_button = $BackButton
@onready var scroll_container = $ScrollContainer
@onready var activities_grid = $ScrollContainer/ActivitiesGrid

# Button textures
var motion_button_normal = preload("res://assets/student_card_bg.png")
var motion_button_pressed = preload("res://assets/student_card_pressed.png")
var custom_font = preload("res://font/LilitaOne-Regular.ttf")
var custom_font1 = preload("res://font/Summary Notes.ttf")
var buttons_created: bool = false
var loading_label: Label
var loading_timer: Timer
var dot_count: int = 0

var current_student_data: Dictionary = {}
var motion_data: Dictionary = {}

# Touch scrolling for mobile
var touch_scrolling = false
var touch_start_y = 0.0
var touch_last_y = 0.0
var scroll_velocity = 0.0
var last_touch_time = 0.0
const SCROLL_FRICTION = 0.92
const MIN_VELOCITY = 5.0
const TOUCH_THRESHOLD = 10.0
var has_moved = false

func _ready():
	# Get student data
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup ScrollContainer for mobile
	setup_scroll_container()
	
	# Setup UI
	student_name_label.text = "%s - Motion Activities" % current_student_data.get("name", "Unknown")
	
	# Set to 2 columns with spacing
	activities_grid.columns = 2
	activities_grid.add_theme_constant_override("h_separation", 20)
	activities_grid.add_theme_constant_override("v_separation", 20)
	
	create_loading_animation()
	
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	StudentData.motion_data_loaded.connect(_on_motion_data_loaded)
	
	# Check if data is already loaded from dashboard preload
	if StudentData.get_current_student_motion_data().size() > 0:
		print("DEBUG: Using preloaded motion data")
		motion_data = StudentData.get_current_student_motion_data()
		create_motion_buttons()
	else:
		print("DEBUG: No preloaded motion data, loading...")
		# Wait a moment for potential preload to finish
		await get_tree().create_timer(0.5).timeout
		if StudentData.get_current_student_motion_data().size() > 0:
			motion_data = StudentData.get_current_student_motion_data()
			create_motion_buttons()
		else:
			StudentData.load_student_motion_data()

func setup_scroll_container():
	if scroll_container:
		# ScrollContainer settings for Godot 4.4
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll_container.follow_focus = false
		
		# Enable input processing
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS

func get_responsive_button_width() -> float:
	var viewport_width = get_viewport().get_visible_rect().size.x
	
	# Two columns - calculate width based on viewport with gap
	var gap = 20  # Gap between columns
	var margin = 40  # Total horizontal margin (20 on each side)
	var button_width = (viewport_width - margin - gap) / 2.0
	
	# Clamp between reasonable values
	return clamp(button_width, 250, 550)

func _process(delta):
	# Apply scroll momentum/inertia
	if not touch_scrolling and abs(scroll_velocity) > MIN_VELOCITY:
		scroll_container.scroll_vertical += int(scroll_velocity)
		scroll_velocity *= SCROLL_FRICTION
		
		# Clamp scrolling within bounds
		var max_scroll = max(0, activities_grid.size.y - scroll_container.size.y)
		scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func _input(event):
	# Handle touch/mouse input for smooth scrolling
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			# Touch/click started
			touch_scrolling = true
			touch_start_y = event.position.y
			touch_last_y = event.position.y
			scroll_velocity = 0.0
			last_touch_time = Time.get_ticks_msec() / 1000.0
			has_moved = false
		else:
			# Touch/click released
			touch_scrolling = false
			
			# Calculate release velocity for momentum scrolling
			var current_time = Time.get_ticks_msec() / 1000.0
			var time_delta = current_time - last_touch_time
			if time_delta > 0 and has_moved:
				scroll_velocity = (touch_last_y - event.position.y) / time_delta * 2.0
				# Limit max velocity
				scroll_velocity = clamp(scroll_velocity, -3000, 3000)
	
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT):
		if touch_scrolling:
			var delta_y = touch_last_y - event.position.y
			
			# Check if movement exceeds threshold
			if abs(event.position.y - touch_start_y) > TOUCH_THRESHOLD:
				has_moved = true
			
			if has_moved:
				# Apply scrolling
				scroll_container.scroll_vertical += int(delta_y)
				
				# Update for velocity calculation
				touch_last_y = event.position.y
				last_touch_time = Time.get_ticks_msec() / 1000.0
				
				# Clamp within bounds
				var max_scroll = max(0, activities_grid.size.y - scroll_container.size.y)
				scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func _on_motion_data_loaded(data: Dictionary):
	motion_data = data
	# Only create buttons if they haven't been created yet
	if not buttons_created:
		create_motion_buttons()

func create_motion_buttons():
	if loading_timer:
		loading_timer.stop()
		loading_timer.queue_free()
		loading_timer = null
	
	# Remove loading container from main scene
	var loading_container = get_node_or_null("LoadingContainer")
	if loading_container:
		loading_container.queue_free()
	
	# Prevent multiple calls
	if buttons_created:
		return
		
	buttons_created = true
	
	# Clear existing buttons
	for child in activities_grid.get_children():
		child.queue_free()
	
	# Define motion activities in alphabetical order
	var motion_types = ["clapping", "wave", "jump", "raise_hand"]
	
	for motion_type in motion_types:
		create_motion_button(motion_type)
	
	# Force layout update
	await get_tree().process_frame
	activities_grid.queue_sort()

func create_motion_button(motion_type: String):
	# Main button container with responsive width
	var button_container = Control.new()
	var button_width = get_responsive_button_width()
	# Increased height to 200 for better visibility
	button_container.custom_minimum_size = Vector2(button_width, 200)
	
	# Motion button
	var motion_button = TextureButton.new()
	motion_button.texture_normal = motion_button_normal
	motion_button.texture_pressed = motion_button_pressed
	motion_button.stretch_mode = TextureButton.STRETCH_SCALE
	motion_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Important: Stop mouse filter but allow press events
	motion_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	button_container.add_child(motion_button)
	
	# Button content container
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 25)
	content_margin.add_theme_constant_override("margin_right", 25)
	content_margin.add_theme_constant_override("margin_top", 25)
	content_margin.add_theme_constant_override("margin_bottom", 25)
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_button.add_child(content_margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 15)
	content_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_margin.add_child(content_vbox)
	
	# Activity name - centered and larger
	var name_label = Label.new()
	name_label.text = motion_type.capitalize()
	name_label.add_theme_color_override("font_color", Color("#3f4553"))
	name_label.add_theme_font_size_override("font_size", 40)
	name_label.add_theme_font_override("font", custom_font)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(name_label)
	
	# Attempts count - centered
	var attempts_label = Label.new()
	var attempt_count = StudentData.get_motion_attempt_count(motion_type)
	attempts_label.text = "Attempts: %d" % attempt_count
	attempts_label.add_theme_color_override("font_color", Color.REBECCA_PURPLE)
	attempts_label.add_theme_font_size_override("font_size", 35)
	attempts_label.add_theme_font_override("font", custom_font1)
	attempts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attempts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(attempts_label)
	
	# Success rate - centered
	var success_label = Label.new()
	var success_rate = StudentData.get_motion_success_rate(motion_type)
	success_label.text = "Success Rate: %.1f%%" % success_rate
	success_label.add_theme_font_size_override("font_size", 35)
	success_label.add_theme_font_override("font", custom_font1)
	success_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	success_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Color code success rate
	var success_color = get_success_rate_color(success_rate)
	success_label.add_theme_color_override("font_color", success_color)
	
	content_vbox.add_child(success_label)
	
	# Connect button with custom handler to detect scroll vs tap
	motion_button.gui_input.connect(_on_button_input.bind(motion_type))
	
	# Add to grid
	activities_grid.add_child(button_container)

func _on_button_input(event: InputEvent, motion_type: String):
	# Only trigger if it was a tap, not a scroll
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed and not has_moved:
			# This was a tap, not a scroll - you can add navigation here if needed
			print("Motion activity pressed: %s" % motion_type)
			# Example: get_tree().change_scene_to_file("res://scenes/MotionDetail.tscn")

func get_success_rate_color(success_rate: float) -> Color:
	if success_rate >= 80.0:
		return Color.GREEN
	elif success_rate >= 60.0:
		return Color.YELLOW
	elif success_rate >= 40.0:
		return Color.ORANGE
	else:
		return Color.RED

func create_loading_animation():
	# Create a container that fills the entire available space
	var loading_container = Control.new()
	loading_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.name = "LoadingContainer"
	
	# Create centered content
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.add_child(center_container)
	
	loading_label = Label.new()
	loading_label.text = "Loading."
	loading_label.add_theme_font_size_override("font_size", 50)
	loading_label.add_theme_color_override("font_color", Color.GRAY)
	center_container.add_child(loading_label)
	
	# Add to the main scene (not the grid)
	add_child(loading_container)
	
	# Create and start the animation timer
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.5
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	add_child(loading_timer)
	loading_timer.start()

func _on_loading_timer_timeout():
	dot_count = (dot_count + 1) % 4  # Cycle through 0, 1, 2, 3
	
	match dot_count:
		0:
			loading_label.text = "Loading."
		1:
			loading_label.text = "Loading.."
		2:
			loading_label.text = "Loading..."
		3:
			loading_label.text = "Loading"
			
func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
