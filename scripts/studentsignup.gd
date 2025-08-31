extends Control

# UI References
@onready var gender_option = $Container/Gender
@onready var name_input = $Container/Name
@onready var email_input = $Container/Email
@onready var password_input = $Container/Password
@onready var age_input = $Container/Age
@onready var agreement_checkbox = $Container/Password/Agree
@onready var http_request = $HTTPRequest
var signup_loading_dialog: AcceptDialog = null

# Constants
const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"

# State Management
enum Stage { SIGNUP, STORE_DATA, CREATE_PROGRESS, CREATE_STAGES }
var current_stage: Stage
var temp_uid = ""
var temp_id_token = ""
var stages_to_create = ["reading", "fine_motor", "math", "art"]
var current_stage_index = 0

# Debug helper
func debug_print(message: String, icon: String = "📋"):
	print("%s %s" % [icon, message])

func _ready():
	setup_ui()

func setup_ui():
	$Container/Hello.text = "Hello %s!" % Global.user_type.capitalize()
	gender_option.add_item("Select Gender...")
	gender_option.add_item("Male")
	gender_option.add_item("Female")
	gender_option.selected = 0
	gender_option.item_selected.connect(_on_gender_item_selected)

# Input Validation
func validate_inputs() -> bool:
	var name = name_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if name == "" or email == "" or password == "":
		debug_print("Please fill in all required fields", "⚠️")
		return false
	
	if gender_option.selected == 0:
		debug_print("Please select a gender", "⚠️")
		return false
	
	if not agreement_checkbox.button_pressed:
		debug_print("You must agree to Terms and Privacy Policy", "⚠️")
		return false
	
	return true

# HTTP Request Helper
func make_request(url: String, payload: Dictionary, headers: Array = []):
	var default_headers = ["Content-Type: application/json"]
	if temp_id_token != "":
		default_headers.append("Authorization: Bearer %s" % temp_id_token)
	
	var final_headers = default_headers + headers
	http_request.request(url, final_headers, HTTPClient.METHOD_PATCH if "documents" in url else HTTPClient.METHOD_POST, JSON.stringify(payload))

# Event Handlers
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_signup_pressed():
	if not validate_inputs():
		return
	
	current_stage = Stage.SIGNUP
	var signup_url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + FIREBASE_API_KEY
	var payload = {
		"email": email_input.text.strip_edges(),
		"password": password_input.text.strip_edges(),
		"returnSecureToken": true
	}
	make_request(signup_url, payload)

func _on_gender_item_selected(index: int):
	if index > 0:
		debug_print("Selected: %s" % gender_option.get_item_text(index))

# Response Handlers
func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	match current_stage:
		Stage.SIGNUP: handle_signup_response(response_code, response)
		Stage.STORE_DATA: handle_store_data_response(response_code, response)
		Stage.CREATE_PROGRESS: handle_create_progress_response(response_code, response)
		Stage.CREATE_STAGES: handle_create_stages_response(response_code, response)

func handle_signup_response(response_code: int, response: Dictionary):
	if response_code == 200:
		debug_print("Student signup successful", "✅")
		temp_uid = response["localId"]
		temp_id_token = response["idToken"]
		
		# Set user info
		Global.firebase_id_token = temp_id_token
		Global.set_user_type("student")
		Global.set_user_info(temp_uid, response["email"], name_input.text)
		
		# Show loading state as we start creating documents
		show_signup_loading("Creating your profile...")
		
		current_stage = Stage.STORE_DATA
		create_user_document()
	else:
		debug_print("Signup failed: %s" % str(response), "❌")

func handle_store_data_response(response_code: int, response: Dictionary):
	if response_code == 200:
		debug_print("Student data stored successfully", "✅")
		current_stage = Stage.CREATE_PROGRESS
		create_initial_progress_data()
	else:
		debug_print("Failed to store user data: %s" % str(response), "❌")

func handle_create_progress_response(response_code: int, response: Dictionary):
	var success = response_code == 200
	debug_print("Initial progress data: %s" % ("created" if success else "failed"), "✅" if success else "❌")
	
	# Proceed to create stages regardless
	current_stage = Stage.CREATE_STAGES
	current_stage_index = 0
	create_next_stage_document()

func handle_create_stages_response(response_code: int, response: Dictionary):
	var stage_name = stages_to_create[current_stage_index]
	var success = response_code == 200
	
	debug_print("Stage '%s': %s" % [stage_name, "created" if success else "failed"], "✅" if success else "❌")
	
	current_stage_index += 1
	
	if current_stage_index < stages_to_create.size():
		create_next_stage_document()
	else:
		finish_signup_process()

