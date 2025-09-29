extends Node

# Global User Information
var user_type: String = ""
var user_id: String = ""
var user_email: String = ""
var user_name: String = ""
var is_logged_in: bool = false
var current_index = 0
var current_letter = ""
var start_time: int = 0
var temp_signup_data: Dictionary = {}

#Firebase
var firebase_id_token: String = ""
var firebase_refresh_token: String = ""
var token_expires_at: int = 0

# Student data cache (for teachers)
var students_cache = []
var is_students_cache_loaded = false
var students_cache_http_request: HTTPRequest
var selected_student_data: Dictionary = {}

# Firebase-only Caches
var letter_completion_cache = {}
var is_letter_cache_loaded = false
var letter_cache_http_request: HTTPRequest
var stage_completion_cache = {}
var stage_cache_loading_letters = {}

# Token refresh management
var refresh_http_request: HTTPRequest
var is_refreshing_token = false
var refresh_callbacks = []

# File paths - ONLY for auth and UI preferences
const AUTH_SAVE_PATH = "user://auth_data.save"
const UI_PREFS_PATH = "user://ui_preferences.save"

# Constants
const FIREBASE_API_KEY = "AIzaSyC7bPi7suzy8DmMFSgP7n090t7zHXzI5Bk"
const TOKEN_REFRESH_BUFFER = 300  # Refresh 5 minutes before expiry

# Signals
signal letter_cache_updated
signal stage_cache_updated(letter: String)
signal token_refreshed
signal authentication_failed
signal students_cache_updated

func _ready():
	# Initialize HTTP requests
	letter_cache_http_request = HTTPRequest.new()
	add_child(letter_cache_http_request)
	letter_cache_http_request.request_completed.connect(_on_letter_cache_request_completed)
	
	refresh_http_request = HTTPRequest.new()
	add_child(refresh_http_request)
	refresh_http_request.request_completed.connect(_on_refresh_token_completed)
	
	students_cache_http_request = HTTPRequest.new()
	add_child(students_cache_http_request)
	students_cache_http_request.request_completed.connect(_on_students_cache_request_completed)
	
	# Load saved data
	load_auth_data()
	load_ui_preferences()
	
	# Start token refresh timer
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 60.0
	timer.timeout.connect(_check_token_expiry)
	timer.start()

# UI PREFERENCES: Keep local for better UX
func save_ui_preferences():
	var prefs_data = {
		"current_letter": current_letter,
		"current_index": current_index
	}
	save_data_to_file(UI_PREFS_PATH, prefs_data)

func load_ui_preferences():
	var prefs_data = load_data_from_file(UI_PREFS_PATH, 720)  # 30 days
	
	if not prefs_data.is_empty():
		current_letter = prefs_data.get("current_letter", "A")
		current_index = prefs_data.get("current_index", 0)
	else:
		current_letter = "A"
		current_index = 0

# TOKEN MANAGEMENT
func _check_token_expiry():
	if not is_authenticated():
		return
	
	var current_time = Time.get_unix_time_from_system()
	var time_until_expiry = token_expires_at - current_time
	
	if time_until_expiry <= TOKEN_REFRESH_BUFFER and not is_refreshing_token:
		refresh_auth_token()

func refresh_auth_token(callback_function = null):
	if is_refreshing_token:
		if callback_function:
			refresh_callbacks.append(callback_function)
		return
	
	if firebase_refresh_token == "":
		authentication_failed.emit()
		return
		
	is_refreshing_token = true
	if callback_function:
		refresh_callbacks.append(callback_function)
		
	var url = "https://securetoken.googleapis.com/v1/token?key=" + FIREBASE_API_KEY
	var payload = "grant_type=refresh_token&refresh_token=%s" % firebase_refresh_token
	   
	refresh_http_request.request(
		url,
		["Content-Type: application/x-www-form-urlencoded"],
		HTTPClient.METHOD_POST,
		payload
	)

func _on_refresh_token_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	is_refreshing_token = false
	var response = JSON.parse_string(body.get_string_from_utf8())
	
	if response_code == 200:
		firebase_id_token = response["id_token"]
		firebase_refresh_token = response["refresh_token"]
		user_id = response["user_id"]
		
		var expires_in = int(response.get("expires_in", 3600))
		token_expires_at = Time.get_unix_time_from_system() + expires_in
		
		save_auth_data()
		
		for callback in refresh_callbacks:
			if typeof(callback) == TYPE_CALLABLE and callback.is_valid():
				callback.call()
		refresh_callbacks.clear()
		
		token_refreshed.emit()
	else:
		refresh_callbacks.clear()
		authentication_failed.emit()
		logout()

