# VISUAL MATH GAME - RANDOMIZED SUBTRACTION FOR YARN SCENE
# Attach this to your main Control node
extends Control

# === GAME SETTINGS ===
const GAME_TIME: int = 15
const FAST_COMPLETION_THRESHOLD: int = 10
const MEDIUM_COMPLETION_THRESHOLD: int = 5

# === RANDOM MATH CONSTRAINTS ===
# Subtraction: left - right, minimum result is 5
var min_addend := 1
var max_addend_left := 6
var max_addend_right := 3
var min_result := 3

# === GAME STATE ===
var countdown: int = GAME_TIME
var timer_active: bool = true
var correct_answer: int = 0
var current_equation: String = ""
var start_time: int = 0
var random_left_count := 0
var random_right_count := 0

# === SCENE RESOURCES ===
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")
var popup_instance: Control = null

# === UI NODE REFERENCES ===
@onready var equation_label: Label = $Holder/Label
@onready var timer_label: Label = $Time/Label

# TextureButton references
@onready var button_nodes: Array[TextureButton] = []
@onready var button_labels: Array[Label] = []

# Yarn group paths - 9 TOTAL YARNS (6 left, 3 right)
var left_yarn_paths: Array[String] = [
	"LeftGroup/Yarn1",
	"LeftGroup/Yarn2", 
	"LeftGroup/Yarn3",
	"LeftGroup/Yarn4",
	"LeftGroup/Yarn5",
	"LeftGroup/Yarn6"
]

var right_yarn_paths: Array[String] = [
	"RightGroup/Yarn7",
	"RightGroup/Yarn8",
	"RightGroup/Yarn9"
]

# Yarn collections
var left_yarns: Array[Node] = []
var right_yarns: Array[Node] = []
var motivational_5s_played = false
var motivational_10s_played = false

# === INITIALIZATION ===
func _ready() -> void:
	print("Yarn Math Game - Starting with Randomization")
	Global.start_time = Time.get_ticks_msec()
	motivational_5s_played = false
	motivational_10s_played = false
	reset_time_tracking()
	debug_scene_structure()
	initialize_game()

func debug_scene_structure() -> void:
	"""Debug function to see what nodes actually exist"""
	print("\n=== DEBUGGING SCENE STRUCTURE ===")
	
	var ui_paths = [
		"Holder/Label",
		"Time/Label", 
		"Button1",
		"Button2",
		"Button3", 
		"Button4",
		"Button1/Label3",
		"Button2/Label3",
		"Button3/Label3",
		"Button4/Label3"
	]
	
	for path in ui_paths:
		var node = get_node_or_null(path)
		if node:
			print("Found UI: %s (%s)" % [path, node.get_class()])
		else:
			print("Missing UI: %s" % path)
	
	print("\nChecking yarn nodes...")
	var all_yarn_paths = left_yarn_paths + right_yarn_paths
	for path in all_yarn_paths:
		var node = get_node_or_null(path)
		if node:
			print("Found yarn: %s (%s)" % [path, node.get_class()])
		else:
			print("Missing yarn: %s" % path)
	
	print("=== END SCENE DEBUG ===\n")

func initialize_game() -> void:
	"""Initialize all game components in order"""
	generate_random_numbers()
	setup_node_references()
	collect_yarn_nodes()
	display_yarns_based_on_random()
	setup_math_problem()
	setup_ui()
	setup_button_connections()
	start_countdown_timer()

# === RANDOM NUMBER GENERATION ===
func generate_random_numbers() -> void:
	"""Generate random yarn counts ensuring left - right >= 5"""
	var valid_combination = false
	
	while not valid_combination:
		random_left_count = randi_range(min_addend, max_addend_left)
		random_right_count = randi_range(min_addend, max_addend_right)
		
		# Ensure subtraction result is at least 5
		if (random_left_count - random_right_count) >= min_result:
			valid_combination = true
	
	print("Random left yarns: %d" % random_left_count)
	print("Random right yarns: %d" % random_right_count)
	print("Total: %d - %d = %d" % [random_left_count, random_right_count, random_left_count - random_right_count])

func setup_node_references() -> void:
	"""Setup node references with fallback checking"""
	button_nodes.clear()
	button_labels.clear()
	
	var button_paths = ["Button1", "Button2", "Button3", "Button4"]
	var label_paths = ["Button1/Label3", "Button2/Label3", "Button3/Label3", "Button4/Label3"]
	
	for i in range(button_paths.size()):
		var button = get_node_or_null(button_paths[i])
		var label = get_node_or_null(label_paths[i])
		
		if button:
			button_nodes.append(button)
			print("Button %d reference set" % (i + 1))
		else:
			button_nodes.append(null)
			print("Button %d not found at path: %s" % [i + 1, button_paths[i]])
		
		if label:
			button_labels.append(label)
			print("Button %d label reference set" % (i + 1))
		else:
			button_labels.append(null)
			print("Button %d label not found at path: %s" % [i + 1, label_paths[i]])

