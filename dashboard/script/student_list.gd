extends Control

# Node references
@onready var scroll_container = $MainContainer/ScrollContainer
@onready var student_grid = $MainContainer/ScrollContainer/StudentGrid
@onready var back_button = $BackButton
@onready var refresh_button = $RefreshButton
@onready var sort_dropdown = $FilterContainer/SortDropdown

# Preload avatar textures
var boy_avatar = preload("res://assets/boy_avatar.png")
var girl_avatar = preload("res://assets/girl_avatar.png")
var student_card_bg = preload("res://assets/Container1.png")
var student_card_pressed = preload("res://assets/Container_Pressed.png")
var dialog_theme = preload("res://assets/main_theme.tres")
var custom_font = preload("res://font/LilitaOne-Regular.ttf")
var custom_font1 = preload("res://font/Summary Notes.ttf")

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

enum SortMode { 
	ALPHABETICAL_AZ,
	ALPHABETICAL_ZA,
	RATING_HIGH_TO_LOW,
	RATING_LOW_TO_HIGH
}
var current_sort_mode = SortMode.ALPHABETICAL_AZ

# Track ongoing rating requests
var pending_rating_requests = {}  # {user_id: HTTPRequest}
var profile_picture_cache = {}  # Cache downloaded profile pictures {user_id: ImageTexture}

func _ready():
	setup_scroll_container()
	setup_filter_dropdown()
	sort_dropdown.theme = dialog_theme
	
	back_button.pressed.connect(_on_back_button_pressed)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	
	Global.students_cache_updated.connect(_on_students_cache_updated)
	
	LoadingScreen.show_loading()
	load_students_from_cache()
	
	student_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	student_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func setup_scroll_container():
	if scroll_container:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		scroll_container.follow_focus = false
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	if student_grid:
		student_grid.columns = 2

func get_responsive_button_width() -> float:
	var viewport_width = get_viewport().get_visible_rect().size.x
	var h_separation = 15
	var total_padding = 40
	var available_width = viewport_width - h_separation - total_padding
	var button_width = available_width / 2.0
	return clamp(button_width, 280, 550)

func _process(delta):
	if not touch_scrolling and abs(scroll_velocity) > MIN_VELOCITY:
		scroll_container.scroll_vertical += int(scroll_velocity)
		scroll_velocity *= SCROLL_FRICTION
		
		var max_scroll = max(0, student_grid.size.y - scroll_container.size.y)
		scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func _input(event):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			touch_scrolling = true
			touch_start_y = event.position.y
			touch_last_y = event.position.y
			scroll_velocity = 0.0
			last_touch_time = Time.get_ticks_msec() / 1000.0
			has_moved = false
		else:
			touch_scrolling = false
			var current_time = Time.get_ticks_msec() / 1000.0
			var time_delta = current_time - last_touch_time
			if time_delta > 0 and has_moved:
				scroll_velocity = (touch_last_y - event.position.y) / time_delta * 2.0
				scroll_velocity = clamp(scroll_velocity, -3000, 3000)
	
	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT):
		if touch_scrolling:
			var delta_y = touch_last_y - event.position.y
			if abs(event.position.y - touch_start_y) > TOUCH_THRESHOLD:
				has_moved = true
			
			if has_moved:
				scroll_container.scroll_vertical += int(delta_y)
				touch_last_y = event.position.y
				last_touch_time = Time.get_ticks_msec() / 1000.0
				var max_scroll = max(0, student_grid.size.y - scroll_container.size.y)
				scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func load_students_from_cache():
	print("📋 Loading students from Global cache...")
	cancel_all_rating_requests()
	clear_student_grid()
	
	if not Global.is_students_cache_ready():
		print("DEBUG: Cache not ready")
		create_loading_message()
		return
	
	var students_data = Global.get_students_cache()
	
	if students_data.size() == 0:
		print("DEBUG: No students found")
		create_no_students_message()
		LoadingScreen.hide_loading()
		return
	
	print("👥 Found %d students in cache" % students_data.size())
	display_sorted_students(students_data)

func display_sorted_students(students_data: Array):
	var sorted_students = sort_students(students_data)
	
	# For rating-based sorts, we need to load all ratings first
	if current_sort_mode == SortMode.RATING_HIGH_TO_LOW or current_sort_mode == SortMode.RATING_LOW_TO_HIGH:
		load_all_ratings_then_display(sorted_students)
	else:
		# For alphabetical, display immediately and load ratings in background
		for student_data in sorted_students:
			create_student_card(student_data)
		LoadingScreen.hide_loading()

