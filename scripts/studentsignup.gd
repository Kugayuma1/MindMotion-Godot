extends Control

# UI References
@onready var gender_option = $Container/Gender
@onready var name_input = $Container/Name
@onready var email_input = $Container/Email
@onready var password_input = $Container/Password
@onready var hide_button = $Container/Password/Hide
@onready var age_input = $Container/Age
@onready var agreement_checkbox = $Container/Password/Agree
@onready var terms_button = $Container/Password/TermsButton
@onready var privacy_button = $Container/Password/PrivacyButton
@onready var http_request = $HTTPRequest
var signup_loading_dialog: AcceptDialog = null
var dialog_theme = preload("res://assets/main_theme.tres")
var eye_open_icon = preload("res://assets/eye.png")
var eye_closed_icon = preload("res://assets/eyeofthetiger.png")

# Constants
const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"

# State Management
enum Stage { SIGNUP, SEND_VERIFICATION, STORE_DATA, CREATE_PROGRESS, CREATE_STAGES }
var current_stage: Stage
var temp_uid = ""
var temp_id_token = ""
var temp_refresh_token = ""
var temp_email = ""
var stages_to_create = ["reading", "fine_motor", "math", "art"]
var current_stage_index = 0

# Email verification
var verification_check_timer: Timer = null
var verification_attempts = 0
const MAX_VERIFICATION_ATTEMPTS = 60  # Check for 5 minutes (every 5 seconds)

# Terms and Privacy tracking
var terms_read = false
var privacy_read = false

# Debug helper
func debug_print(message: String, icon: String = "📋"):
	print("%s %s" % [icon, message])

func _ready():
	setup_ui()
	setup_terms_privacy_buttons()
	gender_option.theme = dialog_theme
	
	if hide_button:
		hide_button.texture_normal = eye_closed_icon
	
	# Setup verification timer
	verification_check_timer = Timer.new()
	add_child(verification_check_timer)
	verification_check_timer.timeout.connect(_check_email_verification)
	
	# Restore data if returning from terms/privacy screens
	restore_signup_data()

func setup_ui():
	$Container/Hello.text = "Hello %s!" % Global.user_type.capitalize()
	gender_option.add_item("Select Gender...")
	gender_option.add_item("Male")
	gender_option.add_item("Female")
	gender_option.selected = 0
	gender_option.item_selected.connect(_on_gender_item_selected)
	
	# Disable agreement checkbox initially but preserve its styling
	agreement_checkbox.disabled = true
	agreement_checkbox.button_pressed = false
	agreement_checkbox.modulate = Color.WHITE

func setup_terms_privacy_buttons():
	if terms_button:
		terms_button.pressed.connect(_on_terms_button_pressed)
	if privacy_button:
		privacy_button.pressed.connect(_on_privacy_button_pressed)

func restore_signup_data():
	if Global.temp_signup_data and Global.temp_signup_data.get("return_scene") == "student_signup":
		name_input.text = Global.temp_signup_data.get("name", "")
		email_input.text = Global.temp_signup_data.get("email", "")
		password_input.text = Global.temp_signup_data.get("password", "")
		age_input.text = Global.temp_signup_data.get("age", "")
		gender_option.selected = Global.temp_signup_data.get("gender", 0)
		terms_read = Global.temp_signup_data.get("terms_read", false)
		privacy_read = Global.temp_signup_data.get("privacy_read", false)
		update_agreement_checkbox()
		Global.temp_signup_data = {}

func _on_terms_button_pressed():
	Global.temp_signup_data = {
		"name": name_input.text,
		"email": email_input.text,
		"password": password_input.text,
		"age": age_input.text,
		"gender": gender_option.selected,
		"terms_read": terms_read,
		"privacy_read": privacy_read,
		"return_scene": "student_signup"
	}
	get_tree().change_scene_to_file("res://scenes/TermsScreen.tscn")

func _on_privacy_button_pressed():
	Global.temp_signup_data = {
		"name": name_input.text,
		"email": email_input.text,
		"password": password_input.text,
		"age": age_input.text,
		"gender": gender_option.selected,
		"terms_read": terms_read,
		"privacy_read": privacy_read,
		"return_scene": "student_signup"
	}
	get_tree().change_scene_to_file("res://scenes/PrivacyScreen.tscn")

func update_agreement_checkbox():
	agreement_checkbox.disabled = not (terms_read and privacy_read)
	agreement_checkbox.modulate = Color.WHITE
	
	if terms_read and privacy_read:
		agreement_checkbox.button_pressed = true
		debug_print("Agreement checkbox enabled and checked", "✅")
	else:
		agreement_checkbox.button_pressed = false

