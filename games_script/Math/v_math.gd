# VISUAL MATH GAME - CLEAN VERSION FOR VOLLEYBALL SCENE
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

# TextureButton references
@onready var button_nodes: Array[TextureButton] = []
@onready var button_labels: Array[Label] = []

# Volleyball group paths
var left_volleyball_paths: Array[String] = [
	"LeftGroup/Volleyball1",
	"LeftGroup/Volleyball2", 
	"LeftGroup/Volleyball3",
	"LeftGroup/Volleyball4",
	"LeftGroup/Volleyball5"
]

var right_volleyball_paths: Array[String] = [
	"RightGroup/Volleyball6",
	"RightGroup/Volleyball7"
]

# Volleyball collections
var left_volleyballs: Array[Node] = []
var right_volleyballs: Array[Node] = []

# === INITIALIZATION ===
func _ready() -> void:
	print("🏐 Starting Volleyball Math Game - Debug Mode")
	start_time = Time.get_ticks_msec()
	debug_scene_structure()
	initialize_game()

func debug_scene_structure() -> void:
	print("\n=== DEBUGGING SCENE STRUCTURE ===")
	var ui_paths = [
		"Holder/Label",
		"Time/Label", 
		"Button1", "Button2", "Button3", "Button4",
		"Button1/Label3", "Button2/Label3", "Button3/Label3", "Button4/Label3"
	]
	for path in ui_paths:
		var node = get_node_or_null(path)
		if node:
			print("✅ Found UI: %s (%s)" % [path, node.get_class()])
		else:
			print("❌ Missing UI: %s" % path)
	
	print("\nChecking Volleyball nodes...")
	var all_volleyball_paths = left_volleyball_paths + right_volleyball_paths
	for path in all_volleyball_paths:
		var node = get_node_or_null(path)
		if node:
			print("✅ Found volleyball: %s (%s)" % [path, node.get_class()])
		else:
			print("❌ Missing volleyball: %s" % path)
	print("=== END SCENE DEBUG ===\n")

func initialize_game() -> void:
	setup_node_references()
	collect_volleyball_nodes()
	setup_math_problem()
	setup_ui()
	setup_button_connections()
	start_countdown_timer()

func setup_node_references() -> void:
	button_nodes.clear()
	button_labels.clear()
	var button_paths = ["Button1", "Button2", "Button3", "Button4"]
	var label_paths = ["Button1/Label3", "Button2/Label3", "Button3/Label3", "Button4/Label3"]
	for i in range(button_paths.size()):
		var button = get_node_or_null(button_paths[i])
		var label = get_node_or_null(label_paths[i])
		if button: button_nodes.append(button)
		else: button_nodes.append(null)
		if label: button_labels.append(label)
		else: button_labels.append(null)

# === VOLLEYBALL NODE COLLECTION ===
func collect_volleyball_nodes() -> void:
	left_volleyballs.clear()
	right_volleyballs.clear()
	for volleyball_path in left_volleyball_paths:
		var node = get_node_or_null(volleyball_path)
		if node: left_volleyballs.append(node)
	for volleyball_path in right_volleyball_paths:
		var node = get_node_or_null(volleyball_path)
		if node: right_volleyballs.append(node)
	print("🏐 Left volleyballs: %d, Right volleyballs: %d" % [left_volleyballs.size(), right_volleyballs.size()])

# === MATH PROBLEM SETUP ===
func setup_math_problem() -> void:
	var left_count = left_volleyballs.size() # 5
	var right_count = right_volleyballs.size() # 2
	
	# Subtraction logic
	correct_answer = left_count - right_count
	current_equation = "%d - %d = ?" % [left_count, right_count]
	
	print("🧮 Equation: %s (Answer: %d)" % [current_equation, correct_answer])
	generate_answer_options()

func generate_answer_options() -> void:
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
	assign_options_to_buttons(options)

func assign_options_to_buttons(options: Array[int]) -> void:
	for i in range(min(4, options.size())):
		if i < button_labels.size() and button_labels[i]:
			button_labels[i].text = str(options[i])
		if i < button_nodes.size() and button_nodes[i]:
			button_nodes[i].set_meta("answer_value", options[i])

# === UI SETUP ===
func setup_ui() -> void:
	if equation_label:
		equation_label.text = current_equation
	update_timer_display()

func setup_button_connections() -> void:
	for i in range(button_nodes.size()):
		if button_nodes[i] and not button_nodes[i].pressed.is_connected(_on_button_pressed):
			button_nodes[i].pressed.connect(_on_button_pressed.bind(i))

# === TIMER SYSTEM ===
func start_countdown_timer() -> void:
	countdown = GAME_TIME
	timer_active = true
	update_timer_display()
	countdown_loop()

func countdown_loop() -> void:
	while timer_active and countdown > 0:
		await get_tree().create_timer(1.0).timeout
		if not timer_active: break
		countdown -= 1
		update_timer_display()
	if timer_active and countdown <= 0:
		handle_timeout()

func update_timer_display() -> void:
	if timer_label:
		timer_label.text = "⏱️ %ds" % countdown

func handle_timeout() -> void:
	timer_active = false
	if equation_label:
		equation_label.text = "⏰ Time's up! Answer: %d" % correct_answer
	if timer_label:
		timer_label.text = "⏰ Time's up!"
	ProgressManager.save_progress("math", false)
	Global.refresh_everything_after_stage_completion("math", false)
	end_game(false)

# === BUTTON HANDLING ===
func _on_button_pressed(button_index: int) -> void:
	if not timer_active: return
	if button_index < 0 or button_index >= button_nodes.size(): return
	var clicked_button = button_nodes[button_index]
	if not clicked_button: return
	var selected_answer = clicked_button.get_meta("answer_value", -1)
	if selected_answer == correct_answer:
		handle_correct_answer()
	else:
		handle_wrong_answer(clicked_button)

func handle_correct_answer() -> void:
	timer_active = false
	if equation_label:
		equation_label.text = "✅ Correct! %d" % correct_answer
	ProgressManager.save_progress("math", true)
	Global.refresh_everything_after_stage_completion("math", true)
	end_game(true)

func handle_wrong_answer(button: TextureButton) -> void:
	if equation_label:
		equation_label.text = "❌ Wrong! Try again"
	animate_button_shake(button)
	await get_tree().create_timer(1.5).timeout
	if timer_active and equation_label:
		equation_label.text = current_equation

func animate_button_shake(button: TextureButton) -> void:
	if not button: return
	var original_position = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_position + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_position + Vector2(10, 0), 0.05)
	tween.tween_property(button, "position", original_position, 0.05)

# === GAME END ===
func end_game(success: bool) -> void:
	hide_game_ui()
	show_result_popup(success)

func hide_game_ui() -> void:
	var ui_paths = [
		"GameBG/Canvas", "Time", "Holder", "RightGroup", "LeftGroup", 
		"Button1", "Button2", "Button3", "Button4", "Quitbtn", "Operations"
	]
	for element_path in ui_paths:
		var element = get_node_or_null(element_path)
		if element:
			element.visible = false

func show_result_popup(success: bool) -> void:
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

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
