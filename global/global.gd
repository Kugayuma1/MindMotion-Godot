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

# Letter completion cache
var letter_completion_cache = {}
var is_letter_cache_loaded = false
var letter_cache_http_request: HTTPRequest

# Stage completion cache - IMPROVED
var stage_completion_cache = {}
var is_stage_cache_loaded = false
var stage_cache_loading_letters = {}  # Track which letters are currently being loaded

# Persistent auth file path
const AUTH_SAVE_PATH = "user://auth_data.save"
const STAGE_CACHE_PATH = "user://stage_cache.save"  # NEW: Local stage cache

# Add these signals to your Global.gd at the top:
signal letter_cache_updated
signal stage_cache_updated(letter: String)

func _ready():
	# Initialize HTTP request for letter cache loading
	letter_cache_http_request = HTTPRequest.new()
	add_child(letter_cache_http_request)
	letter_cache_http_request.request_completed.connect(_on_letter_cache_request_completed)
	
	# Load saved data on startup
	load_auth_data()
	load_local_stage_cache()  # NEW: Load cached stage data from disk

# NEW: Save stage cache to disk for faster startup
func save_local_stage_cache():
	var save_file = FileAccess.open(STAGE_CACHE_PATH, FileAccess.WRITE)
	if save_file == null:
		print("❌ Failed to create stage cache file")
		return
	
	var cache_data = {
		"stage_completion_cache": stage_completion_cache,
		"save_timestamp": Time.get_unix_time_from_system()
	}
	
	save_file.store_string(JSON.stringify(cache_data))
	save_file.close()
	print("💾 Stage cache saved to disk")

# NEW: Load stage cache from disk
func load_local_stage_cache():
	if not FileAccess.file_exists(STAGE_CACHE_PATH):
		print("📁 No local stage cache found")
		return
	
	var save_file = FileAccess.open(STAGE_CACHE_PATH, FileAccess.READ)
	if save_file == null:
		print("❌ Failed to open stage cache file")
		return
	
	var json_text = save_file.get_as_text()
	save_file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("❌ Failed to parse stage cache file")
		return
	
	var cache_data = json.data
	
	# Check if cache is recent (expire after 1 hour for stage data)
	var save_timestamp = cache_data.get("save_timestamp", 0)
	var current_time = Time.get_unix_time_from_system()
	var hours_since_save = (current_time - save_timestamp) / (60 * 60)
	
	if hours_since_save > 1:  # Cache for 1 hour only
		print("⏰ Stage cache expired")
		return
	
	# Load cached stage data
	stage_completion_cache = cache_data.get("stage_completion_cache", {})
	print("✅ Stage cache loaded from disk: %d letters cached" % stage_completion_cache.size())

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
	
	# Check if the save data is recent (expire after 30 days)
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
	save_auth_data()
	print("User type set to:", user_type)

func set_user_info(uid: String, email: String, name: String, token: String = "") -> void:
	user_id = uid
	user_email = email
	user_name = name
	if token != "":
		firebase_id_token = token
	is_logged_in = true
	save_auth_data()
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
	stage_completion_cache.clear()
	is_stage_cache_loaded = false
	stage_cache_loading_letters.clear()
	clear_auth_data()
	# Clear stage cache file too
	if FileAccess.file_exists(STAGE_CACHE_PATH):
		DirAccess.remove_absolute(STAGE_CACHE_PATH)
	print("User logged out.")

func load_all_letter_completion_data():
	if not is_logged_in or user_id == "" or firebase_id_token == "":
		print("⚠️ User not logged in or missing token, skipping letter cache load")
		return
	
	print("📡 Loading all letter completion data...")
	
	var project_id = "mindmotion-55c99"
	var uid = user_id
	
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress" % [project_id, uid]
	
	var headers = [
		"Authorization: Bearer %s" % firebase_id_token,
		"Content-Type: application/json"
	]
	
	var err = letter_cache_http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("❌ Failed to load letter completion cache: %s" % err)
		set_default_letter_cache()

