extends Node

# Global User Information
var user_type: String = ""
var user_id: String = ""
var user_email: String = ""
var user_name: String = ""
var is_logged_in: bool = false
var current_index = 0
var current_letter = ""
var firebase_id_token: String = ""
var start_time: int = 0

# Caches
var letter_completion_cache = {}
var is_letter_cache_loaded = false
var letter_cache_http_request: HTTPRequest
var stage_completion_cache = {}
var is_stage_cache_loaded = false
var stage_cache_loading_letters = {}

# File paths
const AUTH_SAVE_PATH = "user://auth_data.save"
const STAGE_CACHE_PATH = "user://stage_cache.save"

# Signals
signal letter_cache_updated
signal stage_cache_updated(letter: String)

# Debug helper
func debug_print(message: String, category: String = "Global", icon: String = "📋"):
	print("[%s] %s %s" % [category, icon, message])

func _ready():
	letter_cache_http_request = HTTPRequest.new()
	add_child(letter_cache_http_request)
	letter_cache_http_request.request_completed.connect(_on_letter_cache_request_completed)
	load_auth_data()
	load_local_stage_cache()

# File Operations
func save_data_to_file(file_path: String, data: Dictionary):
	var save_file = FileAccess.open(file_path, FileAccess.WRITE)
	if save_file == null:
		debug_print("Failed to create save file: %s" % file_path, "FileOp", "❌")
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
		debug_print("Failed to open file: %s" % file_path, "FileOp", "❌")
		return {}
	
	var json_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	if json.parse(json_text) != OK:
		debug_print("Failed to parse JSON from: %s" % file_path, "FileOp", "❌")
		return {}
	
	var data = json.data
	var save_timestamp = data.get("save_timestamp", 0)
	var hours_since_save = (Time.get_unix_time_from_system() - save_timestamp) / 3600.0
	
	if hours_since_save > max_age_hours:
		debug_print("Data expired in: %s" % file_path, "FileOp", "⏰")
		return {}
	
	return data

# Auth Management
func save_auth_data():
	var auth_data = {
		"user_type": user_type, "user_id": user_id, "user_email": user_email,
		"user_name": user_name, "firebase_id_token": firebase_id_token, "is_logged_in": is_logged_in
	}
	if save_data_to_file(AUTH_SAVE_PATH, auth_data):
		debug_print("Auth data saved", "Auth", "💾")

func load_auth_data():
	var auth_data = load_data_from_file(AUTH_SAVE_PATH, 720)  # 30 days
	
	if auth_data.is_empty():
		debug_print("No valid auth data found", "Auth", "📁")
		return
	
	user_type = auth_data.get("user_type", "")
	user_id = auth_data.get("user_id", "")
	user_email = auth_data.get("user_email", "")
	user_name = auth_data.get("user_name", "")
	firebase_id_token = auth_data.get("firebase_id_token", "")
	is_logged_in = auth_data.get("is_logged_in", false)
	
	if is_authenticated():
		debug_print("Auth loaded - User: %s (%s)" % [user_name, user_type], "Auth", "✅")
		load_all_letter_completion_data()
	else:
		debug_print("Incomplete auth data", "Auth", "⚠️")
		clear_auth_data()

func clear_auth_data():
	if FileAccess.file_exists(AUTH_SAVE_PATH):
		DirAccess.remove_absolute(AUTH_SAVE_PATH)
	if FileAccess.file_exists(STAGE_CACHE_PATH):
		DirAccess.remove_absolute(STAGE_CACHE_PATH)

# Stage Cache Management
func save_local_stage_cache():
	var cache_data = {"stage_completion_cache": stage_completion_cache}
	if save_data_to_file(STAGE_CACHE_PATH, cache_data):
		debug_print("Stage cache saved to disk", "Cache", "💾")

func load_local_stage_cache():
	var cache_data = load_data_from_file(STAGE_CACHE_PATH, 1)  # 1 hour
	
	if not cache_data.is_empty():
		stage_completion_cache = cache_data.get("stage_completion_cache", {})
		debug_print("Stage cache loaded: %d letters" % stage_completion_cache.size(), "Cache", "✅")

