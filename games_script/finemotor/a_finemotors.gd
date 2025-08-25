# MAIN GAME CONTROLLER SCRIPT
# Attach this to your main Control node or create a new script for game management
extends Control

var correct_answers = ["Apple", "Axe", "Ant", "Avocado"]  # All possible correct items
var completed_matches = []  # Track completed matches
var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

# Update these paths to match your actual scene structure
@onready var feedback_label = $Holder/Label  # Instructions/feedback label
@onready var timer_label = $Time/Label      # Timer label

func _ready():
	completed_matches.clear()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Drag the "  # Initial instruction
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Connect to all draggable items to handle their drop events
	setup_draggable_items()

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
		timer_label.text = "⏱️ 15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		if timer_label:
			timer_label.text = "⏰ Done!"
		if feedback_label:
			feedback_label.text = "⏱️Time's "
		timer_active = false
		game_over(false)  # Time's up - game failed
		return
	
	if timer_label:
		timer_label.text = "⏱️ " + str(countdown) + "s"
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
			feedback_label.text = "✅Correct " + item_name
		
		# Check if all items are matched
		if completed_matches.size() == correct_answers.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "🎉 Very Good"
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
		feedback_label.text = "❌ Try again."
	
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
	if success:
		print("🎉 Game completed successfully!")
		# Save progress as successful
		ProgressManager.save_progress("fine_motor", true)
	else:
		print("⏰ Game over - Time's up!")
		# Save progress as failed
		ProgressManager.save_progress("fine_motor", false)
	
	# You can add scene transition or restart logic here

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		feedback_label.text = "Drag the object"
