extends Node
@onready var http_request := HTTPRequest.new()
@onready var levels_http_request := HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	add_child(levels_http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	levels_http_request.request_completed.connect(_on_levels_http_request_completed)

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
	
	# Store completion info for callback
	http_request.set_meta("should_update_stats", completed)
	http_request.set_meta("completed_level", level_name)
	http_request.set_meta("attempt_time", elapsed_time)
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
	if err != OK:
		push_error("❌ Firestore save request failed: %s" % err)
	else:
		# Also save the last attempt time locally for calculations
		if completed:
			save_last_attempt_time(level_name, elapsed_time)

# 📊 UPDATE LEVELS COLLECTION
func update_levels_collection(completed_level: String, attempt_time: int) -> void:
	if not Global.is_logged_in or Global.user_id == "":
		return
	
	print("🔄 UPDATE_LEVELS_COLLECTION CALLED:")
	print("  - Completed Level: %s" % completed_level)
	print("  - Attempt Time: %d ms" % attempt_time)
	print("  - User ID: %s" % Global.user_id)
	print("  - Current Letter: %s" % Global.current_letter)
	
	# Calculate stats directly from local storage
	calculate_and_update_from_local(completed_level, attempt_time)

# 📊 CALCULATE FROM LOCAL STORAGE AND UPDATE (FIXED VERSION)
func calculate_and_update_from_local(completed_level: String, attempt_time: int) -> void:
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	# Define the 4 required stages
	var required_stages = ["reading", "fine_motor", "math", "art"]
	var completed_stages = []
	var total_attempt_time = 0
	
	print("🔍 CHECKING LOCAL COMPLETION STATUS:")
	
	# Check each stage from local storage
	for stage in required_stages:
		var is_completed = check_local_ever_completed(stage)
		if is_completed:
			completed_stages.append(stage)
			var stage_time = get_stage_last_attempt_time(stage)
			if stage_time > 0:
				total_attempt_time += stage_time
				print("  ✅ %s completed with time: %d ms" % [stage, stage_time])
			else:
				print("  ✅ %s completed (no time recorded)" % stage)
		else:
			print("  ❌ %s not completed yet" % stage)
	
	print("📊 SUMMARY:")
	print("  - Completed stages: %s" % str(completed_stages))
	print("  - Total stages completed: %d" % completed_stages.size())
	print("  - Total time: %d ms" % total_attempt_time)
	
	# Calculate new values
	var new_completed_levels = completed_stages.size()
	var new_average_time = 0
	
	# Calculate average time only from completed stages
	if completed_stages.size() > 0 and total_attempt_time > 0:
		new_average_time = total_attempt_time / completed_stages.size()
	
	var new_letter_completed = (completed_stages.size() == 4)
	
	print("📈 CALCULATED STATS:")
	print("  - completedLevels: %d" % new_completed_levels)
	print("  - averageTime: %d ms" % new_average_time)
	print("  - letterCompleted: %s" % str(new_letter_completed))
	
	# Update the main letter document
	update_letter_stats(new_completed_levels, new_average_time, new_letter_completed)

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

# 💾 SAVE LAST ATTEMPT TIME LOCALLY
func save_last_attempt_time(level_name: String, time: int) -> void:
	var save_key = "last_attempt_time_%s_%s_%s" % [Global.user_id, Global.current_letter, level_name]
	var config = ConfigFile.new()
	config.load("user://best_times.save")
	config.set_value("last_attempts", save_key, time)
	config.save("user://best_times.save")

# --- HTTP completion handlers ---
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()
	
	if response_code in [200, 201]:
		print("✅ Progress saved to Firebase")
		print("📥 Response: %s" % body_text)
		
		# Check if we should update stats after successful save
		var should_update = http_request.get_meta("should_update_stats", false)
		var completed_level = http_request.get_meta("completed_level", "")
		var attempt_time = http_request.get_meta("attempt_time", 0)
		
		# Clear metadata
		http_request.remove_meta("should_update_stats")
		http_request.remove_meta("completed_level")
		http_request.remove_meta("attempt_time")
		
		# Update stats if this was a completion
		if should_update and completed_level != "":
			print("🔄 Triggering stats update after successful completion save")
			calculate_and_update_from_local(completed_level, attempt_time)
	else:
		# Clear metadata on failure too
		http_request.remove_meta("should_update_stats")
		http_request.remove_meta("completed_level")
		http_request.remove_meta("attempt_time")
		push_error("❌ Firestore save failed %s — %s" % [response_code, body_text])

func _on_levels_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()
	
	if response_code in [200, 201]:
		print("📥 Levels data fetched successfully")
		
		var json = JSON.new()
		var parse_result = json.parse(body_text)
		
		if parse_result == OK:
			var completed_level = levels_http_request.get_meta("completed_level")
			var attempt_time = levels_http_request.get_meta("attempt_time")
			
			# Clear metadata
			levels_http_request.remove_meta("completed_level")
			levels_http_request.remove_meta("attempt_time")
			
			# ✅ FIXED: Use the correct function name
			calculate_and_update_from_local(completed_level, attempt_time)
		else:
			push_error("❌ Failed to parse levels data JSON")
	else:
		push_error("❌ Failed to fetch levels data: %s — %s" % [response_code, body_text])

# 🎯 UPDATE LETTER STATS (the main document fields)
func update_letter_stats(completed_levels: int, average_time: int, letter_completed: bool) -> void:
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	print("📤 UPDATING LETTER DOCUMENT:")
	print("  - Document path: users/%s/progress/%s" % [uid, letter_id])
	print("  - completedLevels: %d" % completed_levels)
	print("  - averageTime: %d ms" % average_time)
	print("  - letterCompleted: %s" % str(letter_completed))
	
	# Prepare update data for the main letter document
	var stats_data = {
		"completedLevels": completed_levels,
		"averageTime": average_time,
		"letterCompleted": letter_completed,
	}
	
	# Convert to Firestore format
	var fields = {}
	for key in stats_data.keys():
		fields[key] = to_firestore_field(stats_data[key])
	
	var body_json = {"fields": fields}
	
	print("📡 FIRESTORE REQUEST:")
	print("  - Body: %s" % JSON.stringify(body_json))
	
	# Update the main letter document (same level as the levels collection)
	var stats_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s" \
		% [project_id, uid, letter_id]
	
	print("  - URL: %s" % stats_url)
	
	var headers = [
		"Authorization: Bearer %s" % id_token,
		"Content-Type: application/json"
	]
	
	# Create a new HTTP request for the stats update
	var update_request = HTTPRequest.new()
	add_child(update_request)
	update_request.request_completed.connect(_on_levels_update_completed.bind(update_request))
	
	var err = update_request.request(stats_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
	if err != OK:
		push_error("❌ Letter stats update request failed: %s" % err)
		update_request.queue_free()
	else:
		print("✅ Letter stats update request sent successfully")

# 🔍 CHECK STAGE COMPLETION FROM LOCAL STORAGE
func check_stage_completion_from_local(stage_name: String) -> bool:
	return check_local_ever_completed(stage_name)

# ⏱️ GET STAGE LAST ATTEMPT TIME FROM LOCAL STORAGE
func get_stage_last_attempt_time(stage_name: String) -> int:
	var save_key = "last_attempt_time_%s_%s_%s" % [Global.user_id, Global.current_letter, stage_name]
	var config = ConfigFile.new()
	if config.load("user://best_times.save") == OK:
		return config.get_value("last_attempts", save_key, 0)
	return 0

func _on_levels_update_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, sender: HTTPRequest) -> void:
	var body_text = body.get_string_from_utf8()
	
	print("📥 LETTER STATS UPDATE RESPONSE:")
	print("  - Response Code: %d" % response_code)
	print("  - Response Body: %s" % body_text)
	
	if response_code in [200, 201]:
		print("✅ Letter stats updated successfully!")
	else:
		push_error("❌ Letter stats update failed %d — %s" % [response_code, body_text])
	
	# Clean up the temporary HTTPRequest node
	sender.queue_free()

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
