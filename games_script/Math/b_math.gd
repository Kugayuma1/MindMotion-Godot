extends Control

var correct_balloon_order = [1, 2, 3, 4, 5]
var current_balloon_index = 0
var completed_balloons = []

# Mapping of balloon nodes to their actual numbers
var balloon_number_mapping = {
	"balloon1": 2,  # Will be randomized
	"balloon2": 1,  # Will be randomized
	"balloon3": 5,  # Will be randomized
	"balloon4": 4,  # Will be randomized
	"balloon5": 3   # Will be randomized
}

var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null
var popped_texture = preload("res://Game Assets/Math/5.png")

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

# Balloon nodes
@onready var balloon1 = $Balloon1
@onready var balloon2 = $Balloon2
@onready var balloon3 = $Balloon3
@onready var balloon4 = $Balloon4
@onready var balloon5 = $Balloon5

func _ready():
	completed_balloons.clear()
	current_balloon_index = 0
	
	# Randomize balloon number assignments
	randomize_balloon_numbers()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the balloons in order: 1, 2, 3, 4, 5"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Setup balloon click handlers
	setup_balloon_handlers()

func randomize_balloon_numbers() -> void:
	# Create a shuffled list of numbers 1-5
	var numbers = [1, 2, 3, 4, 5]
	numbers.shuffle()
	
	# Assign shuffled numbers to each balloon
	balloon_number_mapping["balloon1"] = numbers[0]
	balloon_number_mapping["balloon2"] = numbers[1]
	balloon_number_mapping["balloon3"] = numbers[2]
	balloon_number_mapping["balloon4"] = numbers[3]
	balloon_number_mapping["balloon5"] = numbers[4]
	
	# Update the balloon label displays
	update_balloon_labels()
	
	# Debug: Print the randomized mapping
	print("🎈 Randomized Balloon Mapping:")
	for balloon_name in balloon_number_mapping:
		print("%s → %d" % [balloon_name, balloon_number_mapping[balloon_name]])

func update_balloon_labels() -> void:
	# Update label for each balloon - adjust the path if your labels are named differently
	if balloon1 and balloon1.has_node("Label"):
		balloon1.get_node("Label").text = str(balloon_number_mapping["balloon1"])
	if balloon2 and balloon2.has_node("Label"):
		balloon2.get_node("Label").text = str(balloon_number_mapping["balloon2"])
	if balloon3 and balloon3.has_node("Label"):
		balloon3.get_node("Label").text = str(balloon_number_mapping["balloon3"])
	if balloon4 and balloon4.has_node("Label"):
		balloon4.get_node("Label").text = str(balloon_number_mapping["balloon4"])
	if balloon5 and balloon5.has_node("Label"):
		balloon5.get_node("Label").text = str(balloon_number_mapping["balloon5"])

func setup_balloon_handlers():
	# Connect balloon click signals with correct number mapping
	if balloon1:
		balloon1.pressed.connect(_on_balloon_pressed.bind(balloon_number_mapping["balloon1"], balloon1, "balloon1"))
	if balloon2:
		balloon2.pressed.connect(_on_balloon_pressed.bind(balloon_number_mapping["balloon2"], balloon2, "balloon2"))
	if balloon3:
		balloon3.pressed.connect(_on_balloon_pressed.bind(balloon_number_mapping["balloon3"], balloon3, "balloon3"))
	if balloon4:
		balloon4.pressed.connect(_on_balloon_pressed.bind(balloon_number_mapping["balloon4"], balloon4, "balloon4"))
	if balloon5:
		balloon5.pressed.connect(_on_balloon_pressed.bind(balloon_number_mapping["balloon5"], balloon5, "balloon5"))

