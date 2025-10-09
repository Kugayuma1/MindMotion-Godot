extends Control

var correct_answers = ["Alive", "Apple", "Art"]
var selected_correct = []
var original_feedback_text = ""
var countdown := 15
var timer_active = true
var start_time := 0

# Preload popup star scenes (adjust the paths as needed!)
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $TextureRect/Holder/Label
@onready var timer_label = $TextureRect/Time/Label

func _ready():
	AudioManager.play_temp_music("game")
	selected_correct.clear()
	original_feedback_text = feedback_label.text
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	

func start_timer() -> void:
	timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "Time's up!"
		timer_active = false
		ProgressManager.save_progress("reading", false)
		Global.refresh_everything_after_stage_completion("reading", false)
		game_over(false)  # ⬅️ Show 1-star popup if time runs out
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
				timer_active = false
				ProgressManager.save_progress("reading", true)
				Global.refresh_everything_after_stage_completion("reading", true)
				game_over(true)  # ⬅️ Show star popup when complete
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

func shake_button(button: TextureButton) -> void:
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.10)

# 🎯 Game over function (popup logic)
func game_over(success: bool):
	
	# Hide objects except background
	if has_node("TextureRect/ant1"): $TextureRect/ant1.visible = false
	if has_node("TextureRect/ant2"): $TextureRect/ant2.visible = false
	if has_node("TextureRect/ant3"): $TextureRect/ant3.visible = false
	if has_node("TextureRect/ant4"): $TextureRect/ant4.visible = false
	if has_node("TextureRect/ant5"): $TextureRect/ant5.visible = false
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

	add_child(popup_instance)  # Show popup on top



func _on_ant_1_pressed() -> void:
	check_answer("Mouse", $TextureRect/ant1)


func _on_ant_2_pressed() -> void:
	check_answer("Alive", $TextureRect/ant2)


func _on_ant_3_pressed() -> void:
	check_answer("Apple", $TextureRect/ant3)


func _on_ant_4_pressed() -> void:
	check_answer("Dove", $TextureRect/ant4)


func _on_ant_5_pressed() -> void:
	check_answer("Art", $TextureRect/ant5)


func _on_quitbtn_pressed() -> void:
	AudioManager.resume_previous_music() 
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
