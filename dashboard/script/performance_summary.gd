extends Control

# Node references
@onready var student_name_label = $StudentNameLabel
@onready var back_button = $BackButton
@onready var summary_scroll = $ScrollContainer/CenterContainer/SummaryContainer

# Card textures
var card_bg = preload("res://assets/student_card_bg.png")

# Loading animation
var loading_label: Label
var loading_timer: Timer
var dot_count: int = 0

var current_student_data: Dictionary = {}
var cognitive_data: Dictionary = {}
var motion_data: Dictionary = {}
var voice_data: Dictionary = {}
var all_data_loaded: int = 0  # Track how many datasets are loaded

func _ready():
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back()
		return
	
	student_name_label.text = "%s - Performance Summary" % current_student_data.get("name", "Unknown")
	
	summary_scroll.custom_minimum_size.x = 700
	summary_scroll.add_theme_constant_override("separation", 20)
	summary_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	create_loading_animation()
	
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Connect to all data signals
	StudentData.cognitive_data_loaded.connect(_on_cognitive_loaded)
	StudentData.motion_data_loaded.connect(_on_motion_loaded)
	StudentData.voice_data_loaded.connect(_on_voice_loaded)
	
	# Check if data already exists or load it
	check_and_load_data()

func check_and_load_data():
	var needs_loading = false
	
	# Check cognitive data
	if StudentData.get_current_student_cognitive_data().size() > 0:
		cognitive_data = StudentData.get_current_student_cognitive_data()
		all_data_loaded += 1
	else:
		StudentData.load_student_cognitive_data()
		needs_loading = true
	
	# Check motion data
	if StudentData.get_current_student_motion_data().size() > 0:
		motion_data = StudentData.get_current_student_motion_data()
		all_data_loaded += 1
	else:
		StudentData.load_student_motion_data()
		needs_loading = true
	
	# Check voice data
	if StudentData.get_current_student_voice_data().size() > 0:
		voice_data = StudentData.get_current_student_voice_data()
		all_data_loaded += 1
	else:
		StudentData.load_student_voice_data()
		needs_loading = true
	
	# If all data already loaded, create summary immediately
	if all_data_loaded >= 3:
		create_performance_summary()

func _on_cognitive_loaded(data: Dictionary):
	cognitive_data = data
	all_data_loaded += 1
	check_if_ready()

func _on_motion_loaded(data: Dictionary):
	motion_data = data
	all_data_loaded += 1
	check_if_ready()

func _on_voice_loaded(data: Dictionary):
	voice_data = data
	all_data_loaded += 1
	check_if_ready()

func check_if_ready():
	if all_data_loaded >= 3:
		create_performance_summary()

func create_loading_animation():
	var loading_container = Control.new()
	loading_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.name = "LoadingContainer"
	
	var center_container = CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading_container.add_child(center_container)
	
	loading_label = Label.new()
	loading_label.text = "Generating report."
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
		0: loading_label.text = "Generating report."
		1: loading_label.text = "Generating report.."
		2: loading_label.text = "Generating report..."
		3: loading_label.text = "Generating report"

func create_performance_summary():
	# Stop loading
	if loading_timer:
		loading_timer.stop()
		loading_timer.queue_free()
		loading_timer = null
	
	var loading_container = get_node_or_null("LoadingContainer")
	if loading_container:
		loading_container.queue_free()
	
	# Clear existing content
	for child in summary_scroll.get_children():
		child.queue_free()
	
	# Create summary sections
	create_overview_cards()
	create_cognitive_summary()
	create_motion_summary()
	create_voice_summary()