# Email validation function
func is_valid_email(email: String) -> bool:
	var email_regex = RegEx.new()
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return email_regex.search(email) != null

# Input Validation
func validate_inputs() -> bool:
	var name = name_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var age = age_input.text.strip_edges()
	
	if name == "" or email == "" or password == "":
		show_error_dialog("Please fill in all required fields")
		return false
	
	if not is_valid_email(email):
		show_error_dialog("Please enter a valid email address (e.g., user@example.com)")
		return false
	
	if age == "" or not age.is_valid_int() or int(age) < 3 or int(age) > 18:
		show_error_dialog("Please enter a valid age between 3 and 18")
		return false
	
	if password.length() < 6:
		show_error_dialog("Password must be at least 6 characters long")
		return false
	
	if gender_option.selected == 0:
		show_error_dialog("Please select a gender")
		return false
	
	if not terms_read or not privacy_read:
		show_error_dialog("You must read and agree to both Terms & Conditions and Privacy Policy")
		return false
	
	if not agreement_checkbox.button_pressed:
		show_error_dialog("You must check the agreement checkbox")
		return false
	
	return true

func make_request(url: String, payload: Dictionary, headers: Array = []):
	var default_headers = ["Content-Type: application/json"]
	if temp_id_token != "":
		default_headers.append("Authorization: Bearer %s" % temp_id_token)
	
	var final_headers = default_headers + headers
	var method = HTTPClient.METHOD_GET if payload.is_empty() else (HTTPClient.METHOD_PATCH if "documents" in url else HTTPClient.METHOD_POST)
	var body = "" if payload.is_empty() else JSON.stringify(payload)
	http_request.request(url, final_headers, method, body)