# User Management
func is_authenticated() -> bool:
	return is_logged_in and user_id != "" and user_type != "" and firebase_id_token != ""

func set_user_type(type: String) -> void:
	user_type = type
	save_auth_data()

func set_user_info(uid: String, email: String, name: String, token: String = "") -> void:
	user_id = uid
	user_email = email
	user_name = name
	if token != "":
		firebase_id_token = token
	is_logged_in = true
	save_auth_data()
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
	stage_completion_cache.clear()
	is_stage_cache_loaded = false
	stage_cache_loading_letters.clear()
	clear_auth_data()
	debug_print("User logged out", "Auth", "🚪")

# Letter Completion Management
func load_all_letter_completion_data():
	if not is_authenticated():
		debug_print("Not authenticated, skipping letter cache", "LetterCache", "⚠️")
		return
	
	debug_print("Loading letter completion data", "LetterCache", "📡")
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress" % user_id
	var headers = ["Authorization: Bearer %s" % firebase_id_token, "Content-Type: application/json"]
	
	var err = letter_cache_http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		debug_print("Failed to request letter cache: %s" % err, "LetterCache", "❌")
		set_default_letter_cache()

func _on_letter_cache_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body_text) == OK:
			process_letter_cache_data(json.data)
		else:
			debug_print("Failed to parse letter cache", "LetterCache", "❌")
			set_default_letter_cache()
	else:
		debug_print("Letter cache request failed: %d" % response_code, "LetterCache", "⚠️")
		if response_code in [401, 403]:
			logout()
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
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
	debug_print("Letter cache loaded: %s" % str(letter_completion_cache), "LetterCache", "✅")
	
	# Force immediate UI refresh
	force_ui_refresh()
	load_priority_stage_data()

func force_ui_refresh():
	debug_print("Forcing UI refresh after cache update", "LetterCache", "🔄")
	letter_cache_updated.emit()
	
	# Also refresh current scene if it has update methods
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.has_method("refresh_carousel"):
		current_scene.refresh_carousel()
	elif current_scene and current_scene.has_method("update_letters_with_lock_status"):
		current_scene.update_letters_with_lock_status()
		

func set_default_letter_cache():
	letter_completion_cache.clear()
	letter_completion_cache["A"] = true  # ✅ A should ALWAYS be unlocked
	
	# For new accounts, only A should be unlocked
	# Don't set other letters to false explicitly - absence means locked
	
	is_letter_cache_loaded = true
	debug_print("Set default letter cache: A=true", "LetterCache", "📊")
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
	
	debug_print("Loading priority stages: %s" % str(priority_letters), "StageCache", "🎯")
	for letter in priority_letters:
		load_letter_stages_on_demand(letter)

func is_letter_unlocked(letter: String) -> bool:
	if letter == "A":
		return true  # A is ALWAYS unlocked
	
	# Wait for cache to load if we're logged in
	if is_logged_in and not is_letter_cache_loaded:
		debug_print("Cache not ready, assuming locked for %s" % letter, "LetterCache", "⏳")
		return false
	
	var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
				   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return true
	
	var previous_letter = letters[letter_index - 1]
	return letter_completion_cache.get(previous_letter, false)

# Stage Completion Management
func get_default_stage_data() -> Dictionary:
	return {"reading": false, "fine_motor": false, "math": false, "art": false}

func get_stage_cache(letter: String):
	return stage_completion_cache.get(letter, get_default_stage_data()).duplicate()

func set_stage_cache(letter: String, stage_data: Dictionary):
	stage_completion_cache[letter] = stage_data.duplicate()
	save_local_stage_cache()

