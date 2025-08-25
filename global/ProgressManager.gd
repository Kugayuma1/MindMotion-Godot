extends Node
@onready var http_request := HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

# 🔒 SUPER-SAFE VERSION
func save_progress(level_name: String, completed: bool) -> void:
	if not Global.is_logged_in or Global.user_id == "":
		push_error("Cannot save progress: user not logged in")
		return
	
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	var elapsed_time = Time.get_ticks_msec() - Global.start_time
	
	# Load local best + everCompleted
	var stored_best = get_local_best_time(level_name)
	var has_best = stored_best != -1
	var ever_completed_before = check_local_ever_completed(level_name)
	
	# --- Always send these base fields ---
	var progress_data = {
		"level_name": level_name,
		"lastAttemptTime": elapsed_time,
		"lastAttemptCompleted": completed,
		"lastPlayedAt": Time.get_datetime_string_from_system()
	}
	
	# --- Handle success ---
	if completed:
		progress_data["everCompleted"] = true
		mark_local_ever_completed(level_name)
		print("🎉 Level completed! Setting everCompleted = true")
		
		# On first ever completion → always set bestTime
		if not has_best:
			progress_data["bestTime"] = elapsed_time
			save_local_best_time(level_name, elapsed_time)
			print("🏆 FIRST BEST TIME: %d ms!" % elapsed_time)
		else:
			# Update only if better
			if elapsed_time < stored_best:
				progress_data["bestTime"] = elapsed_time
				save_local_best_time(level_name, elapsed_time)
				print("🏆 NEW BEST TIME: %d ms!" % elapsed_time)
			else:
				progress_data["bestTime"] = stored_best
				print("⏱️ Completed in %d ms (Best remains: %d ms)" % [elapsed_time, stored_best])
	
	# --- Handle fail ---
	else:
		if has_best:
			progress_data["bestTime"] = stored_best
		if ever_completed_before:
			progress_data["everCompleted"] = true
		print("❌ Failed attempt - preserving bestTime/everCompleted if they exist")
	
	# --- Debug printout ---
	print("📤 SENDING TO FIREBASE:")
	for key in progress_data.keys():
		print("  %s: %s" % [key, str(progress_data[key])])
	
	# --- Convert to Firestore format ---
	var fields = {}
	for key in progress_data.keys():
		fields[key] = to_firestore_field(progress_data[key])
	
	var body_json = {"fields": fields}
	
	# --- PATCH request ---
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels/%s" \
		% [project_id, uid, letter_id, level_name]
	
	var headers = [
		"Authorization: Bearer %s" % id_token,
		"Content-Type: application/json"
	]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
	if err != OK:
		push_error("❌ Firestore save request failed: %s" % err)

# --- Local storage functions ---
func get_local_best_time(level_name: String) -> int:
	var save_key = "best_time_%s_%s_%s" % [Global.user_id, Global.current_letter, level_name]
	var config = ConfigFile.new()
	var err = config.load("user://best_times.save")
	if err == OK:
		return config.get_value("best_times", save_key, -1)
	else:
		return -1

func save_local_best_time(level_name: String, time: int) -> void:
	var save_key = "best_time_%s_%s_%s" % [Global.user_id, Global.current_letter, level_name]
	var config = ConfigFile.new()
	config.load("user://best_times.save")
	config.set_value("best_times", save_key, time)
	config.save("user://best_times.save")

func check_local_ever_completed(level_name: String) -> bool:
	var save_key = "ever_completed_%s_%s_%s" % [Global.user_id, Global.current_letter, level_name]
	var config = ConfigFile.new()
	if config.load("user://best_times.save") == OK:
		return config.get_value("ever_completed", save_key, false)
	return false

func mark_local_ever_completed(level_name: String) -> void:
	var save_key = "ever_completed_%s_%s_%s" % [Global.user_id, Global.current_letter, level_name]
	var config = ConfigFile.new()
	config.load("user://best_times.save")
	config.set_value("ever_completed", save_key, true)
	config.save("user://best_times.save")

# --- HTTP completion handler ---
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()
	if response_code in [200, 201]:
		print("✅ Progress saved to Firebase")
		print("📥 Response: %s" % body_text)
	else:
		push_error("❌ Firestore save failed %s — %s" % [response_code, body_text])

# --- Firestore type conversion ---
func to_firestore_field(value):
	match typeof(value):
		TYPE_INT:
			return {"integerValue": str(value)}
		TYPE_FLOAT:
			return {"doubleValue": value}
		TYPE_BOOL:
			return {"booleanValue": value}
		TYPE_STRING:
			return {"stringValue": value}
		_:
			return {"stringValue": str(value)}
