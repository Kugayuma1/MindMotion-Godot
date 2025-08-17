extends Control

var correct_answers = ["Alive", "Apple", "Art"]
var selected_correct = []
var original_feedback_text = ""
var countdown := 15
var timer_active := true
var start_time := 0

@onready var feedback_label = $TextureRect/Holder/Label
@onready var timer_label = $TextureRect/Time/Label

func _ready():
	selected_correct.clear()
	original_feedback_text = feedback_label.text
	start_timer()  # start the countdown
	Global.start_time = Time.get_ticks_msec()  # store start time globally

func start_timer() -> void:
	timer_label.text = "⏱️ 15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "⏰ Time's up!"
		timer_active = false
		ProgressManager.save_progress("reading", false)
		return

	timer_label.text = "⏱️ " + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

func check_answer(answer: String, button: TextureButton) -> void:
	if !timer_active:
		feedback_label.text = "⏱️ Tapos na ang oras!"
		return

	if correct_answers.has(answer):
		if !selected_correct.has(answer):
			selected_correct.append(answer)
			feedback_label.text = "✅ Tama! " + answer
			button.visible = false

			if selected_correct.size() == correct_answers.size():
				feedback_label.text = "🎉 Nakuha mo lahat!"
				timer_active = false  # stop timer when done
				ProgressManager.save_progress("reading", true)
			else:
				await get_tree().create_timer(1.5).timeout
				reset_feedback_label()
		else:
			feedback_label.text = "👆 Na-tap mo na yan!"
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()
	else:
		feedback_label.text = "❌ Mali! Try again."
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
