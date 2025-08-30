extends Control

# Store stage completion status
var stage_completion = {}

func _ready():
	$LetterLabel.text = "Letter %s" % Global.current_letter
	
	# Set initial states immediately using cached data or safe defaults
	set_initial_button_states_immediate()
	
	# Then load fresh data in background without blocking UI
	load_stage_completion_data_background()

func set_initial_button_states_immediate():
	var current_letter = Global.current_letter
	
	# Get cached stage data from Global (this should be instant)
	var cached_data = Global.get_stage_cache(current_letter)
	
	if cached_data and not cached_data.is_empty():
		# Use cached data for instant display
		stage_completion = cached_data.duplicate()
		print("📋 Using cached stage data: %s" % str(stage_completion))
	else:
		# Use safe defaults - only reading unlocked
		stage_completion = {
			"reading": true,
			"fine_motor": false,
			"math": false,
			"art": false
		}
		print("🔒 Using default states (reading unlocked only)")
		
		# Try to load this letter's data immediately if not cached
		if Global.is_authenticated():
			Global.load_letter_stages_on_demand(current_letter)
	
	# Apply the states immediately - no waiting
	update_button_states()

func load_stage_completion_data_background():
	if not Global.is_authenticated():
		print("User not authenticated, keeping current states")
		return
	
	print("📡 Loading fresh stage data in background (non-blocking)...")
	
	var project_id = "mindmotion-55c99"
	var uid = Global.user_id
	var letter = Global.current_letter
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_background_stage_data_completed)
	
	var url = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/users/%s/progress/%s/levels" % [project_id, uid, letter]
	
	var headers = [
		"Authorization: Bearer %s" % Global.firebase_id_token,
		"Content-Type: application/json"
	]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		print("❌ Failed to request background stage data: %s" % err)

func _on_background_stage_data_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body_text)
		
		if parse_result == OK:
			var data = json.data
			var new_stage_completion = {
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
						new_stage_completion[stage_name] = is_completed
			
			# Always ensure reading is available
			new_stage_completion["reading"] = true
			
			# Only update UI if data actually changed
			if new_stage_completion != stage_completion:
				print("📊 Background: Stage data updated from server")
				stage_completion = new_stage_completion
				update_button_states()
				
				# Update Global cache for next time
				Global.set_stage_cache(Global.current_letter, stage_completion)
			else:
				print("✅ Background: Stage data unchanged")
		else:
			print("❌ Failed to parse background stage data")
	else:
		print("⚠️ Background stage request failed with code: %d" % response_code)
		if response_code == 401 or response_code == 403:
			print("🔐 Authentication token expired")
			Global.logout()
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")

func update_button_states():
	# Get completion status with linear unlocking logic
	var reading_completed = stage_completion.get("reading", false)
	var fine_motor_completed = stage_completion.get("fine_motor", false) 
	var math_completed = stage_completion.get("math", false)
	var art_completed = stage_completion.get("art", false)
	
	print("📊 Current stage completion: %s" % str(stage_completion))
	print("🔍 Button unlock logic:")
	print("  Reading: always unlocked, completed: %s" % reading_completed)
	print("  Fine Motor: unlocked if reading completed (%s), completed: %s" % [reading_completed, fine_motor_completed])
	print("  Math: unlocked if fine motor completed (%s), completed: %s" % [fine_motor_completed, math_completed])
	print("  Art: unlocked if math completed (%s), completed: %s" % [math_completed, art_completed])
	
	# Update each button based on sequential unlock logic
	update_single_button("Reading", true, reading_completed)  # Always unlocked
	update_single_button("FineMotor", reading_completed, fine_motor_completed)
	update_single_button("Math", fine_motor_completed, math_completed)
	update_single_button("Arts", math_completed, art_completed)

func update_single_button(button_name: String, is_unlocked: bool, is_completed: bool):
	var button = find_button_node(button_name)
	
	if not button:
		print("⚠️ Button not found: %s" % button_name)
		return
	
	print("🎯 Updating %s - Unlocked: %s, Completed: %s" % [button_name, is_unlocked, is_completed])
	
	# Apply visual state immediately
	if is_unlocked:
		button.disabled = false
		button.modulate = Color.WHITE
		print("  ✅ %s unlocked and enabled" % button_name)
		
	else:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5, 0.6)  # Grayed out
		print("  🔒 %s locked and grayed out" % button_name)