# Modify the _on_letter_cache_request_completed function in Global.gd:
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
				for doc in data.documents:
					var letter = doc.name.split("/")[-1]
					
					if doc.has("fields") and doc.fields.has("letterCompleted"):
						var is_completed = doc.fields.letterCompleted.booleanValue if doc.fields.letterCompleted.has("booleanValue") else false
						letter_completion_cache[letter] = is_completed
						print("📊 Cached letter %s: %s" % [letter, is_completed])
			
			is_letter_cache_loaded = true
			print("✅ Letter completion cache loaded successfully: %s" % str(letter_completion_cache))
			
			# EMIT SIGNAL TO NOTIFY UI
			letter_cache_updated.emit()
			
			# Load priority stage data for better UX
			load_priority_stage_data()
		else:
			push_error("❌ Failed to parse letter completion cache")
			set_default_letter_cache()
	else:
		print("⚠️ Letter completion cache request failed with code: %d" % response_code)
		if response_code == 401 or response_code == 403:
			print("🔐 Authentication token expired, clearing auth data")
			logout()
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
		else:
			set_default_letter_cache()

# Also update set_default_letter_cache to emit the signal:
func set_default_letter_cache():
	letter_completion_cache.clear()
	letter_completion_cache["A"] = true
	is_letter_cache_loaded = true
	print("📊 Set default letter cache (A unlocked only)")
	
	# EMIT SIGNAL HERE TOO
	letter_cache_updated.emit()
	
	# Still try to load some stage data
	load_priority_stage_data()

# IMPROVED: Load stage data for the most important letters only
func load_priority_stage_data():
	if not is_authenticated():
		print("⚠️ Not authenticated, skipping priority stage data load")
		return
	
	var priority_letters = []
	
	# Always include current letter if set
	if current_letter != "":
		priority_letters.append(current_letter)
	
	# Include letter A (always unlocked)
	if not priority_letters.has("A"):
		priority_letters.append("A")
	
	# Include the next unlocked letter based on letter completion
	var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
				   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	
	for letter in letters:
		if is_letter_unlocked(letter) and not priority_letters.has(letter):
			priority_letters.append(letter)
			if priority_letters.size() >= 3:  # Limit to 3 letters for faster loading
				break
	
	print("🎯 Loading priority stage data for letters: %s" % str(priority_letters))
	
	for letter in priority_letters:
		load_letter_stages_on_demand(letter)

# Helper function to check if a letter is unlocked
func is_letter_unlocked(letter: String) -> bool:
	if letter == "A":
		return true
	
	var letters = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", 
				   "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
	
	var letter_index = letters.find(letter)
	if letter_index <= 0:
		return true
	
	var previous_letter = letters[letter_index - 1]
	return letter_completion_cache.get(previous_letter, false)

# IMPROVED: Get cached stage completion data with better defaults
func get_stage_cache(letter: String):
	var cached_data = stage_completion_cache.get(letter, null)
	
	if cached_data == null:
		# Return safe default - only reading unlocked
		return {
			"reading": true,
			"fine_motor": false,
			"math": false,
			"art": false
		}
	
	return cached_data.duplicate()

# Cache stage completion data for a specific letter
func set_stage_cache(letter: String, stage_data: Dictionary):
	stage_completion_cache[letter] = stage_data.duplicate()
	print("💾 Cached stage data for letter %s" % letter)
	
	# Save to disk for persistence
	save_local_stage_cache()

# IMPROVED: Load stage data for a specific letter on demand (non-blocking)
func load_letter_stages_on_demand(letter: String):
	# Check if already cached
	if stage_completion_cache.has(letter):
		print("📋 Stage data for letter %s already cached" % letter)
		return
	
	# Check if already loading
	if stage_cache_loading_letters.has(letter):
		print("⏳ Stage data for letter %s already loading" % letter)
		return
	
	print("📡 Loading stage data for letter %s on demand..." % letter)
	stage_cache_loading_letters[letter] = true
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	http_request.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
		var body_text = body.get_string_from_utf8()
		
		if response_code == 200:
			var json = JSON.new()
			var parse_result = json.parse(body_text)
			
			if parse_result == OK:
				var data = json.data
				var stage_data = {
					"reading": true,  # Always unlocked
					"fine_motor": false,
					"math": false,
					"art": false
				}
				
				if data.has("documents"):
					for doc in data.documents:
						var stage_name = doc.name.split("/")[-1]
						if doc.has("fields") and doc.fields.has("everCompleted"):
							var is_completed = doc.fields.everCompleted.booleanValue if doc.fields.everCompleted.has("booleanValue") else false
							stage_data[stage_name] = is_completed
				
				# Cache the stage data
				set_stage_cache(letter, stage_data)
				print("✅ Loaded stages for letter %s: %s" % [letter, stage_data])
			else:
				print("❌ Failed to parse stage data for letter %s" % letter)
		else:
			print("⚠️ Stage data request failed for letter %s with code: %d" % [letter, response_code])
		
		# Remove from loading list and cleanup
		stage_cache_loading_letters.erase(letter)
		http_request.queue_free()
	)
	
	var project_id = "mindmotion-55c99"
	var uid = user_id
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels" % [project_id, uid, letter]
	
	var headers = [
		"Authorization: Bearer %s" % firebase_id_token,
		"Content-Type: application/json"
	]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("❌ Failed to request stage data for letter %s: %s" % [letter, err])
		stage_cache_loading_letters.erase(letter)
		http_request.queue_free()

