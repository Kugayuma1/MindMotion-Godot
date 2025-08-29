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
var start_time: int = 0

# Letter completion cache
var letter_completion_cache = {}
var is_letter_cache_loaded = false
var letter_cache_http_request: HTTPRequest

# Persistent auth file path
const AUTH_SAVE_PATH = "user://auth_data.save"

func _ready():
	# Initialize HTTP request for letter cache loading
	letter_cache_http_request = HTTPRequest.new()
	add_child(letter_cache_http_request)
	letter_cache_http_request.request_completed.connect(_on_letter_cache_request_completed)
	
	# Load saved authentication data on startup
	load_auth_data()

# Save authentication data to file
func save_auth_data():
	var save_file = FileAccess.open(AUTH_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		print("❌ Failed to create auth save file")
		return
	
	var auth_data = {
		"user_type": user_type,
		"user_id": user_id,
		"user_email": user_email,
		"user_name": user_name,
		"firebase_id_token": firebase_id_token,
		"is_logged_in": is_logged_in,
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	save_file.store_string(JSON.stringify(auth_data))
	save_file.close()
	print("💾 Auth data saved successfully")

# Load authentication data from file
func load_auth_data():
	if not FileAccess.file_exists(AUTH_SAVE_PATH):
		print("📁 No auth save file found")
		return
	
	var save_file = FileAccess.open(AUTH_SAVE_PATH, FileAccess.READ)
	if save_file == null:
		print("❌ Failed to open auth save file")
		return
	
	var json_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("❌ Failed to parse auth save file")
		return
	
	var auth_data = json.data
	
	# Check if the save data is recent (optional: expire after 30 days)
	var save_timestamp = auth_data.get("save_timestamp", 0)
	var current_time = Time.get_unix_time_from_system()
	var days_since_save = (current_time - save_timestamp) / (24 * 60 * 60)
	
	if days_since_save > 30:
		print("⏰ Auth data expired, requiring fresh login")
		clear_auth_data()
		return
	
	# Restore user data
	user_type = auth_data.get("user_type", "")
	user_id = auth_data.get("user_id", "")
	user_email = auth_data.get("user_email", "")
	user_name = auth_data.get("user_name", "")
	firebase_id_token = auth_data.get("firebase_id_token", "")
	is_logged_in = auth_data.get("is_logged_in", false)
	
	if is_logged_in and user_id != "" and firebase_id_token != "":
		print("✅ Auth data loaded successfully - User: %s (%s)" % [user_name, user_type])
		# Load letter completion data
		load_all_letter_completion_data()
	else:
		print("⚠️ Incomplete auth data, requiring fresh login")
		clear_auth_data()

# Clear saved authentication data
func clear_auth_data():
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)
		print("🗑️ Auth data cleared")

# Check if user is authenticated and data is valid
func is_authenticated() -> bool:
	return is_logged_in and user_id != "" and user_type != "" and firebase_id_token != ""

# Utility Methods
func set_user_type(type: String) -> void:
	user_type = type
	save_auth_data()  # Save when user type changes
	print("User type set to:", user_type)

func set_user_info(uid: String, email: String, name: String, token: String = "") -> void:
	user_id = uid
	user_email = email
	user_name = name
	if token != "":
		firebase_id_token = token
	is_logged_in = true
	save_auth_data()  # Save after successful login
	print("User logged in:", user_name, user_email)
	
	# Load letter completion data after login
	load_all_letter_completion_data()

func logout() -> void:
	user_id = ""
	user_email = ""
	user_name = ""
	user_type = ""
	firebase_id_token = ""
	is_logged_in = false
	letter_completion_cache.clear()
	is_letter_cache_loaded = false
	clear_auth_data()  # Clear saved data on logout
	print("User logged out.")

# Call this after successful login or when loading saved auth
func load_all_letter_completion_data():
	if not is_logged_in or user_id == "" or firebase_id_token == "":
		print("⚠️ User not logged in or missing token, skipping letter cache load")
		return
	
	print("📡 Loading all letter completion data...")
	
	var project_id = "mindmotion-55c99"
	var uid = user_id
	
	# Use Firestore's collection query to get all progress documents at once
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress" % [project_id, uid]
	
	var headers = [
		"Authorization: Bearer %s" % firebase_id_token,
		"Content-Type: application/json"
	]
	
	var err = letter_cache_http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("❌ Failed to load letter completion cache: %s" % err)
		# Set default cache (only A unlocked)
		set_default_letter_cache()

func _on_letter_cache_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body_text)
		
		if parse_result == OK:
			var data = json.data
			
			# Clear existing cache
			letter_completion_cache.clear()
			
			# Set A as always unlocked
			letter_completion_cache["A"] = true
			
			if data.has("documents"):
				# Process each document (each represents a letter's progress)
				for doc in data.documents:
					var letter = doc.name.split("/")[-1]  # Extract letter from document path
					
					if doc.has("fields") and doc.fields.has("letterCompleted"):
						var is_completed = doc.fields.letterCompleted.booleanValue if doc.fields.letterCompleted.has("booleanValue") else false
						letter_completion_cache[letter] = is_completed
						print("📊 Cached letter %s: %s" % [letter, is_completed])
			
			is_letter_cache_loaded = true
			print("✅ Letter completion cache loaded successfully: %s" % str(letter_completion_cache))
		else:
			push_error("❌ Failed to parse letter completion cache")
			set_default_letter_cache()
	else:
		print("⚠️ Letter completion cache request failed with code: %d" % response_code)
		# If token is expired (401/403), clear auth and require re-login
		if response_code == 401 or response_code == 403:
			print("🔐 Authentication token expired, clearing auth data")
			logout()
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
		else:
			set_default_letter_cache()

func set_default_letter_cache():
	letter_completion_cache.clear()
	letter_completion_cache["A"] = true  # A is always unlocked
	is_letter_cache_loaded = true
	print("📊 Set default letter cache (A unlocked only)")

# Helper function to check if a letter is unlocked (use this in LetterCarousel)
func is_letter_unlocked(letter: String) -> bool:
	# A is always unlocked
	if letter == "A":
		return true
	
	# Get all letters A-Z
	var letters = []
	for i in range(26):
		letters.append(String.chr(65 + i))
	
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return true  # Fallback
	
	# Check if previous letter is completed
	var previous_letter = letters[letter_index - 1]
	return letter_completion_cache.get(previous_letter, false)
