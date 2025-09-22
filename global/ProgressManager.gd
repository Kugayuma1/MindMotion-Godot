extends Node
@onready var http_request := HTTPRequest.new()
@onready var levels_http_request := HTTPRequest.new()
@onready var fetch_request := HTTPRequest.new()

func _ready() -> void:
	add_child(http_request)
	add_child(levels_http_request)
	add_child(fetch_request)
	http_request.request_completed.connect(_on_http_request_completed)
	levels_http_request.request_completed.connect(_on_levels_http_request_completed)
	fetch_request.request_completed.connect(_on_fetch_request_completed)

# FIREBASE-FIRST APPROACH: Always fetch current data before saving
func save_progress(level_name: String, completed: bool) -> void:
	if not Global.is_logged_in or Global.user_id == "":
		push_error("Cannot save progress: user not logged in")
		return
	
	var elapsed_time = Time.get_ticks_msec() - Global.start_time
	print("🎯 Saving progress: %s = %s (%d ms)" % [level_name, str(completed), elapsed_time])
	
	# STEP 1: Fetch current Firebase data before saving
	fetch_current_progress_then_save(level_name, completed, elapsed_time)

# NEW: Fetch current Firebase data to prevent overwrites
func fetch_current_progress_then_save(level_name: String, completed: bool, elapsed_time: int):
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	print("📡 Fetching current Firebase data before saving...")
	
	# Store parameters for after fetch
	fetch_request.set_meta("level_name", level_name)
	fetch_request.set_meta("completed", completed)
	fetch_request.set_meta("elapsed_time", elapsed_time)
	fetch_request.set_meta("operation", "save_progress")
	
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels/%s" \
		% [project_id, uid, letter_id, level_name]
	
	var headers = ["Authorization: Bearer %s" % id_token]
	
	var err = fetch_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("❌ Failed to fetch current progress: %s" % err)
		# Fallback to saving without current data
		save_progress_with_current_data(level_name, completed, elapsed_time, {})

func _on_fetch_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var operation = fetch_request.get_meta("operation", "")
	
	if operation == "save_progress":
		handle_save_progress_fetch_response(response_code, body.get_string_from_utf8())
	
	# Clear metadata
	fetch_request.remove_meta("level_name")
	fetch_request.remove_meta("completed")
	fetch_request.remove_meta("elapsed_time")
	fetch_request.remove_meta("operation")

func handle_save_progress_fetch_response(response_code: int, body_text: String):
	var level_name = fetch_request.get_meta("level_name", "")
	var completed = fetch_request.get_meta("completed", false)
	var elapsed_time = fetch_request.get_meta("elapsed_time", 0)
	
	var current_data = {}
	
	if response_code == 200:
		# Parse existing Firebase data
		var json = JSON.new()
		if json.parse(body_text) == OK and json.data.has("fields"):
			current_data = parse_firestore_fields(json.data.fields)
			print("📥 Current Firebase data for %s: %s" % [level_name, str(current_data)])
		else:
			print("⚠️ Failed to parse existing data, treating as new entry")
	elif response_code == 404:
		print("📄 No existing data found for %s, creating new entry" % level_name)
	else:
		print("⚠️ Fetch error %d for %s, proceeding anyway" % [response_code, level_name])
	
	# Proceed with save using Firebase data
	save_progress_with_current_data(level_name, completed, elapsed_time, current_data)

func save_progress_with_current_data(level_name: String, completed: bool, elapsed_time: int, current_data: Dictionary):
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	# Extract current Firebase values (NOT local cache)
	var current_ever_completed = current_data.get("everCompleted", false)
	var current_best_time = current_data.get("bestTime", 0)
	
	print("🔍 Firebase state for %s:" % level_name)
	print("  - Current everCompleted: %s" % str(current_ever_completed))
	print("  - Current bestTime: %d ms" % current_best_time)
	print("  - New attempt: %s (%d ms)" % [str(completed), elapsed_time])
	
	# Always include these base fields
	var progress_data = {
		"level_name": level_name,
		"lastAttemptTime": elapsed_time,
		"lastAttemptCompleted": completed,
		"lastPlayedAt": Time.get_datetime_string_from_system()
	}
	
	# Handle success case
	if completed:
		# Always set everCompleted to true on completion
		progress_data["everCompleted"] = true
		print("🎉 Level completed! Setting everCompleted = true")
		
		# Handle best time logic
		if current_best_time == 0:
			# First completion - always set best time
			progress_data["bestTime"] = elapsed_time
			print("🏆 FIRST COMPLETION - Best time: %d ms!" % elapsed_time)
		elif elapsed_time < current_best_time:
			# New best time
			progress_data["bestTime"] = elapsed_time
			print("🏆 NEW BEST TIME: %d ms (was %d ms)!" % [elapsed_time, current_best_time])
		else:
			# Keep existing best time
			progress_data["bestTime"] = current_best_time
			print("⏱️ Completed in %d ms (best remains: %d ms)" % [elapsed_time, current_best_time])
	else:
		# Failed attempt - preserve existing Firebase values
		progress_data["everCompleted"] = current_ever_completed
		if current_best_time > 0:
			progress_data["bestTime"] = current_best_time
		print("❌ Failed attempt - preserving Firebase values")
	
	# Debug output
	print("📤 SENDING TO FIREBASE:")
	for key in progress_data.keys():
		print("  %s: %s" % [key, str(progress_data[key])])
	
	# Convert to Firestore format and save
	var fields = {}
	for key in progress_data.keys():
		fields[key] = to_firestore_field(progress_data[key])
	
	var body_json = {"fields": fields}
	
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

