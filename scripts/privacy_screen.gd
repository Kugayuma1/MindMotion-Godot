extends Control

@onready var scroll_container = $TextureRect/ScrollContainer
@onready var privacy_text = $TextureRect/ScrollContainer/PrivacyText
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
	load_privacy_text()
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
		if privacy_text:
			var max_scroll = max(0, privacy_text.size.y - scroll_container.size.y)
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
				if privacy_text:
					var max_scroll = max(0, privacy_text.size.y - scroll_container.size.y)
					scroll_container.scroll_vertical = clamp(scroll_container.scroll_vertical, 0, max_scroll)

func load_privacy_text():
	var privacy_content = """[center][b][font_size=24]Privacy Policy[/font_size][/b][/center]
[center][i]Last Updated: October 2025[/i][/center]

[b][font_size=18]1. Introduction[/font_size][/b]
MindMotion respects your privacy and is committed to protecting the personal information of its users. This Privacy Policy explains how MindMotion collects, uses, stores, and safeguards information when you use the application.

MindMotion is a supplementary Android-based learning tool developed by students from [b]CSTC College of Sciences, Technology and Communications, Inc.[/b] in collaboration with [b]Pauline Jane Education Consultancy Services (PJECS)[/b]. It aims to support cognitive and gross motor training for children with ADHD through motion-based activities using MediaPipe Pose Estimation.

[b][font_size=18]2. Information We Collect[/font_size][/b]
MindMotion is designed with child safety and privacy in mind. The app collects minimal data and does not gather or store personal identifiers such as names, photos, or contact information.

The following types of information may be collected:
• [b]Activity Performance Data:[/b] Scores, activity completion times, and task results used to monitor progress.
• [b]Usage Information:[/b] The number of sessions, last activity time, and interaction logs for educational tracking.
• [b]Device Information:[/b] Basic non-identifiable technical data (e.g., device model or OS version) to improve compatibility and performance.

[b][color=green]MindMotion does not record, store, or transmit video footage captured by the camera. Pose tracking happens in real time and remains entirely on the device.[/color][/b]

[b][font_size=18]3. How We Use the Information[/font_size][/b]
The data collected is used only for educational and research purposes:
• To track and display user progress in training activities.
• To improve the effectiveness of the app's exercises.
• To support teacher or guardian monitoring of learning outcomes.
• To ensure system functionality and app performance.

[b]No data is sold, shared, or used for advertising purposes.[/b]

[b][font_size=18]4. Data Storage and Security[/font_size][/b]
MindMotion uses secure, research-approved methods to store activity data, which may include limited cloud storage via Firebase. All stored data is:
• Encrypted and accessible only to authorized project personnel.
• Used solely for educational or research evaluation purposes.
• Deleted or anonymized once the study or training period concludes.

The app follows local data privacy laws and ethical standards consistent with the [b]Data Privacy Act of 2012 (Republic Act No. 10173)[/b].

[b][font_size=18]5. Parental or Guardian Consent[/font_size][/b]
Because the app is designed for children, parental or guardian consent is required before use. Teachers or facilitators are responsible for obtaining and confirming consent forms prior to a child's participation in MindMotion activities.

[b][font_size=18]6. Data Sharing and Disclosure[/font_size][/b]
MindMotion does not share any personal data with third parties. However, anonymous, aggregated results may be used for:
• Academic reporting and project evaluation, or
• Research publications related to educational technology and child development.

[b]Such data will never identify individual users.[/b]

[b][font_size=18]7. User Rights[/font_size][/b]
Parents, guardians, or authorized educators have the right to:
• Request access to activity records.
• Request correction or deletion of stored data.
• Withdraw consent for data collection at any time.

To make a request, please contact the project team through the details below.

[b][font_size=18]8. Changes to This Policy[/font_size][/b]
Developers may update this Privacy Policy periodically to reflect improvements or legal requirements. Any changes will be communicated through the app or official project channels.

[b][font_size=18]9. Contact Information[/font_size][/b]
For questions, requests, or concerns about data privacy, please contact:

[b]Pauline Jane Education Consultancy Services (PJECS)[/b]
Educational Partner – MindMotion Project
📧 [b]Email:[/b] mindmotionproject@gmail.com

[b]CSTC College of Sciences, Technology and Communications, Inc.[/b]

[center]━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━[/center]

[center][b]Your privacy and your child's safety are our top priorities.[/b][/center]"""
	
	if privacy_text:
		privacy_text.text = privacy_content
		# Ensure RichTextLabel allows mouse filter pass for scrolling
		privacy_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_agree_toggled(checked: bool):
	# When checkbox is checked, automatically mark as read and return
	if checked:
		if Global.temp_signup_data:
			Global.temp_signup_data["privacy_read"] = true
		# Brief delay so user sees the checkbox get checked
		await get_tree().create_timer(0.1).timeout
		navigate_back_to_signup()
	else:
		# If unchecked, remove the privacy_read flag
		if Global.temp_signup_data:
			Global.temp_signup_data["privacy_read"] = false

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
