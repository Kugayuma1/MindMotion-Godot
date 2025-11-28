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

# Profile picture UI (add these to your scene)
@onready var profile_preview = $Container/VBoxContainer/ProfilePreview  # TextureRect node
@onready var upload_picture_button = $Container/VBoxContainer/UploadPictureButton  # Button node

var signup_loading_dialog: AcceptDialog = null
var dialog_theme = preload("res://assets/main_theme.tres")
var eye_open_icon = preload("res://assets/eye.png")
var eye_closed_icon = preload("res://assets/eyeofthetiger.png")

# Constants
const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"
const FIREBASE_STORAGE_URL = "https://firebasestorage.googleapis.com/v0/b/mindmotion-55c99.firebasestorage.app/o"

# State Management
enum Stage { SIGNUP, SEND_VERIFICATION, UPLOAD_PICTURE, STORE_DATA, CREATE_PROGRESS, CREATE_STAGES }
var current_stage: Stage
var temp_uid = ""
var temp_id_token = ""
var temp_refresh_token = ""
var temp_email = ""
var stages_to_create = ["reading", "fine_motor", "math", "art"]
var current_stage_index = 0

# Profile picture variables
var profile_image_path = ""
var profile_image_data: PackedByteArray
var profile_picture_url = ""
var upload_http_request: HTTPRequest = null
var has_profile_picture = false

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
	setup_profile_picture_upload()
	gender_option.theme = dialog_theme
	
	if hide_button:
		hide_button.texture_normal = eye_closed_icon
	
	# Setup verification timer
	verification_check_timer = Timer.new()
	add_child(verification_check_timer)
	verification_check_timer.timeout.connect(_check_email_verification)
	
	# Setup upload HTTP request
	upload_http_request = HTTPRequest.new()
	add_child(upload_http_request)
	upload_http_request.request_completed.connect(_on_upload_request_completed)
	
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

func setup_profile_picture_upload():
	if upload_picture_button:
		upload_picture_button.pressed.connect(_on_upload_picture_pressed)
		debug_print("Upload button connected", "✅")
	else:
		debug_print("WARNING: upload_picture_button node not found!", "⚠️")
	
	# Set default avatar in preview if it exists
	if profile_preview:
		var default_avatar = load("res://assets/addprofile.png")
		if default_avatar:
			profile_preview.texture = default_avatar
			debug_print("Default avatar loaded", "✅")
		else:
			debug_print("WARNING: default_avatar.png not found at res://assets/", "⚠️")
	else:
		debug_print("WARNING: profile_preview node not found!", "⚠️")

func restore_signup_data():
	if Global.temp_signup_data and Global.temp_signup_data.get("return_scene") == "student_signup":
		name_input.text = Global.temp_signup_data.get("name", "")
		email_input.text = Global.temp_signup_data.get("email", "")
		password_input.text = Global.temp_signup_data.get("password", "")
		age_input.text = Global.temp_signup_data.get("age", "")
		gender_option.selected = Global.temp_signup_data.get("gender", 0)
		terms_read = Global.temp_signup_data.get("terms_read", false)
		privacy_read = Global.temp_signup_data.get("privacy_read", false)
		
		# Restore profile picture data
		profile_image_data = Global.temp_signup_data.get("profile_image_data", PackedByteArray())
		has_profile_picture = Global.temp_signup_data.get("has_profile_picture", false)
		
		# Restore the preview if there's image data
		if has_profile_picture and not profile_image_data.is_empty() and profile_preview:
			var image = Image.new()
			var error = image.load_png_from_buffer(profile_image_data)
			if error == OK:
				var texture = ImageTexture.create_from_image(image)
				profile_preview.texture = texture
				debug_print("Profile picture restored from saved data", "✅")
			else:
				debug_print("Failed to restore profile picture preview", "⚠️")
		
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
		"profile_image_data": profile_image_data,
		"has_profile_picture": has_profile_picture,
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
		"profile_image_data": profile_image_data,
		"has_profile_picture": has_profile_picture,
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

# Profile Picture Upload Functions - UPDATED FOR ANDROID
func _on_upload_picture_pressed():
	# Request permissions on Android
	if OS.get_name() == "Android":
		var permissions = OS.get_granted_permissions()
		if permissions.find("android.permission.READ_MEDIA_IMAGES") == -1 and permissions.find("android.permission.READ_EXTERNAL_STORAGE") == -1:
			OS.request_permissions()
			await get_tree().create_timer(0.5).timeout
	
	debug_print("Opening image picker...", "📱")
	
	# Use native file picker (Android will use media picker automatically)
	DisplayServer.file_dialog_show(
		"Select Profile Picture",
		OS.get_system_dir(OS.SYSTEM_DIR_PICTURES),
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png", "*.jpg", "*.jpeg", "*.webp"],
		_on_native_image_selected
	)

