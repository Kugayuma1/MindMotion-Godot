# XYLOPHONE COUNTING GAME
# Attach this to your main Control node
extends Control

# Game settings
var countdown := 15
var timer_active := true
var correct_answer := 0
var current_question := "How many Xylophones are in the scene?"

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null
var start_time: int = 0

# UI References
@onready var question_label = $Holder/Label
@onready var timer_label = $Time/Label
@onready var button1_label = $Button1/Label3
@onready var button2_label = $Button2/Label3
@onready var button3_label = $Button3/Label3
@onready var button4_label = $Button4/Label3

# Buttons
@onready var btn1 = $Button1
@onready var btn2 = $Button2
@onready var btn3 = $Button3
@onready var btn4 = $Button4

# Xylophone container
@onready var xylophone_container = $Xylophone  

# List of Xylophone node names (fallback if container not used)
var xylophone_names = ["Xylophone1", "Xylophone2", "Xylophone3", "Xylophone4", "Xylophone5", "Xylophone6", "Xylophone7"]

var xylophone_nodes = []

func _ready():
	start_time = Time.get_ticks_msec()
	find_all_xylophones()
	setup_counting_game()
	start_timer()
	setup_buttons()

func find_all_xylophones():
	xylophone_nodes.clear()
	
	# Method 1: From container
	if xylophone_container:
		for child in xylophone_container.get_children():
			xylophone_nodes.append(child)
			print("✅ Found xylophone in container: %s" % child.name)
	else:
		# Method 2: From predefined names
		for xylophone_name in xylophone_names:
			var xylophone_node = get_node_or_null(xylophone_name)
			if xylophone_node:
				xylophone_nodes.append(xylophone_node)
				print("✅ Found xylophone by name: %s" % xylophone_name)
			else:
				print("❌ Could not find xylophone: %s" % xylophone_name)
	
	print("Total xylophones found: %d" % xylophone_nodes.size())
	
	if xylophone_nodes.size() == 0:
		print("⚠️ No xylophones found! Using fallback count of 7")
		correct_answer = 7
	else:
		correct_answer = xylophone_nodes.size()

func setup_counting_game():
	if question_label:
		question_label.text = current_question
	print("Question: %s" % current_question)
	print("Correct answer: %d Xylophones" % correct_answer)
	generate_answer_choices()

func generate_answer_choices():
	var choices = [correct_answer]
	var wrong_answers = []
	
	# Numbers around the correct answer
	var potential_wrongs = []
	for i in range(correct_answer - 3, correct_answer + 4):
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
			question_label.text = "✅ Correct! There are " + str(correct_answer) + " Xylophones!"
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
			question_label.text = "⏱️ Time's up! Answer: " + str(correct_answer) + " Xylophones"
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
	if has_node("Xylophone"): $Xylophone.visible = false
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
