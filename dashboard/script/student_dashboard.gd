extends Control

# Node references
@onready var student_name_label = $HBoxContainer/StudentNameLabel
@onready var student_avatar = $HBoxContainer/StudentAvatar  
@onready var back_button = $BackButton
@onready var cognitive_activities_button = $CognitiveActivitiesButton
@onready var motion_activities_button = $MotionActivitiesButton
@onready var voice_activities_button = $VoiceActivitiesButton
@onready var performance_button = $PerformanceSummaryButton

# Preload textures
var boy_avatar = preload("res://assets/boy_avatar.png")
var girl_avatar = preload("res://assets/girl_avatar.png")

var current_student_data: Dictionary = {}

func _ready():
	# Get selected student data from Global
	current_student_data = Global.selected_student_data
	
	if current_student_data.is_empty():
		print("ERROR: No student data found!")
		go_back_to_student_list()
		return
	
	# Set up student data in StudentData singleton
	StudentData.set_current_student(current_student_data.user_id)
	
	# Preload both cognitive and motion data immediately
	StudentData.load_student_cognitive_data()
	StudentData.load_student_motion_data()
	StudentData.load_student_voice_data()
	
	# Setup UI
	setup_ui()
	
	# Connect button signals
	back_button.pressed.connect(_on_back_button_pressed)
	voice_activities_button.pressed.connect(_on_voice_activities_pressed)
	cognitive_activities_button.pressed.connect(_on_cognitive_activities_pressed)
	motion_activities_button.pressed.connect(_on_motion_activities_pressed)
	performance_button.pressed.connect(_on_performance_summary_pressed)

func setup_ui():
	# Set student name
	student_name_label.text = current_student_data.get("name", "Unknown Student")
	
	# Set default avatar based on gender
	var default_avatar = girl_avatar if current_student_data.get("gender", "Male").to_lower() == "female" else boy_avatar
	student_avatar.texture = default_avatar
	
	# Try to load custom profile picture if available
	var profile_picture_url = current_student_data.get("profilePicture", "")
	if profile_picture_url != "" and profile_picture_url != null:
		load_profile_picture(profile_picture_url, default_avatar)

func load_profile_picture(url: String, fallback_texture: Texture2D):
	print("🖼️ Loading profile picture from: %s" % url)
	
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
				# Resize image if it exceeds 300x300
				var img_size = image.get_size()
				if img_size.x > 300 or img_size.y > 300:
					# Calculate scaling to fit within 300x300 while maintaining aspect ratio
					var scale = min(300.0 / img_size.x, 300.0 / img_size.y)
					var new_width = int(img_size.x * scale)
					var new_height = int(img_size.y * scale)
					image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
					print("📐 Resized image from %dx%d to %dx%d" % [img_size.x, img_size.y, new_width, new_height])
				
				# Create texture from image
				var image_texture = ImageTexture.create_from_image(image)
				
				# Update the avatar if it's still valid
				if is_instance_valid(student_avatar):
					student_avatar.texture = image_texture
					print("✅ Profile picture loaded successfully")
			else:
				print("⚠️ Failed to load image, keeping default avatar")
		else:
			print("⚠️ Failed to download profile picture (Code: %d), keeping default avatar" % response_code)
		
		# Clean up the HTTP request
		http_request.queue_free()
	)
	
	# Start the download
	http_request.request(url)

func _on_back_button_pressed():
	go_back_to_student_list()

func _on_cognitive_activities_pressed():
	print("Opening cognitive activities for student: %s" % current_student_data.name)
	get_tree().change_scene_to_file("res://dashboard/scene/CognitiveActivities.tscn")

func _on_motion_activities_pressed():
	print("Opening motion activities for student: %s" % current_student_data.name)
	get_tree().change_scene_to_file("res://dashboard/scene/MotionActivities.tscn")

func _on_voice_activities_pressed():
	print("Opening voice activities for student: %s" % current_student_data.name)
	get_tree().change_scene_to_file("res://dashboard/scene/VoiceEntries.tscn")

func _on_performance_summary_pressed():
	print("Opening performance summary for student: %s" % current_student_data.name)
	get_tree().change_scene_to_file("res://dashboard/scene/PerformanceSummary.tscn")
	
func go_back_to_student_list():
	get_tree().change_scene_to_file("res://dashboard/scene/StudentList.tscn")
