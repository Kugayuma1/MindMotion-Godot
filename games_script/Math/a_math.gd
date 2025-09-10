# VISUAL MATH GAME - FIXED WITH CORRECT NODE PATHS
# Attach this to your main Control node
extends Control

# Game settings
var countdown := 15
var timer_active := true
var correct_answer := 0
var current_equation := ""

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Track time
var start_time: int = 0

# UI References
@onready var equation_label = $TextureRect/Holder/Label
@onready var timer_label = $TextureRect/Time/Label
@onready var button1 = $Button1/Label3
@onready var button2 = $Button2/Label3  
@onready var button3 = $Button3/Label3
@onready var button4 = $Button4/Label3

# Button nodes
@onready var btn1 = $Button1
@onready var btn2 = $Button2
@onready var btn3 = $Button3
@onready var btn4 = $Button4

# CORRECT NODE PATHS based on your scene structure
var group1_names = ["LeftGroup/TextureRect2", "LeftGroup/TextureRect3", "LeftGroup/TextureRect4", "LeftGroup/TextureRect5"]  # LEFT SIDE - 4 avocados
var group2_names = ["RightGroup/TextureRect6", "RightGroup/TextureRect7", "RightGroup/TextureRect8"]  # RIGHT SIDE - 3 avocados

var group1_avocados = []
var group2_avocados = []

func _ready():
	print("=== GAME STARTING WITH CORRECT PATHS ===")
	start_time = Time.get_ticks_msec()  # record when the game starts
	
	assign_avocados_to_groups()
	setup_visual_math_game()
	debug_everything()
	start_timer()
	setup_buttons()

func assign_avocados_to_groups():
	print("--- ASSIGNING AVOCADOS TO GROUPS (CORRECT PATHS) ---")
	
	group1_avocados = []
	group2_avocados = []
	
	# Assign Group 1 avocados (LEFT SIDE)
	for avocado_path in group1_names:
		var avocado_node = get_node_or_null(avocado_path)
		if avocado_node:
			group1_avocados.append(avocado_node)
			print("✅ Added %s to GROUP 1 (LEFT)" % avocado_path)
		else:
			print("❌ Could not find: %s" % avocado_path)
	
	# Assign Group 2 avocados (RIGHT SIDE)  
	for avocado_path in group2_names:
		var avocado_node = get_node_or_null(avocado_path)
		if avocado_node:
			group2_avocados.append(avocado_node)
			print("✅ Added %s to GROUP 2 (RIGHT)" % avocado_path)
		else:
			print("❌ Could not find: %s" % avocado_path)
	
	print("Group 1 (LEFT) has %d avocados" % group1_avocados.size())
	print("Group 2 (RIGHT) has %d avocados" % group2_avocados.size())
	print("Expected equation: %d + %d = %d" % [group1_avocados.size(), group2_avocados.size(), group1_avocados.size() + group2_avocados.size()])

func setup_visual_math_game():
	print("--- SETTING UP MATH GAME ---")
	
	# Count avocados in each group
	var group1_count = group1_avocados.size()
	var group2_count = group2_avocados.size()
	
	# Calculate correct answer
	correct_answer = group1_count + group2_count
	
	# Create equation
	current_equation = "%d + %d = %d" % [group1_count, group2_count, correct_answer]
	
	print("Visual equation: %s" % current_equation)
	print("Correct answer: %d" % correct_answer)
	
	# Generate choices for buttons
	generate_answer_choices()

