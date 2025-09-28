extends Control

# Node references - update these paths to match your actual scene structure
@onready var student_name_label = $Activities
@onready var back_button = $BackButton  
@onready var activities_grid = $ScrollContainer/ActivitiesGrid  # Check this path

# Button textures
var activity_button_normal = preload("res://assets/student_card_bg.png")
var activity_button_pressed = preload("res://assets/student_card_pressed.png")


var current_student_data: Dictionary = {}
var cognitive_data: Dictionary = {}
var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
			   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

func _ready():
	# Get student data
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup UI
	student_name_label.text = "%s - Cognitive Activities" % current_student_data.get("name", "Unknown")
	
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	StudentData.cognitive_data_loaded.connect(_on_cognitive_data_loaded)
	
	# Check if data is already loaded from dashboard preload
	if StudentData.get_current_student_cognitive_data().size() > 0:
		print("DEBUG: Using preloaded cognitive data")
		cognitive_data = StudentData.get_current_student_cognitive_data()
		create_activity_buttons()
	else:
		print("DEBUG: No preloaded data, creating buttons with N/A and loading data")
		# Create buttons first (they will show N/A initially)
		create_activity_buttons()
		# Then load data and update buttons when ready
		StudentData.load_student_cognitive_data()

func _on_cognitive_data_loaded(data: Dictionary):
	cognitive_data = data
	print("DEBUG: Cognitive data loaded in scene: %s" % var_to_str(cognitive_data))
	# Update existing buttons with new data
	update_button_ratings()

func create_activity_buttons():
	# Clear existing buttons
	for child in activities_grid.get_children():
		child.queue_free()
	
	# Create buttons for each letter
	for letter in letters:
		create_letter_button(letter)

func update_button_ratings():
	# Update ratings for existing buttons
	var button_index = 0
	for letter in letters:
		if button_index < activities_grid.get_child_count():
			var button_container = activities_grid.get_child(button_index)
			var activity_button = button_container.get_child(0)  # TextureButton
			var content_hbox = activity_button.get_child(0)     # HBoxContainer
			var rating_label = content_hbox.get_child(3)        # Rating label (4th child)
			
			# Update rating text and color
			var rating_text = get_letter_rating(letter)
			rating_label.text = rating_text
			var rating_color = get_rating_color(rating_text)
			rating_label.add_theme_color_override("font_color", rating_color)
		
		button_index += 1

func create_letter_button(letter: String):
	# Main button container - full width for single column
	var button_container = Control.new()
	button_container.custom_minimum_size = Vector2(675, 80)
	
	# Activity button
	var activity_button = TextureButton.new()
	activity_button.texture_normal = activity_button_normal
	activity_button.texture_pressed = activity_button_pressed
	activity_button.stretch_mode = TextureButton.STRETCH_SCALE
	activity_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	
	# Letter label - bigger for single column
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
	
	# Rating label - bigger and better positioned
	var rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rating_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 18)
	rating_label.custom_minimum_size = Vector2(120, 0)
	
	# Get rating for this letter
	var rating_text = get_letter_rating(letter)
	rating_label.text = rating_text
	
	# Color code the rating
	var rating_color = get_rating_color(rating_text)
	rating_label.add_theme_color_override("font_color", rating_color)
	
	content_hbox.add_child(rating_label)
	
	# Add margin right
	var margin_right = Control.new()
	margin_right.custom_minimum_size = Vector2(20, 0)
	content_hbox.add_child(margin_right)
	
	# Connect button signal
	activity_button.pressed.connect(_on_activity_button_pressed.bind(letter))
	
	# Add to grid
	activities_grid.add_child(button_container)

func get_letter_rating(letter: String) -> String:
	# Check if we have data for this letter
	if not cognitive_data.has(letter):
		return "N/A"
	
	var letter_data = cognitive_data[letter]
	var average_time = letter_data.get("averageTime", 0.0)
	
	# If averageTime is 0 or missing, show N/A
	if average_time == 0.0:
		return "N/A"
	
	# Return the rating based on time
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
	
	# Store the selected letter for the detail view
	Global.current_letter = letter
	
	# Navigate to letter detail scene
	get_tree().change_scene_to_file("res://scenes/LetterDetail.tscn")

func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
