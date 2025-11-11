extends Control

# UI References
@onready var instruction_label: Label = $InstructionLabel
@onready var status_label: Label = $StatusLabel

# Motion Detection Manager
var motion_manager
var session_timer: Timer
var time_remaining: int = 60

# Current user data - integrate with your login system
var current_user_id: String = ""
var current_user_name: String = ""
var current_user_type: String = ""

# Signals for game progression
signal motion_completed(success: bool)
signal scene_finished

func _ready():
	AudioManager.play_temp_music("clap")
	setup_motion_manager()
	setup_timer()
	connect_signals()
	
	var custom_font = load("res://font/Summary Notes.ttf")  # Change path to your font
	instruction_label.add_theme_font_override("font", custom_font)
	status_label.add_theme_font_override("font", custom_font)
	
	# Get current user from your login system
	load_current_user()
	
	# Auto-start the clapping activity
	start_clapping_activity()

func setup_motion_manager():
	var MotionDetectionManagerScript = preload("res://scripts/MotionDetectionManager.gd")
	motion_manager = MotionDetectionManagerScript.new()
	add_child(motion_manager)

func setup_timer():
	session_timer = Timer.new()
	add_child(session_timer)
	session_timer.wait_time = 30.0  # 60 seconds total
	session_timer.one_shot = true
	session_timer.timeout.connect(_on_session_timeout)

func connect_signals():
	motion_manager.motion_session_started.connect(_on_motion_session_started)
	motion_manager.motion_detected.connect(_on_motion_detected)
	motion_manager.motion_timeout.connect(_on_motion_timeout)

func load_current_user():
	# Use your Global directly - much cleaner!
	current_user_id = Global.user_id
	current_user_name = Global.user_name
	current_user_type = Global.user_type
	
	print("Current user loaded: ", current_user_name, " (", current_user_type, ")")
	
	# Debug check to make sure we have valid user data
	if not Global.is_authenticated():
		push_error("Clapping scene loaded but user not authenticated!")
		return
	
	if current_user_type != "student":
		push_warning("Clapping scene loaded for non-student user type: " + current_user_type)

func start_clapping_activity():
	instruction_label.text = "Do Clap"
	status_label.text = "Get ready to show your clapping skills!"
	
	# Wait 2 seconds then start detection
	await get_tree().create_timer(2.0).timeout
	
	if current_user_type == "student":
		motion_manager.start_motion_detection("clapping", current_user_id)
		session_timer.start()
	else:
		# If somehow a teacher gets here, skip the activity
		instruction_label.text = "Teacher mode - Activity skipped"
		finish_scene()

func _on_motion_session_started(motion_type: String):
	instruction_label.text = "Do Clap"
	status_label.text = "Open Motion Detector app on your phone and start clapping!"
	print("Motion detection started - waiting for clapping...")

func _on_motion_detected():
	session_timer.stop()
	
	
	instruction_label.text = "Great Job! 🎉"
	status_label.text = "Perfect clapping detected!"
	
	# Save activity record for teacher dashboard
	save_student_activity(true)
	
	# Show success for 3 seconds then finish
	await get_tree().create_timer(3.0).timeout
	emit_signal("motion_completed", true)
	AudioManager.stop_music(false)
	finish_scene()
	AudioManager.resume_previous_music(true)	

func _on_motion_timeout():
	_on_session_timeout()

func _on_session_timeout():
	session_timer.stop()
	
	instruction_label.text = "Better Luck Next Time!"
	status_label.text = "Time's up, but keep trying!"
	
	# Save activity record
	save_student_activity(false)

	# Show message for 2 seconds then finish
	await get_tree().create_timer(1.0).timeout
	emit_signal("motion_completed", false)
	finish_scene()
	AudioManager.stop_music(false)
	AudioManager.resume_previous_music(true)

func save_student_activity(success: bool):
	# Save to your existing Firestore structure for teacher dashboard
	var activity_data = {
		"student_id": current_user_id,
		"student_name": current_user_name,
		"activity_type": "clapping",
		"success": success,
		"timestamp": Time.get_unix_time_from_system(),
		"date": Time.get_datetime_string_from_system()
	}
	
	motion_manager.save_activity_to_firestore(activity_data)

func finish_scene():
	emit_signal("scene_finished")
	print("Clapping scene finished - ready to continue game")
	
	# After clapping is done, go to next level
	await get_tree().create_timer(1.0).timeout  # Brief pause
	continue_to_next_level()

func continue_to_next_level():
	# Add your logic here to proceed to the next level
	# Examples:
	
	# Option 1: Go back to level selection
	# get_tree().change_scene_to_file("res://scenes/Categories.tscn")
	
	# Option 2: Go to next level in sequence  
	# get_tree().change_scene_to_file("res://scenes/NextLevel.tscn")
	
	# Option 3: Use your existing navigation system
	# Global.go_to_next_level()
	
	# For now, placeholder:
	print("TODO: Add next level navigation")
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
