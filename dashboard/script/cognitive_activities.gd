extends Control

# Node references
@onready var student_name_label = $Activities
@onready var back_button = $BackButton  
@onready var scroll_container = $ScrollContainer
@onready var activities_grid = $ScrollContainer/ActivitiesGrid

# Button textures
var activity_button_normal = preload("res://assets/student_card_bg.png")
var activity_button_pressed = preload("res://assets/student_card_pressed.png")

var current_student_data: Dictionary = {}
var cognitive_data: Dictionary = {}
var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
			   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

# Touch scrolling for mobile
var touch_scrolling = false
var touch_start_y = 0.0
var touch_last_y = 0.0
var scroll_velocity = 0.0
var last_touch_time = 0.0
const SCROLL_FRICTION = 0.92
const MIN_VELOCITY = 5.0
const TOUCH_THRESHOLD = 10.0  # Minimum movement to count as scroll
var has_moved = false

func get_responsive_button_width() -> float:
	var viewport_width = get_viewport().get_visible_rect().size.x
	
	# Single column - use percentage of viewport width
	var button_width = viewport_width * 0.85  # 85% of screen width
	
	# Clamp between reasonable values for landscape
	return clamp(button_width, 500, 1100)

func _ready():
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup ScrollContainer for mobile
	setup_scroll_container()
	
	# Setup UI
	student_name_label.text = "%s - Cognitive Activities" % current_student_data.get("name", "Unknown")
	
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	StudentData.cognitive_data_loaded.connect(_on_cognitive_data_loaded)
	
	# Check if data is already loaded
	if StudentData.get_current_student_cognitive_data().size() > 0:
		print("DEBUG: Using preloaded cognitive data")
		cognitive_data = StudentData.get_current_student_cognitive_data()
		create_activity_buttons()
	else:
		print("DEBUG: No preloaded data, creating buttons with N/A and loading data")
		create_activity_buttons()
		StudentData.load_student_cognitive_data()

func setup_scroll_container():
	if scroll_container:
		# ScrollContainer settings for Godot 4.4
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.follow_focus = false
		
		# Enable input processing
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Set GridContainer to 1 column
	if activities_grid:
		activities_grid.columns = 1

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

func _on_cognitive_data_loaded(data: Dictionary):
	cognitive_data = data
	print("DEBUG: Cognitive data loaded in scene: %s" % var_to_str(cognitive_data))
	update_button_ratings()

func create_activity_buttons():
	# Clear existing buttons
	for child in activities_grid.get_children():
		child.queue_free()
	
	# Create buttons for each letter
	for letter in letters:
		create_letter_button(letter)
	
	# Force layout update
	await get_tree().process_frame
	activities_grid.queue_sort()

func update_button_ratings():
	var button_index = 0
	for letter in letters:
		if button_index < activities_grid.get_child_count():
			var button_container = activities_grid.get_child(button_index)
			var activity_button = button_container.get_child(0)
			var content_hbox = activity_button.get_child(0)
			var rating_label = content_hbox.get_child(3)
			
			var rating_text = get_letter_rating(letter)
			rating_label.text = rating_text
			var rating_color = get_rating_color(rating_text)
			rating_label.add_theme_color_override("font_color", rating_color)
		
		button_index += 1

func create_letter_button(letter: String):
	# Main button container with responsive width
	var button_container = Control.new()
	var button_width = get_responsive_button_width()
	button_container.custom_minimum_size = Vector2(button_width, 80)
	
	# Activity button
	var activity_button = TextureButton.new()
	activity_button.texture_normal = activity_button_normal
	activity_button.texture_pressed = activity_button_pressed
	activity_button.stretch_mode = TextureButton.STRETCH_SCALE
	activity_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Important: Stop mouse filter but allow press events
	activity_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	button_container.add_child(activity_button)
	
	# Button content container
	var content_hbox = HBoxContainer.new()
	content_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity_button.add_child(content_hbox)
	
	# Add margins
	var margin_left = Control.new()
	margin_left.custom_minimum_size = Vector2(20, 0)
	content_hbox.add_child(margin_left)
	
	# Letter label
	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.add_theme_color_override("font_color", Color("#3f4553"))
	letter_label.add_theme_font_size_override("font_size", 36)
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.custom_minimum_size = Vector2(60, 0)
	content_hbox.add_child(letter_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(spacer)
	
	# Rating label
	var rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rating_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 18)
	rating_label.custom_minimum_size = Vector2(120, 0)
	
	var rating_text = get_letter_rating(letter)
	rating_label.text = rating_text
	
	var rating_color = get_rating_color(rating_text)
	rating_label.add_theme_color_override("font_color", rating_color)
	
	content_hbox.add_child(rating_label)
	
	# Add margin right
	var margin_right = Control.new()
	margin_right.custom_minimum_size = Vector2(20, 0)
	content_hbox.add_child(margin_right)
	
	# Connect button with custom handler to detect scroll vs tap
	activity_button.gui_input.connect(_on_button_input.bind(letter))
	
	# Add to grid
	activities_grid.add_child(button_container)

func _on_button_input(event: InputEvent, letter: String):
	# Only trigger if it was a tap, not a scroll
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed and not has_moved:
			# This was a tap, not a scroll
			_on_activity_button_pressed(letter)

func get_letter_rating(letter: String) -> String:
	if not cognitive_data.has(letter):
		return "N/A"
	
	var letter_data = cognitive_data[letter]
	var average_time = letter_data.get("averageTime", 0.0)
	
	if average_time == 0.0:
		return "N/A"
	
	return StudentData.get_cognitive_rating(average_time)

func get_rating_color(rating: String) -> Color:
	match rating:
		"Very Good":
			return Color.GREEN
		"Good":
			return Color.CYAN
		"Average":
			return Color.YELLOW
		"Low":
			return Color.ORANGE
		"Very Low":
			return Color.RED
		"N/A":
			return Color.LIGHT_GRAY
		_:
			return Color.GRAY

func _on_activity_button_pressed(letter: String):
	print("Letter %s pressed for student: %s" % [letter, current_student_data.name])
	Global.current_letter = letter
	get_tree().change_scene_to_file("res://scenes/LetterDetail.tscn")

func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
