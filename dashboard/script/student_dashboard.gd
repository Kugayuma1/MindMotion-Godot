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
	
	# Set student avatar based on gender
	if current_student_data.get("gender", "Male").to_lower() == "female":
		student_avatar.texture = girl_avatar
	else:
		student_avatar.texture = boy_avatar

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
