# D-etective Game (Letter D)
# Scene: Control
# Children: Cat (TextureButton), Dog (TextureButton), Fish (TextureButton)
# Also requires: Holder/Label (feedback), Time/Label (timer), Quitbtn

extends Control

# ✅ Correct answer
var correct_answer := "Dog"

# Timer setup
var countdown := 15
var timer_active := true

# Popup reward scenes (adjust paths if needed)
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

func _ready() -> void:
	feedback_label.text = "🔍I am an animal 
that barks!"
	start_timer()

# 🕒 Timer functions
func start_timer() -> void:
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "⏰ Time's up!"
		timer_active = false
		game_over(false)
		return

	timer_label.text = "" + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

# 🐶 Check answer logic
func check_answer(choice: String, node: Control) -> void:
	if !timer_active:
		feedback_label.text = "⏱️ Game Over!"
		return

	if choice == correct_answer:
		timer_active = false
		feedback_label.text = "✅ Correct! It’s a Dog who barks 🐶"
		highlight_correct(node)

		# Pause for 2 seconds before showing popup
		await get_tree().create_timer(2.0).timeout
		game_over(true)
	else:
		feedback_label.text = "❌ Try again."
		shake_button(node)
		await get_tree().create_timer(1.5).timeout
		feedback_label.text = "🔍 Who barks?"

# 🔔 Tween shake effect for wrong answers
func shake_button(node: Control) -> void:
	var original_pos = node.position
	var tween = create_tween()
	tween.tween_property(node, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(node, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(node, "position", original_pos, 0.05).set_delay(0.10)

# ✨ Optional highlight for correct choice
func highlight_correct(node: Control) -> void:
	var tween = create_tween()
	tween.tween_property(node, "modulate", Color(0, 1, 0, 1), 0.5) # Green flash

# 🎯 Game Over (reward logic)
func game_over(success: bool) -> void:
	$Cat.visible = false
	$Dog.visible = false
	$Fish.visible = false
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

# 🔘 Button signals

func _on_cat_pressed() -> void:
	check_answer("Cat", $Cat)


func _on_fish_pressed() -> void:
	check_answer("Fish", $Fish)


func _on_dog_pressed() -> void:
	check_answer("Dog", $Dog)


func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