func _on_native_image_selected(status: bool, selected_paths: PackedStringArray, selected_filter_index: int):
	if not status or selected_paths.is_empty():
		debug_print("Image selection cancelled", "❌")
		return
	
	var path = selected_paths[0]
	debug_print("Image selected from native picker: %s" % path, "📁")
	_on_image_file_selected(path)

# UPDATED: Handle both Android content URIs and desktop file paths
func _on_image_file_selected(path: String):
	profile_image_path = path
	debug_print("Image file selected: %s" % path, "📁")
	
	var image = Image.new()
	var error: int
	
	# Check if it's an Android content URI or if we're on Android
	if path.begins_with("content://") or OS.get_name() == "Android":
		debug_print("Loading image from Android content URI...", "📱")
		
		# Read the file as bytes first
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			var file_error = FileAccess.get_open_error()
			debug_print("Failed to open file. Error code: %d" % file_error, "❌")
			show_error_dialog("Failed to access the selected image. Please try again or check app permissions.")
			return
		
		var file_data = file.get_buffer(file.get_length())
		file.close()
		
		debug_print("Read %d bytes from file" % file_data.size(), "✅")
		
		# Try to load as different formats
		error = image.load_png_from_buffer(file_data)
		if error != OK:
			debug_print("Not PNG, trying JPG...", "🔄")
			error = image.load_jpg_from_buffer(file_data)
		if error != OK:
			debug_print("Not JPG, trying WebP...", "🔄")
			error = image.load_webp_from_buffer(file_data)
		
		if error != OK:
			debug_print("Failed to load image from buffer. Error: %d" % error, "❌")
			show_error_dialog("Failed to load image. Please select a valid PNG, JPG, or WebP file.")
			return
	else:
		# Desktop: Direct file path loading
		debug_print("Loading image from desktop path...", "💻")
		error = image.load(path)
		
		if error != OK:
			debug_print("Failed to load image. Error: %d" % error, "❌")
			show_error_dialog("Failed to load image. Please select a valid image file.")
			return
	
	debug_print("Image loaded successfully: %dx%d" % [image.get_width(), image.get_height()], "✅")
	
	# Resize image to reasonable size (512x512 max)
	var max_size = 512
	if image.get_width() > max_size or image.get_height() > max_size:
		var scale = min(max_size / float(image.get_width()), max_size / float(image.get_height()))
		var new_width = int(image.get_width() * scale)
		var new_height = int(image.get_height() * scale)
		image.resize(new_width, new_height, Image.INTERPOLATE_LANCZOS)
		debug_print("Image resized to %dx%d" % [new_width, new_height], "🔧")
	
	# Convert to PNG bytes for upload
	profile_image_data = image.save_png_to_buffer()
	has_profile_picture = true
	
	debug_print("Image processed: %d bytes ready for upload" % profile_image_data.size(), "🖼️")
	
	# Update preview
	if profile_preview:
		var texture = ImageTexture.create_from_image(image)
		profile_preview.texture = texture
		debug_print("Preview updated", "✅")

func upload_profile_picture():
	if profile_image_data.is_empty():
		debug_print("No profile picture to upload", "ℹ️")
		return
	
	debug_print("Uploading profile picture (%d bytes)..." % profile_image_data.size(), "📤")
	
	# Create unique filename using UID
	var filename = "profile_pictures/%s.png" % temp_uid
	var encoded_filename = filename.uri_encode()
	
	# Firebase Storage upload URL
	var upload_url = "%s/%s" % [FIREBASE_STORAGE_URL, encoded_filename]
	
	debug_print("Upload URL: %s" % upload_url, "🔗")
	
	# Headers for upload
	var headers = [
		"Content-Type: image/png",
		"Authorization: Bearer %s" % temp_id_token
	]
	
	# Upload the image - use request_raw for binary data
	current_stage = Stage.UPLOAD_PICTURE
	upload_http_request.request_raw(upload_url, headers, HTTPClient.METHOD_POST, profile_image_data)

func _on_upload_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if current_stage != Stage.UPLOAD_PICTURE:
		return
	
	debug_print("Upload request completed - Result: %d, Response Code: %d" % [result, response_code], "📡")
	
	if response_code == 200:
		# Generate the download URL
		var filename = "profile_pictures/%s.png" % temp_uid
		var encoded_filename = filename.uri_encode()
		profile_picture_url = "https://firebasestorage.googleapis.com/v0/b/mindmotion-55c99.firebasestorage.app/o/%s?alt=media" % encoded_filename
		
		debug_print("Profile picture uploaded successfully!", "✅")
		debug_print("Download URL: %s" % profile_picture_url, "🔗")
		
		# Update the user document with the profile picture URL
		update_signup_loading("Updating profile picture...")
		update_profile_picture_in_firestore()
	else:
		debug_print("Failed to upload profile picture: %d" % response_code, "❌")
		var response_text = body.get_string_from_utf8()
		debug_print("Error details: %s" % response_text, "❌")
		debug_print("Result code meaning: %s" % get_result_string(result), "ℹ️")
		
		# Continue without profile picture
		profile_picture_url = ""
		update_signup_loading("Setting up your activities...")
		current_stage = Stage.CREATE_PROGRESS
		create_initial_progress_data()