# Document Creation Methods
func create_user_document():
	var doc_url = "%s/users/%s" % [FIRESTORE_URL, temp_uid]
	var student_data = {
		"fields": {
			"name": {"stringValue": name_input.text},
			"email": {"stringValue": email_input.text},
			"userType": {"stringValue": "student"},
			"age": {"integerValue": str(age_input.text.strip_edges())},
			"gender": {"stringValue": gender_option.get_item_text(gender_option.selected)},
			"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))}
		}
	}
	make_request(doc_url, student_data)

func create_initial_progress_data():
	debug_print("Creating initial progress data for letter A", "📊")
	
	var progress_url = "%s/users/%s/progress/A" % [FIRESTORE_URL, temp_uid]
	var progress_data = {
		"fields": {
			"averageTime": {"integerValue": "0"},
			"completedLevels": {"integerValue": "0"},
			"letterCompleted": {"booleanValue": false}
		}
	}
	make_request(progress_url, progress_data)

func create_next_stage_document():
	var stage_name = stages_to_create[current_stage_index]
	debug_print("Creating stage document: %s" % stage_name, "📝")
	
	var stage_url = "%s/users/%s/progress/A/levels/%s" % [FIRESTORE_URL, temp_uid, stage_name]
	var stage_data = {
		"fields": {
			"everCompleted": {"booleanValue": false},
			"bestTime": {"integerValue": "0"},
			"lastAttemptCompleted": {"booleanValue": false},
			"lastAttemptTime": {"integerValue": "0"},
			"lastPlayedAt": {"stringValue": ""},
			"level_name": {"stringValue": stage_name}
		}
	}
	make_request(stage_url, stage_data)

func finish_signup_process():
	debug_print("All signup documents created successfully!", "🎉")
	
	# Show loading state
	show_signup_loading("Finalizing your account...")
	
	# Wait for data to load properly
	await load_new_student_data()
	
	hide_signup_loading()
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")

func load_new_student_data():
	debug_print("Loading initial data for new student...", "📡")
	
	update_signup_loading("Loading your progress...")
	
	# For new students, we know A should be available and others locked
	# But still load from Firebase to be consistent
	Global.load_all_letter_completion_data()
	
	# Wait for letter cache
	var wait_time = 0.0
	var max_wait = 8.0  # Shorter for new accounts since we just created the data
	
	while not Global.is_letter_cache_loaded and wait_time < max_wait:
		await get_tree().process_frame
		wait_time += 0.1
		await get_tree().create_timer(0.1).timeout
		
		if int(wait_time) % 2 == 0:
			update_signup_loading("Setting up activities... %d seconds" % int(wait_time))
	
	if Global.is_letter_cache_loaded:
		debug_print("New student cache loaded successfully", "✅")
	else:
		debug_print("Cache timeout for new student - using defaults", "⚠️")
		Global.set_default_letter_cache()
	
	# Load stage data for A (since that's what new students will access)
	update_signup_loading("Preparing activities...")
	Global.load_letter_stages_on_demand("A")
	await get_tree().create_timer(1.0).timeout  # Brief wait for A stages
	
	debug_print("New student data loading complete", "✅")
	
func show_signup_loading(message: String):
	# Disable signup button if it exists
	var signup_button = get_node_or_null("Container/SignupButton")  # Adjust path as needed
	if signup_button:
		signup_button.disabled = true
		signup_button.text = "Creating Account..."
	
	# Create loading dialog
	signup_loading_dialog = AcceptDialog.new()
	signup_loading_dialog.name = "SignupLoadingDialog"
	add_child(signup_loading_dialog)
	signup_loading_dialog.dialog_text = message + "\n\nPlease wait..."
	signup_loading_dialog.title = "Creating Account"
	signup_loading_dialog.get_ok_button().visible = false
	signup_loading_dialog.close_requested.connect(_on_signup_loading_dialog_closed)
	signup_loading_dialog.popup_centered()
	
	# Disable form inputs to prevent changes during loading
	name_input.editable = false
	email_input.editable = false
	password_input.editable = false
	age_input.editable = false
	gender_option.disabled = true
	

func update_signup_loading(message: String):
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.dialog_text = message + "\n\nPlease wait..."

func hide_signup_loading():
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.queue_free()
		signup_loading_dialog = null
	
	# Re-enable form (though user will navigate away)
	name_input.editable = true
	email_input.editable = true
	password_input.editable = true
	age_input.editable = true
	gender_option.disabled = false
	
func _on_signup_loading_dialog_closed():
	# Don't allow closing during signup
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.popup_centered()
