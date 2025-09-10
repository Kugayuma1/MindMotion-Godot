extends Control

var correct_answer = "BURGER"
var current_answer = ""
var countdown := 15
var timer_active = true

# Preload popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# UI References
@onready var feedback_label = $Instruction
@onready var timer_label = $Time/Label

# Letter display labels
@onready var first_ltr = $FirstLtr
@onready var second_ltr = $ScndLtr
@onready var third_ltr = $ThrdLtr
@onready var fourth_ltr = $FrthLtr
@onready var fifth_ltr = $FfthLtr
@onready var sixth_ltr = $SixthLtr

# Letter buttons
@onready var button1 = $Button1  # G
@onready var button2 = $Button2  # H
@onready var button3 = $Button3  # U
@onready var button4 = $Button4  # E
@onready var button5 = $Button5  # B
@onready var button6 = $Button6  # R
@onready var button7 = $Button7  # M
@onready var button8 = $Button8  # R

func _ready():
	current_answer = ""
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	show_initial_dashes()

func show_initial_dashes():
	if first_ltr: first_ltr.text = "_"
	if second_ltr: second_ltr.text = "_"
	if third_ltr: third_ltr.text = "_"
	if fourth_ltr: fourth_ltr.text = "_"
	if fifth_ltr: fifth_ltr.text = "_"
	if sixth_ltr: sixth_ltr.text = "_"

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
		game_over(false)
		return

	timer_label.text = "⏱️ " + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

func add_letter_to_answer(letter: String) -> void:
	if !timer_active:
		feedback_label.text = "⏱️ Tapos na ang oras!"
		return
	
	if current_answer.length() < 6:  # BURGER has 6 letters
		current_answer += letter
		update_letter_display()
		
		# Check if we have 6 letters
		if current_answer.length() == 6:
			check_answer()
		else:
			feedback_label.text = "Keep going! " + str(6 - current_answer.length()) + " more letters"

func update_letter_display() -> void:
	# Update only the filled positions, keep remaining as dashes
	for i in range(6):  # BURGER has 6 letters
		if i < current_answer.length():
			var letter = current_answer[i]
			match i:
				0:
					if first_ltr: first_ltr.text = letter
				1:
					if second_ltr: second_ltr.text = letter
				2:
					if third_ltr: third_ltr.text = letter
				3:
					if fourth_ltr: fourth_ltr.text = letter
				4:
					if fifth_ltr: fifth_ltr.text = letter
				5:
					if sixth_ltr: sixth_ltr.text = letter
		else:
			# Keep remaining positions as dashes
			match i:
				0:
					if first_ltr: first_ltr.text = "_"
				1:
					if second_ltr: second_ltr.text = "_"
				2:
					if third_ltr: third_ltr.text = "_"
				3:
					if fourth_ltr: fourth_ltr.text = "_"
				4:
					if fifth_ltr: fifth_ltr.text = "_"
				5:
					if sixth_ltr: sixth_ltr.text = "_"

func clear_all_letters() -> void:
	if first_ltr: first_ltr.text = ""
	if second_ltr: second_ltr.text = ""
	if third_ltr: third_ltr.text = ""
	if fourth_ltr: fourth_ltr.text = ""
	if fifth_ltr: fifth_ltr.text = ""
	if sixth_ltr: sixth_ltr.text = ""

func check_answer() -> void:
	if current_answer == correct_answer:
		feedback_label.text = "🎉BURGER!"
		timer_active = false
		ProgressManager.save_progress("reading", true)
		await get_tree().create_timer(2.0).timeout
		game_over(true)
	else:
		feedback_label.text = "❌Try again."
		await get_tree().create_timer(2.0).timeout
		reset_game()

func reset_game() -> void:
	current_answer = ""
	show_initial_dashes()
	show_all_buttons()
	feedback_label.text = "Tap the letters to spell BURGER!"

func show_all_buttons() -> void:
	if button1: button1.visible = true
	if button2: button2.visible = true
	if button3: button3.visible = true
	if button4: button4.visible = true
	if button5: button5.visible = true
	if button6: button6.visible = true
	if button7: button7.visible = true
	if button8: button8.visible = true

func hide_all_buttons() -> void:
	if button1: button1.visible = false
	if button2: button2.visible = false
	if button3: button3.visible = false
	if button4: button4.visible = false
	if button5: button5.visible = false
	if button6: button6.visible = false
	if button7: button7.visible = false
	if button8: button8.visible = false

func shake_button(button: TextureButton) -> void:
	if !button:
		return
	var original_pos = button.position
	var tween = create_tween()
	tween.tween_property(button, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(button, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(button, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	# Hide UI elements
	if has_node("Instruction"): $Instruction.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("FrstLtr"): $FrstLtr.visible = false
	if has_node("ScndLtr"): $ScndLtr.visible = false
	if has_node("ThrdLtr"): $ThrdLtr.visible = false
	if has_node("FrthLtr"): $FrthLtr.visible = false
	if has_node("FfthLtr"): $FfthLtr.visible = false
	if has_node("SixthLtr"): $SixthLtr.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("AssetsBG"): $AssetsBG.visible = false
	if has_node("ObjectBurger"): $ObjectBurger.visible = false
	
	hide_all_buttons()

	# Choose popup based on performance
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()

	if popup_instance:
		add_child(popup_instance)

func _on_button_1_pressed() -> void:
	add_letter_to_answer("G")

func _on_button_2_pressed() -> void:
	add_letter_to_answer("H")

func _on_button_3_pressed() -> void:
	add_letter_to_answer("U")

func _on_button_4_pressed() -> void:
	add_letter_to_answer("E")

func _on_button_5_pressed() -> void:
	add_letter_to_answer("B")

func _on_button_6_pressed() -> void:
	add_letter_to_answer("R")

func _on_button_7_pressed() -> void:
	add_letter_to_answer("M")

func _on_button_8_pressed() -> void:
	add_letter_to_answer("R")
