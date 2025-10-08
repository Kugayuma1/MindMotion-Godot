extends Control

@onready var name_input = $Container/Name
@onready var email_input = $Container/Email
@onready var password_input = $Container/Password
@onready var hide_button = $Container/Password/Hide
@onready var hidden_button = $Container/Confirm/Hidden
@onready var confirm_password_input = $Container/Confirm
@onready var agreement_checkbox = $Container/Confirm/Agree
@onready var terms_button = $Container/Confirm/TermsButton
@onready var privacy_button = $Container/Confirm/PrivacyButton
@onready var http_request = $HTTPRequest

const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"

enum Stage { SIGNUP, STORE_DATA }
var current_stage: Stage
var temp_uid = ""
var temp_id_token = ""
var temp_refresh_token = ""
var loading_dialog: AcceptDialog = null
var dialog_theme = preload("res://assets/main_theme.tres")
var eye_open_icon = preload("res://assets/eye.png")
var eye_closed_icon = preload("res://assets/eyeofthetiger.png")

# Terms and Privacy tracking
var terms_read = false
var privacy_read = false

func _ready():
	setup_ui()
	setup_terms_privacy_buttons()
	
	if hide_button:
		hide_button.texture_normal = eye_closed_icon
	
	if hidden_button:
		hidden_button.texture_normal = eye_closed_icon
	# Restore data if returning from terms/privacy screens
	restore_signup_data()

func setup_ui():
	var user_type = Global.user_type.capitalize()
	$Container/Hello.text = "Hello %s!" % user_type
	
	# Disable agreement checkbox initially but preserve its styling
	agreement_checkbox.disabled = true
	agreement_checkbox.button_pressed = false
	# Keep the checkbox visually unchanged when disabled
	agreement_checkbox.modulate = Color.WHITE

func setup_terms_privacy_buttons():
	# Connect to your existing buttons
	if terms_button:
		terms_button.pressed.connect(_on_terms_button_pressed)
	if privacy_button:
		privacy_button.pressed.connect(_on_privacy_button_pressed)

func restore_signup_data():
	# Restore form data when returning from terms/privacy screens
	if Global.temp_signup_data and Global.temp_signup_data.get("return_scene") == "teacher_signup":
		name_input.text = Global.temp_signup_data.get("name", "")
		email_input.text = Global.temp_signup_data.get("email", "")
		password_input.text = Global.temp_signup_data.get("password", "")
		confirm_password_input.text = Global.temp_signup_data.get("confirm_password", "")
		terms_read = Global.temp_signup_data.get("terms_read", false)
		privacy_read = Global.temp_signup_data.get("privacy_read", false)
		update_agreement_checkbox()
		# Clear the temp data
		Global.temp_signup_data = {}

func _on_terms_button_pressed():
	# Store current signup data and navigate to terms screen
	Global.temp_signup_data = {
		"name": name_input.text,
		"email": email_input.text,
		"password": password_input.text,
		"confirm_password": confirm_password_input.text,
		"terms_read": terms_read,
		"privacy_read": privacy_read,
		"return_scene": "teacher_signup"
	}
	get_tree().change_scene_to_file("res://scenes/TermsScreen.tscn")

func _on_privacy_button_pressed():
	# Store current signup data and navigate to privacy screen
	Global.temp_signup_data = {
		"name": name_input.text,
		"email": email_input.text,
		"password": password_input.text,
		"confirm_password": confirm_password_input.text,
		"terms_read": terms_read,
		"privacy_read": privacy_read,
		"return_scene": "teacher_signup"
	}
	get_tree().change_scene_to_file("res://scenes/PrivacyScreen.tscn")

func update_agreement_checkbox():
	# Enable the main agreement checkbox only if both terms and privacy are read
	agreement_checkbox.disabled = not (terms_read and privacy_read)
	# Always keep the checkbox visually normal
	agreement_checkbox.modulate = Color.WHITE
	
	if terms_read and privacy_read:
		agreement_checkbox.button_pressed = true
		print("Agreement checkbox enabled and checked")
	else:
		agreement_checkbox.button_pressed = false

