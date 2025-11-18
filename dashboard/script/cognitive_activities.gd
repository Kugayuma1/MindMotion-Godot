extends Control

# Node references
@onready var student_name_label = $Activities
@onready var back_button = $BackButton  
@onready var scroll_container = $ScrollContainer
@onready var activities_grid = $ScrollContainer/ActivitiesGrid

# Button textures
var activity_button_normal = preload("res://assets/student_card_bg.png")
var activity_button_pressed = preload("res://assets/student_card_pressed.png")
var custom_font = preload("res://font/Summary Notes.ttf")
var custom_font1 = preload("res://font/LilitaOne-Regular.ttf")

var current_student_data: Dictionary = {}
var cognitive_data: Dictionary = {}
var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
			   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

const LETTER_CATEGORY_ORDER = ["Reading", "Fine Motor", "Math", "Arts"]
const LETTER_STAGE_CATEGORY_MAP = {
	"reading": "Reading",
	"letters": "Reading",
	"phonics": "Reading",
	"story": "Reading",
	
	"fine_motor": "Fine Motor",
	"fine-motor": "Fine Motor",
	"motor": "Fine Motor",
	"tracing": "Fine Motor",
	"drawing": "Fine Motor",
	
	"math": "Math",
	"counting": "Math",
	"numbers": "Math",
	
	"art": "Arts",
	"arts": "Arts",
	"craft": "Arts",
	"coloring": "Arts",
	"painting": "Arts"
}

var detail_window: AcceptDialog
var detail_content: VBoxContainer
var detail_theme = preload("res://assets/main_theme.tres")

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
	
	# Two columns - calculate width based on viewport with gap
	var gap = 20  # Gap between columns
	var margin = 40  # Total horizontal margin (20 on each side)
	var button_width = (viewport_width - margin - gap) / 2.0
	
	# Clamp between reasonable values
	return clamp(button_width, 250, 550)

func _ready():
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	# Setup UI helpers
	setup_detail_window()
	
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
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll_container.follow_focus = false
		
		# Enable input processing
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Set GridContainer to 2 columns
	if activities_grid:
		activities_grid.columns = 2
		activities_grid.add_theme_constant_override("h_separation", 20)
		activities_grid.add_theme_constant_override("v_separation", 20)

func setup_detail_window():
	if detail_window:
		return
	
	detail_window = AcceptDialog.new()
	detail_window.title = "Letter Details"
	detail_window.visible = false
	detail_window.min_size = Vector2i(640, 520)
	detail_window.exclusive = true
	detail_window.dialog_hide_on_ok = true
	detail_window.ok_button_text = "Close"
	if detail_theme:
		detail_window.theme = detail_theme
	detail_window.close_requested.connect(func(): detail_window.hide())
	add_child(detail_window)
	
	var content_root = VBoxContainer.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_theme_constant_override("separation", 0)
	content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_window.add_child(content_root)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_root.add_child(margin)
	
	var scroll = ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(scroll)
	
	detail_content = VBoxContainer.new()
	detail_content.add_theme_constant_override("separation", 18)
	detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_content)

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
			var content_vbox = activity_button.get_child(0)
			var rating_label = content_vbox.get_child(2)  # Changed from 1 to 2 - this is the rating label
			
			var rating_text = get_letter_rating(letter)
			rating_label.text = "Avg. Rating: " + rating_text
			var rating_color = get_rating_color(rating_text)
			rating_label.add_theme_color_override("font_color", rating_color)
		
		button_index += 1