# Handle individual level save response
func _on_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code in [200, 201]:
		print("✅ Progress saved to Firebase successfully")
		
		var should_update = http_request.get_meta("should_update_stats", false)
		var completed_level = http_request.get_meta("completed_level", "")
		var attempt_time = http_request.get_meta("attempt_time", 0)
		
		# Clear metadata
		http_request.remove_meta("should_update_stats")
		http_request.remove_meta("completed_level")
		http_request.remove_meta("attempt_time")
		
		if should_update and completed_level != "":
			print("🔄 Triggering Firebase-based stats update")
			calculate_and_update_from_firebase(completed_level, attempt_time)
	else:
		# Clear metadata on failure
		http_request.remove_meta("should_update_stats")
		http_request.remove_meta("completed_level")
		http_request.remove_meta("attempt_time")
		push_error("❌ Firestore save failed %s — %s" % [response_code, body_text])

# FIREBASE-BASED STATS CALCULATION: No more local dependencies
func calculate_and_update_from_firebase(completed_level: String, attempt_time: int) -> void:
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	print("🔍 CALCULATING STATS FROM FIREBASE:")
	print("  - User: %s" % uid)
	print("  - Letter: %s" % letter_id)
	print("  - Just completed: %s" % completed_level)
	
	# Fetch current progress from Firebase
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels" % [project_id, uid, letter_id]
	
	var headers = ["Authorization: Bearer %s" % id_token]
	
	# Store completion info for callback
	levels_http_request.set_meta("completed_level", completed_level)
	levels_http_request.set_meta("attempt_time", attempt_time)
	levels_http_request.set_meta("is_update_request", true)
	
	var err = levels_http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		push_error("❌ Failed to fetch Firebase levels: %s" % err)
	else:
		print("📡 Fetching all level data from Firebase...")

# Handle Firebase levels data response
func _on_levels_http_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		print("📥 Firebase levels data fetched successfully")
		
		var json = JSON.new()
		var parse_result = json.parse(body_text)
		
		if parse_result == OK:
			var is_update_request = levels_http_request.get_meta("is_update_request", false)
			
			if is_update_request:
				var completed_level = levels_http_request.get_meta("completed_level", "")
				var attempt_time = levels_http_request.get_meta("attempt_time", 0)
				
				# Clear metadata
				levels_http_request.remove_meta("completed_level")
				levels_http_request.remove_meta("attempt_time")
				levels_http_request.remove_meta("is_update_request")
				
				# Calculate stats from Firebase data
				calculate_stats_from_firebase_data(json.data, completed_level, attempt_time)
			else:
				# This was a sync request (if you still have any)
				sync_local_from_firebase_data(json.data)
		else:
			push_error("❌ Failed to parse levels data JSON")
	elif response_code == 404:
		# No levels exist yet - first completion
		print("📥 No existing levels found - first completion detected")
		var is_update_request = levels_http_request.get_meta("is_update_request", false)
		
		if is_update_request:
			var completed_level = levels_http_request.get_meta("completed_level", "")
			var attempt_time = levels_http_request.get_meta("attempt_time", 0)
			
			levels_http_request.remove_meta("completed_level")
			levels_http_request.remove_meta("attempt_time")
			levels_http_request.remove_meta("is_update_request")
			
			# For first completion, only current level is completed
			calculate_stats_for_first_completion(completed_level, attempt_time)
	else:
		# Clear metadata on error
		levels_http_request.remove_meta("completed_level")
		levels_http_request.remove_meta("attempt_time")
		levels_http_request.remove_meta("is_update_request")
		push_error("❌ Failed to fetch levels data: %s — %s" % [response_code, body_text])

