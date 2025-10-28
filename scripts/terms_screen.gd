extends Control

@onready var scroll_container = $TextureRect/ScrollContainer
@onready var terms_text = $TextureRect/ScrollContainer/TermsText
@onready var agree_checkbox = $TextureRect/AgreeCheckBox
@onready var back_button = $TextureRect/BackButton

# Touch scrolling variables for mobile
var touch_scrolling = false
var touch_start_y = 0.0
var touch_last_y = 0.0
var scroll_velocity = 0.0
var last_touch_time = 0.0
const SCROLL_FRICTION = 0.92
const MIN_VELOCITY = 5.0
const TOUCH_THRESHOLD = 10.0  # Minimum movement to count as scroll
var has_moved = false

func _ready():
	setup_scroll_container()
	load_terms_text()
	# Connect signals if they exist and aren't already connected
	if agree_checkbox and not agree_checkbox.toggled.is_connected(_on_agree_toggled):
		agree_checkbox.toggled.connect(_on_agree_toggled)

func setup_scroll_container():
	if scroll_container:
		# ScrollContainer settings for Godot 4.4
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll_container.follow_focus = false
		
		# Enable input processing
		scroll_container.mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta):
	# Apply scroll momentum/inertia
	if not touch_scrolling and abs(scroll_velocity) > MIN_VELOCITY:
		scroll_container.scroll_vertical += int(scroll_velocity)
		scroll_velocity *= SCROLL_FRICTION
		
		# Clamp scrolling within bounds
		if terms_text:
			var max_scroll = max(0, terms_text.size.y - scroll_container.size.y)
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
				if terms_text:
					var max_scroll = max(0, terms_text.size.y - scroll_container.size.y)
					scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func load_terms_text():
	var terms_content = """[center][b][font_size=24]Terms & Conditions[/font_size][/b][/center]

[b][font_size=18]1. Acceptance of Terms[/font_size][/b]
By downloading, installing, or using the MindMotion application, you agree to be bound by these Terms and Conditions. If you do not agree, please do not use the app.

[b][font_size=18]2. Purpose of the Application[/font_size][/b]
MindMotion is designed as a supplementary educational tool to assist children with Attention-Deficit/Hyperactivity Disorder (ADHD) in developing their cognitive and gross motor skills through interactive and motion-based activities.

[b]Important:[/b] It is not a medical application and does not replace professional therapy, diagnosis, or treatment.

[b][font_size=18]3. Eligibility[/font_size][/b]
The application is intended for use under the supervision of a parent, guardian, or authorized teacher. All users must have consent from a parent or guardian before using the app.

[b][font_size=18]4. User Responsibilities[/font_size][/b]
• Use the app in a safe environment with adequate space for movement.
• Ensure that the device's camera and sensors are used appropriately and only within the app's intended functions.
• Do not attempt to modify, distribute, or misuse any part of the application.

[b][font_size=18]5. Data Collection and Privacy[/font_size][/b]
MindMotion respects your privacy:
• The app does not store or share personal video data; pose detection occurs in real time using the device's camera.
• Limited user progress data (e.g., scores, activity timestamps) may be stored securely to monitor learning outcomes.
• No personally identifiable information (PII) is collected without explicit consent from the parent, guardian, or school representative.

For more details, please refer to the Privacy Policy.

[b][font_size=18]6. Parental or Guardian Consent[/font_size][/b]
By allowing a child to use MindMotion, the parent, guardian, or authorized educator acknowledges and accepts responsibility for the child's app usage. A consent form may be required before the child participates in any activity.

[b][font_size=18]7. Intellectual Property[/font_size][/b]
All contents of the MindMotion application—including software, graphics, logos, and activity designs—are owned by the developers and their academic institution, [b]CSTC College of Sciences, Technology and Communications, Inc.[/b], and are protected under applicable copyright laws.

[b][font_size=18]8. Limitations of Liability[/font_size][/b]
The developers are not liable for:
• Any injury resulting from improper use of the app or failure to follow safety guidelines.
• Any data loss, system error, or malfunction arising from unauthorized modification.
• Any assumption that the app provides medical advice or treatment.

[b][font_size=18]9. Updates and Modifications[/font_size][/b]
The developers reserve the right to update, modify, or discontinue the app or its features at any time, with or without prior notice.

[b][font_size=18]10. Termination[/font_size][/b]
Use of the app may be terminated without notice if you violate any of these terms. Upon termination, you must uninstall the app and cease all usage.

[b][font_size=18]11. Contact Information[/font_size][/b]
For concerns, inquiries, or feedback, please contact:

[b]Pauline Jane Educational Consultancy Services (PJECS)[/b]
Educational Partner of the MindMotion Project

📧 [b]Email:[/b] mindmotionproject@gmail.com

[i]Last updated: [current_date][/i]

[center][b]Thank you for choosing MindMotion for your child's educational journey![/b][/center]"""
	
	if terms_text:
		terms_text.text = terms_content.replace("[current_date]", Time.get_datetime_string_from_system())
		# Ensure RichTextLabel allows mouse filter pass for scrolling
		terms_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_agree_toggled(checked: bool):
	# When checkbox is checked, automatically mark as read and return
	if checked:
		if Global.temp_signup_data:
			Global.temp_signup_data["terms_read"] = true
		# Brief delay so user sees the checkbox get checked
		await get_tree().create_timer(0.1).timeout
		navigate_back_to_signup()
	else:
		# If unchecked, remove the terms_read flag
		if Global.temp_signup_data:
			Global.temp_signup_data["terms_read"] = false

func navigate_back_to_signup():
	# Determine which signup screen to return to
	var return_scene = "res://scenes/studentsignup.tscn"  # default
	
	if Global.temp_signup_data and Global.temp_signup_data.has("return_scene"):
		var scene_name = Global.temp_signup_data["return_scene"]
		if scene_name == "teacher_signup":
			return_scene = "res://scenes/teachersignup.tscn"
		elif scene_name == "student_signup":
			return_scene = "res://scenes/studentsignup.tscn"
	
	get_tree().change_scene_to_file(return_scene)
	
func _on_back_button_pressed():
	# Return to signup without confirming
	navigate_back_to_signup()
