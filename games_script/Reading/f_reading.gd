extends Control

var question_data = [
	{
		"correct_answers": ["Fish", "Frog", "Fan"],
		"all_choices": ["Fish", "Kite", "Zebra", "Frog", "Fan"]
	},
	{
		"correct_answers": ["Face", "Feet", "Fork"],
		"all_choices": ["Moon", "Face", "Fork", "Ball", "Feet"]
	}
]


var current_question_index = 0
var correct_answers = []
var all_choices = []
var selected_correct = []
var original_feedback_text = ""
var countdown := 15
var timer_active = true

# 🌟 Popup star scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# 🧩 UI references
@onready var feedback_label = $TextureRect/Holder/Label
@onready var timer_label = $TextureRect/Time/Label
@onready var choice_buttons = [
	$TextureRect/Fish1,
	$TextureRect/Fish2,
	$TextureRect/Fish3,
	$TextureRect/Fish4,
	$TextureRect/Fish5
]

func _ready() -> void:
	selected_correct.clear()
	original_feedback_text = feedback_label.text
	load_current_question()
	start_timer()

# --- LOAD CURRENT QUESTION ---
func load_current_question() -> void:
	if current_question_index >= question_data.size():
		current_question_index = 0  # Optional: loop back after last question
	
	var data = question_data[current_question_index]
	correct_answers = data["correct_answers"].duplicate()
	all_choices = data["all_choices"].duplicate()
	selected_correct.clear()

	for i in range(choice_buttons.size()):
		if i < all_choices.size():
			var button = choice_buttons[i]
			var label = button.get_node("Label")
			label.text = all_choices[i]
			button.visible = true
	
	feedback_label.text = original_feedback_text
	timer_label.text = "15s"
	countdown = 15
	timer_active = true

# --- TIMER LOGIC ---
func start_timer() -> void:
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "⏰ Time's up!"
		timer_active = false
		ProgressManager.save_progress("reading", false)
		Global.refresh_everything_after_stage_completion("reading", false)
		game_over(false)
		return

	timer_label.text = " " + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

# --- CHECK ANSWERS ---
func check_answer(answer: String, button: TextureButton) -> void:
	if !timer_active:
		feedback_label.text = "⏱️ Time's Up!"
		return

	if correct_answers.has(answer):
		if !selected_correct.has(answer):
			selected_correct.append(answer)
			feedback_label.text = "✅ Correct! " + answer
			button.visible = false

			if selected_correct.size() == correct_answers.size():
				feedback_label.text = "🎉 You've got it all right!"
				timer_active = false
				game_over(true)
			else:
				await get_tree().create_timer(1.5).timeout
				reset_feedback_label()
		else:
			feedback_label.text = "👆 You already tapped that!"
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()
	else:
		feedback_label.text = "❌ Wrong! Try again."
		shake_button(button)
		await get_tree().create_timer(1.5).timeout
		reset_feedback_label()

func reset_feedback_label() -> void:
	feedback_label.text = original_feedback_text

# --- SHAKE EFFECT ---
func shake_button(button: TextureButton) -> void:
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.10)

# --- GAME OVER / POPUP HANDLER ---
func game_over(success: bool) -> void:
	# Hide buttons and UI temporarily
	for button in choice_buttons:
		button.visible = false
	if has_node("TextureRect/Holder"): $TextureRect/Holder.visible = false
	if has_node("TextureRect/Time"): $TextureRect/Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false

	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()

	add_child(popup_instance)

# --- NEXT QUESTION ---
func next_word() -> void:
	current_question_index += 1
	if current_question_index < question_data.size():
		for button in choice_buttons:
			button.visible = true
		if has_node("TextureRect/Holder"): $TextureRect/Holder.visible = true
		if has_node("TextureRect/Time"): $TextureRect/Time.visible = true
		if has_node("Quitbtn"): $Quitbtn.visible = true

		load_current_question()
		start_timer()
	else:
		print("✅ All questions completed!")

# --- BUTTON SIGNALS ---
func _on_fish_1_pressed() -> void:
	check_answer(all_choices[0], $TextureRect/Fish1)

func _on_fish_2_pressed() -> void:
	check_answer(all_choices[1], $TextureRect/Fish2)

func _on_fish_3_pressed() -> void:
	check_answer(all_choices[2], $TextureRect/Fish3)

func _on_fish_4_pressed() -> void:
	check_answer(all_choices[3], $TextureRect/Fish4)

func _on_fish_5_pressed() -> void:
	check_answer(all_choices[4], $TextureRect/Fish5)

# --- QUIT BUTTON ---
func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
