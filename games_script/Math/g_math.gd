extends Control

# Correct order for gifts
var correct_gift_order = [11, 12, 13, 14, 15]
var current_gift_index = 0
var completed_gifts = []

# Mapping of gift nodes to their actual numbers
var gift_number_mapping = {
	"gift1": 11,
	"gift2": 12,
	"gift3": 14,
	"gift4": 13,
	"gift5": 15
}

var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""
var motivational_5s_played = false
var motivational_10s_played = false

# Reward scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

# Gift nodes
@onready var gift1 = $Gift1
@onready var gift2 = $Gift2
@onready var gift3 = $Gift3
@onready var gift4 = $Gift4
@onready var gift5 = $Gift5

func _ready():
	completed_gifts.clear()
	current_gift_index = 0
	
	# Randomize gift number assignments
	randomize_gift_numbers()
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the gifts in order: 11, 12, 13, 14, 15"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	setup_gift_handlers()
	var motivational_5s_played = false
	var motivational_10s_played = false

func randomize_gift_numbers() -> void:
	# Create a shuffled list of numbers 11-15
	var numbers = [11, 12, 13, 14, 15]
	numbers.shuffle()
	
	# Assign shuffled numbers to each gift
	gift_number_mapping["gift1"] = numbers[0]
	gift_number_mapping["gift2"] = numbers[1]
	gift_number_mapping["gift3"] = numbers[2]
	gift_number_mapping["gift4"] = numbers[3]
	gift_number_mapping["gift5"] = numbers[4]
	
	# Update the gift label displays
	update_gift_labels()
	
	# Debug: Print the randomized mapping
	print("🎁 Randomized Gift Mapping:")
	for gift_name in gift_number_mapping:
		print("%s → %d" % [gift_name, gift_number_mapping[gift_name]])

func update_gift_labels() -> void:
	# Update label for each gift - adjust the path if your labels are named differently
	if gift1 and gift1.has_node("Label"):
		gift1.get_node("Label").text = str(gift_number_mapping["gift1"])
	if gift2 and gift2.has_node("Label"):
		gift2.get_node("Label").text = str(gift_number_mapping["gift2"])
	if gift3 and gift3.has_node("Label"):
		gift3.get_node("Label").text = str(gift_number_mapping["gift3"])
	if gift4 and gift4.has_node("Label"):
		gift4.get_node("Label").text = str(gift_number_mapping["gift4"])
	if gift5 and gift5.has_node("Label"):
		gift5.get_node("Label").text = str(gift_number_mapping["gift5"])

func setup_gift_handlers():
	if gift1:
		gift1.pressed.connect(_on_gift_pressed.bind(gift_number_mapping["gift1"], gift1, "gift1"))
	if gift2:
		gift2.pressed.connect(_on_gift_pressed.bind(gift_number_mapping["gift2"], gift2, "gift2"))
	if gift3:
		gift3.pressed.connect(_on_gift_pressed.bind(gift_number_mapping["gift3"], gift3, "gift3"))
	if gift4:
		gift4.pressed.connect(_on_gift_pressed.bind(gift_number_mapping["gift4"], gift4, "gift4"))
	if gift5:
		gift5.pressed.connect(_on_gift_pressed.bind(gift_number_mapping["gift5"], gift5, "gift5"))

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

func _on_gift_pressed(gift_number: int, gift_node: Control, gift_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_gift_order[current_gift_index]
	print("Pressed %s (shows %d), Expected: %d" % [gift_name, gift_number, expected_number])
	
	if gift_number == expected_number:
		on_correct_gift(gift_number, gift_node)
	else:
		on_wrong_gift(gift_number, expected_number, gift_node)

func on_correct_gift(gift_number: int, gift_node: Control):
	if !timer_active:
		return
	
	completed_gifts.append(gift_number)
	current_gift_index += 1
	
	gift_node.disabled = true
	await pop_gift_visual(gift_node)
	gift_node.visible = false
	
	if completed_gifts.size() >= correct_gift_order.size():
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All gifts tapped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		if feedback_label and current_gift_index < correct_gift_order.size():
			feedback_label.text = "✅ Great! Now tap %d" % correct_gift_order[current_gift_index]

func on_wrong_gift(gift_number: int, expected_number: int, gift_node: Control):
	if !timer_active:
		return
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! Tap %d first." % expected_number
	
	shake_gift(gift_node)
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_gift_visual(gift_node: Control):
	var tween = create_tween()
	tween.parallel().tween_property(gift_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(gift_node, "rotation", deg_to_rad(10), 0.1)
	tween.tween_property(gift_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(gift_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(gift_node, "rotation", deg_to_rad(-15), 0.3)
	await tween.finished

func shake_gift(gift_node: Control) -> void:
	var original_pos = gift_node.position
	var tween = create_tween()
	tween.tween_property(gift_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(gift_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(gift_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(gift_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if gift1: gift1.visible = false
	if gift2: gift2.visible = false
	if gift3: gift3.visible = false
	if gift4: gift4.visible = false
	if gift5: gift5.visible = false
	
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
		if current_gift_index < correct_gift_order.size():
			feedback_label.text = "Tap %d next!" % correct_gift_order[current_gift_index]
		else:
			feedback_label.text = "Tap the gifts in order: 11, 12, 13, 14, 15"

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
