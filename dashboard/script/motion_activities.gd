extends Control

# Node references
@onready var student_name_label = $Activities
@onready var back_button = $BackButton
@onready var activities_grid = $ScrollContainer/ActivitiesGrid

# Button textures
var motion_button_normal = preload("res://assets/student_card_bg.png")
var motion_button_pressed = preload("res://assets/student_card_pressed.png")
var buttons_created: bool = false
var loading_label: Label
var loading_timer: Timer
var dot_count: int = 0

var current_student_data: Dictionary = {}
var motion_data: Dictionary = {}

func _ready():
	# Get student data
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup UI
	student_name_label.text = "%s - Motion Activities" % current_student_data.get("name", "Unknown")
	
	activities_grid.columns = 1
	activities_grid.add_theme_constant_override("v_separation", 75)
	
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
	var motion_types = ["clapping", "wave"]
	
	for motion_type in motion_types:
		create_motion_button(motion_type)

func create_motion_button(motion_type: String):
	# Main button container
	var button_container = Control.new()
	button_container.custom_minimum_size = Vector2(675, 100)
	
	# Motion button
	var motion_button = TextureButton.new()
	motion_button.texture_normal = motion_button_normal
	motion_button.texture_pressed = motion_button_pressed
	motion_button.stretch_mode = TextureButton.STRETCH_SCALE
	motion_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_container.add_child(motion_button)
	
	# Button content container
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 15)
	content_margin.add_theme_constant_override("margin_bottom", 15)
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion_button.add_child(content_margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 8)
	content_margin.add_child(content_vbox)
	
	# Activity name
	var name_label = Label.new()
	name_label.text = motion_type.capitalize()
	name_label.add_theme_color_override("font_color", Color("#3f4553"))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	content_vbox.add_child(name_label)
	
	# Stats container
	var stats_hbox = HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 30)
	content_vbox.add_child(stats_hbox)
	
	# Attempts count
	var attempts_label = Label.new()
	var attempt_count = StudentData.get_motion_attempt_count(motion_type)
	attempts_label.text = "Attempts: %d" % attempt_count
	attempts_label.add_theme_color_override("font_color", Color.CYAN)
	attempts_label.add_theme_font_size_override("font_size", 16)
	stats_hbox.add_child(attempts_label)
	
	# Success rate
	var success_label = Label.new()
	var success_rate = StudentData.get_motion_success_rate(motion_type)
	success_label.text = "Success Rate: %.1f%%" % success_rate
	success_label.add_theme_font_size_override("font_size", 16)
	
	# Color code success rate
	var success_color = get_success_rate_color(success_rate)
	success_label.add_theme_color_override("font_color", success_color)
	
	stats_hbox.add_child(success_label)
	
	# Add to grid
	activities_grid.add_child(button_container)

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
