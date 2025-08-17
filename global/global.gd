extends Node

# Global User Information
var user_type: String = ""     # "student" or "teacher"
var user_id: String = ""       # Firebase UID
var user_email: String = ""
var user_name: String = ""
var is_logged_in: bool = false
var current_index = 0
var current_letter = ""
var firebase_id_token: String = ""   # store after login

# Utility Methods
func set_user_type(type: String) -> void:
	user_type = type
	print("User type set to:", user_type)

func set_user_info(uid: String, email: String, name: String) -> void:
	user_id = uid
	user_email = email
	user_name = name
	is_logged_in = true
	print("User logged in:", user_name, user_email)

func logout() -> void:
	user_id = ""
	user_email = ""
	user_name = ""
	user_type = ""
	is_logged_in = false
	print("User logged out.")