# Enhanced request helper
func make_authenticated_request(http_request: HTTPRequest, url: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: String = "", extra_headers: Array = [], callback_function = null):
	if not is_authenticated():
		return false
	
	var current_time = Time.get_unix_time_from_system()
	var time_until_expiry = token_expires_at - current_time
	
	if time_until_expiry <= TOKEN_REFRESH_BUFFER:
		refresh_auth_token(func(): make_authenticated_request(http_request, url, method, payload, extra_headers, callback_function))
		return true
	
	var headers = ["Authorization: Bearer %s" % firebase_id_token, "Content-Type: application/json"] + extra_headers
	var err = http_request.request(url, headers, method, payload)
	
	return err == OK

# FILE OPERATIONS
func save_data_to_file(file_path: String, data: Dictionary) -> bool:
	var save_file = FileAccess.open(file_path, FileAccess.WRITE)
	if save_file == null:
		return false
	
	data["save_timestamp"] = Time.get_unix_time_from_system()
	save_file.store_string(JSON.stringify(data))
	save_file.close()
	return true

func load_data_from_file(file_path: String, max_age_hours: float = 24) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	
	var save_file = FileAccess.open(file_path, FileAccess.READ)
	if save_file == null:
		return {}
	
	var json_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		return {}
	
	var data = json.data
	var save_timestamp = data.get("save_timestamp", 0)
	var hours_since_save = (Time.get_unix_time_from_system() - save_timestamp) / 3600.0
	
	if hours_since_save > max_age_hours:
		return {}
	
	return data

# AUTH MANAGEMENT
func save_auth_data():
	var auth_data = {
		"user_type": user_type,
		"user_id": user_id,
		"user_email": user_email,
		"user_name": user_name,
		"firebase_id_token": firebase_id_token,
		"firebase_refresh_token": firebase_refresh_token,
		"token_expires_at": token_expires_at,
		"is_logged_in": is_logged_in
	}
	save_data_to_file(AUTH_SAVE_PATH, auth_data)

func load_auth_data():
	var auth_data = load_data_from_file(AUTH_SAVE_PATH, 720)  # 30 days
	
	if auth_data.is_empty():
		return
	
	user_type = auth_data.get("user_type", "")
	user_id = auth_data.get("user_id", "")
	user_email = auth_data.get("user_email", "")
	user_name = auth_data.get("user_name", "")
	firebase_id_token = auth_data.get("firebase_id_token", "")
	firebase_refresh_token = auth_data.get("firebase_refresh_token", "")
	token_expires_at = auth_data.get("token_expires_at", 0)
	is_logged_in = auth_data.get("is_logged_in", false)
	
	if is_authenticated():
		var current_time = Time.get_unix_time_from_system()
		if token_expires_at - current_time <= TOKEN_REFRESH_BUFFER:
			refresh_auth_token(func(): 
				load_all_letter_completion_data()
				if user_type == "teacher":
					load_students_cache()
			)
		else:
			load_all_letter_completion_data()
			if user_type == "teacher":
				load_students_cache()
	else:
		clear_auth_data()

func clear_auth_data():
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)

# USER MANAGEMENT
func is_authenticated() -> bool:
	return (is_logged_in and user_id != "" and user_type != "" and 
			firebase_id_token != "" and firebase_refresh_token != "")

func set_user_type(type: String) -> void:
	user_type = type
	save_auth_data()

func set_user_info(uid: String, email: String, name: String, id_token: String = "", refresh_token: String = "") -> void:
	user_id = uid
	user_email = email
	user_name = name
	
	if id_token != "":
		firebase_id_token = id_token
	if refresh_token != "":
		firebase_refresh_token = refresh_token
		token_expires_at = Time.get_unix_time_from_system() + 3600
	
	is_logged_in = true
	save_auth_data()
	load_all_letter_completion_data()
	
	if user_type == "teacher":
		load_students_cache()

func logout() -> void:
	user_id = ""
	user_email = ""
	user_name = ""
	user_type = ""
	firebase_id_token = ""
	firebase_refresh_token = ""
	token_expires_at = 0
	is_logged_in = false
	letter_completion_cache.clear()
	is_letter_cache_loaded = false
	stage_completion_cache.clear()
	stage_cache_loading_letters.clear()
	refresh_callbacks.clear()
	students_cache.clear()
	is_students_cache_loaded = false
	clear_auth_data()
	
