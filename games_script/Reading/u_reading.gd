extends Control

# Choices with textures
var choices = [
	{"name": "House", "texture": "res://Game Assets/Reading Assets/Assetsulit/2NANAMAN/37.png"},
	{"name": "Uniform", "texture": "res://Game Assets/Reading Assets/Assetsulit/2NANAMAN/38.png"},
	{"name": "Out", "texture": "res://Game Assets/Reading Assets/Assetsulit/2NANAMAN/39.png"}
]

# Game configuration
var correct_answer := "Uniform"
var clue := "🔍 The one you wears at School"
var clue_short := "At School?"
var success_message := "✅ Correct! Uniform is the one you wears at School"
var shuffled_choices = []
var button_to_choice = {}

# Timer setup
var countdown := 15
var timer_active := true

# Popup reward scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")
var popup_instance: Control = null

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

# Button references
@onready var choice_buttons = [
	$House,
	$Uniform,
	$Out
]

func _ready() -> void:
	load_game()
	Global.start_time = Time.get_ticks_msec()
	start_timer()

func load_game() -> void:
	shuffled_choices = []
	for choice in choices:
		shuffled_choices.append(choice.duplicate())
	shuffled_choices.shuffle()
	
	# Assign shuffled choices to button positions
	button_to_choice.clear()
	for i in range(choice_buttons.size()):
		if i < shuffled_choices.size():
			var button = choice_buttons[i]
			var choice_data = shuffled_choices[i]
			
			# Set the texture on the button
			button.texture_normal = load(choice_data["texture"])
			
			# Store the mapping
			button_to_choice[button] = choice_data["name"]
			button.visible = true
	
	feedback_label.text = clue
	
	# Debug: Show which button has the correct answer
	var correct_button = ""
	for button in choice_buttons:
		if button_to_choice[button] == correct_answer:
			correct_button = button.name
			break
	print("Shuffled order: ", shuffled_choices.map(func(c): return c["name"]))
	print("Correct answer '", correct_answer, "' is now on button: ", correct_button)

func start_timer() -> void:
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "Time's up!"
		timer_active = false
		game_over(false)
		return
	timer_label.text = "" + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func check_answer(choice: String, node: Control) -> void:
	if !timer_active:
		feedback_label.text = "Game Over!"
		return
	
	if choice == correct_answer:
		timer_active = false
		feedback_label.text = success_message
		highlight_correct(node)
		await get_tree().create_timer(2.0).timeout
		game_over(true)
	else:
		feedback_label.text = "Try again."
		shake_button(node)
		await get_tree().create_timer(1.5).timeout
		feedback_label.text = clue_short

func shake_button(node: Control) -> void:
	var original_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(node, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(node, "position", original_pos, 0.05).set_delay(0.10)

func highlight_correct(node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(0, 1, 0, 1), 0.5)

func game_over(success: bool) -> void:
	$House.visible = false
	$Uniform.visible = false
	$Out.visible = false
	$Time.visible = false
	$Holder.visible = false
	$Quitbtn.visible = false
	
	if success:
		ProgressManager.save_progress("reading", true)
		Global.refresh_everything_after_stage_completion("reading", true)
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		ProgressManager.save_progress("reading", false)
		Global.refresh_everything_after_stage_completion("reading", false)
		popup_instance = retry_scene.instantiate()
	
	add_child(popup_instance)

func _on_house_pressed() -> void:
	check_answer(button_to_choice[$House], $House)

func _on_uniform_pressed() -> void:
	check_answer(button_to_choice[$Uniform], $Uniform)

func _on_out_pressed() -> void:
	check_answer(button_to_choice[$Out], $Out)

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)

func next_round() -> void:
	load_game()
	
	$House.visible = true
	$Uniform.visible = true
	$Out.visible = true
	$Time.visible = true
	$Holder.visible = true
	$Quitbtn.visible = true
	
	start_timer()
