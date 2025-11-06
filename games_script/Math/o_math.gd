extends Control

# Correct order for onions
var correct_onion_order = [6, 7, 8, 9, 10]
var current_onion_index = 0
var completed_onions = []

# Mapping of onion nodes to their actual numbers
var onion_number_mapping = {
	"onion1": 8,
	"onion2": 6,
	"onion3": 9,
	"onion4": 10,
	"onion5": 7
}

var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""
var motivational_5s_played = false
var motivational_10s_played = false

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

# Onion nodes
@onready var onion1 = $Onion1
@onready var onion2 = $Onion2
@onready var onion3 = $Onion3
@onready var onion4 = $Onion4
@onready var onion5 = $Onion5

func _ready():
	completed_onions.clear()
	current_onion_index = 0
	
	# Randomize onion number assignments
	randomize_onion_numbers()
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the onions in order: 6, 7, 8, 9, 10"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	setup_onion_handlers()
	motivational_5s_played = false
	motivational_10s_played = false

func randomize_onion_numbers() -> void:
	# Create a shuffled list of numbers 6-10
	var numbers = [6, 7, 8, 9, 10]
	numbers.shuffle()
	
	# Assign shuffled numbers to each onion
	onion_number_mapping["onion1"] = numbers[0]
	onion_number_mapping["onion2"] = numbers[1]
	onion_number_mapping["onion3"] = numbers[2]
	onion_number_mapping["onion4"] = numbers[3]
	onion_number_mapping["onion5"] = numbers[4]
	
	# Update the onion label displays
	update_onion_labels()
	
	# Debug: Print the randomized mapping
	print("🧅 Randomized Onion Mapping:")
	for onion_name in onion_number_mapping:
		print("%s → %d" % [onion_name, onion_number_mapping[onion_name]])

func update_onion_labels() -> void:
	# Update label for each onion - adjust the path if your labels are named differently
	if onion1 and onion1.has_node("Label"):
		onion1.get_node("Label").text = str(onion_number_mapping["onion1"])
	if onion2 and onion2.has_node("Label"):
		onion2.get_node("Label").text = str(onion_number_mapping["onion2"])
	if onion3 and onion3.has_node("Label"):
		onion3.get_node("Label").text = str(onion_number_mapping["onion3"])
	if onion4 and onion4.has_node("Label"):
		onion4.get_node("Label").text = str(onion_number_mapping["onion4"])
	if onion5 and onion5.has_node("Label"):
		onion5.get_node("Label").text = str(onion_number_mapping["onion5"])

func setup_onion_handlers():
	if onion1:
		onion1.pressed.connect(_on_onion_pressed.bind(onion_number_mapping["onion1"], onion1, "onion1"))
	if onion2:
		onion2.pressed.connect(_on_onion_pressed.bind(onion_number_mapping["onion2"], onion2, "onion2"))
	if onion3:
		onion3.pressed.connect(_on_onion_pressed.bind(onion_number_mapping["onion3"], onion3, "onion3"))
	if onion4:
		onion4.pressed.connect(_on_onion_pressed.bind(onion_number_mapping["onion4"], onion4, "onion4"))
	if onion5:
		onion5.pressed.connect(_on_onion_pressed.bind(onion_number_mapping["onion5"], onion5, "onion5"))

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
	var elapsed_time = 15 - countdown
		
	# Play motivational sounds at specific marks
	if elapsed_time == 5 and !motivational_5s_played:
		AudioManager.play_sound("motivational_5s")
		motivational_5s_played = true
		print("Playing 5-second motivational audio")
	elif elapsed_time == 10 and !motivational_10s_played:
		AudioManager.play_sound("motivational_10s")
		motivational_10s_played = true
		print("Playing 10-second motivational audio")
	if timer_label:
		timer_label.text = str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func _on_onion_pressed(onion_number: int, onion_node: Control, onion_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_onion_order[current_onion_index]
	print("Pressed %s (shows %d), Expected: %d" % [onion_name, onion_number, expected_number])
	
	if onion_number == expected_number:
		on_correct_onion(onion_number, onion_node)
	else:
		on_wrong_onion(onion_number, expected_number, onion_node)

func on_correct_onion(onion_number: int, onion_node: Control):
	if !timer_active:
		return
	
	completed_onions.append(onion_number)
	current_onion_index += 1
	
	onion_node.disabled = true
	await pop_onion_visual(onion_node)
	onion_node.visible = false
	
	if completed_onions.size() >= correct_onion_order.size():
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All onions tapped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		if feedback_label and current_onion_index < correct_onion_order.size():
			feedback_label.text = "✅ Great! Now tap %d" % correct_onion_order[current_onion_index]

func on_wrong_onion(onion_number: int, expected_number: int, onion_node: Control):
	if !timer_active:
		return
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! Tap %d first." % expected_number
	
	shake_onion(onion_node)
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_onion_visual(onion_node: Control):
	var tween = create_tween()
	tween.parallel().tween_property(onion_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(onion_node, "rotation", deg_to_rad(10), 0.1)
	tween.tween_property(onion_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(onion_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(onion_node, "rotation", deg_to_rad(-15), 0.3)
	await tween.finished

func shake_onion(onion_node: Control) -> void:
	var original_pos = onion_node.position
	var tween = create_tween()
	tween.tween_property(onion_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(onion_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(onion_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(onion_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if onion1: onion1.visible = false
	if onion2: onion2.visible = false
	if onion3: onion3.visible = false
	if onion4: onion4.visible = false
	if onion5: onion5.visible = false
	
	var popup_instance: Node = null
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()
	
	if popup_instance:
		add_child(popup_instance)
	
	if success:
		ProgressManager.save_progress("math", true)
		Global.refresh_everything_after_stage_completion("math", true)
	else:
		ProgressManager.save_progress("math", false)
		Global.refresh_everything_after_stage_completion("math", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		if current_onion_index < correct_onion_order.size():
			feedback_label.text = "Tap %d next!" % correct_onion_order[current_onion_index]
		else:
			feedback_label.text = "Tap the onions in order: 6, 7, 8, 9, 10"


func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
