extends Control

# Node references
@onready var student_name_label = $Activities
@onready var back_button = $BackButton
@onready var activities_grid = $ScrollContainer/VoiceGrid

# Button textures
var date_button_normal = preload("res://assets/student_card_bg.png")
var date_button_pressed = preload("res://assets/student_card_pressed.png")
var word_button_normal = preload("res://assets/student_card_bg.png")

# Loading animation variables
var loading_label: Label
var loading_timer: Timer
var dot_count: int = 0

var current_student_data: Dictionary = {}
var voice_data: Dictionary = {}
var expanded_dates: Dictionary = {}  # Track which dates are expanded

func _ready():
	# Get student data
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup UI
	student_name_label.text = "%s - Voice Activities" % current_student_data.get("name", "Unknown")
	
	# Setup grid
	activities_grid.add_theme_constant_override("separation", 10)
	
	create_loading_animation()
	
	# Connect signals
	back_button.pressed.connect(_on_back_button_pressed)
	StudentData.voice_data_loaded.connect(_on_voice_data_loaded)
	
	# Check if data is already loaded from dashboard preload
	if StudentData.get_current_student_voice_data().size() > 0:
		print("DEBUG: Using preloaded voice data")
		voice_data = StudentData.get_current_student_voice_data()
		create_voice_sections()
	else:
		print("DEBUG: No preloaded voice data, loading...")
		await get_tree().create_timer(0.5).timeout
		if StudentData.get_current_student_voice_data().size() > 0:
			voice_data = StudentData.get_current_student_voice_data()
			create_voice_sections()
		else:
			StudentData.load_student_voice_data()

func _on_voice_data_loaded(data: Dictionary):
	voice_data = data
	create_voice_sections()

func create_loading_animation():
	var loading_container = Control.new()
	loading_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.name = "LoadingContainer"
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.add_child(center_container)
	
	loading_label = Label.new()
	loading_label.text = "Loading."
	loading_label.add_theme_font_size_override("font_size", 18)
	loading_label.add_theme_color_override("font_color", Color.GRAY)
	center_container.add_child(loading_label)
	
	add_child(loading_container)
	
	loading_timer = Timer.new()
	loading_timer.wait_time = 0.5
	loading_timer.timeout.connect(_on_loading_timer_timeout)
	add_child(loading_timer)
	loading_timer.start()

func _on_loading_timer_timeout():
	dot_count = (dot_count + 1) % 4
	
	match dot_count:
		0:
			loading_label.text = "Loading."
		1:
			loading_label.text = "Loading.."
		2:
			loading_label.text = "Loading..."
		3:
			loading_label.text = "Loading"

func create_voice_sections():
	# Stop loading animation
	if loading_timer:
		loading_timer.stop()
		loading_timer.queue_free()
		loading_timer = null
	
	var loading_container = get_node_or_null("LoadingContainer")
	if loading_container:
		loading_container.queue_free()
	
	# Clear existing content
	for child in activities_grid.get_children():
		child.queue_free()
	
	if voice_data.is_empty():
		create_no_data_message()
		return
	
	# Get dates and sort them (newest first)
	var dates = voice_data.keys()
	dates.sort_custom(func(a, b): return a > b)
	
	# Create sections for each date
	for date in dates:
		create_date_section(date, voice_data[date])

func create_no_data_message():
	var message_label = Label.new()
	message_label.text = "No voice data found for this student"
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 16)
	message_label.add_theme_color_override("font_color", Color.GRAY)
	activities_grid.add_child(message_label)

