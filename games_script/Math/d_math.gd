# DUCK COUNTING GAME
# Attach this to your main Control node
extends Control

# Game settings
var countdown := 15
var timer_active := true
var correct_answer := 0
var current_question := "How many Ducks are in the pond?"

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Track time
var start_time: int = 0

# UI References - adjust paths to match your scene structure
@onready var question_label = $Holder/Label  # "How many Ducks are in the pond?" 
@onready var timer_label = $Time/Label
@onready var button1_label = $Button1/Label3  # Button text labels
@onready var button2_label = $Button2/Label3  
@onready var button3_label = $Button3/Label3
@onready var button4_label = $Button4/Label3

# Button nodes
@onready var btn1 = $Button1
@onready var btn2 = $Button2
@onready var btn3 = $Button3
@onready var btn4 = $Button4

# Duck container - adjust path to match your scene structure
@onready var ducks_container = $Ducks  # Container with all duck nodes

# List of duck node names in your scene
var duck_names = ["Duck", "Duck2", "Duck3", "Duck4", "Duck5", "Duck6", "Duck7"]  # Add more as needed

var duck_nodes = []

func _ready():
	print("=== DUCK COUNTING GAME STARTING ===")
	Global.start_time = Time.get_ticks_msec()  # record when the game starts
	
	find_all_ducks()
	setup_counting_game()
	debug_everything()
	start_timer()
	setup_buttons()

func find_all_ducks():
	print("--- FINDING ALL DUCKS ---")
	
	duck_nodes.clear()
	
	# Method 1: Try to find ducks in a container
	if ducks_container:
		for child in ducks_container.get_children():
			duck_nodes.append(child)
			print("✅ Found duck in container: %s" % child.name)
	else:
		# Method 2: Look for specific duck names in the scene
		for duck_name in duck_names:
			var duck_node = get_node_or_null(duck_name)
			if duck_node:
				duck_nodes.append(duck_node)
				print("✅ Found duck by name: %s" % duck_name)
			else:
				print("❌ Could not find duck: %s" % duck_name)
	
	print("Total ducks found: %d" % duck_nodes.size())
	
	# If no ducks found, create a fallback count (for testing)
	if duck_nodes.size() == 0:
		print("⚠️ No ducks found! Using fallback count of 8")
		correct_answer = 8
	else:
		correct_answer = duck_nodes.size()

func setup_counting_game():
	print("--- SETTING UP COUNTING GAME ---")
	
	# Set the question
	if question_label:
		question_label.text = current_question
	
	print("Question: %s" % current_question)
	print("Correct answer: %d ducks" % correct_answer)
	
	# Generate choices for buttons
	generate_answer_choices()

func generate_answer_choices():
	print("--- GENERATING ANSWER CHOICES ---")
	
	# ALWAYS start with the correct answer
	var choices = [correct_answer]
	
	# Generate exactly 3 wrong answers
	var wrong_answers = []
	
	# Create potential wrong answers around the correct count
	var potential_wrongs = []
	
	# Add numbers around the correct answer
	for i in range(correct_answer - 4, correct_answer + 5):
		if i > 0 and i != correct_answer:  # Must be positive and not correct
			potential_wrongs.append(i)
	
	# Also add some random numbers in a reasonable range
	var random_range_min = max(1, correct_answer - 6)
	var random_range_max = correct_answer + 8
	
	for i in range(random_range_min, random_range_max + 1):
		if i != correct_answer and not potential_wrongs.has(i):
			potential_wrongs.append(i)
	
	# Shuffle and pick 3 wrong answers
	potential_wrongs.shuffle()
	
	for wrong in potential_wrongs:
		if wrong_answers.size() < 3:
			wrong_answers.append(wrong)
	
	# If we still don't have enough wrong answers, generate some manually
	while wrong_answers.size() < 3:
		var new_wrong = correct_answer + wrong_answers.size() + 10
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
	var labels = [button1_label, button2_label, button3_label, button4_label]
	
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
	
	print("Button %d pressed. Selected answer: %d, Correct: %d" % [button_num, selected_answer, correct_answer])
	
	if selected_answer == correct_answer:
		# Correct!
		if question_label:
			question_label.text = "✅ Correct! There are " + str(correct_answer) + " ducks!"
		timer_active = false
		
		# Calculate elapsed time
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		print("🎉 CORRECT in %.2f seconds" % elapsed)
		
		# Optional: Highlight all ducks briefly
		highlight_all_ducks()
		
		await get_tree().create_timer(2.0).timeout  # Show success message longer
		game_over(true, elapsed)
		ProgressManager.save_progress("duck_counting", true)
	else:
		if question_label:
			question_label.text = "❌ Wrong! Try again!"
		shake_button(clicked_button)
		await get_tree().create_timer(1.5).timeout
		if timer_active and question_label:
			question_label.text = current_question

func highlight_all_ducks():
	# Optional: Make all ducks briefly glow or bounce
	for duck in duck_nodes:
		if duck:
			var tween = create_tween()
			tween.parallel().tween_property(duck, "modulate", Color.YELLOW, 0.3)
			tween.parallel().tween_property(duck, "scale", Vector2(1.2, 1.2), 0.3)
			tween.parallel().tween_property(duck, "modulate", Color.WHITE, 0.3).set_delay(0.3)
			tween.parallel().tween_property(duck, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.3)

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
		timer_label.text = str(countdown) + "s"
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_active = false
		if timer_label:
			timer_label.text = "⏰ Done!"
		if question_label:
			question_label.text = "⏱️ Time's up! Answer: " + str(correct_answer) + " ducks"
		ProgressManager.save_progress("duck_counting", false)
		await get_tree().create_timer(2.0).timeout
		game_over(false)
		return

	# Show time
	if timer_label:
		timer_label.text = str(countdown) + "s"
	
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

func game_over(success: bool, elapsed: float = 999.0):
	timer_active = false
	
	# Hide game UI elements - adjust paths as needed
	
	if has_node("Time"): $Time.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Ducks"): $Ducks.visible = false
	if has_node("Button1"): $Button1.visible = false
	if has_node("Button2"): $Button2.visible = false
	if has_node("Button3"): $Button3.visible = false
	if has_node("Button4"): $Button4.visible = false
	
	# Popup logic based on countdown (like the math game)
	if success:
		if countdown >= 10:   # finished fast → 3 stars
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:  # medium speed → 2 stars
			popup_instance = complete2_scene.instantiate()
		else:                 # slow but correct → 1 star
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()  # retry scene

	# Add popup to scene
	if popup_instance:
		add_child(popup_instance)

# DEBUG FUNCTION
func debug_everything():
	print("\n=== COMPLETE DEBUG INFO ===")
	print("Total ducks found: %d" % duck_nodes.size())
	print("Question: %s" % current_question)
	print("Correct answer: %d" % correct_answer)
	
	# List all duck nodes
	print("--- DUCK NODES ---")
	for i in range(duck_nodes.size()):
		var duck = duck_nodes[i]
		print("Duck %d: %s" % [i+1, duck.name if duck else "NULL"])
	
	# Check button assignments
	var buttons = [btn1, btn2, btn3, btn4]
	var labels = [button1_label, button2_label, button3_label, button4_label]
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