# Email validation function
func is_valid_email(email: String) -> bool:
	var email_regex = RegEx.new()
	email_regex.compile("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$")
	return email_regex.search(email) != null

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_signup_pressed():
	if not validate_inputs():
		return
	
	show_loading("Creating your account...")
	current_stage = Stage.SIGNUP
	
	var signup_url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + FIREBASE_API_KEY
	var payload = {
		"email": email_input.text.strip_edges(),
		"password": password_input.text.strip_edges(),
		"returnSecureToken": true
	}
	
	http_request.request(signup_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))

func validate_inputs() -> bool:
	var name = name_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var confirm_password = confirm_password_input.text.strip_edges()
	
	if name == "" or email == "" or password == "" or confirm_password == "":
		show_error_dialog("Please fill in all required fields.")
		return false
	
	if not is_valid_email(email):
		show_error_dialog("Please enter a valid email address (e.g., user@example.com)")
		return false
	
	if password != confirm_password:
		show_error_dialog("Passwords do not match.")
		return false
	
	if password.length() < 6:
		show_error_dialog("Password must be at least 6 characters long.")
		return false
	
	if not terms_read or not privacy_read:
		show_error_dialog("You must read and agree to both Terms & Conditions and Privacy Policy")
		return false
	
	if not agreement_checkbox.button_pressed:
		show_error_dialog("You must check the agreement checkbox.")
		return false
	
	return true

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	match current_stage:
		Stage.SIGNUP: handle_signup_response(response_code, response)
		Stage.STORE_DATA: handle_store_data_response(response_code, response)

func handle_signup_response(response_code: int, response: Dictionary):
	if response_code == 200:
		print("Teacher signup successful")
		temp_uid = response["localId"]
		temp_id_token = response["idToken"]
		temp_refresh_token = response.get("refreshToken", "")
		
		# Set user info with Firebase UID
		Global.set_user_type("teacher")
		print("DEBUG: User type set to: ", Global.user_type)
		
		Global.set_user_info(temp_uid, response["email"], name_input.text, temp_id_token, temp_refresh_token)
		print("DEBUG: User info set - ID: ", temp_uid)
		print("DEBUG: Is authenticated: ", Global.is_authenticated())
		print("DEBUG: Students cache ready: ", Global.is_students_cache_ready())
		
		update_loading("Creating your profile...")
		current_stage = Stage.STORE_DATA
		create_teacher_document()
	else:
		hide_loading()
		handle_signup_error(response)


func handle_store_data_response(response_code: int, response: Dictionary):
	if response_code == 200:
		print("Teacher data stored successfully.")
		update_loading("Loading students data...")

		# Force fresh fetch
		Global.refresh_students_cache()
		
		# ✅ Always wait for students cache (even if it was already ready)
		await Global.wait_for_students_cache()
		
		print("DEBUG: Students loaded:", Global.get_students_cache().size())
		hide_loading()
		get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")
	else:
		hide_loading()
		show_error_dialog("Failed to create your profile. Please try again.")

func await_students_cache_then_proceed():
	print("DEBUG: Starting await_students_cache_then_proceed")
	print("DEBUG: User type: ", Global.user_type)
	print("DEBUG: Is authenticated: ", Global.is_authenticated())
	
	# Connect to the students cache signal if not already connected
	if not Global.students_cache_updated.is_connected(_on_students_loaded):
		Global.students_cache_updated.connect(_on_students_loaded)
		print("DEBUG: Connected to students_cache_updated signal")
	
	# ALWAYS force a fresh fetch during signup, don't rely on potentially stale cache
	if Global.user_type == "teacher" and Global.is_authenticated():
		print("DEBUG: Forcing fresh students cache fetch during signup...")
		Global.refresh_students_cache()  # This will trigger students_cache_updated when done
	else:
		print("DEBUG: Authentication or user type issue")
		hide_loading()
		show_error_dialog("Authentication issue. Please try logging in again.")