func sort_students(students: Array) -> Array:
	var sorted = students.duplicate()
	
	match current_sort_mode:
		SortMode.ALPHABETICAL_AZ:
			sorted.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
		
		SortMode.ALPHABETICAL_ZA:
			sorted.sort_custom(func(a, b): return a.name.to_lower() > b.name.to_lower())
		
		SortMode.RATING_HIGH_TO_LOW:
			sorted.sort_custom(func(a, b):
				var a_rating = StudentData.get_student_rating(a.user_id)
				var b_rating = StudentData.get_student_rating(b.user_id)
				if a_rating.score == b_rating.score:
					return a.name.to_lower() < b.name.to_lower()
				return a_rating.score > b_rating.score
			)
		
		SortMode.RATING_LOW_TO_HIGH:
			sorted.sort_custom(func(a, b):
				var a_rating = StudentData.get_student_rating(a.user_id)
				var b_rating = StudentData.get_student_rating(b.user_id)
				if a_rating.score == b_rating.score:
					return a.name.to_lower() < b.name.to_lower()
				return a_rating.score < b_rating.score
			)
	
	return sorted

func load_all_ratings_then_display(students: Array):
	print("📊 Loading all ratings before display...")
	var total_students = students.size()
	var loaded_count = 0
	
	for student in students:
		# Check if we already have this rating cached
		var cached = StudentData.get_student_rating(student.user_id)
		if cached.rating != "Loading...":
			loaded_count += 1
			if loaded_count == total_students:
				finalize_rating_sort(students)
			continue
		
		# Need to load this rating
		load_student_rating(student.user_id, func():
			loaded_count += 1
			print("⏳ Loaded %d/%d ratings" % [loaded_count, total_students])
			
			if loaded_count == total_students:
				finalize_rating_sort(students)
		)

func finalize_rating_sort(students: Array):
	print("✅ All ratings loaded, sorting and displaying...")
	
	# Sort again now that we have all ratings
	var sorted = sort_students(students)
	
	# Display cards
	for student_data in sorted:
		create_student_card(student_data)
	
	LoadingScreen.hide_loading()

func create_student_card(student_data: Dictionary):
	var card_button = TextureButton.new()
	card_button.texture_normal = student_card_bg
	card_button.texture_pressed = student_card_pressed
	var button_width = get_responsive_button_width()
	card_button.custom_minimum_size = Vector2(button_width, 280)
	card_button.stretch_mode = TextureButton.STRETCH_SCALE
	card_button.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var card_margin = MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 20)
	card_margin.add_theme_constant_override("margin_right", 20)
	card_margin.add_theme_constant_override("margin_top", 20)
	card_margin.add_theme_constant_override("margin_bottom", 20)
	card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_button.add_child(card_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 40)
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_margin.add_child(main_vbox)
	
	var card_hbox = HBoxContainer.new()
	card_hbox.add_theme_constant_override("separation", 1)
	card_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(card_hbox)
	
	# Profile picture with smart loading
	var profile_pic = TextureRect.new()
	profile_pic.custom_minimum_size = Vector2(150, 150)
	profile_pic.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	profile_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Set initial default based on gender
	var default_avatar = girl_avatar if student_data.gender.to_lower() == "female" else boy_avatar
	profile_pic.texture = default_avatar
	
	# Load custom profile picture if available
	var profile_picture_url = student_data.get("profilePicture", "")
	if profile_picture_url != "" and profile_picture_url != null:
		load_profile_picture(student_data.user_id, profile_picture_url, profile_pic, default_avatar)
	
	profile_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_child(profile_pic)
	
	# ... rest of your existing card creation code stays the same ...
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 8)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = student_data.name
	name_label.add_theme_color_override("font_color", Color("#3f4553"))
	name_label.add_theme_font_size_override("font_size", 35)
	name_label.add_theme_font_override("font", custom_font)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(name_label)
	
	var email_label = Label.new()
	email_label.text = student_data.email
	email_label.add_theme_color_override("font_color", Color("#3f4553"))
	email_label.add_theme_font_size_override("font_size", 25)
	email_label.add_theme_font_override("font", custom_font1)
	email_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(email_label)
	
	var age_label = Label.new()
	age_label.text = "Age: %d" % student_data.age if student_data.age > 0 else "Age: Not specified"
	age_label.add_theme_color_override("font_color", Color("#3f4553"))
	age_label.add_theme_font_size_override("font_size", 27)
	age_label.add_theme_font_override("font", custom_font1)
	age_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(age_label)
	
	var rating_container = CenterContainer.new()
	rating_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(rating_container)
	
	var rating_label = Label.new()
	rating_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rating_label.custom_minimum_size = Vector2(button_width - 40, 0)
	rating_label.add_theme_font_override("font", custom_font)
	var rating_data = StudentData.get_student_rating(student_data.user_id)
	
	if rating_data.rating == "Loading...":
		rating_label.text = "Loading rating..."
		rating_label.add_theme_color_override("font_color", Color.GRAY)
		load_student_rating(student_data.user_id, func():
			if is_instance_valid(rating_label):
				var updated_rating = StudentData.get_student_rating(student_data.user_id)
				update_rating_label(rating_label, updated_rating.rating)
		)
	else:
		update_rating_label(rating_label, rating_data.rating)
	
	rating_label.add_theme_font_size_override("font_size", 40)
	rating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rating_container.add_child(rating_label)
	
	card_button.gui_input.connect(_on_card_input.bind(student_data))
	student_grid.add_child(card_button)

