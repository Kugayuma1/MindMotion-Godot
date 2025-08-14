extends Control

@onready var gender_option = $Container/Gender
@onready var name_input = $Container/Name
@onready var email_input = $Container/Email
@onready var password_input = $Container/Password
@onready var age_input = $Container/Age
@onready var agreement_checkbox = $Container/Password/Agree
@onready var http_request = $HTTPRequest

const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const FIRESTORE_URL = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents"

var current_stage = ""  # "signup" or "store_data"
var temp_uid = ""
var temp_id_token = ""

func _ready():
	var user_type = Global.user_type.capitalize()
	$Container/Hello.text = "Hello %s!" % user_type
	gender_option.add_item("Select Gender...")
	gender_option.add_item("Male")
	gender_option.add_item("Female")
	gender_option.selected = 0
	
	gender_option.item_selected.connect(_on_gender_item_selected)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
	
func _on_signup_pressed():
	var name = name_input.text.strip_edges()
	var email = email_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	var age = age_input.text.strip_edges()
	var gender_index = gender_option.selected
	var gender = gender_option.get_item_text(gender_index)
	
	# Field validation
	if name == "" or email == "" or password == "":
		print("Please fill in all required fields.")
		return
	if gender_index == 0:
		print("Please select a gender.")
		return
	if !agreement_checkbox.button_pressed:
		print("You must agree to Terms and Privacy Policy.")
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
			print("Student signup successful.")
			temp_uid = response["localId"]
			temp_id_token = response["idToken"]

			# Save to Global
			Global.set_user_type("student")
			Global.set_user_info(temp_uid, response["email"], name_input.text)

			# Now upload additional student info to Firestore
			current_stage = "store_data"
			var doc_url = "%s/users/%s" % [FIRESTORE_URL, temp_uid]
			var student_data = {
				"fields": {
					"name": {"stringValue": name_input.text},
					"email": {"stringValue": response["email"]},
					"userType": {"stringValue": "student"},
					"age": {"integerValue": str(age_input.text.strip_edges())},
					"gender": {"stringValue": gender_option.get_item_text(gender_option.selected)},
					"createdAt": {"integerValue": str(int(Time.get_unix_time_from_system()))}
				}
			}
			var request_headers = [
				"Content-Type: application/json",
				"Authorization: Bearer %s" % temp_id_token
			]
			http_request.request(doc_url, request_headers, HTTPClient.METHOD_PATCH, JSON.stringify(student_data))
		else:
			print("Signup failed:", response)

	elif current_stage == "store_data":
		if response_code == 200:
			print("Student data stored successfully.")
			get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
		else:
			print("Failed to store user data:", response)
	
func _on_gender_item_selected(index: int):
	if index == 0:
	# User tried to select hint, keep it selected
		gender_option.selected = 0
	else:
		print("Selected: ", gender_option.get_item_text(index))
