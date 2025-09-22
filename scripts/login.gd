extends Control

@onready var password_input = $Container/Password
@onready var email_input = $Container/Email
@onready var login_button = $Container/LoginButton
@onready var http_request = $HTTPRequest

const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"

var current_request_type: String = ""
var loading_dialog: AcceptDialog = null
var original_login_text: String = ""

func _ready():
	$Container/HelloLabel.text = "Hello %s!" % Global.user_type.capitalize()
	if login_button:
		original_login_text = login_button.text
	
	# Connect to Global's authentication signals
	Global.authentication_failed.connect(_on_authentication_failed)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if email == "" or password == "":
		print("Email or password cannot be empty.")
		return
	
	show_loading("Signing in...")
	current_request_type = "login"
	make_request("signInWithPassword", {"email": email, "password": password, "returnSecureToken": true})

func _on_forget_pressed():
	var email = email_input.text.strip_edges()
	if email == "":
		print("Please enter your email.")
		return
	current_request_type = "forgot_password"
	make_request("sendOobCode", {"requestType": "PASSWORD_RESET", "email": email})

func _on_hide_pressed():
	password_input.secret = !password_input.secret

func make_request(endpoint: String, data: Dictionary):
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:%s?key=%s" % [endpoint, FIREBASE_API_KEY]
	http_request.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if current_request_type == "login":
		if response_code == 200:
			await handle_login_success(response)
		else:
			hide_loading()
			print("Login failed:", response)
			
			# Show user-friendly error message
			var error_message = "Login failed. Please check your credentials."
			if response and response.has("error") and response.error.has("message"):
				var firebase_error = response.error.message
				if "INVALID_PASSWORD" in firebase_error or "EMAIL_NOT_FOUND" in firebase_error:
					error_message = "Invalid email or password."
				elif "USER_DISABLED" in firebase_error:
					error_message = "This account has been disabled."
				elif "TOO_MANY_ATTEMPTS_TRY_LATER" in firebase_error:
					error_message = "Too many failed attempts. Please try again later."
			
			show_error_dialog(error_message)
	else: # forgot_password
		hide_loading()
		if response_code == 200:
			show_info_dialog("Password reset email sent to: " + email_input.text)
		else:
			show_error_dialog("Failed to send password reset email. Please check your email address.")

func handle_login_success(response: Dictionary):
	print("Login successful! User:", response["localId"])
	
	# Extract tokens from response
	var id_token = response.get("idToken", "")
	var refresh_token = response.get("refreshToken", "")
	
	# Set user info with both tokens
	Global.set_user_info(
		response["localId"], 
		response["email"], 
		"",  # Name will be loaded from Firestore if needed
		id_token,
		refresh_token
	)
	
	if Global.user_type == "student":
		await load_student_data()
		get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
	else:
		hide_loading()
		get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")

func load_student_data():
	update_loading("Loading your progress...")
	Global.load_all_letter_completion_data()
	
	# Wait for letter cache with better timeout handling
	var wait_time = 0.0
	while not Global.is_letter_cache_loaded and wait_time < 15.0:  # Increased timeout
		await get_tree().process_frame
		wait_time += 0.1
		await get_tree().create_timer(0.1).timeout
		if int(wait_time) % 3 == 0:
			update_loading("Loading progress... %d seconds" % int(wait_time))
	
	if not Global.is_letter_cache_loaded:
		print("⚠️ Letter cache timeout - using safe defaults")
		Global.set_default_letter_cache()
	
	# Don't pre-load stage data - let it load on-demand
	# This reduces login time and prevents sync issues
	update_loading("Almost ready...")
	await get_tree().create_timer(1.0).timeout
	hide_loading()

func show_loading(message: String):
	set_inputs_enabled(false)
	if login_button:
		login_button.text = "Loading..."
	
	loading_dialog = AcceptDialog.new()
	add_child(loading_dialog)
	loading_dialog.dialog_text = message + "\n\nPlease wait..."
	loading_dialog.title = "Loading"
	loading_dialog.get_ok_button().visible = false
	loading_dialog.close_requested.connect(func(): loading_dialog.popup_centered())
	loading_dialog.popup_centered()

func update_loading(message: String):
	if loading_dialog and is_instance_valid(loading_dialog):
		loading_dialog.dialog_text = message + "\n\nPlease wait..."

func hide_loading():
	set_inputs_enabled(true)
	if login_button:
		login_button.text = original_login_text
	if loading_dialog and is_instance_valid(loading_dialog):
		loading_dialog.queue_free()
		loading_dialog = null

func set_inputs_enabled(enabled: bool):
	if login_button:
		login_button.disabled = not enabled
	email_input.editable = enabled
	password_input.editable = enabled

func show_error_dialog(message: String):
	var error_dialog = AcceptDialog.new()
	add_child(error_dialog)
	error_dialog.dialog_text = message
	error_dialog.title = "Error"
	error_dialog.popup_centered()
	
	# Auto-cleanup when closed
	error_dialog.confirmed.connect(func(): error_dialog.queue_free())
	error_dialog.close_requested.connect(func(): error_dialog.queue_free())

func show_info_dialog(message: String):
	var info_dialog = AcceptDialog.new()
	add_child(info_dialog)
	info_dialog.dialog_text = message
	info_dialog.title = "Information"
	info_dialog.popup_centered()
	
	# Auto-cleanup when closed
	info_dialog.confirmed.connect(func(): info_dialog.queue_free())
	info_dialog.close_requested.connect(func(): info_dialog.queue_free())

func _on_authentication_failed():
	hide_loading()
	show_error_dialog("Your session has expired. Please log in again.")
	
	# Clear the form
	email_input.text = ""
	password_input.text = ""


func _on_signup_pressed() -> void:
	pass # Replace with function body.