func update_rating_label(label: Label, rating: String):
	if rating != "N/A" and rating != "Loading...":
		label.text = "Avg. Rating: %s" % rating
	elif rating == "N/A":
		label.text = "Rating: No data"
	else:
		label.text = "Loading rating..."
	
	label.add_theme_color_override("font_color", get_rating_color(rating))

func load_student_rating(student_id: String, callback: Callable):
	# Cancel existing request for this student if any
	if pending_rating_requests.has(student_id):
		pending_rating_requests[student_id].queue_free()
		pending_rating_requests.erase(student_id)
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	pending_rating_requests[student_id] = http_request
	
	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		var rating = "N/A"
		var rating_score = 0.0
		
		if response_code == 200:
			var response = body.get_string_from_utf8()
			var json = JSON.new()
			if json.parse(response) == OK:
				rating = calculate_student_avg_rating(json.data)
				rating_score = get_rating_score(rating)
		
		# Cache the rating in StudentData
		StudentData.set_student_rating(student_id, rating, rating_score)
		
		# Clean up
		pending_rating_requests.erase(student_id)
		http_request.queue_free()
		
		# Execute callback
		if callback:
			callback.call()
	)
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress" % student_id
	Global.make_authenticated_request(http_request, url, HTTPClient.METHOD_GET)

func calculate_student_avg_rating(data: Dictionary) -> String:
	if not data.has("documents"):
		return "N/A"
	
	var total_score = 0.0
	var count = 0
	
	for doc in data.documents:
		var fields = doc.get("fields", {})
		var avg_time_field = fields.get("averageTime", {})
		
		if avg_time_field.has("integerValue"):
			var avg_time = int(avg_time_field.integerValue)
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

func get_rating_color(rating: String) -> Color:
	match rating:
		"Very Good": return Color.GREEN
		"Good": return Color("#007FFF")
		"Average": return Color("#D4D411")
		"Low": return Color.ORANGE
		"Very Low": return Color.RED
		_: return Color.GRAY

func cancel_all_rating_requests():
	for request in pending_rating_requests.values():
		if is_instance_valid(request):
			request.queue_free()
	pending_rating_requests.clear()

func clear_student_grid():
	for child in student_grid.get_children():
		child.queue_free()

func _on_card_input(event: InputEvent, student_data: Dictionary):
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.pressed and not has_moved:
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
	Global.selected_student_data = student_data
	get_tree().change_scene_to_file("res://dashboard/scene/StudentDashboard.tscn")

func setup_filter_dropdown():
	if not sort_dropdown:
		return
	
	sort_dropdown.clear()
	sort_dropdown.add_item("Name (A-Z)", SortMode.ALPHABETICAL_AZ)
	sort_dropdown.add_item("Name (Z-A)", SortMode.ALPHABETICAL_ZA)
	sort_dropdown.add_item("Rating (High to Low)", SortMode.RATING_HIGH_TO_LOW)
	sort_dropdown.add_item("Rating (Low to High)", SortMode.RATING_LOW_TO_HIGH)
	sort_dropdown.selected = current_sort_mode
	sort_dropdown.item_selected.connect(_on_sort_option_selected)

func _on_sort_option_selected(index: int):
	current_sort_mode = index
	print("🔄 Sort mode changed to: %d" % index)
	LoadingScreen.show_loading()
	load_students_from_cache()

func load_profile_picture(user_id: String, url: String, texture_rect: TextureRect, fallback_texture: Texture2D):
	# Check cache first
	if profile_picture_cache.has(user_id):
		print("📦 Using cached profile picture for: %s" % user_id)
		texture_rect.texture = profile_picture_cache[user_id]
		return
	
	print("🖼️ Loading profile picture for user: %s" % user_id)
	
	# Create HTTP request to download the image
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		if response_code == 200 and body.size() > 0:
			# Load image from downloaded bytes
			var image = Image.new()
			var error = image.load_png_from_buffer(body)
			
			# If PNG fails, try JPEG
			if error != OK:
				error = image.load_jpg_from_buffer(body)
			
			if error == OK:
				# Create texture from image
				var image_texture = ImageTexture.create_from_image(image)
				
				# Cache it
				profile_picture_cache[user_id] = image_texture
				
				# Update the TextureRect if it's still valid
				if is_instance_valid(texture_rect):
					texture_rect.texture = image_texture
					print("✅ Profile picture loaded successfully for: %s" % user_id)
			else:
				print("⚠️ Failed to load image for user %s, keeping default" % user_id)
		else:
			print("⚠️ Failed to download profile picture (Code: %d), keeping default for: %s" % [response_code, user_id])
		
		# Clean up the HTTP request
		http_request.queue_free()
	)
	
	# Start the download
	http_request.request(url)

func _on_back_button_pressed():
	print("🔙 Back button pressed - returning to dashboard")
	cancel_all_rating_requests()
	get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")

func _on_refresh_button_pressed():
	print("🔄 Refresh button pressed - fetching latest student data")
	LoadingScreen.show_loading()
	Global.refresh_students_cache()
