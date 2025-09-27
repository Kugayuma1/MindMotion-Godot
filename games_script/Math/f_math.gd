# VISUAL MATH GAME - CLEAN VERSION FOR FIRE SCENE
# Attach this to your main Control node
extends Control

# === GAME SETTINGS ===
const GAME_TIME: int = 15
const FAST_COMPLETION_THRESHOLD: int = 10
const MEDIUM_COMPLETION_THRESHOLD: int = 5

# === GAME STATE ===
var countdown: int = GAME_TIME
var timer_active: bool = true
var correct_answer: int = 0
var current_equation: String = ""
var start_time: int = 0

# === SCENE RESOURCES ===
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")
var popup_instance: Control = null

# === UI NODE REFERENCES ===
@onready var equation_label: Label = $Holder/Label
@onready var timer_label: Label = $Time/Label

# TextureButton references (NOT Button!)
@onready var button_nodes: Array[TextureButton] = []
@onready var button_labels: Array[Label] = []

# Fire group paths - EXACT matches to your scene
var left_fire_paths: Array[String] = [
	"LeftGroup/Fire1",
	"LeftGroup/Fire2", 
	"LeftGroup/Fire3",
	"LeftGroup/Fire4",
	"LeftGroup/Fire5"
]

var right_fire_paths: Array[String] = [
	"RightGroup/Fire6",
	"RightGroup/Fire7",
	"RightGroup/Fire8", 
	"RightGroup/Fire9",
	"RightGroup/Fire10"
]

# Fire collections
var left_fires: Array[Node] = []
var right_fires: Array[Node] = []

# === INITIALIZATION ===
func _ready() -> void:
	print("🔥 Starting Fire Math Game - Debug Mode")
	start_time = Time.get_ticks_msec()
	
	# First, let's debug what nodes we can actually find
	debug_scene_structure()
	
	# Then initialize normally
	initialize_game()

func debug_scene_structure() -> void:
	"""Debug function to see what nodes actually exist"""
	print("\n=== DEBUGGING SCENE STRUCTURE ===")
	
	# Check main UI elements
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
			print("✅ Found UI: %s (%s)" % [path, node.get_class()])
		else:
			print("❌ Missing UI: %s" % path)
	
	# Check fire nodes
	print("\nChecking fire nodes...")
	var all_fire_paths = left_fire_paths + right_fire_paths
	for path in all_fire_paths:
		var node = get_node_or_null(path)
		if node:
			print("✅ Found fire: %s (%s)" % [path, node.get_class()])
		else:
			print("❌ Missing fire: %s" % path)
	
	print("=== END SCENE DEBUG ===\n")

func initialize_game() -> void:
	"""Initialize all game components in order"""
	setup_node_references()
	collect_fire_nodes() 
	setup_math_problem()
	setup_ui()
	setup_button_connections()
	start_countdown_timer()

func setup_node_references() -> void:
	"""Setup node references with fallback checking"""
	button_nodes.clear()
	button_labels.clear()
	
	# Try to get button nodes (TextureButton)
	var button_paths = ["Button1", "Button2", "Button3", "Button4"]
	var label_paths = ["Button1/Label3", "Button2/Label3", "Button3/Label3", "Button4/Label3"]
	
	for i in range(button_paths.size()):
		var button = get_node_or_null(button_paths[i])
		var label = get_node_or_null(label_paths[i])
		
		if button:
			button_nodes.append(button)
			print("✅ Button %d reference set" % (i + 1))
		else:
			button_nodes.append(null)
			print("❌ Button %d not found at path: %s" % [i + 1, button_paths[i]])
		
		if label:
			button_labels.append(label)
			print("✅ Button %d label reference set" % (i + 1))
		else:
			button_labels.append(null)
			print("❌ Button %d label not found at path: %s" % [i + 1, label_paths[i]])

# === FIRE NODE COLLECTION ===
func collect_fire_nodes() -> void:
	"""Collect all fire nodes from both groups"""
	left_fires.clear()
	right_fires.clear()
	
	# Collect left side fires
	for fire_path in left_fire_paths:
		var fire_node = get_node_or_null(fire_path)
		if fire_node:
			left_fires.append(fire_node)
			print("✅ Found left fire: %s" % fire_path)
		else:
			print("⚠️ Missing left fire: %s" % fire_path)
	
	# Collect right side fires  
	for fire_path in right_fire_paths:
		var fire_node = get_node_or_null(fire_path)
		if fire_node:
			right_fires.append(fire_node)
			print("✅ Found right fire: %s" % fire_path)
		else:
			print("⚠️ Missing right fire: %s" % fire_path)
	
	print("🔥 Left fires: %d, Right fires: %d" % [left_fires.size(), right_fires.size()])

# === MATH PROBLEM SETUP ===
func setup_math_problem() -> void:
	"""Create the math problem based on visible fire counts"""
	var left_count = left_fires.size()
	var right_count = right_fires.size()
	
	correct_answer = left_count + right_count
	current_equation = "%d + %d = ?" % [left_count, right_count]
	
	print("🧮 Equation: %s (Answer: %d)" % [current_equation, correct_answer])
	
	generate_answer_options()

