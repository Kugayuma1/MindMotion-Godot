extends Control

@onready var password_input = $Container/Password
@onready var email_input = $Container/Email
@onready var eye_button = $Container/Password/Hide
@onready var http_request = $HTTPRequest

const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"

var current_request_type: String = ""

func _ready():
	var user_type = Global.user_type.capitalize()
	$Container/HelloLabel.text = "Hello %s!" % user_type

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_login_pressed():
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if email == "" or password == "":
		print("Email or password cannot be empty.")
		return
		
	current_request_type = "login"
		
	var url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" + FIREBASE_API_KEY
	var data = {
		"email": email,
		"password": password,
		"returnSecureToken": true
	}
	var headers = ["Content-Type: application/json"]
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))
	
func _on_forget_pressed():
	var email = email_input.text.strip_edges()

	if email == "":
		print("Please enter your email.")
		return

	current_request_type = "forgot_password"

	var url = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=" + FIREBASE_API_KEY
	var data = {
		"requestType": "PASSWORD_RESET",
		"email": email
	}
	var headers = ["Content-Type: application/json"]
	http_request.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(data))

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())

	if current_request_type == "login":
		if response_code == 200:
			print("Login successful!")
			print("ID Token:", response["idToken"])
			print("User ID (UID):", response["localId"])
			
			Global.set_user_info(response["localId"], response["email"], "")
			
			if Global.user_type == "student":
				get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
			elif Global.user_type == "teacher":
				get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")
			else:
				print("Unknown user type:", Global.user_type)
		else:
			print("Login failed:", response)
	elif current_request_type == "forgot_password":
		if response_code == 200:
			print("Password reset email sent to:", email_input.text)
		else:
			print("Failed to send reset email:", response)

func _on_hide_pressed():
	password_input.secret = !password_input.secret