# PURE FIREBASE CALCULATION: No local cache involved
func calculate_stats_from_firebase_data(firebase_data: Dictionary, just_completed_level: String, attempt_time: int) -> void:
	var required_stages = ["reading", "fine_motor", "math", "art"]
	var completed_stages = []
	var total_recent_successful_time = 0
	
	print("🔍 ANALYZING FIREBASE DATA:")
	
	# Parse Firebase documents
	var stage_completion_status = {}
	var stage_best_times = {}
	var stage_last_successful_times = {}
	
	if firebase_data.has("documents"):
		for doc in firebase_data.documents:
			var stage_name = doc.name.split("/")[-1]  # Extract stage name
			
			if doc.has("fields"):
				# Check everCompleted status
				var ever_completed = false
				if doc.fields.has("everCompleted") and doc.fields.everCompleted.has("booleanValue"):
					ever_completed = doc.fields.everCompleted.booleanValue
				
				# Get best time (keep for reference)
				var best_time = 0
				if doc.fields.has("bestTime"):
					if doc.fields.bestTime.has("integerValue"):
						best_time = int(doc.fields.bestTime.integerValue)
					elif doc.fields.bestTime.has("doubleValue"):
						best_time = int(doc.fields.bestTime.doubleValue)
				
				# Get lastAttemptTime
				var last_attempt_time = 0
				if doc.fields.has("lastAttemptTime"):
					if doc.fields.lastAttemptTime.has("integerValue"):
						last_attempt_time = int(doc.fields.lastAttemptTime.integerValue)
					elif doc.fields.lastAttemptTime.has("doubleValue"):
						last_attempt_time = int(doc.fields.lastAttemptTime.doubleValue)
				
				# Check if lastAttemptCompleted is true
				var last_attempt_completed = false
				if doc.fields.has("lastAttemptCompleted") and doc.fields.lastAttemptCompleted.has("booleanValue"):
					last_attempt_completed = doc.fields.lastAttemptCompleted.booleanValue
				
				# Store the data
				stage_completion_status[stage_name] = ever_completed
				stage_best_times[stage_name] = best_time  # Keep for reference
				
				# Only use lastAttemptTime for average if it was a successful attempt
				if last_attempt_completed and last_attempt_time > 0:
					stage_last_successful_times[stage_name] = last_attempt_time
				
				print("  📋 Firebase: %s - everCompleted: %s, bestTime: %d ms, lastAttempt: %d ms (completed: %s)" % [
					stage_name, 
					str(ever_completed), 
					best_time, 
					last_attempt_time, 
					str(last_attempt_completed)
				])
	
	# Count completed stages and calculate total time using lastAttemptTime (successful only)
	for stage in required_stages:
		var is_completed = stage_completion_status.get(stage, false)
		
		if is_completed:
			completed_stages.append(stage)
			
			# Use lastAttemptTime (successful) for average calculation
			var stage_time = stage_last_successful_times.get(stage, 0)
			if stage_time > 0:
				total_recent_successful_time += stage_time
				print("  ✅ %s completed - using last successful time: %d ms for average" % [stage, stage_time])
			else:
				# Fallback to bestTime if no successful lastAttemptTime available
				var best_time = stage_best_times.get(stage, 0)
				if best_time > 0:
					total_recent_successful_time += best_time
					print("  ✅ %s completed - fallback to best time: %d ms for average" % [stage, best_time])
				else:
					print("  ✅ %s completed - no time data available for average" % stage)
		else:
			print("  ❌ %s not completed yet" % stage)
	
	print("📊 FIREBASE-BASED SUMMARY:")
	print("  - Completed stages: %s" % str(completed_stages))
	print("  - Total completed: %d/4" % completed_stages.size())
	print("  - Total recent successful time: %d ms" % total_recent_successful_time)
	
	# Calculate final stats
	var new_completed_levels = completed_stages.size()
	var new_average_time = 0
	
	if completed_stages.size() > 0 and total_recent_successful_time > 0:
		new_average_time = total_recent_successful_time / completed_stages.size()
	
	var new_letter_completed = (completed_stages.size() == 4)
	
	print("📈 FINAL CALCULATED STATS:")
	print("  - completedLevels: %d" % new_completed_levels)
	print("  - averageTime: %d ms (based on last successful attempts)" % new_average_time)
	print("  - letterCompleted: %s" % str(new_letter_completed))
	
	# Update letter stats
	update_letter_stats(new_completed_levels, new_average_time, new_letter_completed)

# Handle first completion case
func calculate_stats_for_first_completion(completed_level: String, attempt_time: int) -> void:
	print("🎯 FIRST COMPLETION DETECTED")
	print("  - First completed stage: %s" % completed_level)
	print("  - Time: %d ms" % attempt_time)
	
	# For first completion, only 1 stage completed, letter not complete
	update_letter_stats(1, attempt_time, false)

