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

func _ready():
	# Initialize HTTP request for letter cache loading
	letter_cache_http_request = HTTPRequest.new()
	add_child(letter_cache_http_request)
	letter_cache_http_request.request_completed.connect(_on_letter_cache_request_completed)

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
	
# Call this after successful login
func load_all_letter_completion_data():
	if not is_logged_in or user_id == "":
		print("⚠️ User not logged in, skipping letter cache load")
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