func _on_students_loaded():
	print("DEBUG: _on_students_loaded called")
	var students = Global.get_students_cache()
	print("DEBUG: Students loaded - count: ", students.size())
	
	# Print first few students for debugging
	for i in range(min(3, students.size())):
		print("DEBUG: Student %d: %s" % [i, students[i].name])
	
	hide_loading()
	
	# Disconnect the signal to avoid duplicate calls
	if Global.students_cache_updated.is_connected(_on_students_loaded):
		Global.students_cache_updated.disconnect(_on_students_loaded)
		print("DEBUG: Disconnected from students_cache_updated signal")
	
	# Now proceed to the main teacher dashboard
	print("DEBUG: Proceeding to TeacherMain.tscn with %d students" % students.size())
	get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")

func create_teacher_document():
	# Use Firebase's internal UID as document ID
	var doc_url = "%s/users/%s" % [FIRESTORE_URL, temp_uid]
	var teacher_data = {
		"fields": {
			"name": {"stringValue": name_input.text.strip_edges()},
			"email": {"stringValue": email_input.text.strip_edges()},
			"userType": {"stringValue": "teacher"},
			"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))}
		}
	}
	
	var request_headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % temp_id_token
	]
	
	http_request.request(doc_url, request_headers, HTTPClient.METHOD_PATCH, JSON.stringify(teacher_data))

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

func show_loading(message: String):
	set_inputs_enabled(false)
	
	loading_dialog = AcceptDialog.new()
	add_child(loading_dialog)
	loading_dialog.theme = dialog_theme
	loading_dialog.dialog_text = message + "\n\nPlease wait..."
	loading_dialog.title = "Creating Account"
	loading_dialog.get_ok_button().visible = false
	loading_dialog.close_requested.connect(_on_loading_dialog_close)
	loading_dialog.min_size = Vector2(350, 150)  # Width x Height
	loading_dialog.size = Vector2(350, 150)
	loading_dialog.popup_centered()

func update_loading(message: String):
	if loading_dialog and is_instance_valid(loading_dialog):
		loading_dialog.dialog_text = message + "\n\nPlease wait..."

func hide_loading():
	set_inputs_enabled(true)
	if loading_dialog and is_instance_valid(loading_dialog):
		loading_dialog.queue_free()
		loading_dialog = null

func set_inputs_enabled(enabled: bool):
	name_input.editable = enabled
	email_input.editable = enabled
	password_input.editable = enabled
	confirm_password_input.editable = enabled
	agreement_checkbox.disabled = not enabled
	terms_button.disabled = not enabled
	privacy_button.disabled = not enabled

func show_error_dialog(message: String):
	var error_dialog = AcceptDialog.new()
	add_child(error_dialog)
	error_dialog.theme = dialog_theme
	error_dialog.dialog_text = message
	error_dialog.title = "Error"
	error_dialog.confirmed.connect(_on_error_dialog_closed.bind(error_dialog))
	error_dialog.close_requested.connect(_on_error_dialog_closed.bind(error_dialog))
	error_dialog.min_size = Vector2(350, 150)  # Width x Height
	error_dialog.size = Vector2(350, 150)	
	error_dialog.popup_centered()

func _on_loading_dialog_close():
	if loading_dialog:
		loading_dialog.popup_centered()

func _on_error_dialog_closed(dialog: AcceptDialog):
	if dialog and is_instance_valid(dialog):
		dialog.queue_free()

func _on_hide_pressed() -> void:
	password_input.secret = !password_input.secret
	
	if hide_button:
		if password_input.secret:
			hide_button.texture_normal = eye_closed_icon  # Password hidden, show crossed eye
		else:
			hide_button.texture_normal = eye_open_icon

func _on_hidden_pressed() -> void:
	confirm_password_input.secret = !confirm_password_input.secret
	
	if hidden_button:
		if password_input.secret:
			hidden_button.texture_normal = eye_closed_icon  # Password hidden, show crossed eye
		else:
			hidden_button.texture_normal = eye_open_icon
