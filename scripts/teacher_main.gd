extends Control

@onready var students_button = $Students  # Your students button
@onready var logout_button = $Logout      # Your logout button

# Optional: Add a status label to show student count
@onready var status_label = $StatusLabel       # Add this if you want to show student count

var last_student_count = 0

func _ready():
	# Connect buttons
	students_button.pressed.connect(_on_students_pressed)
	logout_button.pressed.connect(_on_logout_pressed)
	
	# Connect to student cache updates to show notifications
	Global.students_cache_updated.connect(_on_students_updated)
	
	# Show initial student count if you have a status label
	update_student_status()
	StudentData.load_student_cognitive_data()
	StudentData.load_student_motion_data()

func _on_logout_pressed():
	Global.logout()  # Clear user info
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")

func _on_students_pressed():
	# Check if students cache is ready before navigating
	if not Global.is_students_cache_ready():
		show_loading_dialog("Loading students data...")
		# Wait for cache to be ready
		await Global.students_cache_updated
		hide_loading_dialog()
	
	get_tree().change_scene_to_file("res://dashboard/scene/StudentList.tscn")

func _on_students_updated():
	update_student_status()
	show_update_notification()

func update_student_status():
	# Optional: Update status display with student count
	if status_label:
		var student_count = Global.get_students_cache().size()
		status_label.text = "Students: %d registered" % student_count
		
		# Check for new students
		if student_count > last_student_count and last_student_count > 0:
			var new_students = student_count - last_student_count
			show_notification("🎉 %d new student(s) registered!" % new_students)
		
		last_student_count = student_count

func show_update_notification():
	# Optional: Show a brief notification when data updates
	var notification = create_notification("📊 Student data updated")
	add_child(notification)
	
	# Auto-hide after 3 seconds
	var timer = Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	add_child(timer)
	timer.start()

func show_notification(text: String):
	var notification = create_notification(text)
	add_child(notification)
	
	# Auto-hide after 4 seconds
	var timer = Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if is_instance_valid(notification):
			notification.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)
	add_child(timer)
	timer.start()

func create_notification(text: String) -> Panel:
	var notification = Panel.new()
	notification.add_theme_color_override("bg_color", Color(0.2, 0.8, 0.2, 0.9))
	notification.size = Vector2(300, 60)
	notification.position = Vector2(get_viewport().size.x - 320, 20)
	notification.z_index = 1000
	
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 14)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification.add_child(label)
	
	return notification

var loading_dialog: AcceptDialog = null

func show_loading_dialog(message: String):
	if loading_dialog != null:
		return
	
	loading_dialog = AcceptDialog.new()
	add_child(loading_dialog)
	loading_dialog.dialog_text = message
	loading_dialog.title = "Loading"
	loading_dialog.get_ok_button().visible = false
	loading_dialog.popup_centered()

func hide_loading_dialog():
	if loading_dialog != null:
		loading_dialog.queue_free()
		loading_dialog = null