func load_letter_stages_on_demand(letter: String):
	if stage_completion_cache.has(letter) or stage_cache_loading_letters.has(letter):
		return
	
	debug_print("Loading stages for letter %s" % letter, "StageCache", "📡")
	stage_cache_loading_letters[letter] = true
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		process_stage_data_response(letter, response_code, body.get_string_from_utf8())
		stage_cache_loading_letters.erase(letter)
		http_request.queue_free()
	)
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress/%s/levels" % [user_id, letter]
	var headers = ["Authorization: Bearer %s" % firebase_id_token, "Content-Type: application/json"]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		debug_print("Failed to request stages for %s: %s" % [letter, err], "StageCache", "❌")
		stage_cache_loading_letters.erase(letter)
		http_request.queue_free()

func process_stage_data_response(letter: String, response_code: int, body_text: String):
	if response_code == 200:
		var json = JSON.new()
		if json.parse(body_text) == OK:
			var stage_data = parse_stage_data(json.data)
			set_stage_cache(letter, stage_data)
			debug_print("Loaded stages for %s: %s" % [letter, str(stage_data)], "StageCache", "✅")
			if letter == current_letter:
				stage_cache_updated.emit(letter)
		else:
			debug_print("Failed to parse stage JSON for %s" % letter, "StageCache", "❌")
	elif response_code == 404:
		debug_print("No progress for %s - using defaults" % letter, "StageCache", "🆕")
		set_stage_cache(letter, get_default_stage_data())
	else:
		debug_print("Stage request failed for %s: %d" % [letter, response_code], "StageCache", "⚠️")

func parse_stage_data(data) -> Dictionary:
	var stage_data = get_default_stage_data()
	
	if data.has("documents") and data.documents.size() > 0:
		for doc in data.documents:
			var stage_name = doc.name.split("/")[-1]
			if doc.has("fields") and doc.fields.has("everCompleted") and doc.fields.everCompleted.has("booleanValue"):
				if doc.fields.everCompleted.booleanValue == true:
					stage_data[stage_name] = true
	
	return stage_data

func mark_stage_completed(letter: String, stage: String):
	if not stage_completion_cache.has(letter):
		stage_completion_cache[letter] = get_default_stage_data()
	
	stage_completion_cache[letter][stage] = true
	save_local_stage_cache()
	stage_cache_updated.emit(letter)
	debug_print("Stage %s completed for %s" % [stage, letter], "StageCache", "✅")

# Utility Methods
func is_stage_completed(letter: String, stage: String) -> bool:
	var cached_data = get_stage_cache(letter)
	return cached_data.get(stage, false)

func is_stage_cache_ready() -> bool:
	return stage_completion_cache.has(current_letter) or current_letter == ""

func wait_for_stage_cache() -> void:
	if current_letter == "":
		return
	
	var elapsed_time = 0.0
	while not stage_completion_cache.has(current_letter) and elapsed_time < 2.0:
		await Engine.get_main_loop().process_frame
		elapsed_time += 0.1
		await Engine.get_main_loop().create_timer(0.1).timeout
	
	var status = "ready" if stage_completion_cache.has(current_letter) else "timed out"
	debug_print("Stage cache %s for %s" % [status, current_letter], "StageCache", "⏳")

func refresh_category_locks():
	var current_scene = get_tree().current_scene
	if current_scene.has_method("refresh_stage_locks"):
		current_scene.refresh_stage_locks()
	elif current_scene.has_method("update_button_states"):
		current_scene.update_button_states()

func preload_letter_stages(letter: String):
	if not stage_completion_cache.has(letter):
		debug_print("Preloading stages for %s" % letter, "StageCache", "🚀")
		load_letter_stages_on_demand(letter)

func debug_cache_status():
	debug_print("=== CACHE STATUS ===", "Debug")
	debug_print("Letter cache: %s loaded, %d entries" % [is_letter_cache_loaded, letter_completion_cache.size()], "Debug")
	debug_print("Stage cache: %d letters cached" % stage_completion_cache.size(), "Debug")
	debug_print("Loading: %s" % str(stage_cache_loading_letters.keys()), "Debug")

func change_scene_with_cache_wait(scene_path: String):
	# Since login/signup now handles cache loading, this can be simple
	debug_print("Changing scene: %s (cache loaded: %s)" % [scene_path, is_letter_cache_loaded], "Scene", "🔄")
	get_tree().change_scene_to_file(scene_path)