func clearData() -> void:
	user_id = ""
	user_email = ""
	user_name = ""
	firebase_id_token = ""
	firebase_refresh_token = ""
	token_expires_at = 0
	is_logged_in = false
	letter_completion_cache.clear()
	is_letter_cache_loaded = false
	stage_completion_cache.clear()
	stage_cache_loading_letters.clear()
	refresh_callbacks.clear()
	students_cache.clear()
	is_students_cache_loaded = false
	clear_auth_data()

# LETTER COMPLETION MANAGEMENT
func load_all_letter_completion_data():
	if not is_authenticated():
		return
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress" % user_id
	make_authenticated_request(letter_cache_http_request, url, HTTPClient.METHOD_GET)

func _on_letter_cache_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body_text) == OK:
			process_letter_cache_data(json.data)
		else:
			set_default_letter_cache()
	elif response_code == 401:
		refresh_auth_token(func(): load_all_letter_completion_data())
	else:
		set_default_letter_cache()

func process_letter_cache_data(data):
	letter_completion_cache.clear()
	letter_completion_cache["A"] = true  # Always unlocked
	
	if data.has("documents"):
		for doc in data.documents:
			var letter = doc.name.split("/")[-1]
			if doc.has("fields") and doc.fields.has("letterCompleted"):
				var is_completed = doc.fields.letterCompleted.booleanValue if doc.fields.letterCompleted.has("booleanValue") else false
				letter_completion_cache[letter] = is_completed
	
	is_letter_cache_loaded = true
	force_ui_refresh()
	load_priority_stage_data()

func force_ui_refresh():
	letter_cache_updated.emit()
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("refresh_carousel"):
		current_scene.refresh_carousel()
	elif current_scene and current_scene.has_method("update_letters_with_lock_status"):
		current_scene.update_letters_with_lock_status()

func set_default_letter_cache():
	letter_completion_cache.clear()
	letter_completion_cache["A"] = true
	is_letter_cache_loaded = true
	letter_cache_updated.emit()
	load_priority_stage_data()

func load_priority_stage_data():
	if not is_authenticated():
		return
	
	var priority_letters = []
	if current_letter != "":
		priority_letters.append(current_letter)
	if not priority_letters.has("A"):
		priority_letters.append("A")
	
	var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
				   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	
	for letter in letters:
		if is_letter_unlocked(letter) and not priority_letters.has(letter):
			priority_letters.append(letter)
			if priority_letters.size() >= 3:
				break
	
	for letter in priority_letters:
		load_letter_stages_on_demand(letter)

func is_letter_unlocked(letter: String) -> bool:
	if letter == "A":
		return true
	
	if is_logged_in and not is_letter_cache_loaded:
		return false
	
	var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
				   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return true
	
	var previous_letter = letters[letter_index - 1]
	return letter_completion_cache.get(previous_letter, false)

# STAGE COMPLETION MANAGEMENT
func get_default_stage_data() -> Dictionary:
	return {"reading": false, "fine_motor": false, "math": false, "art": false}

func get_stage_cache(letter: String):
	return stage_completion_cache.get(letter, get_default_stage_data()).duplicate()

func load_letter_stages_on_demand(letter: String):
	if stage_completion_cache.has(letter) or stage_cache_loading_letters.has(letter):
		return
	
	stage_cache_loading_letters[letter] = true
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		process_stage_data_response(letter, response_code, body.get_string_from_utf8())
		stage_cache_loading_letters.erase(letter)
		http_request.queue_free()
	)
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress/%s/levels" % [user_id, letter]
	make_authenticated_request(http_request, url)

func process_stage_data_response(letter: String, response_code: int, body_text: String):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body_text) == OK:
			var stage_data = parse_stage_data(json.data)
			stage_completion_cache[letter] = stage_data
			if letter == current_letter:
				stage_cache_updated.emit(letter)
	elif response_code == 401:
		refresh_auth_token(func(): load_letter_stages_on_demand(letter))
	elif response_code == 404:
		stage_completion_cache[letter] = get_default_stage_data()
		if letter == current_letter:
			stage_cache_updated.emit(letter)

func parse_stage_data(data) -> Dictionary:
	var stage_data = get_default_stage_data()
	
	if data.has("documents") and data.documents.size() > 0:
		for doc in data.documents:
			var stage_name = doc.name.split("/")[-1]
			if doc.has("fields") and doc.fields.has("everCompleted") and doc.fields.everCompleted.has("booleanValue"):
				if doc.fields.everCompleted.booleanValue == true:
					stage_data[stage_name] = true
	
	return stage_data