func create_letter_button(letter: String):
	# Main button container with responsive width
	var button_container = Control.new()
	var button_width = get_responsive_button_width()
	button_container.custom_minimum_size = Vector2(button_width, 180)
	
	# Activity button
	var activity_button = TextureButton.new()
	activity_button.texture_normal = activity_button_normal
	activity_button.texture_pressed = activity_button_pressed
	activity_button.stretch_mode = TextureButton.STRETCH_SCALE
	activity_button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Important: Stop mouse filter but allow press events
	activity_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	button_container.add_child(activity_button)
	
	# Button content container - VBoxContainer for vertical layout
	var content_vbox = VBoxContainer.new()
	content_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_vbox.add_theme_constant_override("separation", 15)
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	activity_button.add_child(content_vbox)
	
	# Add top margin
	var margin_top = Control.new()
	margin_top.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(margin_top)
	
	# Letter label - centered and larger
	var letter_label = Label.new()
	letter_label.text = letter
	letter_label.add_theme_color_override("font_color", Color("#3f4553"))
	letter_label.add_theme_font_size_override("font_size", 55)
	letter_label.add_theme_font_override("font", custom_font1)
	letter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(letter_label)
	
	# Rating label - centered below letter
	var rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rating_label.add_theme_font_size_override("font_size", 30)
	rating_label.add_theme_font_override("font", custom_font1)
	rating_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var rating_text = get_letter_rating(letter)
	rating_label.text = "Avg. Rating: " + rating_text
	
	var rating_color = get_rating_color(rating_text)
	rating_label.add_theme_color_override("font_color", rating_color)
	
	content_vbox.add_child(rating_label)
	
	# Add bottom margin
	var margin_bottom = Control.new()
	margin_bottom.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(margin_bottom)
	
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
			return Color("#007FFF")
		"Average":
			return Color("#D4D411")
		"Low":
			return Color.ORANGE
		"Very Low":
			return Color.RED
		"N/A":
			return Color.LIGHT_GRAY
		_:
			return Color.GRAY

func show_letter_details(letter: String):
	if detail_window == null or detail_content == null:
		setup_detail_window()
	
	for child in detail_content.get_children():
		child.queue_free()
	
	if not cognitive_data.has(letter):
		var no_data = create_detail_label("No data available for letter %s yet." % letter, 26, Color(0.6, 0.6, 0.6, 1), custom_font)
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_content.add_child(no_data)
		detail_window.popup_centered(detail_window.min_size + Vector2i(40, 40))
		return
	
	var letter_data = cognitive_data[letter]
	
	var title_label = create_detail_label("Letter %s" % letter, 48, Color("#3f4553"), custom_font1)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_content.add_child(title_label)
	
	var rating_text = get_letter_rating(letter)
	var rating_label = create_detail_label("Average Rating: %s" % rating_text, 30, get_rating_color(rating_text), custom_font)
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_content.add_child(rating_label)
	
	add_category_section(letter_data)
	add_activity_section(letter_data)
	
	detail_window.popup_centered(detail_window.min_size + Vector2i(60, 80))

func add_category_section(letter_data: Dictionary):
	var section_title = create_detail_label("Best Time by Category", 34, Color("#3f4553"), custom_font1)
	detail_content.add_child(section_title)
	
	var category_stats = get_letter_category_stats(letter_data)
	var any_data = false
	
	for category in LETTER_CATEGORY_ORDER:
		var data = category_stats.get(category, {"best_time": 0.0})
		var best_time = data.get("best_time", 0.0)
		if best_time <= 0.0:
			continue
		
		any_data = true
		var value_text = "%s : %s" % [category, format_time_seconds(best_time)]
		var value_label = create_detail_label(value_text, 28, Color(0.25, 0.27, 0.33, 1), custom_font)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		detail_content.add_child(value_label)
	
	if not any_data:
		var no_data = create_detail_label("No completed categories yet.", 26, Color(0.6, 0.6, 0.6, 1), custom_font)
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_content.add_child(no_data)

