extends Control

# Store stage completion status
var stage_completion = {}

# Simple debug helper - just consolidates print statements
func debug_print(message: String, icon: String = "📋"):
	print("%s %s" % [icon, message])

func _ready():
	$LetterLabel.text = "Letter %s" % Global.current_letter
	
	if not Global.stage_cache_updated.is_connected(_on_stage_cache_updated):
		Global.stage_cache_updated.connect(_on_stage_cache_updated)
		
	set_initial_button_states_immediate()
	load_stage_completion_data_background()

func set_initial_button_states_immediate():
	var cached_data = Global.get_stage_cache(Global.current_letter)
	
	if cached_data and not cached_data.is_empty():
		stage_completion = cached_data.duplicate()
		debug_print("Using cached stage data: %s" % str(stage_completion))
	else:
		stage_completion = {"reading": false, "fine_motor": false, "math": false, "art": false}
		debug_print("Using default states (all stages incomplete)", "🔒")
		
		if Global.is_authenticated():
			Global.load_letter_stages_on_demand(Global.current_letter)
	
	update_button_states()

func load_stage_completion_data_background():
	if not Global.is_authenticated():
		debug_print("User not authenticated, keeping current states", "⚠️")
		return
	
	debug_print("Loading fresh stage data in background...", "📡")
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_background_stage_data_completed)
	
	var url = "https://firestore.googleapis.com/v1/projects/mindmotion-55c99/databases/(default)/documents/users/%s/progress/%s/levels" % [Global.user_id, Global.current_letter]
	var headers = ["Authorization: Bearer %s" % Global.firebase_id_token, "Content-Type: application/json"]
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		debug_print("Failed to request background stage data: %s" % err, "❌")

func _on_background_stage_data_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var body_text = body.get_string_from_utf8()
	debug_print("Firebase Response Code: %d" % response_code, "🔍")
	
	if response_code == 200:
		var new_completion = parse_firebase_data(body_text)
		if new_completion != stage_completion:
			debug_print("Stage data updated from server", "📊")
			stage_completion = new_completion
			update_button_states()
			Global.set_stage_cache(Global.current_letter, stage_completion)
		else:
			debug_print("Stage data unchanged", "✅")
	elif response_code in [401, 403]:
		debug_print("Authentication token expired", "🔐")
		Global.logout()
		get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
	elif response_code == 404:
		debug_print("No progress found - treating as new account", "🆕")
	else:
		debug_print("Background request failed with code: %d" % response_code, "⚠️")

func parse_firebase_data(body_text: String) -> Dictionary:
	var json = JSON.new()
	if json.parse(body_text) != OK:
		debug_print("Failed to parse JSON", "❌")
		return stage_completion
	
	var new_completion = {"reading": false, "fine_motor": false, "math": false, "art": false}
	var data = json.data
	
	if data.has("documents") and data.documents.size() > 0:
		debug_print("Processing %d documents from Firebase" % data.documents.size(), "📄")
		
		for doc in data.documents:
			var stage_name = doc.name.split("/")[-1]
			if doc.has("fields") and doc.fields.has("everCompleted") and doc.fields.everCompleted.has("booleanValue"):
				if doc.fields.everCompleted.booleanValue == true:
					new_completion[stage_name] = true
					debug_print("Stage %s marked as completed" % stage_name, "✅")
	
	debug_print("Final computed completion: %s" % str(new_completion), "🎯")
	return new_completion

func update_button_states():
	var reading_done = stage_completion.get("reading", false)
	var fine_motor_done = stage_completion.get("fine_motor", false)
	var math_done = stage_completion.get("math", false)
	
	debug_print("Current completion: %s" % str(stage_completion), "📊")
	
	# Apply states with consolidated logic
	set_button_state("Reading", true, reading_done)
	set_button_state("FineMotor", reading_done, fine_motor_done)
	set_button_state("Math", fine_motor_done, math_done)
	set_button_state("Arts", math_done, stage_completion.get("art", false))

func set_button_state(button_name: String, unlocked: bool, completed: bool):
	var button = find_button_node(button_name)
	if not button:
		debug_print("Button not found: %s" % button_name, "⚠️")
		return
	
	button.disabled = not unlocked
	button.modulate = Color.WHITE if unlocked else Color(0.5, 0.5, 0.5, 0.6)
	debug_print("%s - unlocked:%s completed:%s" % [button_name, unlocked, completed])

func find_button_node(button_name: String) -> Node:
	# Try direct node access first
	for variant in [button_name, button_name.to_lower()]:
		if has_node(variant):
			return get_node(variant)
	
	# Fallback to recursive search
	var queue = [self]
	var name_lower = button_name.to_lower()
	
	while queue.size() > 0:
		var current = queue.pop_front()
		for child in current.get_children():
			if child is Button and child.name.to_lower().contains(name_lower.substr(0, 4)):
				return child
			queue.append(child)
	return null

func is_stage_unlocked(stage_name: String) -> bool:
	match stage_name:
		"reading": return true
		"fine_motor": return stage_completion.get("reading", false)
		"math": return stage_completion.get("fine_motor", false)
		"art": return stage_completion.get("math", false)
		_: return false

# Consolidated button handlers
func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/LevelSelection.tscn")

func _on_reading_pressed():
	load_stage_scene("reading", "Reading", "reading")

func _on_fine_motor_pressed():
	if try_load_locked_stage("fine_motor", "Fine Motor Skills", "Complete Reading first"):
		load_stage_scene("fine_motor", "FineMotor", "finemotors")

func _on_math_pressed():
	if try_load_locked_stage("math", "Math", "Complete Fine Motor first"):
		load_stage_scene("math", "Math", "math")

func _on_arts_pressed():
	if try_load_locked_stage("art", "Arts & Crafts", "Complete Math first"):
		load_stage_scene("art", "Arts", "arts")

func try_load_locked_stage(stage: String, display_name: String, requirement: String) -> bool:
	if not is_stage_unlocked(stage):
		show_dialog("🔒 %s is locked!\n\n%s." % [display_name, requirement], "Stage Locked")
		return false
	return true

func load_stage_scene(stage: String, folder: String, filename: String):
	var path = "res://games/%s/%s_%s.tscn" % [folder, Global.current_letter.to_lower(), filename]
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		show_dialog("❌ Scene for letter %s not found." % Global.current_letter, "Scene not found")

func show_dialog(text: String, title: String):
	var dialog = AcceptDialog.new()
	add_child(dialog)
	dialog.dialog_text = text
	dialog.title = title
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())

func refresh_stage_locks():
	debug_print("Refreshing stage locks...", "🔄")
	var fresh_cache = Global.get_stage_cache(Global.current_letter)
	if fresh_cache and fresh_cache != stage_completion:
		stage_completion = fresh_cache.duplicate()
		update_button_states()
	load_stage_completion_data_background()

func _on_stage_cache_updated(letter: String):
	if letter == Global.current_letter:
		debug_print("Stage cache updated for letter %s" % letter, "🔄")
		var fresh_data = Global.get_stage_cache(letter)
		if fresh_data != stage_completion:
			stage_completion = fresh_data.duplicate()
			update_button_states()

func debug_print_states():
	debug_print("=== DEBUG STATES ===")
	debug_print("Letter: %s, Completion: %s" % [Global.current_letter, str(stage_completion)])
	for stage in ["reading", "fine_motor", "math", "art"]:
		debug_print("%s: unlocked=%s, completed=%s" % [stage, is_stage_unlocked(stage), stage_completion.get(stage, false)])
	debug_print("====================")