func update_profile_picture_in_firestore():
	debug_print("Updating Firestore with profile picture URL", "📝")
	
	# Use updateMask to only update the profilePicture field
	var doc_url = "%s/users/%s?updateMask.fieldPaths=profilePicture" % [FIRESTORE_URL, temp_uid]
	var update_data = {
		"fields": {
			"profilePicture": {"stringValue": profile_picture_url}
		}
	}
	
	var temp_http = HTTPRequest.new()
	add_child(temp_http)
	
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % temp_id_token
	]
	
	temp_http.request(doc_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(update_data))
	
	var response = await temp_http.request_completed
	var response_code = response[1]
	
	temp_http.queue_free()
	
	if response_code == 200:
		debug_print("Profile picture URL updated in Firestore", "✅")
	else:
		debug_print("Failed to update profile picture URL: %d" % response_code, "⚠️")
		var body = response[3] as PackedByteArray
		debug_print("Response: %s" % body.get_string_from_utf8(), "❌")
	
	# Continue with progress setup
	update_signup_loading("Setting up your activities...")
	current_stage = Stage.CREATE_PROGRESS
	create_initial_progress_data()

func get_result_string(result: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS: return "SUCCESS"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: return "CHUNKED_BODY_SIZE_MISMATCH"
		HTTPRequest.RESULT_CANT_CONNECT: return "CANT_CONNECT"
		HTTPRequest.RESULT_CANT_RESOLVE: return "CANT_RESOLVE"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "CONNECTION_ERROR"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "TLS_HANDSHAKE_ERROR"
		HTTPRequest.RESULT_NO_RESPONSE: return "NO_RESPONSE"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "BODY_SIZE_LIMIT_EXCEEDED"
		HTTPRequest.RESULT_REQUEST_FAILED: return "REQUEST_FAILED"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "DOWNLOAD_FILE_CANT_OPEN"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "DOWNLOAD_FILE_WRITE_ERROR"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "REDIRECT_LIMIT_REACHED"
		HTTPRequest.RESULT_TIMEOUT: return "TIMEOUT"
		_: return "UNKNOWN_ERROR"

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
	
	if age == "" or not age.is_valid_int() or int(age) < 6 or int(age) > 12:
		show_error_dialog("Please enter a valid age between 6 and 12")
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
	verify_dialog.min_size = Vector2(400, 200)
	verify_dialog.size = Vector2(400, 200)
	
	var ok_button = verify_dialog.get_ok_button()
	ok_button.text = "Cancel Signup"

	verify_dialog.confirmed.connect(cancel_verification)
	
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
			show_signup_loading("Email verified! Setting up your profile...")
			proceed_with_account_creation()
		else:
			debug_print("Email not yet verified, will check again...", "⏳")
	
	temp_http.queue_free()

func proceed_with_account_creation():
	# Set user info with Firebase UID
	Global.set_user_type("student")
	Global.set_user_info(temp_uid, temp_email, name_input.text, temp_id_token, temp_refresh_token)
	
	# First create the user document, THEN upload profile picture
	update_signup_loading("Creating your profile...")
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
		
		# Now upload profile picture if provided (AFTER user document is created)
		if has_profile_picture and not profile_image_data.is_empty():
			update_signup_loading("Uploading profile picture...")
			upload_profile_picture()
		else:
			# No profile picture, continue to progress setup
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
	
	# Build user data with optional profile picture
	var fields = {
		"name": {"stringValue": name_input.text.strip_edges()},
		"email": {"stringValue": temp_email},
		"userType": {"stringValue": "student"},
		"age": {"integerValue": age_input.text.strip_edges()},
		"gender": {"stringValue": gender_option.get_item_text(gender_option.selected)},
		"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))},
		"emailVerified": {"booleanValue": true}
	}
	
	# Add profile picture URL if available
	if profile_picture_url != "":
		fields["profilePicture"] = {"stringValue": profile_picture_url}
		debug_print("Adding profile picture to user document: %s" % profile_picture_url, "🖼️")
	else:
		fields["profilePicture"] = {"stringValue": ""}  # Empty string for no picture
	
	var student_data = {
		"fields": fields
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
	
	if upload_picture_button:
		upload_picture_button.disabled = not enabled

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