func add_activity_section(letter_data: Dictionary):
	var section_title = create_detail_label("Recent Activities", 34, Color("#3f4553"), custom_font1)
	detail_content.add_child(section_title)
	
	var entries = build_activity_entries(letter_data)
	if entries.is_empty():
		var no_data = create_detail_label("No activities played yet.", 26, Color(0.6, 0.6, 0.6, 1), custom_font)
		no_data.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_content.add_child(no_data)
		return
	
	entries.sort_custom(func(a, b):
		return a.get("last_played_raw", "") > b.get("last_played_raw", "")
	)
	
	var max_entries = min(entries.size(), 8)
	for i in range(max_entries):
		var entry = entries[i]
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 1)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		panel.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_bottom", 12)
		panel.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		margin.add_child(vbox)
		
		var name_text = entry.get("name", "Activity")
		var category_name = entry.get("category")
		if category_name != "":
			name_text = "%s" % [category_name]
		var name_label = create_detail_label(name_text, 30, Color("#3f4553"), custom_font1)
		vbox.add_child(name_label)
		
		var best_time = entry.get("best_time", 0.0)
		var last_time = entry.get("last_time", 0.0)
		var summary_parts = []
		if best_time > 0.0:
			summary_parts.append("Best %s" % format_time_seconds(best_time))
		if last_time > 0.0 and last_time != best_time:
			summary_parts.append("Recent %s" % format_time_seconds(last_time))
		if summary_parts.is_empty():
			summary_parts.append("No timing data yet")
		var summary_label = create_detail_label("  :  ".join(summary_parts), 24, Color(0.1, 0.45, 0.6, 1), custom_font)
		vbox.add_child(summary_label)
		
		var last_played = entry.get("last_played", "")
		var last_played_text = last_played if last_played != "" else "Not played yet"
		var played_label = create_detail_label("Last played %s" % last_played_text, 24, Color(0.25, 0.27, 0.33, 1), custom_font)
		vbox.add_child(played_label)
		
		detail_content.add_child(panel)

func create_detail_label(text: String, font_size: int, color: Color, font_resource: Font) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font_resource)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func get_letter_category_stats(letter_data: Dictionary) -> Dictionary:
	var result = {}
	for category in LETTER_CATEGORY_ORDER:
		result[category] = {"best_time": 0.0}
	
	if not letter_data.has("levels"):
		return result
	
	for level_data in letter_data["levels"]:
		if typeof(level_data) != TYPE_DICTIONARY:
			continue
		
		var category = resolve_level_category(level_data)
		if category == "":
			continue
		
		var best_time = extract_time_seconds(level_data, ["bestTime", "lastAttemptTime", "averageTime"])
		if best_time <= 0.0:
			continue
		
		if result[category]["best_time"] == 0.0 or best_time < result[category]["best_time"]:
			result[category]["best_time"] = best_time
	
	return result

func resolve_level_category(level_data: Dictionary) -> String:
	var candidates = []
	
	if level_data.has("stage"):
		candidates.append(str(level_data["stage"]).to_lower())
	if level_data.has("level_id"):
		candidates.append(str(level_data["level_id"]).to_lower())
	if level_data.has("name"):
		candidates.append(str(level_data["name"]).to_lower())
	
	for candidate in candidates:
		for key in LETTER_STAGE_CATEGORY_MAP.keys():
			if candidate == key or candidate.contains(key):
				return LETTER_STAGE_CATEGORY_MAP[key]
	
	return ""

func build_activity_entries(letter_data: Dictionary) -> Array:
	var entries: Array = []
	if not letter_data.has("levels"):
		return entries
	
	for level_data in letter_data["levels"]:
		if typeof(level_data) != TYPE_DICTIONARY:
			continue
		
		var raw_last_played = str(level_data.get("lastPlayedAt", ""))
		
		var entry = {
			"name": str(level_data.get("stage", level_data.get("level_id", "Activity"))),
			"category": resolve_level_category(level_data),
			"best_time": extract_time_seconds(level_data, ["bestTime", "averageTime"]),
			"last_time": extract_time_seconds(level_data, ["lastAttemptTime"]),
			"last_played": format_last_played(raw_last_played),
			"last_played_raw": raw_last_played
		}
		
		entries.append(entry)
	
	return entries

func extract_time_seconds(data: Dictionary, keys: Array) -> float:
	for key in keys:
		if data.has(key):
			var value = data[key]
			if typeof(value) in [TYPE_INT, TYPE_FLOAT] and value > 0:
				return float(value) / 1000.0
	return 0.0

func format_time_seconds(value: float) -> String:
	return "%.1fs" % value

func format_last_played(raw_value: String) -> String:
	if raw_value == "":
		return ""
	if raw_value.find("T") != -1:
		var parts = raw_value.split("T")
		if parts.size() >= 2:
			var date_part = parts[0]
			var time_part = parts[1].substr(0, 5)
			return "%s at %s" % [date_part, time_part]
	return raw_value

func _on_activity_button_pressed(letter: String):
	print("Letter %s pressed for student: %s" % [letter, current_student_data.name])
	Global.current_letter = letter
	show_letter_details(letter)

func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
