# HOTDOG COUNTING GAME
# Attach this to your main Control node
extends Control

# Game settings
var countdown := 15
var timer_active := true
var correct_answer := 0
var current_question := "How many Hotdogs are on the table?"

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Track time
var start_time: int = 0

# UI References - adjust paths to match your scene structure
@onready var question_label = $Holder/Label
@onready var timer_label = $Time/Label
@onready var button1_label = $Button1/Label3
@onready var button2_label = $Button2/Label3
@onready var button3_label = $Button3/Label3
@onready var button4_label = $Button4/Label3

# Button nodes
@onready var btn1 = $Button1
@onready var btn2 = $Button2
@onready var btn3 = $Button3
@onready var btn4 = $Button4

# Hotdog container - adjust path to match your scene structure
@onready var hotdogs_container = $Hotdogs  # Container with all hotdog nodes

# List of hotdog node names in your scene
var hotdog_names = ["Hotdog1", "Hotdog2", "Hotdog3", "Hotdog4", "Hotdog5"]

var hotdog_nodes = []

func _ready():
	Global.start_time = Time.get_ticks_msec()
	find_all_hotdogs()
	setup_counting_game()
	start_timer()
	setup_buttons()

func find_all_hotdogs():
	hotdog_nodes.clear()
	
	# Method 1: From container
	if hotdogs_container:
		for child in hotdogs_container.get_children():
			hotdog_nodes.append(child)
			print("✅ Found hotdog in container: %s" % child.name)
	else:
		# Method 2: From predefined names
		for hotdog_name in hotdog_names:
			var hotdog_node = get_node_or_null(hotdog_name)
			if hotdog_node:
				hotdog_nodes.append(hotdog_node)
				print("✅ Found hotdog by name: %s" % hotdog_name)
			else:
				print("❌ Could not find hotdog: %s" % hotdog_name)
	
	print("Total hotdogs found: %d" % hotdog_nodes.size())
	
	if hotdog_nodes.size() == 0:
		print("⚠️ No hotdogs found! Using fallback count of 5")
		correct_answer = 5
	else:
		correct_answer = hotdog_nodes.size()

func setup_counting_game():
	if question_label:
		question_label.text = current_question
	print("Question: %s" % current_question)
	print("Correct answer: %d hotdogs" % correct_answer)
	generate_answer_choices()

func generate_answer_choices():
	var choices = [correct_answer]
	var wrong_answers = []
	
	# Add numbers around correct answer
	var potential_wrongs = []
	for i in range(correct_answer - 4, correct_answer + 5):
		if i > 0 and i != correct_answer:
			potential_wrongs.append(i)
	
	potential_wrongs.shuffle()
	for wrong in potential_wrongs:
		if wrong_answers.size() < 3:
			wrong_answers.append(wrong)
	
	while wrong_answers.size() < 3:
		wrong_answers.append(correct_answer + wrong_answers.size() + 1)
	
	for wrong in wrong_answers.slice(0, 3):
		choices.append(wrong)
	
	choices.shuffle()
	assign_to_buttons(choices)

func assign_to_buttons(choices: Array):
	var buttons = [btn1, btn2, btn3, btn4]
	var labels = [button1_label, button2_label, button3_label, button4_label]
	
	for i in range(4):
		var value = choices[i]
		if labels[i]:
			labels[i].text = str(value)
		if buttons[i]:
			buttons[i].set_meta("answer_value", value)

func setup_buttons():
	if btn1: btn1.pressed.connect(_on_button_pressed.bind(1))
	if btn2: btn2.pressed.connect(_on_button_pressed.bind(2))
	if btn3: btn3.pressed.connect(_on_button_pressed.bind(3))
	if btn4: btn4.pressed.connect(_on_button_pressed.bind(4))

func _on_button_pressed(button_num: int):
	if !timer_active: return
	var buttons = [btn1, btn2, btn3, btn4]
	var clicked_button = buttons[button_num - 1]
	if !clicked_button: return
	
	var selected_answer = clicked_button.get_meta("answer_value", -999)
	if selected_answer == correct_answer:
		if question_label:
			question_label.text = "✅ Correct! There are " + str(correct_answer) + " hotdogs!"
		timer_active = false
		game_over(true)
	else:
		if question_label:
			question_label.text = "❌ Wrong! Try again!"
		shake_button(clicked_button)
		await get_tree().create_timer(1.5).timeout
		if timer_active and question_label:
			question_label.text = current_question

func shake_button(button: Control) -> void:
	if !button: return
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.1)

func start_timer() -> void:
	countdown = 15
	timer_active = true
	if timer_label: timer_label.text = str(countdown) + "s"
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_active = false
		if question_label:
			question_label.text = "⏱️ Time's up! Answer: " + str(correct_answer) + " hotdogs"
		game_over(false)
		return
	
	if timer_label:
		timer_label.text = str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active: update_timer()

func game_over(success: bool):
	timer_active = false
	if has_node("Time"): $Time.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Hotdogs"): $Hotdogs.visible = false
	if has_node("Button1"): $Button1.visible = false
	if has_node("Button2"): $Button2.visible = false
	if has_node("Button3"): $Button3.visible = false
	if has_node("Button4"): $Button4.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	if success:
		ProgressManager.save_progress("math", true)
		Global.refresh_everything_after_stage_completion("math", true)
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		ProgressManager.save_progress("math", false)
		Global.refresh_everything_after_stage_completion("math", false)
		popup_instance = retry_scene.instantiate()
	
	if popup_instance:
		add_child(popup_instance)

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
