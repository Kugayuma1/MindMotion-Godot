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
		
	# FIREBASE-ONLY: Load from cache immediately, then refresh from Firebase
	load_stage_completion_from_cache()
	
	# Always try to refresh from Firebase for latest data
	if Global.is_authenticated():
		Global.load_letter_stages_on_demand(Global.current_letter)

func load_stage_completion_from_cache():
	# Get cached data from Global (which gets it from Firebase)
	var cached_data = Global.get_stage_cache(Global.current_letter)
	
	if cached_data and not cached_data.is_empty():
		stage_completion = cached_data.duplicate()
		debug_print("Using cached stage data: %s" % str(stage_completion))
	else:
		# Default to all incomplete
		stage_completion = {"reading": false, "fine_motor": false, "math": false, "art": false}
		debug_print("Using default states (all stages incomplete)", "🔒")
	
	update_button_states()

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

# FIREBASE-ONLY: This gets called when Global's stage cache updates from Firebase
func _on_stage_cache_updated(letter: String):
	if letter == Global.current_letter:
		update_button_states()

func debug_print_states():
	debug_print("=== DEBUG STATES ===")
	debug_print("Letter: %s, Completion: %s" % [Global.current_letter, str(stage_completion)])
	for stage in ["reading", "fine_motor", "math", "art"]:
		debug_print("%s: unlocked=%s, completed=%s" % [stage, is_stage_unlocked(stage), stage_completion.get(stage, false)])
	debug_print("====================")