# === YARN NODE COLLECTION ===
func collect_yarn_nodes() -> void:
	"""Collect all yarn nodes from both groups"""
	left_yarns.clear()
	right_yarns.clear()
	
	for yarn_path in left_yarn_paths:
		var yarn_node = get_node_or_null(yarn_path)
		if yarn_node:
			left_yarns.append(yarn_node)
			print("Found left yarn: %s" % yarn_path)
		else:
			print("Missing left yarn: %s" % yarn_path)
	
	for yarn_path in right_yarn_paths:
		var yarn_node = get_node_or_null(yarn_path)
		if yarn_node:
			right_yarns.append(yarn_node)
			print("Found right yarn: %s" % yarn_path)
		else:
			print("Missing right yarn: %s" % yarn_path)
	
	print("Left yarns: %d, Right yarns: %d" % [left_yarns.size(), right_yarns.size()])

func display_yarns_based_on_random() -> void:
	"""Show only the random amount of yarns in shuffled positions"""
	# Collect all left yarn indices
	var left_indices = []
	for i in range(left_yarns.size()):
		left_indices.append(i)
	left_indices.shuffle()
	
	# Collect all right yarn indices
	var right_indices = []
	for i in range(right_yarns.size()):
		right_indices.append(i)
	right_indices.shuffle()
	
	# Hide all yarns first
	for yarn in left_yarns:
		yarn.visible = false
	for yarn in right_yarns:
		yarn.visible = false
	
	# Show only the random count from shuffled positions
	for i in range(random_left_count):
		if i < left_indices.size():
			left_yarns[left_indices[i]].visible = true
	
	for i in range(random_right_count):
		if i < right_indices.size():
			right_yarns[right_indices[i]].visible = true
	
	print("Displayed %d left yarns (shuffled) and %d right yarns (shuffled)" % [random_left_count, random_right_count])

# === MATH PROBLEM SETUP ===
func setup_math_problem() -> void:
	"""Create the math problem based on visible yarn counts"""
	var left_count = random_left_count
	var right_count = random_right_count
	
	# Subtraction logic
	correct_answer = left_count - right_count
	current_equation = "%d - %d = ?" % [left_count, right_count]
	
	print("Equation: %s (Answer: %d)" % [current_equation, correct_answer])
	
	generate_answer_options()

func generate_answer_options() -> void:
	"""Generate 4 answer options including the correct one"""
	var options: Array[int] = [correct_answer]
	
	var wrong_options: Array[int] = []
	var attempts = 0
	
	while wrong_options.size() < 3 and attempts < 20:
		var offset = randi_range(-5, 5)
		var wrong_answer = correct_answer + offset
		
		if wrong_answer >= 0 and wrong_answer != correct_answer and not wrong_options.has(wrong_answer):
			wrong_options.append(wrong_answer)
		
		attempts += 1
	
	while wrong_options.size() < 3:
		wrong_options.append(correct_answer + wrong_options.size() + 1)
	
	for wrong in wrong_options.slice(0, 3):
		options.append(wrong)
	
	options.shuffle()
	
	print("Answer options: %s (Correct: %d)" % [str(options), correct_answer])
	assign_options_to_buttons(options)

func assign_options_to_buttons(options: Array[int]) -> void:
	"""Assign answer options to buttons"""
	for i in range(min(4, options.size())):
		if i < button_labels.size() and button_labels[i]:
			button_labels[i].text = str(options[i])
			print("Set button %d label to: %d" % [i + 1, options[i]])
		else:
			print("Could not set label for button %d" % [i + 1])
		
		if i < button_nodes.size() and button_nodes[i]:
			button_nodes[i].set_meta("answer_value", options[i])
			print("Set button %d meta to: %d" % [i + 1, options[i]])
		else:
			print("Could not set meta for button %d" % [i + 1])

# === UI SETUP ===
func setup_ui() -> void:
	"""Setup initial UI state"""
	if equation_label:
		equation_label.text = "Solve the yarn: " + current_equation
		print("Equation label set")
	else:
		print("Equation label not found")
	
	update_timer_display()

func setup_button_connections() -> void:
	"""Connect button press signals"""
	for i in range(button_nodes.size()):
		if button_nodes[i]:
			if not button_nodes[i].pressed.is_connected(_on_button_pressed):
				button_nodes[i].pressed.connect(_on_button_pressed.bind(i))
				print("Connected button %d signal" % (i + 1))
		else:
			print("Cannot connect button %d - node is null" % (i + 1))

func reset_time_tracking() -> void:
	"""Reset the global start time for accurate time tracking"""
	Global.start_time = Time.get_ticks_msec()
	start_time = Global.start_time
	print("Time tracking reset at: ", start_time)

func stop_timer() -> void:
	"""Stop the countdown timer"""
	timer_active = false

# === TIMER SYSTEM ===
func start_countdown_timer() -> void:
	"""Start the countdown timer"""
	countdown = GAME_TIME
	timer_active = true
	update_timer_display()
	countdown_loop()
	motivational_5s_played = false
	motivational_10s_played = false