# Method to update stage completion (call this when a stage is completed)
func mark_stage_completed(letter: String, stage: String):
	print("✅ Stage %s completed for letter %s" % [stage, letter])
	
	# Update local cache immediately
	if not stage_completion_cache.has(letter):
		stage_completion_cache[letter] = {
			"reading": true,
			"fine_motor": false,
			"math": false,
			"art": false
		}
	
	stage_completion_cache[letter][stage] = true
	
	# Save updated cache to disk
	save_local_stage_cache()
	
	# Refresh UI immediately
	refresh_category_locks()

# Helper method to check stage completion for a specific letter and stage
func is_stage_completed(letter: String, stage: String) -> bool:
	var cached_data = get_stage_cache(letter)
	if cached_data:
		return cached_data.get(stage, false)
	return false

# Method to check if stage cache is ready
func is_stage_cache_ready() -> bool:
	return stage_completion_cache.has(current_letter) or current_letter == ""

# Method to wait for stage cache to load (useful for scenes)
func wait_for_stage_cache() -> void:
	if current_letter == "":
		return
	
	var max_wait_time = 2.0  # Reduced to 2 seconds
	var wait_interval = 0.1
	var elapsed_time = 0.0
	
	while not stage_completion_cache.has(current_letter) and elapsed_time < max_wait_time:
		await Engine.get_main_loop().process_frame
		elapsed_time += wait_interval
		await Engine.get_main_loop().create_timer(wait_interval).timeout
	
	if not stage_completion_cache.has(current_letter):
		print("⚠️ Stage cache loading timed out for letter %s" % current_letter)
	else:
		print("✅ Stage cache ready for letter %s" % current_letter)

# Method to refresh category locks in the current scene
func refresh_category_locks():
	var current_scene = get_tree().current_scene
	if current_scene.has_method("refresh_stage_locks"):
		current_scene.refresh_stage_locks()
	elif current_scene.has_method("update_button_states"):
		current_scene.update_button_states()

# IMPROVED: Method to preload stage data when changing letters
func preload_letter_stages(letter: String):
	if stage_completion_cache.has(letter):
		print("📋 Stage data for letter %s already available" % letter)
		return
	
	print("🚀 Preloading stage data for letter %s" % letter)
	load_letter_stages_on_demand(letter)

# Method to clear expired cache entries
func cleanup_expired_cache():
	# This could be called periodically to keep memory usage down
	# For now, we'll keep it simple and rely on the disk cache expiry
	print("🧹 Cache cleanup (placeholder for future implementation)")

# Debug method to print current cache status
func debug_cache_status():
	print("=== CACHE DEBUG INFO ===")
	print("Letter cache loaded: %s" % is_letter_cache_loaded)
	print("Letter completion cache: %s" % str(letter_completion_cache))
	print("Stage completion cache: %d letters" % stage_completion_cache.size())
	for letter in stage_completion_cache.keys():
		print("  Letter %s: %s" % [letter, str(stage_completion_cache[letter])])
	print("Currently loading letters: %s" % str(stage_cache_loading_letters.keys()))
	print("========================")

func change_scene_with_cache_wait(scene_path: String):
	print("🔄 Changing scene with cache preload: %s" % scene_path)
	
	if is_logged_in and not is_letter_cache_loaded:
		print("⏳ Cache not ready, waiting...")
		
		# Start loading if not already started
		if not letter_cache_http_request:
			load_all_letter_completion_data()
		
		# Wait for cache to load (max 2 seconds)
		var wait_time = 0.0
		var max_wait = 2.0
		
		while not is_letter_cache_loaded and wait_time < max_wait:
			await get_tree().process_frame
			wait_time += 0.1
			await get_tree().create_timer(0.1).timeout
		
		if not is_letter_cache_loaded:
			print("⚠️ Cache loading timeout, using defaults")
			set_default_letter_cache()
		else:
			print("✅ Cache loaded successfully")
	
	# Now change scene
	get_tree().change_scene_to_file(scene_path)
