extends Control

# Node references
@onready var student_grid = $MainContainer/ScrollContainer/StudentGrid
@onready var back_button = $BackButton
@onready var refresh_button = $RefreshButton

# Loading overlay references
var loading_overlay: Control = null
var loading_label: Label = null

# Preload avatar textures
var boy_avatar = preload("res://assets/boy_avatar.png")
var girl_avatar = preload("res://assets/girl_avatar.png")
var student_card_bg = preload("res://assets/student_card_bg.png")
var student_card_pressed = preload("res://assets/student_card_pressed.png")

func _ready():
	# Connect back button
	back_button.pressed.connect(_on_back_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	# Connect to Global's students cache signal
	Global.students_cache_updated.connect(_on_students_cache_updated)
	
	# Load students immediately from cache
	load_students_from_cache()
	
	student_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	student_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER

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
		return
	
	print("👥 Found %d students in cache" % students_data.size())
	
	# Create student cards immediately - no waiting!
	for i in range(students_data.size()):
		var student_data = students_data[i]
		print("DEBUG: Creating card for student %d: %s" % [i, student_data.get("name", "Unknown")])
		create_student_card(student_data)
	
	print("DEBUG: Finished creating all student cards")

func create_student_card(student_data: Dictionary):
	# Main card button
	var card_button = TextureButton.new()
	card_button.texture_normal = student_card_bg
	card_button.texture_pressed = student_card_pressed
	card_button.custom_minimum_size = Vector2(600, 175)
	
	card_button.stretch_mode = TextureButton.STRETCH_SCALE
	
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
	
	# Connect button press signal
	card_button.pressed.connect(_on_student_card_pressed.bind(student_data))
	
	# Add to grid
	student_grid.add_child(card_button)

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

func show_refresh_loading():
	if loading_overlay != null:
		return  # Already showing
	
	# Create semi-transparent overlay
	loading_overlay = ColorRect.new()
	loading_overlay.color = Color(0, 0, 0, 0.7)
	loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_overlay.z_index = 100
	add_child(loading_overlay)
	
	# Create loading label
	loading_label = Label.new()
	loading_label.text = "Refreshing students data..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	loading_label.add_theme_color_override("font_color", Color.WHITE)
	loading_label.add_theme_font_size_override("font_size", 18)
	loading_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading_overlay.add_child(loading_label)
	
	# Disable refresh button during loading
	refresh_button.disabled = true

func hide_refresh_loading():
	if loading_overlay != null:
		loading_overlay.queue_free()
		loading_overlay = null
		loading_label = null
	
	# Re-enable refresh button
	refresh_button.disabled = false

func _on_students_cache_updated():
	print("🔄 Students cache updated - refreshing list")
	hide_refresh_loading()
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
	show_refresh_loading()
	
	# Force refresh the students cache from server
	Global.refresh_students_cache()
	