func create_overview_cards():
	var title = Label.new()
	title.text = "Overall Performance"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.BLACK)
	summary_scroll.add_child(title)
	
	var cards_grid = GridContainer.new()
	cards_grid.columns = 2
	cards_grid.add_theme_constant_override("h_separation", 15)
	cards_grid.add_theme_constant_override("v_separation", 15)
	summary_scroll.add_child(cards_grid)
	
	# Calculate stats
	var letters_completed = 0
	for letter in cognitive_data.keys():
		if cognitive_data[letter].get("letterCompleted", false):
			letters_completed += 1
	
	var total_motion_attempts = 0
	for activity_type in motion_data.keys():
		total_motion_attempts += motion_data[activity_type].size()
	
	var total_words = 0
	for date in voice_data.keys():
		total_words += voice_data[date].size()
	
	var avg_rating = calculate_average_rating()
	
	# Create stat cards
	create_stat_card(cards_grid, "Letters Completed", "%d / 26" % letters_completed, Color.CYAN)
	create_stat_card(cards_grid, "Avg. Cognitive Rating", avg_rating, get_rating_display_color(avg_rating))
	create_stat_card(cards_grid, "Motion Attempts", str(total_motion_attempts), Color.ORANGE)
	create_stat_card(cards_grid, "Words Detected", str(total_words), Color.GREEN)

func create_stat_card(parent: GridContainer, title_text: String, value_text: String, color: Color):
	var card = Control.new()
	card.custom_minimum_size = Vector2(320, 100)
	
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.25, 1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(bg)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)
	
	var title_label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(title_label)
	
	var value_label = Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 28)
	value_label.add_theme_color_override("font_color", color)
	vbox.add_child(value_label)
	
	parent.add_child(card)

func create_cognitive_summary():
	var section_title = Label.new()
	section_title.text = "Cognitive Activities Performance"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color("#3f4553"))
	summary_scroll.add_child(section_title)
	
	if cognitive_data.is_empty():
		var no_data = Label.new()
		no_data.text = "No cognitive data available"
		no_data.add_theme_color_override("font_color", Color.GRAY)
		summary_scroll.add_child(no_data)
		return
	
	# Rating distribution
	var ratings = {"Very Good": 0, "Good": 0, "Average": 0, "Low": 0, "Very Low": 0}
	
	for letter in cognitive_data.keys():
		var avg_time = cognitive_data[letter].get("averageTime", 0)
		if avg_time > 0:
			var rating = StudentData.get_cognitive_rating(avg_time)
			ratings[rating] += 1
	
	# Create bar chart for ratings
	for rating_name in ["Very Good", "Good", "Average", "Low", "Very Low"]:
		var count = ratings[rating_name]
		if count > 0:
			create_bar_chart_item(rating_name, count, cognitive_data.size(), get_rating_bar_color(rating_name))

func create_motion_summary():
	var section_title = Label.new()
	section_title.text = "Motion Activities Performance"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color.BLACK)
	summary_scroll.add_child(section_title)
	
	if motion_data.is_empty():
		var no_data = Label.new()
		no_data.text = "No motion data available"
		no_data.add_theme_color_override("font_color", Color.GRAY)
		summary_scroll.add_child(no_data)
		return
	
	# Show success rates for each activity type
	for activity_type in motion_data.keys():
		var success_rate = StudentData.get_motion_success_rate(activity_type)
		var attempts = StudentData.get_motion_attempt_count(activity_type)
		
		create_progress_bar_item(
			"%s (Success Rate)" % activity_type.capitalize(),
			success_rate,
			100.0,
			"%d attempts, %.1f%% success" % [attempts, success_rate],
			get_success_rate_color(success_rate)
		)

func create_voice_summary():
	var section_title = Label.new()
	section_title.text = "Voice Detection Summary"
	section_title.add_theme_font_size_override("font_size", 20)
	section_title.add_theme_color_override("font_color", Color("#3f4553"))
	summary_scroll.add_child(section_title)
	
	if voice_data.is_empty():
		var no_data = Label.new()
		no_data.text = "No voice data available"
		no_data.add_theme_color_override("font_color", Color.GRAY)
		summary_scroll.add_child(no_data)
		return
	
	# Count word frequency
	var word_frequency = {}
	for date in voice_data.keys():
		for word_data in voice_data[date]:
			var word = word_data.get("word", "")
			if word != "":
				word_frequency[word] = word_frequency.get(word, 0) + 1
	
	# Sort by frequency
	var words_array = []
	for word in word_frequency.keys():
		words_array.append({"word": word, "count": word_frequency[word]})
	
	words_array.sort_custom(func(a, b): return a.count > b.count)
	
	# Show top 5 words
	var max_count = words_array[0].count if words_array.size() > 0 else 1
	var show_count = min(5, words_array.size())
	
	for i in range(show_count):
		var word_info = words_array[i]
		create_bar_chart_item(
			word_info.word,
			word_info.count,
			max_count,
			Color.GREEN
		)