# UTILITY METHODS
func is_stage_completed(letter: String, stage: String) -> bool:
	var cached_data = get_stage_cache(letter)
	return cached_data.get(stage, false)

func is_stage_cache_ready() -> bool:
	return stage_completion_cache.has(current_letter) or current_letter == ""

func wait_for_stage_cache() -> void:
	if current_letter == "" or stage_completion_cache.has(current_letter):
		return
	
	var letter = await stage_cache_updated

func preload_letter_stages(letter: String):
	if not stage_completion_cache.has(letter):
		load_letter_stages_on_demand(letter)

func change_scene_with_cache_wait(scene_path: String):
	save_ui_preferences()
	get_tree().change_scene_to_file(scene_path)

func refresh_everything_after_stage_completion(stage_name: String, completed: bool):
	if not completed:
		return
	
	var current_letter = Global.current_letter
	
	# Update stage completion
	if not stage_completion_cache.has(current_letter):
		stage_completion_cache[current_letter] = get_default_stage_data()
	
	stage_completion_cache[current_letter][stage_name] = true
	
	# Check if letter is complete
	var required_stages = ["reading", "fine_motor", "math", "art"]
	var completed_count = 0
	
	for stage in required_stages:
		if stage_completion_cache[current_letter].get(stage, false):
			completed_count += 1
	
	# Update letter completion if all stages complete
	if completed_count == 4:
		letter_completion_cache[current_letter] = true
	
	# Refresh UI
	letter_cache_updated.emit()
	stage_cache_updated.emit(current_letter)
	
	var current_scene = get_tree().current_scene
	if current_scene:
		if current_scene.has_method("update_button_states"):
			current_scene.update_button_states()
		elif current_scene.has_method("refresh_carousel"):
			current_scene.refresh_carousel()
		elif current_scene.has_method("update_letters_with_lock_status"):
			current_scene.update_letters_with_lock_status()

# STUDENT CACHE MANAGEMENT
func load_students_cache():
	if not is_authenticated() or user_type != "teacher":
		return
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users"
	make_authenticated_request(students_cache_http_request, url, HTTPClient.METHOD_GET)

func _on_students_cache_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body_text) == OK:
			process_students_cache_data(json.data)
		else:
			set_empty_students_cache()
	elif response_code == 401:
		refresh_auth_token(func(): load_students_cache())
	else:
		set_empty_students_cache()

func process_students_cache_data(data):
	students_cache.clear()
	
	if not data.has("documents"):
		set_empty_students_cache()
		return
	
	# Filter and process student documents
	for doc in data.documents:
		var fields = doc.get("fields", {})
		var user_type_field = fields.get("userType", {}).get("stringValue", "")
		
		if user_type_field == "student":
			var student_data = extract_student_data_from_doc(doc)
			if not student_data.is_empty():
				students_cache.append(student_data)
	
	# Sort students alphabetically by name
	students_cache.sort_custom(func(a, b): return a.name.to_lower() < b.name.to_lower())
	
	is_students_cache_loaded = true
	students_cache_updated.emit()

func extract_student_data_from_doc(doc) -> Dictionary:
	var fields = doc.get("fields", {})
	
	# Extract user ID from document path
	var doc_path = doc.get("name", "")
	var user_id = doc_path.split("/")[-1]
	
	# Extract student information
	var student_data = {
		"user_id": user_id,
		"name": fields.get("name", {}).get("stringValue", "Unknown"),
		"email": fields.get("email", {}).get("stringValue", "No email"),
		"gender": fields.get("gender", {}).get("stringValue", "Male"),
		"age": int(fields.get("age", {}).get("integerValue", 0)),
		"created_at": int(fields.get("createdAt", {}).get("integerValue", 0))
	}
	
	# Validate essential data
	if student_data.name == "Unknown" or student_data.name == "":
		return {}
	
	return student_data

func set_empty_students_cache():
	students_cache.clear()
	is_students_cache_loaded = true
	students_cache_updated.emit()

func get_students_cache() -> Array:
	return students_cache.duplicate()

func is_students_cache_ready() -> bool:
	return is_students_cache_loaded

func get_student_by_id(student_id: String) -> Dictionary:
	for student in students_cache:
		if student.user_id == student_id:
			return student
	return {}

func refresh_students_cache():
	if user_type == "teacher":
		is_students_cache_loaded = false
		load_students_cache()

func wait_for_students_cache() -> void:
	# If already loaded, return immediately
	if is_students_cache_ready():
		return
	# Otherwise wait until the signal fires
	await students_cache_updated

func get_current_user_id() -> String:
	return user_id