# SAFE LETTER STATS UPDATE: Uses PATCH to avoid overwrites
func update_letter_stats(completed_levels: int, average_time: int, letter_completed: bool) -> void:
	var uid = Global.user_id
	var letter_id = Global.current_letter
	var project_id = "mindmotion-55c99"
	var id_token = Global.firebase_id_token
	
	print("📤 UPDATING LETTER DOCUMENT:")
	print("  - Document: users/%s/progress/%s" % [uid, letter_id])
	print("  - completedLevels: %d" % completed_levels)
	print("  - averageTime: %d ms" % average_time)
	print("  - letterCompleted: %s" % str(letter_completed))
	
	# Prepare update data
	var stats_data = {
		"completedLevels": completed_levels,
		"averageTime": average_time,
		"letterCompleted": letter_completed
	}
	
	# Convert to Firestore format
	var fields = {}
	for key in stats_data.keys():
		fields[key] = to_firestore_field(stats_data[key])
	
	var body_json = {"fields": fields}
	
	print("📡 FIRESTORE UPDATE REQUEST:")
	print("  - Body: %s" % JSON.stringify(body_json))
	
	# Update main letter document
	var stats_url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s" \
		% [project_id, uid, letter_id]
	
	print("  - URL: %s" % stats_url)
	
	var headers = [
		"Authorization: Bearer %s" % id_token,
		"Content-Type: application/json"
	]
	
	# Create new HTTP request for stats update
	var update_request = HTTPRequest.new()
	add_child(update_request)
	update_request.request_completed.connect(_on_letter_stats_update_completed.bind(update_request))
	
	var err = update_request.request(stats_url, headers, HTTPClient.METHOD_PATCH, JSON.stringify(body_json))
	if err != OK:
		push_error("❌ Letter stats update failed: %s" % err)
		update_request.queue_free()

# Handle letter stats update response
func _on_letter_stats_update_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, sender: HTTPRequest) -> void:
	var body_text = body.get_string_from_utf8()
	
	print("📥 LETTER STATS UPDATE RESPONSE:")
	print("  - Response Code: %d" % response_code)
	
	if response_code in [200, 201]:
		print("✅ Letter stats updated successfully!")
		
		# Check if letter was completed
		var json = JSON.new()
		if json.parse(body_text) == OK:
			var data = json.data
			if data.has("fields") and data.fields.has("letterCompleted"):
				var letter_completed = data.fields.letterCompleted.get("booleanValue", false)
				if letter_completed:
					print("🎉 LETTER COMPLETED! Refreshing caches...")
					# Wait for Firebase to propagate, then refresh
					await get_tree().create_timer(1.5).timeout
					Global.load_all_letter_completion_data()
					
					# Update Global's stage completion understanding
					Global.preload_letter_stages(Global.current_letter)
	else:
		push_error("❌ Letter stats update failed %d — %s" % [response_code, body_text])
	
	sender.queue_free()

# HELPER FUNCTIONS

# Convert Godot values to Firestore field format
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

# Parse Firestore fields back to Godot values
func parse_firestore_fields(fields: Dictionary) -> Dictionary:
	var result = {}
	for key in fields.keys():
		var field = fields[key]
		if field.has("booleanValue"):
			result[key] = field.booleanValue
		elif field.has("integerValue"):
			result[key] = int(field.integerValue)
		elif field.has("doubleValue"):
			result[key] = field.doubleValue
		elif field.has("stringValue"):
			result[key] = field.stringValue
	return result

# OPTIONAL: Sync function if needed (mostly for Global.gd)
func sync_local_from_firebase_data(firebase_data: Dictionary) -> void:
	print("🔄 Syncing Global cache from Firebase data...")
	
	if firebase_data.has("documents"):
		for doc in firebase_data.documents:
			var stage_name = doc.name.split("/")[-1]
			
			if doc.has("fields"):
				# Update Global's stage cache if it exists
				if doc.fields.has("everCompleted") and doc.fields.everCompleted.has("booleanValue"):
					if doc.fields.everCompleted.booleanValue:
						if Global.has_method("mark_stage_completed"):
							Global.mark_stage_completed(Global.current_letter, stage_name)
						print("  ✅ Synced %s as completed" % stage_name)
	
	print("✅ Global cache sync complete")

# LEGACY COMPATIBILITY: Keep these for any remaining dependencies
func get_stage_last_attempt_time(stage_name: String) -> int:
	print("⚠️ get_stage_last_attempt_time() called - consider removing this dependency")
	return 0  # Return 0 since we're not using local storage

func check_stage_completion_from_local(stage_name: String) -> bool:
	print("⚠️ check_stage_completion_from_local() called - use Global.is_stage_completed() instead")
	return Global.is_stage_completed(Global.current_letter, stage_name)
