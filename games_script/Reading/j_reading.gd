extends Control

# ✅ GAME CONFIGURATION — 2 QUESTION SETS FOR LETTER J
var question_data = [
	{
		"correct_answers": ["Jaguar", "Jug", "Junk"],
		"all_choices": ["Jaguar", "Draw", "Jug", "Glass", "Junk"]
	},
	{
		"correct_answers": ["Jam", "Jet", "Jar"],
		"all_choices": ["Jet", "Jar", "Moon", "Jam", "Glass"]
	}
]

var current_question_index = 0
var correct_answers = []
var all_choices = []
var selected_correct = []
var original_feedback_text = ""
var countdown := 15
var timer_active = false
var start_time := 0
var timer_node: SceneTreeTimer = null

# 🌟 POPUP STAR SCENES
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# 🧩 UI REFERENCES
@onready var feedback_label = $TextureRect/Holder/Label
@onready var timer_label = $TextureRect/Time/Label
@onready var choice_buttons = [
	$TextureRect/Jeep1,
	$TextureRect/Jeep2,
	$TextureRect/Jeep3,
	$TextureRect/Jeep4,
	$TextureRect/Jeep5
]

func _ready():
	# AudioManager.play_temp_music("game")  # optional
	question_data.shuffle()
	load_current_question()
	selected_correct.clear()
	original_feedback_text = feedback_label.text
	start_timer()
	reset_time_tracking()

func load_current_question() -> void:
	if current_question_index >= question_data.size():
		current_question_index = 0
	
	var data = question_data[current_question_index]
	correct_answers = data["correct_answers"].duplicate()
	all_choices = data["all_choices"].duplicate()
	all_choices.shuffle()
	
	for i in range(choice_buttons.size()):
		if i < all_choices.size():
			var button = choice_buttons[i]
			var label = button.get_node("Label")
			label.text = all_choices[i]
			button.visible = true
	
	print("Loaded question: ", current_question_index, " with correct answers: ", correct_answers)

func start_timer() -> void:
	stop_timer()
	timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func stop_timer() -> void:
	timer_active = false

func reset_time_tracking() -> void:
	Global.start_time = Time.get_ticks_msec()
	start_time = Global.start_time
	print("Time tracking reset at: ", start_time)

func update_timer() -> void:
	if !timer_active:
		return
		
	if countdown <= 0:
		timer_label.text = "Time's up!"
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

func check_answer(answer: String, button: TextureButton) -> void:
	if !timer_active:
		feedback_label.text = "⏱️Time's Up!"
		return

	if correct_answers.has(answer):
		if !selected_correct.has(answer):
			selected_correct.append(answer)
			feedback_label.text = "✅ Correct! " + answer
			button.visible = false

			if selected_correct.size() == correct_answers.size():
				feedback_label.text = "🎉You've got it all right!"
				stop_timer()
				ProgressManager.save_progress("reading", true)
				Global.refresh_everything_after_stage_completion("reading", true)
				game_over(true)
			else:
				await get_tree().create_timer(1.5).timeout
				if timer_active:
					reset_feedback_label()
		else:
			feedback_label.text = "👆 You already tapped that!"
			await get_tree().create_timer(1.5).timeout
			if timer_active:
				reset_feedback_label()
	else:
		feedback_label.text = "❌ Wrong! Try again."
		shake_button(button)
		await get_tree().create_timer(1.5).timeout
		if timer_active:
			reset_feedback_label()

func reset_feedback_label() -> void:
	feedback_label.text = original_feedback_text

func shake_button(button: TextureButton) -> void:
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	stop_timer()
	
	if has_node("TextureRect/Jeep1"): $TextureRect/Jeep1.visible = false
	if has_node("TextureRect/Jeep2"): $TextureRect/Jeep2.visible = false
	if has_node("TextureRect/Jeep3"): $TextureRect/Jeep3.visible = false
	if has_node("TextureRect/Jeep4"): $TextureRect/Jeep4.visible = false
	if has_node("TextureRect/Jeep5"): $TextureRect/Jeep5.visible = false
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

func _on_jeep_1_pressed() -> void:
	check_answer(all_choices[0], $TextureRect/Jeep1)

func _on_jeep_2_pressed() -> void:
	check_answer(all_choices[1], $TextureRect/Jeep2)

func _on_jeep_3_pressed() -> void:
	check_answer(all_choices[2], $TextureRect/Jeep3)

func _on_jeep_4_pressed() -> void:
	check_answer(all_choices[3], $TextureRect/Jeep4)

func _on_jeep_5_pressed() -> void:
	check_answer(all_choices[4], $TextureRect/Jeep5)

func _on_quitbtn_pressed() -> void:
	stop_timer()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)

func restart_game() -> void:
	stop_timer()
	reset_time_tracking()
	
	current_question_index += 1
	if current_question_index >= question_data.size():
		current_question_index = 0
		question_data.shuffle()
	
	load_current_question()
	selected_correct.clear()
	
	if has_node("TextureRect/Jeep1"): $TextureRect/Jeep1.visible = true
	if has_node("TextureRect/Jeep2"): $TextureRect/Jeep2.visible = true
	if has_node("TextureRect/Jeep3"): $TextureRect/Jeep3.visible = true
	if has_node("TextureRect/Jeep4"): $TextureRect/Jeep4.visible = true
	if has_node("TextureRect/Jeep5"): $TextureRect/Jeep5.visible = true
	if has_node("TextureRect/Holder"): $TextureRect/Holder.visible = true
	if has_node("TextureRect/Time"): $TextureRect/Time.visible = true
	if has_node("Quitbtn"): $Quitbtn.visible = true
	
	reset_feedback_label()
	start_timer()
	print("Retrying with question: ", current_question_index)