# Event Handlers
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_signup_pressed():
	if not validate_inputs():
		return
	
	show_signup_loading("Creating your account...")
	current_stage = Stage.SIGNUP
	temp_email = email_input.text.strip_edges()
	
	var signup_url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + FIREBASE_API_KEY
	var payload = {
		"email": temp_email,
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
		Stage.SEND_VERIFICATION: handle_send_verification_response(response_code, response)
		Stage.STORE_DATA: handle_store_data_response(response_code, response)
		Stage.CREATE_PROGRESS: handle_create_progress_response(response_code, response)
		Stage.CREATE_STAGES: handle_create_stages_response(response_code, response)

func handle_signup_response(response_code: int, response: Dictionary):
	if response_code == 200:
		debug_print("Student signup successful", "✅")
		temp_uid = response["localId"]
		temp_id_token = response["idToken"]
		temp_refresh_token = response.get("refreshToken", "")
		
		# Now send verification email
		update_signup_loading("Sending verification email...")
		current_stage = Stage.SEND_VERIFICATION
		send_verification_email()
	else:
		hide_signup_loading()
		handle_signup_error(response)

func send_verification_email():
	var verify_url = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=" + FIREBASE_API_KEY
	var payload = {
		"requestType": "VERIFY_EMAIL",
		"idToken": temp_id_token
	}
	
	# Use direct request without make_request helper
	var headers = ["Content-Type: application/json"]
	http_request.request(verify_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func handle_send_verification_response(response_code: int, response: Dictionary):
	if response_code == 200:
		debug_print("Verification email sent successfully", "✅")
		show_verification_dialog()
	else:
		debug_print("Failed to send verification email: %s" % str(response), "❌")
		hide_signup_loading()
		show_error_dialog("Failed to send verification email. Please try again.")

func show_verification_dialog():
	hide_signup_loading()
	
	var verify_dialog = AcceptDialog.new()
	verify_dialog.name = "VerificationDialog"
	add_child(verify_dialog)
	verify_dialog.theme = dialog_theme
	verify_dialog.title = "Email Verification Required"
	verify_dialog.dialog_text = "A verification email has been sent to:\n%s\n\nPlease check your inbox and click the verification link.\n\nThis window will automatically continue once your email is verified.\n\n(This may take a few moments)" % temp_email
	verify_dialog.get_ok_button().visible = false
	verify_dialog.min_size = Vector2(400, 200)
	verify_dialog.size = Vector2(400, 200)
	
	# Add a centered cancel button
	var cancel_button = verify_dialog.add_button("Cancel Signup", false, "cancel")
	cancel_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	verify_dialog.custom_action.connect(func(action):
		if action == "cancel":
			cancel_verification()
	)
	
	verify_dialog.popup_centered()
	
	# Start checking for verification
	verification_attempts = 0
	verification_check_timer.wait_time = 5.0  # Check every 5 seconds
	verification_check_timer.start()

func _check_email_verification():
	verification_attempts += 1
	
	if verification_attempts > MAX_VERIFICATION_ATTEMPTS:
		verification_check_timer.stop()
		show_error_dialog("Email verification timed out. Please try signing up again.")
		cancel_verification()
		return
	
	debug_print("Checking email verification status (attempt %d/%d)" % [verification_attempts, MAX_VERIFICATION_ATTEMPTS], "🔍")
	
	# Get account info to check verification status
	var account_url = "https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=" + FIREBASE_API_KEY
	var payload = {
		"idToken": temp_id_token
	}
	
	var temp_http = HTTPRequest.new()
	add_child(temp_http)
	temp_http.request_completed.connect(func(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
		handle_verification_check_response(response_code, body, temp_http)
	)
	
	var headers = ["Content-Type: application/json"]
	temp_http.request(account_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func handle_verification_check_response(response_code: int, body: PackedByteArray, temp_http: HTTPRequest):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200 and response.has("users") and response.users.size() > 0:
		var user_data = response.users[0]
		var is_verified = user_data.get("emailVerified", false)
		
		if is_verified:
			debug_print("Email verified successfully!", "✅")
			verification_check_timer.stop()
			
			# Close verification dialog
			var verify_dialog = get_node_or_null("VerificationDialog")
			if verify_dialog:
				verify_dialog.queue_free()
			
			# Continue with account creation
			show_signup_loading("Email verified! Creating your profile...")
			proceed_with_account_creation()
		else:
			debug_print("Email not yet verified, will check again...", "⏳")
	
	temp_http.queue_free()

func proceed_with_account_creation():
	# Set user info with Firebase UID
	Global.set_user_type("student")
	Global.set_user_info(temp_uid, temp_email, name_input.text, temp_id_token, temp_refresh_token)
	
	current_stage = Stage.STORE_DATA
	create_user_document()

func cancel_verification():
	verification_check_timer.stop()
	
	# Delete the unverified account
	delete_unverified_account()
	
	# Close verification dialog
	var verify_dialog = get_node_or_null("VerificationDialog")
	if verify_dialog:
		verify_dialog.queue_free()
	
	# Re-enable form
	set_inputs_enabled(true)

func delete_unverified_account():
	# Optional: Delete the Firebase account if user cancels
	var delete_url = "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + FIREBASE_API_KEY
	var payload = {
		"idToken": temp_id_token
	}
	
	var temp_http = HTTPRequest.new()
	add_child(temp_http)
	temp_http.request_completed.connect(func(result, response_code, headers, body):
		debug_print("Unverified account cleanup: %s" % ("success" if response_code == 200 else "failed"), "🗑️")
		temp_http.queue_free()
	)
	
	var headers = ["Content-Type: application/json"]
	temp_http.request(delete_url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))

func handle_store_data_response(response_code: int, response: Dictionary):
	if response_code == 200:
		debug_print("Student data stored successfully", "✅")
		update_signup_loading("Setting up your activities...")
		current_stage = Stage.CREATE_PROGRESS
		create_initial_progress_data()
	else:
		debug_print("Failed to store user data: %s" % str(response), "❌")
		hide_signup_loading()
		show_error_dialog("Failed to create your profile. Please try again.")

func handle_create_progress_response(response_code: int, response: Dictionary):
	var success = response_code == 200
	debug_print("Initial progress data: %s" % ("created" if success else "failed"), "✅" if success else "❌")
	
	update_signup_loading("Preparing learning stages...")
	current_stage = Stage.CREATE_STAGES
	current_stage_index = 0
	create_next_stage_document()

func handle_create_stages_response(response_code: int, response: Dictionary):
	var stage_name = stages_to_create[current_stage_index]
	var success = response_code == 200
	
	debug_print("Stage '%s': %s" % [stage_name, "created" if success else "failed"], "✅" if success else "❌")
	
	current_stage_index += 1
	
	if current_stage_index < stages_to_create.size():
		var progress_text = "Creating activities... (%d/%d)" % [current_stage_index + 1, stages_to_create.size()]
		update_signup_loading(progress_text)
		create_next_stage_document()
	else:
		finish_signup_process()

# Document Creation Methods
func create_user_document():
	var doc_url = "%s/users/%s" % [FIRESTORE_URL, temp_uid]
	var student_data = {
		"fields": {
			"name": {"stringValue": name_input.text.strip_edges()},
			"email": {"stringValue": temp_email},
			"userType": {"stringValue": "student"},
			"age": {"integerValue": age_input.text.strip_edges()},
			"gender": {"stringValue": gender_option.get_item_text(gender_option.selected)},
			"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))},
			"emailVerified": {"booleanValue": true}
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
	
	hide_signup_loading()
	LoadingScreen.show_loading()
	
	await get_tree().create_timer(2.0).timeout
	await load_new_student_data_with_verification()
	
	hide_signup_loading()
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")

func load_new_student_data_with_verification():
	debug_print("Loading and verifying new student data...", "📡")
	
	Global.load_all_letter_completion_data()
	
	var wait_time = 0.0
	var max_wait = 10.0
	
	while not Global.is_letter_cache_loaded and wait_time < max_wait:
		await get_tree().process_frame
		wait_time += 0.1
		await get_tree().create_timer(0.1).timeout
	
	if Global.is_letter_cache_loaded:
		var letter_a_status = Global.letter_completion_cache.get("A", false)
		debug_print("Letter A status: %s" % str(letter_a_status), "✅")
		
		if not letter_a_status and not Global.letter_completion_cache.has("A"):
			Global.letter_completion_cache["A"] = true
			debug_print("Forced Letter A unlock for new user", "🔧")
	else:
		debug_print("Cache timeout - using safe defaults", "⚠️")
		Global.set_default_letter_cache()
	
	debug_print("New student verification complete", "✅")

func handle_signup_error(response: Dictionary):
	var error_message = "Signup failed. Please try again."
	
	if response and response.has("error") and response.error.has("message"):
		var firebase_error = response.error.message
		if "EMAIL_EXISTS" in firebase_error:
			error_message = "An account with this email already exists."
		elif "INVALID_EMAIL" in firebase_error:
			error_message = "Please enter a valid email address."
		elif "WEAK_PASSWORD" in firebase_error:
			error_message = "Password is too weak. Please choose a stronger password."
		elif "TOO_MANY_ATTEMPTS_TRY_LATER" in firebase_error:
			error_message = "Too many attempts. Please try again later."
	
	show_error_dialog(error_message)

func show_signup_loading(message: String):
	var signup_button = get_node_or_null("Container/SignupButton")
	if signup_button:
		signup_button.disabled = true
		signup_button.text = "Creating Account..."
	
	if signup_loading_dialog == null:
		signup_loading_dialog = AcceptDialog.new()
		signup_loading_dialog.name = "SignupLoadingDialog"
		add_child(signup_loading_dialog)
		signup_loading_dialog.theme = dialog_theme
		signup_loading_dialog.title = "Creating Account"
		signup_loading_dialog.get_ok_button().visible = false
		signup_loading_dialog.close_requested.connect(_on_signup_loading_dialog_closed)
	
	signup_loading_dialog.dialog_text = message + "\n\nPlease wait..."
	if not signup_loading_dialog.visible:
		signup_loading_dialog.min_size = Vector2(350, 150)
		signup_loading_dialog.size = Vector2(350, 150)
		signup_loading_dialog.popup_centered()
	
	set_inputs_enabled(false)

func update_signup_loading(message: String):
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.dialog_text = message + "\n\nPlease wait..."

func hide_signup_loading():
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.queue_free()
		signup_loading_dialog = null
	
	set_inputs_enabled(true)
	
	var signup_button = get_node_or_null("Container/SignupButton")
	if signup_button:
		signup_button.disabled = false
		signup_button.text = "Sign Up"

func set_inputs_enabled(enabled: bool):
	name_input.editable = enabled
	email_input.editable = enabled
	password_input.editable = enabled
	age_input.editable = enabled
	gender_option.disabled = not enabled
	agreement_checkbox.disabled = not enabled
	terms_button.disabled = not enabled
	privacy_button.disabled = not enabled

func show_error_dialog(message: String):
	var error_dialog = AcceptDialog.new()
	add_child(error_dialog)
	error_dialog.theme = dialog_theme
	error_dialog.dialog_text = message
	error_dialog.title = "Notice"
	error_dialog.min_size = Vector2(350, 150)
	error_dialog.size = Vector2(350, 150)
	error_dialog.popup_centered()
	
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())
	error_dialog.close_requested.connect(func(): error_dialog.queue_free())

func _on_signup_loading_dialog_closed():
	if signup_loading_dialog and is_instance_valid(signup_loading_dialog):
		signup_loading_dialog.popup_centered()

func _on_hide_pressed():
	password_input.secret = !password_input.secret
	
	if hide_button:
		if password_input.secret:
			hide_button.texture_normal = eye_closed_icon
		else:
			hide_button.texture_normal = eye_open_icon