func start_timer() -> void:
	if timer_label:
		timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		if timer_label:
			timer_label.text = "⏰ Done!"
		if feedback_label:
			feedback_label.text = "⏱️Time's up!"
		timer_active = false
		game_over(false)
		return
	
	if timer_label:
		timer_label.text = str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func _on_balloon_pressed(balloon_number: int, balloon_node: Control, balloon_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_balloon_order[current_balloon_index]
	
	print("Pressed %s (shows number %d), Expected: %d" % [balloon_name, balloon_number, expected_number])
	
	if balloon_number == expected_number:
		on_correct_balloon_pop(balloon_number, balloon_node)
	else:
		on_wrong_balloon_pop(balloon_number, expected_number, balloon_node)

func on_correct_balloon_pop(balloon_number: int, balloon_node: Control):
	if !timer_active:
		return
	
	# Mark balloon as completed
	completed_balloons.append(balloon_number)
	current_balloon_index += 1
	
	print("🎉 Correct! Balloon shows number %d" % balloon_number)
	
	# Disable the balloon button first
	balloon_node.disabled = true
	
	# Play pop animation, then hide balloon
	await pop_balloon_visual(balloon_node)
	balloon_node.visible = false
	
	# Check if all balloons are popped BEFORE updating feedback
	if completed_balloons.size() >= correct_balloon_order.size():
		# All balloons completed
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All balloons popped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		# Show next balloon to tap
		if feedback_label and current_balloon_index < correct_balloon_order.size():
			feedback_label.text = "✅Great! Now tap balloon %d" % correct_balloon_order[current_balloon_index]

func on_wrong_balloon_pop(balloon_number: int, expected_number: int, balloon_node: Control):
	if !timer_active:
		return
	
	print("❌ Wrong! Expected number %d, but pressed number %d" % [expected_number, balloon_number])
	
	if feedback_label:
		feedback_label.text = "❌ Wrong order! Tap balloon %d first." % expected_number
	
	# Shake the wrong balloon
	shake_balloon(balloon_node)
	
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_balloon_visual(balloon_node: Control):
	# Add pop animation before hiding
	var tween = create_tween()
	
	# First expand the balloon (pop effect)
	tween.parallel().tween_property(balloon_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(balloon_node, "rotation", deg_to_rad(10), 0.1)
	
	# Then shrink and fade out
	tween.tween_property(balloon_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(balloon_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(balloon_node, "rotation", deg_to_rad(-15), 0.3)
	
	# Wait for animation to complete
	await tween.finished

func shake_balloon(balloon_node: Control) -> void:
	if !balloon_node:
		return
	
	var original_pos = balloon_node.position
	var tween = create_tween()
	tween.tween_property(balloon_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(balloon_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(balloon_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(balloon_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	
	# Hide game UI
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	# Hide all remaining balloons
	if balloon1: balloon1.visible = false
	if balloon2: balloon2.visible = false
	if balloon3: balloon3.visible = false
	if balloon4: balloon4.visible = false
	if balloon5: balloon5.visible = false
	
	var popup_instance: Node = null
	
	# Popup logic based on remaining time and performance
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
		ProgressManager.save_progress("math", true)
		Global.refresh_everything_after_stage_completion("math", true)
	else:
		print("⏰ Game over - Time's up!")
		ProgressManager.save_progress("math", false)
		Global.refresh_everything_after_stage_completion("math", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		if current_balloon_index < correct_balloon_order.size():
			feedback_label.text = "Tap balloon %d next!" % correct_balloon_order[current_balloon_index]
		else:
			feedback_label.text = "Tap the balloons in order: 1, 2, 3, 4, 5"

func _on_balloon_1_pressed() -> void:
	_on_balloon_pressed(balloon_number_mapping["balloon1"], balloon1, "balloon1")

func _on_balloon_2_pressed() -> void:
	_on_balloon_pressed(balloon_number_mapping["balloon2"], balloon2, "balloon2")

func _on_balloon_3_pressed() -> void:
	_on_balloon_pressed(balloon_number_mapping["balloon3"], balloon3, "balloon3")

func _on_balloon_4_pressed() -> void:
	_on_balloon_pressed(balloon_number_mapping["balloon4"], balloon4, "balloon4")

func _on_balloon_5_pressed() -> void:
	_on_balloon_pressed(balloon_number_mapping["balloon5"], balloon5, "balloon5")

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
