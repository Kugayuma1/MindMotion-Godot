# MAIN GAME CONTROLLER SCRIPT
# Attach this to your main Control node or create a new script for game management
extends Control

var correct_answers = ["Apple", "Axe", "Ant", "Avocado"]  # All possible correct items
var completed_matches = []  # Track completed matches
var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null
# Update these paths to match your actual scene structure
@onready var feedback_label = $Holder/Label  # Instructions/feedback label
@onready var timer_label = $Time/Label      # Timer label

func _ready():
	completed_matches.clear()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Drag the 'A' object to the kids"  # Initial instruction
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Connect to all draggable items to handle their drop events
	setup_draggable_items()

func refresh_cache_after_completion(stage_name: String, completed: bool):
	"""Refresh Global's cache immediately after game completion"""
	if completed:
		# Update cache immediately for this stage
		Global.update_stage_completion_immediately(Global.current_letter, stage_name, true)
		print("Cache refreshed: %s.%s = completed" % [Global.current_letter, stage_name])
		
func setup_draggable_items():
	# Get all draggable items
	var draggable_items = []
	# Adjust this path to match your scene structure
	var item_container = $Item  # or whatever your item container is called
	
	for child in item_container.get_children():
		if child.has_method("setup_game_controller"):
			child.setup_game_controller(self)
			draggable_items.append(child)

func start_timer() -> void:
	if timer_label:
		timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		if timer_label:
			timer_label.text = "Done!"
		if feedback_label:
			feedback_label.text = "Time's "
		timer_active = false
		game_over(false)  # Time's up - game failed
		return
	
	if timer_label:
		timer_label.text = " " + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func on_correct_match(item_name: String, target_name: String):
	if !timer_active:
		return
		
	if !completed_matches.has(item_name):
		completed_matches.append(item_name)
		print("🎉 Correct! %s matched with %s" % [item_name, target_name])
		
		if feedback_label:
			feedback_label.text = "Correct " + item_name
		
		# Check if all items are matched
		if completed_matches.size() == correct_answers.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "Very Good"
			game_over(true)  # All items matched - success!
		else:
			# Reset feedback after 1.5 seconds
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()

func on_wrong_match(item_name: String, target_name: String, child_node):
	if !timer_active:
		return
		
	print("❌ Wrong! %s doesn't go to %s" % [item_name, target_name])
	
	if feedback_label:
		feedback_label.text = "Try again."
	
	shake_child(child_node)
	
	# Reset feedback after 1.5 seconds
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func shake_child(child_node: Node) -> void:
	if !child_node:
		return
		
	var original_pos = child_node.position
	var tween = create_tween()
	tween.tween_property(child_node, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(child_node, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(child_node, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	timer_active = false
	
	# Hide game UI (optional, adjust as needed for your scene)
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Children"): $Children.visible = false
	if has_node("Item"): $Item.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	var popup_instance: Node = null
	
	# ✅ POPUP LOGIC BASED ON REMAINING TIME
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()  # ⭐⭐⭐
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()  # ⭐⭐
		else:
			popup_instance = complete1_scene.instantiate()  # ⭐
	else:
		popup_instance = retry_scene.instantiate()      # ❌ always 1 star on fail
	
	if popup_instance:
		add_child(popup_instance)
	
	# Save progress
	if success:
		print("🎉 Game completed successfully!")
		ProgressManager.save_progress("fine_motor", true)
		Global.refresh_everything_after_stage_completion("fine_motor", true)
	else:
		print("⏰ Game over - Time's up!")
		ProgressManager.save_progress("fine_motor", false)
		Global.refresh_everything_after_stage_completion("fine_motor", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		feedback_label.text = "Drag the 'A' object to the kids"


func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