func generate_answer_choices():
	print("--- GENERATING ANSWER CHOICES ---")
	
	# ALWAYS start with the correct answer
	var choices = [correct_answer]
	
	# Generate exactly 3 wrong answers
	var wrong_answers = []
	
	# Create potential wrong answers
	var potential_wrongs = [
		correct_answer - 3,
		correct_answer - 2,
		correct_answer - 1,
		correct_answer + 1,
		correct_answer + 2,
		correct_answer + 3,
		correct_answer + 4,
		correct_answer + 5,
		correct_answer + 6
	]
	
	# Filter and collect valid wrong answers
	for wrong in potential_wrongs:
		if wrong > 0 and wrong != correct_answer and not wrong_answers.has(wrong):
			wrong_answers.append(wrong)
		if wrong_answers.size() >= 3:
			break
	
	# If we don't have enough wrong answers, generate some manually
	while wrong_answers.size() < 3:
		var new_wrong = correct_answer + wrong_answers.size() + 7
		if new_wrong != correct_answer and not wrong_answers.has(new_wrong):
			wrong_answers.append(new_wrong)
	
	# Add exactly 3 wrong answers to choices
	for i in range(3):
		if i < wrong_answers.size():
			choices.append(wrong_answers[i])
	
	print("Before shuffle - Choices: %s" % str(choices))
	print("Correct answer: %d (MUST be in choices)" % correct_answer)
	
	# VERIFY correct answer is in choices
	if not choices.has(correct_answer):
		print("🚨 ERROR: Correct answer missing! Forcing it back...")
		choices[0] = correct_answer
	
	# Shuffle the choices
	choices.shuffle()
	
	print("After shuffle - Final choices: %s" % str(choices))
	print("Correct answer %d is at position: %d" % [correct_answer, choices.find(correct_answer) + 1])
	
	# Assign to buttons
	assign_to_buttons(choices)

func assign_to_buttons(choices: Array):
	print("--- ASSIGNING TO BUTTONS ---")
	
	# VERIFY we have exactly 4 choices
	if choices.size() != 4:
		print("🚨 ERROR: Expected 4 choices, got %d" % choices.size())
		return
		
	if not choices.has(correct_answer):
		print("🚨 CRITICAL ERROR: Correct answer %d not in choices!" % correct_answer)
		return
	
	var buttons = [btn1, btn2, btn3, btn4]
	var labels = [button1, button2, button3, button4]
	
	for i in range(4):
		var value = choices[i]
		
		# Set button label
		if labels[i]:
			labels[i].text = str(value)
			print("✅ Button %d label set to: %s" % [i+1, str(value)])
		else:
			print("❌ Button %d label not found!" % [i+1])
		
		# Set button meta data
		if buttons[i]:
			buttons[i].set_meta("answer_value", value)
			print("✅ Button %d meta set to: %d" % [i+1, value])
			
			# Verify the meta was set correctly
			var verify_meta = buttons[i].get_meta("answer_value", -999)
			if verify_meta != value:
				print("🚨 Meta verification failed for button %d!" % [i+1])
		else:
			print("❌ Button %d node not found!" % [i+1])
	
	# Final verification
	print("=== FINAL VERIFICATION ===")
	var correct_button_found = false
	for i in range(4):
		if buttons[i]:
			var button_value = buttons[i].get_meta("answer_value", -999)
			if button_value == correct_answer:
				correct_button_found = true
				print("✅ Correct answer %d found on Button %d" % [correct_answer, i+1])
	
	if not correct_button_found:
		print("🚨 CRITICAL: NO BUTTON HAS THE CORRECT ANSWER!")
	else:
		print("✅ SUCCESS: Correct answer is assigned to a button")

func setup_buttons():
	if btn1: btn1.pressed.connect(_on_button_pressed.bind(1))
	if btn2: btn2.pressed.connect(_on_button_pressed.bind(2))
	if btn3: btn3.pressed.connect(_on_button_pressed.bind(3))
	if btn4: btn4.pressed.connect(_on_button_pressed.bind(4))