func create_date_section(date: String, words: Array):
	var word_count = words.size()
	
	# Date header button (collapsible)
	var date_container = Control.new()
	date_container.custom_minimum_size = Vector2(675, 60)
	
	var date_button = TextureButton.new()
	date_button.texture_normal = date_button_normal
	date_button.texture_pressed = date_button_pressed
	date_button.stretch_mode = TextureButton.STRETCH_SCALE
	date_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	date_container.add_child(date_button)
	
	# Date header content
	var header_hbox = HBoxContainer.new()
	header_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_hbox.add_theme_constant_override("separation", 10)
	header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_button.add_child(header_hbox)
	
	# Add margins
	var margin_left = Control.new()
	margin_left.custom_minimum_size = Vector2(20, 0)
	header_hbox.add_child(margin_left)
	
	# Expand/collapse icon
	var icon_label = Label.new()
	var is_expanded = expanded_dates.get(date, word_count <= 10)  # Auto-expand if few words
	icon_label.text = "▼" if is_expanded else "▶"
	icon_label.add_theme_color_override("font_color", Color("#3f4553"))
	icon_label.add_theme_font_size_override("font_size", 20)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(30, 0)
	header_hbox.add_child(icon_label)
	
	# Date label
	var date_label = Label.new()
	date_label.text = format_date(date)
	date_label.add_theme_color_override("font_color", Color("#3f4553"))
	date_label.add_theme_font_size_override("font_size", 20)
	date_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(date_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(spacer)
	
	# Word count
	var count_label = Label.new()
	count_label.text = "%d words" % word_count
	count_label.add_theme_color_override("font_color", Color.GRAY)
	count_label.add_theme_font_size_override("font_size", 16)
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_hbox.add_child(count_label)
	
	# Add margin right
	var margin_right = Control.new()
	margin_right.custom_minimum_size = Vector2(20, 0)
	header_hbox.add_child(margin_right)
	
	# Connect date button
	date_button.pressed.connect(_on_date_button_pressed.bind(date, icon_label))
	
	activities_grid.add_child(date_container)
	
	# Words container (collapsible)
	var words_container = VBoxContainer.new()
	words_container.name = "words_" + date
	words_container.add_theme_constant_override("separation", 5)
	words_container.visible = is_expanded
	expanded_dates[date] = is_expanded
	
	# Create word cards
	for word_data in words:
		create_word_card(words_container, word_data)
	
	activities_grid.add_child(words_container)

func create_word_card(parent: VBoxContainer, word_data: Dictionary):
	var word_container = Control.new()
	word_container.custom_minimum_size = Vector2(675, 50)
	
	# Create a simple background
	var word_bg = ColorRect.new()
	word_bg.color = Color(1, 1, 1, 0.1)  # Light transparent background
	word_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word_container.add_child(word_bg)
	
	# Word content
	var word_margin = MarginContainer.new()
	word_margin.add_theme_constant_override("margin_left", 40)  # Indent for hierarchy
	word_margin.add_theme_constant_override("margin_right", 20)
	word_margin.add_theme_constant_override("margin_top", 10)
	word_margin.add_theme_constant_override("margin_bottom", 10)
	word_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	word_container.add_child(word_margin)
	
	var word_hbox = HBoxContainer.new()
	word_hbox.add_theme_constant_override("separation", 15)
	word_margin.add_child(word_hbox)
	
	# Word text
	var word_label = Label.new()
	word_label.text = word_data.get("word", "Unknown")
	word_label.add_theme_color_override("font_color", Color("#3f4553"))
	word_label.add_theme_font_size_override("font_size", 18)
	word_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_hbox.add_child(word_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_hbox.add_child(spacer)
	
	# Voice ID and time
	var info_label = Label.new()
	var timestamp = word_data.get("timestamp", 0)
	var time_str = format_timestamp(timestamp)
	info_label.text = time_str
	info_label.add_theme_color_override("font_color", Color.GRAY)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	word_hbox.add_child(info_label)
	
	parent.add_child(word_container)

func _on_date_button_pressed(date: String, icon_label: Label):
	var words_container = activities_grid.get_node_or_null("words_" + date)
	if not words_container:
		return
	
	# Toggle visibility
	var is_expanded = not words_container.visible
	words_container.visible = is_expanded
	expanded_dates[date] = is_expanded
	
	# Update icon
	icon_label.text = "▼" if is_expanded else "▶"

func format_date(date_string: String) -> String:
	# Convert "2025-09-28" to "September 28, 2025"
	var parts = date_string.split("-")
	if parts.size() != 3:
		return date_string
	
	var year = parts[0]
	var month_num = int(parts[1])
	var day = int(parts[2])
	
	var months = ["", "January", "February", "March", "April", "May", "June",
				  "July", "August", "September", "October", "November", "December"]
	
	var month_name = months[month_num] if month_num <= 12 else "Unknown"
	return "%s %d, %s" % [month_name, day, year]

func format_timestamp(timestamp: int) -> String:
	# Convert timestamp to readable time
	var datetime = Time.get_datetime_dict_from_unix_time(timestamp / 1000)  # Convert from milliseconds
	return "%02d:%02d" % [datetime.hour, datetime.minute]

func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
