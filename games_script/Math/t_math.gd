extends Control

# Correct order for trucks
var correct_truck_order = [16, 17, 18, 19, 20]
var current_truck_index = 0
var completed_trucks = []

# Mapping of truck nodes to their actual numbers
var truck_number_mapping = {
	"truck1": 17,
	"truck2": 18,
	"truck3": 19,
	"truck4": 20,
	"truck5": 16
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

# Truck nodes
@onready var truck1 = $Truck1
@onready var truck2 = $Truck2
@onready var truck3 = $Truck3
@onready var truck4 = $Truck4
@onready var truck5 = $Truck5

func _ready():
	completed_trucks.clear()
	current_truck_index = 0
	
	# Randomize truck number assignments
	randomize_truck_numbers()
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the trucks in order: 16, 17, 18, 19, 20"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	setup_truck_handlers()
	motivational_5s_played = false
	motivational_10s_played = false

func randomize_truck_numbers() -> void:
	# Create a shuffled list of numbers 16-20
	var numbers = [16, 17, 18, 19, 20]
	numbers.shuffle()
	
	# Assign shuffled numbers to each truck
	truck_number_mapping["truck1"] = numbers[0]
	truck_number_mapping["truck2"] = numbers[1]
	truck_number_mapping["truck3"] = numbers[2]
	truck_number_mapping["truck4"] = numbers[3]
	truck_number_mapping["truck5"] = numbers[4]
	
	# Update the truck label displays
	update_truck_labels()
	
	# Debug: Print the randomized mapping
	print("🚚 Randomized Truck Mapping:")
	for truck_name in truck_number_mapping:
		print("%s → %d" % [truck_name, truck_number_mapping[truck_name]])

func update_truck_labels() -> void:
	# Update label for each truck - adjust the path if your labels are named differently
	if truck1 and truck1.has_node("Label"):
		truck1.get_node("Label").text = str(truck_number_mapping["truck1"])
	if truck2 and truck2.has_node("Label"):
		truck2.get_node("Label").text = str(truck_number_mapping["truck2"])
	if truck3 and truck3.has_node("Label"):
		truck3.get_node("Label").text = str(truck_number_mapping["truck3"])
	if truck4 and truck4.has_node("Label"):
		truck4.get_node("Label").text = str(truck_number_mapping["truck4"])
	if truck5 and truck5.has_node("Label"):
		truck5.get_node("Label").text = str(truck_number_mapping["truck5"])

func setup_truck_handlers():
	if truck1:
		truck1.pressed.connect(_on_truck_pressed.bind(truck_number_mapping["truck1"], truck1, "truck1"))
	if truck2:
		truck2.pressed.connect(_on_truck_pressed.bind(truck_number_mapping["truck2"], truck2, "truck2"))
	if truck3:
		truck3.pressed.connect(_on_truck_pressed.bind(truck_number_mapping["truck3"], truck3, "truck3"))
	if truck4:
		truck4.pressed.connect(_on_truck_pressed.bind(truck_number_mapping["truck4"], truck4, "truck4"))
	if truck5:
		truck5.pressed.connect(_on_truck_pressed.bind(truck_number_mapping["truck5"], truck5, "truck5"))

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

func _on_truck_pressed(truck_number: int, truck_node: Control, truck_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_truck_order[current_truck_index]
	print("Pressed %s (shows %d), Expected: %d" % [truck_name, truck_number, expected_number])
	
	if truck_number == expected_number:
		on_correct_truck(truck_number, truck_node)
	else:
		on_wrong_truck(truck_number, expected_number, truck_node)

func on_correct_truck(truck_number: int, truck_node: Control):
	if !timer_active:
		return
	
	completed_trucks.append(truck_number)
	current_truck_index += 1
	
	truck_node.disabled = true
	await pop_truck_visual(truck_node)
	truck_node.visible = false
	
	if completed_trucks.size() >= correct_truck_order.size():
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All trucks tapped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		if feedback_label and current_truck_index < correct_truck_order.size():
			feedback_label.text = "✅ Great! Now tap %d" % correct_truck_order[current_truck_index]

func on_wrong_truck(truck_number: int, expected_number: int, truck_node: Control):
	if !timer_active:
		return
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! Tap %d first." % expected_number
	
	shake_truck(truck_node)
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_truck_visual(truck_node: Control):
	var tween = create_tween()
	tween.parallel().tween_property(truck_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(truck_node, "rotation", deg_to_rad(10), 0.1)
	tween.tween_property(truck_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(truck_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(truck_node, "rotation", deg_to_rad(-15), 0.3)
	await tween.finished

func shake_truck(truck_node: Control) -> void:
	var original_pos = truck_node.position
	var tween = create_tween()
	tween.tween_property(truck_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(truck_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(truck_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(truck_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if truck1: truck1.visible = false
	if truck2: truck2.visible = false
	if truck3: truck3.visible = false
	if truck4: truck4.visible = false
	if truck5: truck5.visible = false
	
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
		if current_truck_index < correct_truck_order.size():
			feedback_label.text = "Tap %d next!" % correct_truck_order[current_truck_index]
		else:
			feedback_label.text = "Tap the trucks in order: 16, 17, 18, 19, 20"

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