func _on_button_pressed(button_num: int):
	if !timer_active:
		return
	
	var buttons = [btn1, btn2, btn3, btn4]
	var clicked_button = buttons[button_num - 1]
	if !clicked_button:
		return
	
	var selected_answer = clicked_button.get_meta("answer_value", -999)
	
	if selected_answer == correct_answer:
		# Correct!
		if equation_label:
			equation_label.text = "✅ Tama! " + str(correct_answer)
		timer_active = false
		
		# Calculate elapsed time
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		print("🎉 CORRECT in %.2f seconds" % elapsed)
		
		game_over(true, elapsed)   # ✅ now passes elapsed
		ProgressManager.save_progress("math", true)
	else:
		if equation_label:
			equation_label.text = "❌ Mali!"
		shake_button(clicked_button)
		await get_tree().create_timer(1.5).timeout
		if timer_active and equation_label:
			equation_label.text = "solve"


func shake_button(button: Control) -> void:
	if !button:
		return
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.10)

func start_timer() -> void:
	countdown = 15
	timer_active = true
	if timer_label:
		timer_label.text = "⏱️ " + str(countdown) + "s"
	update_timer()   # ✅ start the countdown loop

func update_timer() -> void:
	if countdown <= 0:
		timer_active = false
		if timer_label:
			timer_label.text = "⏰ Tapos na!"
		if equation_label:
			equation_label.text = "⏱️ Time's up! Answer: " + str(correct_answer)
		ProgressManager.save_progress("math", false)
		game_over(false)
		return

	# Show time
	if timer_label:
		timer_label.text = "⏱️ " + str(countdown) + "s"
	
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()   # ✅ loop continues

		
func game_over(success: bool, elapsed: float = 999.0):
	# Hide UI elements
	if has_node("TextureRect/GameBG"): $TextureRect/GameBG.visible = false
	if has_node("TextureRect/Time"): $TextureRect/Time.visible = false
	if has_node("TextureRect/Holder"): $TextureRect/Holder.visible = false
	if has_node("TextureRect/Label"): $TextureRect/Label.visible = false
	if has_node("TextureRect/Label2"): $TextureRect/Label2.visible = false
	if has_node("TextureRect/Label3"): $TextureRect/Label3.visible = false
	if has_node("RightGroup"): $RightGroup.visible = false
	if has_node("LeftGroup"): $LeftGroup.visible = false
	if has_node("Button1"): $Button1.visible = false
	if has_node("Button2"): $Button2.visible = false
	if has_node("Button3"): $Button3.visible = false
	if has_node("Button4"): $Button4.visible = false
	
	# ✅ POPUP LOGIC BASED ON COUNTDOWN (like the spelling game)
	if success:
		if countdown >= 10:   # finished fast → 3 stars
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:  # medium speed → 2 stars
			popup_instance = complete2_scene.instantiate()
		else:                 # slow but correct → 1 star
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()  # always show 1-star if failed

	# Add popup to scene
	if popup_instance:
		add_child(popup_instance)

# DEBUG FUNCTION
func debug_everything():
	print("\n=== COMPLETE DEBUG INFO ===")
	print("Group 1 (LEFT) count: %d avocados" % group1_avocados.size())
	print("Group 2 (RIGHT) count: %d avocados" % group2_avocados.size()) 
	print("Equation: %s" % current_equation)
	print("Correct answer: %d" % correct_answer)
	
	# Check button assignments
	var buttons = [btn1, btn2, btn3, btn4]
	var labels = [button1, button2, button3, button4]
	var correct_found = false
	
	print("--- BUTTON ANALYSIS ---")
	for i in range(4):
		if buttons[i] and labels[i]:
			var meta_val = buttons[i].get_meta("answer_value", "MISSING")
			var label_text = labels[i].text
			var is_correct = (meta_val == correct_answer)
			if is_correct:
				correct_found = true
			print("Button %d: Label='%s', Meta=%s, IsCorrect=%s" % [i+1, label_text, str(meta_val), str(is_correct)])
		else:
			print("Button %d: NODE REFERENCE ERROR" % [i+1])
	
	if correct_found:
		print("✅ SUCCESS: Correct answer IS available on a button")
	else:
		print("🚨 PROBLEM: Correct answer NOT found on any button!")
	
	print("========================\n")