func create_bar_chart_item(label_text: String, value: float, max_value: float, bar_color: Color):
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)
	hbox.add_theme_constant_override("separation", 10)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	label.add_theme_color_override("font_color", Color.BLACK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(label)
	
	# Bar container
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(300, 30)
	hbox.add_child(bar_container)
	
	# Background
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2, 1)
	bar_bg.size = Vector2(300, 30)
	bar_container.add_child(bar_bg)
	
	# Bar fill
	var bar_width = (value / max_value) * 300 if max_value > 0 else 0
	var bar_fill = ColorRect.new()
	bar_fill.color = bar_color
	bar_fill.size = Vector2(bar_width, 30)
	bar_container.add_child(bar_fill)
	
	var spacer_small = Control.new()
	spacer_small.custom_minimum_size = Vector2(10, 0)  # Just 10 pixels gap
	hbox.add_child(spacer_small)
	
	# Value label
	var value_label = Label.new()
	value_label.text = str(int(value))
	value_label.add_theme_color_override("font_color", Color.BLACK)
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(value_label)
	
	summary_scroll.add_child(hbox)

func create_progress_bar_item(label_text: String, value: float, max_value: float, subtitle: String, bar_color: Color):
	var item = VBoxContainer.new()
	item.add_theme_constant_override("separation", 5)
	
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color("#3f4553"))
	item.add_child(label)
	
	var bar_container = Control.new()
	bar_container.custom_minimum_size = Vector2(675, 25)
	
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0.2, 0.2, 0.2, 1)
	bar_bg.size = Vector2(675, 25)
	bar_container.add_child(bar_bg)
	
	var bar_width = (value / max_value) * 675 if max_value > 0 else 0
	var bar_fill = ColorRect.new()
	bar_fill.color = bar_color
	bar_fill.size = Vector2(bar_width, 25)
	bar_container.add_child(bar_fill)
	
	item.add_child(bar_container)
	
	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_color_override("font_color", Color.GRAY)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	item.add_child(subtitle_label)
	
	summary_scroll.add_child(item)

func calculate_average_rating() -> String:
	if cognitive_data.is_empty():
		return "N/A"
	
	var total_score = 0.0
	var count = 0
	
	for letter in cognitive_data.keys():
		var avg_time = cognitive_data[letter].get("averageTime", 0)
		if avg_time > 0:
			var rating = StudentData.get_cognitive_rating(avg_time)
			var score = get_rating_score(rating)
			total_score += score
			count += 1
	
	if count == 0:
		return "N/A"
	
	var avg_score = total_score / count
	return score_to_rating(avg_score)

func get_rating_score(rating: String) -> float:
	match rating:
		"Very Good": return 5.0
		"Good": return 4.0
		"Average": return 3.0
		"Low": return 2.0
		"Very Low": return 1.0
		_: return 0.0

func score_to_rating(score: float) -> String:
	if score >= 4.5: return "Very Good"
	elif score >= 3.5: return "Good"
	elif score >= 2.5: return "Average"
	elif score >= 1.5: return "Low"
	else: return "Very Low"

func get_rating_display_color(rating: String) -> Color:
	match rating:
		"Very Good": return Color.GREEN
		"Good": return Color.CYAN
		"Average": return Color.YELLOW
		"Low": return Color.ORANGE
		"Very Low": return Color.RED
		_: return Color.GRAY

func get_rating_bar_color(rating: String) -> Color:
	return get_rating_display_color(rating)

func get_success_rate_color(rate: float) -> Color:
	if rate >= 80.0: return Color.GREEN
	elif rate >= 60.0: return Color.YELLOW
	elif rate >= 40.0: return Color.ORANGE
	else: return Color.RED

func _on_back_button_pressed():
	go_back()

func go_back():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")
