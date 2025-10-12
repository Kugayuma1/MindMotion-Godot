extends Control

# Node references
@onready var scroll_container = $MainContainer/ScrollContainer
@onready var student_grid = $MainContainer/ScrollContainer/StudentGrid
@onready var back_button = $BackButton
@onready var refresh_button = $RefreshButton



# Preload avatar textures
var boy_avatar = preload("res://assets/boy_avatar.png")
var girl_avatar = preload("res://assets/girl_avatar.png")
var student_card_bg = preload("res://assets/student_card_bg.png")
var student_card_pressed = preload("res://assets/student_card_pressed.png")

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
	# Setup ScrollContainer for mobile
	setup_scroll_container()
	
	# Connect back button
	back_button.pressed.connect(_on_back_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	# Connect to Global's students cache signal
	Global.students_cache_updated.connect(_on_students_cache_updated)
	
	LoadingScreen.show_loading()
	# Load students immediately from cache
	load_students_from_cache()
	
	student_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	student_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func setup_scroll_container():
	if scroll_container:
		# ScrollContainer settings for Godot 4.4
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.follow_focus = false
		
		# Enable input processing
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Set GridContainer to 2 columns
	if student_grid:
		student_grid.columns = 2

func get_responsive_button_width() -> float:
	var viewport_width = get_viewport().get_visible_rect().size.x
	
	# 2 columns - calculate width based on available space
	# Account for separation between columns (assume 10-20px gap)
	var h_separation = 15  # Horizontal gap between cards
	var total_padding = 40  # Side margins
	var available_width = viewport_width - h_separation - total_padding
	var button_width = available_width / 2.0
	
	# Clamp between reasonable values for 2-column layout
	return clamp(button_width, 280, 550)

func _process(delta):
	# Apply scroll momentum/inertia
	if not touch_scrolling and abs(scroll_velocity) > MIN_VELOCITY:
		scroll_container.scroll_vertical += int(scroll_velocity)
		scroll_velocity *= SCROLL_FRICTION
		
		# Clamp scrolling within bounds
		var max_scroll = max(0, student_grid.size.y - scroll_container.size.y)
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
				var max_scroll = max(0, student_grid.size.y - scroll_container.size.y)
				scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func load_students_from_cache():
	print("📋 Loading students from Global cache...")
	
	# Clear existing cards
	for child in student_grid.get_children():
		child.queue_free()
		
	# Debug: Check cache status
	print("DEBUG: Cache ready: %s" % Global.is_students_cache_ready())
	print("DEBUG: User type: %s" % Global.user_type)
	print("DEBUG: Is authenticated: %s" % Global.is_authenticated())
	print("DEBUG: Students cache size: %s" % Global.students_cache.size())
	
	# Check if cache is ready
	if not Global.is_students_cache_ready():
		print("DEBUG: Cache not ready, showing loading message")
		create_loading_message()
		return
	
	# Get students from Global cache
	var students_data = Global.get_students_cache()
	print("DEBUG: Retrieved students data - size: %d" % students_data.size())
	
	# Debug: Print student data structure
	if students_data.size() > 0:
		print("DEBUG: First student data: %s" % var_to_str(students_data[0]))
	
	if students_data.size() == 0:
		print("DEBUG: No students found, showing no students message")
		create_no_students_message()
		LoadingScreen.hide_loading()
		return
	
	print("👥 Found %d students in cache" % students_data.size())
	
	# Create student cards immediately - no waiting!
	for i in range(students_data.size()):
		var student_data = students_data[i]
		print("DEBUG: Creating card for student %d: %s" % [i, student_data.get("name", "Unknown")])
		create_student_card(student_data)
	
	print("DEBUG: Finished creating all student cards")
	LoadingScreen.hide_loading()

func create_student_card(student_data: Dictionary):
	# Main card button with responsive width
	var card_button = TextureButton.new()
	card_button.texture_normal = student_card_bg
	card_button.texture_pressed = student_card_pressed
	var button_width = get_responsive_button_width()
	card_button.custom_minimum_size = Vector2(button_width, 175)
	
	card_button.stretch_mode = TextureButton.STRETCH_SCALE
	
	# Important: Stop mouse filter but allow press events
	card_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Card content container
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_top", 20)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_button.add_child(card_margin)
	
	# Horizontal layout for avatar and info
	var card_hbox = HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 20)
	card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(card_hbox)
	
	# Profile picture
	var profile_pic = TextureRect.new()
	profile_pic.custom_minimum_size = Vector2(150, 150)
	profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set gender-based avatar
	if student_data.gender.to_lower() == "female":
		profile_pic.texture = girl_avatar
	else:
		profile_pic.texture = boy_avatar
	
	profile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_child(profile_pic)
	
	# Student info container
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_child(info_vbox)
	
	# Student name
	var name_label = Label.new()
	name_label.text = student_data.name
	name_label.add_theme_color_override("font_color", Color("#3f4553"))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)
	
	# Student email
	var email_label = Label.new()
	email_label.text = student_data.email
	email_label.add_theme_color_override("font_color", Color("#3f4553"))
	email_label.add_theme_font_size_override("font_size", 16)
	email_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(email_label)
	
	# Student age
	var age_label = Label.new()
	if student_data.age > 0:
		age_label.text = "Age: %d" % student_data.age
	else:
		age_label.text = "Age: Not specified"
	age_label.add_theme_color_override("font_color", Color("#3f4553"))
	age_label.add_theme_font_size_override("font_size", 16)
	age_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(age_label)
	
	# Connect button with custom handler to detect scroll vs tap
	card_button.gui_input.connect(_on_card_input.bind(student_data))
	
	# Add to grid
	student_grid.add_child(card_button)

func _on_card_input(event: InputEvent, student_data: Dictionary):
	# Only trigger if it was a tap, not a scroll
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed and not has_moved:
			# This was a tap, not a scroll
			_on_student_card_pressed(student_data)

func create_no_students_message():
	var message_label = Label.new()
	message_label.text = "No students found\nStudents will appear here once they register"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color.WHITE)
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.custom_minimum_size = Vector2(400, 200)
	student_grid.add_child(message_label)

func create_loading_message():
	var message_label = Label.new()
	message_label.text = "Loading students data...\nPlease wait a moment"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", Color.YELLOW)
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.custom_minimum_size = Vector2(400, 200)
	student_grid.add_child(message_label)

func _on_students_cache_updated():
	print("🔄 Students cache updated - refreshing list")
	LoadingScreen.hide_loading()
	load_students_from_cache()

func _on_student_card_pressed(student_data: Dictionary):
	print("Student card pressed: %s (ID: %s)" % [student_data.name, student_data.user_id])
	
	# Store selected student data in Global for the dashboard
	Global.selected_student_data = student_data
	
	# Change to student dashboard scene (the new main dashboard)
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")

func _on_back_button_pressed():
	print("🔙 Back button pressed - returning to dashboard")
	get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")

func _on_refresh_button_pressed():
	print("🔄 Refresh button pressed - fetching latest student data")
	LoadingScreen.show_loading()  # ← CHANGE THIS
	
	
	# Force refresh the students cache from server
	Global.refresh_students_cache()
