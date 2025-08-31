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
	else: # forgot_password
		print("Password reset email sent to:", email_input.text if response_code == 200 else "Failed:", response)

func handle_login_success(response: Dictionary):
	print("Login successful! User:", response["localId"])
	
	Global.firebase_id_token = response["idToken"]
	Global.set_user_info(response["localId"], response["email"], "")
	
	if Global.user_type == "student":
		await load_student_data()
		get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
	else:
		hide_loading()
		get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")

func load_student_data():
	update_loading("Loading your progress...")
	Global.load_all_letter_completion_data()
	
	# Wait for letter cache
	var wait_time = 0.0
	while not Global.is_letter_cache_loaded and wait_time < 10.0:
		await get_tree().process_frame
		wait_time += 0.1
		await get_tree().create_timer(0.1).timeout
		if int(wait_time) % 2 == 0:
			update_loading("Loading progress... %d seconds" % int(wait_time))
	
	if not Global.is_letter_cache_loaded:
		Global.set_default_letter_cache()
	
	# Load priority stage data
	update_loading("Loading activities...")
	var priority_letters = ["A"]
	if Global.current_letter != "" and Global.current_letter != "A":
		priority_letters.append(Global.current_letter)
	
	for letter in ["B", "C", "D", "E", "F"]:
		if Global.is_letter_unlocked(letter) and priority_letters.size() < 4:
			priority_letters.append(letter)
	
	for letter in priority_letters:
		Global.load_letter_stages_on_demand(letter)
	
	await get_tree().create_timer(1.5).timeout
	update_loading("Almost ready...")
	await get_tree().create_timer(0.5).timeout
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
