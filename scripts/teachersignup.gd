extends Control

@onready var name_input = $Container/Name
@onready var email_input = $Container/Email
@onready var password_input = $Container/Password
@onready var confirm_password_input = $Container/Confirm
@onready var agreement_checkbox = $Container/Confirm/Agreee
@onready var http_request = $HTTPRequest

const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"

var current_stage = ""  # "signup" or "store_data"
var temp_uid = ""
var temp_id_token = ""

func _ready():
	var user_type = Global.user_type.capitalize()
	$Container/Hello.text = "Hello %s!" % user_type

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
	
func _on_signup_pressed():
	var name = name_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var confirm_password = confirm_password_input.text.strip_edges()

	if name == "" or email == "" or password == "" or confirm_password == "":
		print("Please fill in all required fields.")
		return

	if password != confirm_password:
		print("Passwords do not match.")
		return

	if !agreement_checkbox.button_pressed:
		print("You must agree to the Terms and Privacy Policy.")
		return

	# Begin Firebase sign-up
	current_stage = "signup"
	var signup_url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + FIREBASE_API_KEY
	var payload = {
		"email": email,
		"password": password,
		"returnSecureToken": true
	}
	http_request.request(signup_url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload))



func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var response = JSON.parse_string(body.get_string_from_utf8())

	if current_stage == "signup":
		if response_code == 200:
			print("Teacher signup successful.")
			temp_uid = response["localId"]
			temp_id_token = response["idToken"]

			Global.set_user_type("teacher")
			Global.set_user_info(temp_uid, response["email"], name_input.text)

			current_stage = "store_data"
			var doc_url = "%s/users/%s" % [FIRESTORE_URL, temp_uid]
			var teacher_data = {
				"fields": {
					"name": {"stringValue": name_input.text},
					"email": {"stringValue": response["email"]},
					"userType": {"stringValue": "teacher"},
					"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))}
				}
			}
			var request_headers = [
				"Content-Type: application/json",
				"Authorization: Bearer %s" % temp_id_token
			]
			http_request.request(doc_url, request_headers, HTTPClient.METHOD_PATCH, JSON.stringify(teacher_data))
		else:
			print("Signup failed:", response)

	elif current_stage == "store_data":
		if response_code == 200:
			print("Teacher data stored successfully.")
			get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")
		else:
			print("Failed to store teacher data:", response)