func find_button_node(button_name: String) -> Node:
	# Simplified and more efficient button finding
	var button_variants = [
		button_name,
		button_name.to_lower(),
		button_name.replace("Button", ""),
		button_name.replace("Button", "Btn")
	]
	
	for variant in button_variants:
		if has_node(variant):
			return get_node(variant)
		if has_node("$" + variant):
			return get_node("$" + variant)
	
	# Try recursive search as last resort
	return find_button_recursive(button_name)

func find_button_recursive(button_name: String) -> Node:
	var queue = [self]
	var button_name_lower = button_name.to_lower()
	
	while queue.size() > 0:
		var current = queue.pop_front()
		
		for child in current.get_children():
			if child is Button:
				var child_name_lower = child.name.to_lower()
				# Check for keyword matches
				if (child_name_lower.contains("reading") and button_name_lower.contains("reading")) or \
				   (child_name_lower.contains("fine") and button_name_lower.contains("fine")) or \
				   (child_name_lower.contains("math") and button_name_lower.contains("math")) or \
				   (child_name_lower.contains("art") and button_name_lower.contains("art")):
					return child
			
			queue.append(child)
	
	return null

func is_stage_unlocked(stage_name: String) -> bool:
	match stage_name:
		"reading":
			return true  # Always unlocked
		"fine_motor": 
			return stage_completion.get("reading", false)
		"math":
			return stage_completion.get("fine_motor", false)
		"art":
			return stage_completion.get("math", false)
		_:
			return false

# Button handlers with improved lock checking
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/LevelSelection.tscn")

func _on_reading_pressed():
	# Reading is always available
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/Reading/" + letter_lower + "_reading.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		show_error_message("Scene not found", "Reading scene for letter %s not found." % Global.current_letter)

func _on_fine_motor_pressed():
	if not is_stage_unlocked("fine_motor"):
		show_locked_message("Fine Motor Skills", "Complete the Reading stage first to unlock Fine Motor skills.")
		return
		
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/FineMotor/" + letter_lower + "_finemotors.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		show_error_message("Scene not found", "Fine Motor scene for letter %s not found." % Global.current_letter)

func _on_math_pressed():
	if not is_stage_unlocked("math"):
		show_locked_message("Math", "Complete Fine Motor skills first to unlock Math.")
		return
		
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/Math/" + letter_lower + "_math.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		show_error_message("Scene not found", "Math scene for letter %s not found." % Global.current_letter)

func _on_arts_pressed():
	if not is_stage_unlocked("art"):
		show_locked_message("Arts & Crafts", "Complete the Math stage first to unlock Arts & Crafts.")
		return
		
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/Arts/" + letter_lower + "_arts.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		show_error_message("Scene not found", "Arts scene for letter %s not found." % Global.current_letter)

func show_locked_message(stage_name: String, requirement: String):
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.dialog_text = "🔒 " + stage_name + " is locked!\n\n" + requirement
	dialog.title = "Stage Locked"
	dialog.popup_centered()
	
	# Clean up dialog when closed
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

func show_error_message(title: String, message: String):
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.dialog_text = "❌ " + message
	dialog.title = title
	dialog.popup_centered()
	
	# Clean up dialog when closed
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

# Call this when returning from a completed stage
func refresh_stage_locks():
	print("🔄 Refreshing stage locks...")
	# First check if Global has updated cache
	var fresh_cache = Global.get_stage_cache(Global.current_letter)
	if fresh_cache and fresh_cache != stage_completion:
		stage_completion = fresh_cache.duplicate()
		update_button_states()
	
	# Also refresh from server in background
	load_stage_completion_data_background()