func countdown_loop() -> void:
	"""Main countdown loop"""
	while timer_active and countdown > 0:
		await get_tree().create_timer(1.0).timeout
		
		if not timer_active:
			break
			
		countdown -= 1
		var elapsed_time = GAME_TIME - countdown
		
		# Play motivational sounds at specific marks
		if elapsed_time == 5 and !motivational_5s_played:
			AudioManager.play_sound("motivational_5s")
			motivational_5s_played = true
			print("Playing 5-second motivational audio")
		elif elapsed_time == 10 and !motivational_10s_played:
			AudioManager.play_sound("motivational_10s")
			motivational_10s_played = true
			print("Playing 10-second motivational audio")

		update_timer_display()
	
	if timer_active and countdown <= 0:
		handle_timeout()

func update_timer_display() -> void:
	"""Update timer label"""
	if timer_label:
		timer_label.text = " %ds" % countdown
	else:
		print("Timer label not found - cannot update display")

func handle_timeout() -> void:
	"""Handle timer timeout"""
	timer_active = false
	
	if equation_label:
		equation_label.text = "Time's up! Answer: %d" % correct_answer
	
	if timer_label:
		timer_label.text = "Time's up!"
	
	print("Game timed out")
	ProgressManager.save_progress("math", false)
	Global.refresh_everything_after_stage_completion("math", false)
	end_game(false)

# === BUTTON HANDLING ===
func _on_button_pressed(button_index: int) -> void:
	"""Handle button press"""
	print("Button %d pressed" % (button_index + 1))
	
	if not timer_active:
		print("Timer not active, ignoring button press")
		return
	
	if button_index < 0 or button_index >= button_nodes.size():
		print("Invalid button index: %d" % button_index)
		return
	
	var clicked_button = button_nodes[button_index]
	if not clicked_button:
		print("Button node is null for index: %d" % button_index)
		return
	
	var selected_answer = clicked_button.get_meta("answer_value", -1)
	print("Selected answer: %d (Correct: %d)" % [selected_answer, correct_answer])
	
	if selected_answer == correct_answer:
		handle_correct_answer()
	else:
		handle_wrong_answer(clicked_button)

func handle_correct_answer() -> void:
	"""Handle correct answer selection"""
	timer_active = false
	
	if equation_label:
		equation_label.text = "Correct! %d" % correct_answer
	
	var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
	print("Correct answer in %.2f seconds" % elapsed_time)
	
	ProgressManager.save_progress("math", true)
	Global.refresh_everything_after_stage_completion("math", true)
	end_game(true)

func handle_wrong_answer(button: TextureButton) -> void:
	"""Handle wrong answer selection"""
	if equation_label:
		equation_label.text = "Wrong! Try again"
	
	animate_button_shake(button)
	
	await get_tree().create_timer(1.5).timeout
	if timer_active and equation_label:
		equation_label.text = "Solve the yarn: " + current_equation

func animate_button_shake(button: TextureButton) -> void:
	"""Animate button shake effect"""
	if not button:
		return
	
	var original_position = button.position
	var tween = create_tween()
	
	tween.tween_property(button, "position", original_position + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_position + Vector2(10, 0), 0.05)
	tween.tween_property(button, "position", original_position, 0.05)

# === GAME END ===
func end_game(success: bool) -> void:
	"""End the game and show results"""
	hide_game_ui()
	show_result_popup(success)

func hide_game_ui() -> void:
	"""Hide all game UI elements"""
	var ui_paths = [
		"GameBG/Canvas", "Time", "Holder", "RightGroup", "LeftGroup", 
		"Button1", "Button2", "Button3", "Button4", "Quitbtn", "Operations"
	]
	
	for element_path in ui_paths:
		var element = get_node_or_null(element_path)
		if element:
			element.visible = false
			print("Hidden: %s" % element_path)

func show_result_popup(success: bool) -> void:
	"""Show appropriate result popup"""
	if success:
		if countdown >= FAST_COMPLETION_THRESHOLD:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= MEDIUM_COMPLETION_THRESHOLD:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()
	
	if popup_instance:
		add_child(popup_instance)

func restart_game() -> void:
	"""Restart the game with new random numbers"""
	print("\n=== RESTARTING GAME ===")
	
	# Stop the old timer completely
	stop_timer()
	
	# Reset time tracking for new attempt
	reset_time_tracking()
	motivational_5s_played = false
	motivational_10s_played = false
	
	# Show all UI elements again
	show_game_ui()
	
	# Reinitialize the entire game with new random numbers
	initialize_game()
	
	print("=== GAME RESTARTED ===\n")

func show_game_ui() -> void:
	"""Show all game UI elements"""
	var ui_paths = [
		"GameBG/Canvas", "Time", "Holder", "RightGroup", "LeftGroup", 
		"Button1", "Button2", "Button3", "Button4", "Quitbtn", "Operations"
	]
	
	for element_path in ui_paths:
		var element = get_node_or_null(element_path)
		if element:
			element.visible = true
			print("Shown: %s" % element_path)

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