func generate_answer_options() -> void:
	"""Generate 4 answer options including the correct one"""
	var options: Array[int] = [correct_answer]  # Always include correct answer
	
	# Generate wrong answers
	var wrong_options: Array[int] = []
	var attempts = 0
	
	while wrong_options.size() < 3 and attempts < 20:
		var offset = randi_range(-3, 5)
		var wrong_answer = correct_answer + offset
		
		if wrong_answer > 0 and wrong_answer != correct_answer and not wrong_options.has(wrong_answer):
			wrong_options.append(wrong_answer)
		
		attempts += 1
	
	# Ensure we have 3 wrong answers
	while wrong_options.size() < 3:
		wrong_options.append(correct_answer + wrong_options.size() + 1)
	
	# Add wrong answers to options
	for wrong in wrong_options.slice(0, 3):  # Take only 3
		options.append(wrong)
	
	# Shuffle the options
	options.shuffle()
	
	print("🎲 Answer options: %s (Correct: %d)" % [str(options), correct_answer])
	assign_options_to_buttons(options)

func assign_options_to_buttons(options: Array[int]) -> void:
	"""Assign answer options to buttons"""
	for i in range(min(4, options.size())):
		# Set button label
		if i < button_labels.size() and button_labels[i]:
			button_labels[i].text = str(options[i])
			print("✅ Set button %d label to: %d" % [i + 1, options[i]])
		else:
			print("❌ Could not set label for button %d" % [i + 1])
		
		# Set button meta data
		if i < button_nodes.size() and button_nodes[i]:
			button_nodes[i].set_meta("answer_value", options[i])
			print("✅ Set button %d meta to: %d" % [i + 1, options[i]])
		else:
			print("❌ Could not set meta for button %d" % [i + 1])

# === UI SETUP ===
func setup_ui() -> void:
	"""Setup initial UI state"""
	if equation_label:
		equation_label.text = "Solve the fire!"
		print("✅ Equation label set")
	else:
		print("❌ Equation label not found")
	
	update_timer_display()

func setup_button_connections() -> void:
	"""Connect button press signals"""
	for i in range(button_nodes.size()):
		if button_nodes[i]:
			# Connect the pressed signal
			if not button_nodes[i].pressed.is_connected(_on_button_pressed):
				button_nodes[i].pressed.connect(_on_button_pressed.bind(i))
				print("✅ Connected button %d signal" % (i + 1))
		else:
			print("❌ Cannot connect button %d - node is null" % (i + 1))

# === TIMER SYSTEM ===
func start_countdown_timer() -> void:
	"""Start the countdown timer"""
	countdown = GAME_TIME
	timer_active = true
	update_timer_display()
	countdown_loop()

func countdown_loop() -> void:
	"""Main countdown loop"""
	while timer_active and countdown > 0:
		await get_tree().create_timer(1.0).timeout
		
		if not timer_active:
			break
			
		countdown -= 1
		update_timer_display()
	
	if timer_active and countdown <= 0:
		handle_timeout()

func update_timer_display() -> void:
	"""Update timer label"""
	if timer_label:
		timer_label.text = "⏱️ %ds" % countdown
	else:
		print("⚠️ Timer label not found - cannot update display")

func handle_timeout() -> void:
	"""Handle timer timeout"""
	timer_active = false
	
	if equation_label:
		equation_label.text = "⏰ Time's up! Answer: %d" % correct_answer
	
	if timer_label:
		timer_label.text = "⏰ Time's up!"
	
	print("⏰ Game timed out")
	ProgressManager.save_progress("math", false)
	Global.refresh_everything_after_stage_completion("math", false)
	end_game(false)

# === BUTTON HANDLING ===
func _on_button_pressed(button_index: int) -> void:
	"""Handle button press"""
	print("🖱️ Button %d pressed" % (button_index + 1))
	
	if not timer_active:
		print("⚠️ Timer not active, ignoring button press")
		return
	
	if button_index < 0 or button_index >= button_nodes.size():
		print("❌ Invalid button index: %d" % button_index)
		return
	
	var clicked_button = button_nodes[button_index]
	if not clicked_button:
		print("❌ Button node is null for index: %d" % button_index)
		return
	
	var selected_answer = clicked_button.get_meta("answer_value", -1)
	print("🎯 Selected answer: %d (Correct: %d)" % [selected_answer, correct_answer])
	
	if selected_answer == correct_answer:
		handle_correct_answer()
	else:
		handle_wrong_answer(clicked_button)

func handle_correct_answer() -> void:
	"""Handle correct answer selection"""
	timer_active = false
	
	if equation_label:
		equation_label.text = "✅ Correct! %d" % correct_answer
	
	var elapsed_time = (Time.get_ticks_msec() - start_time) / 1000.0
	print("🎉 Correct answer in %.2f seconds" % elapsed_time)
	
	ProgressManager.save_progress("math", true)
	Global.refresh_everything_after_stage_completion("math", true)
	end_game(true)

func handle_wrong_answer(button: TextureButton) -> void:
	"""Handle wrong answer selection"""
	if equation_label:
		equation_label.text = "❌ Wrong! Try again"
	
	animate_button_shake(button)
	
	# Reset equation text after delay
	await get_tree().create_timer(1.5).timeout
	if timer_active and equation_label:
		equation_label.text = "Solve the fire!"

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
			print("✅ Hidden: %s" % element_path)

func show_result_popup(success: bool) -> void:
	"""Show appropriate result popup"""
	if success:
		# Determine stars based on remaining time
		if countdown >= FAST_COMPLETION_THRESHOLD:
			popup_instance = complete3_scene.instantiate()  # 3 stars
		elif countdown >= MEDIUM_COMPLETION_THRESHOLD:
			popup_instance = complete2_scene.instantiate()  # 2 stars
		else:
			popup_instance = complete1_scene.instantiate()  # 1 star
	else:
		popup_instance = retry_scene.instantiate()  # Retry
	
	if popup_instance:
		add_child(popup_instance)

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
