extends Control

# Correct order for umbrellas
var correct_umbrella_order = [6, 7, 8, 9, 10]
var current_umbrella_index = 0
var completed_umbrellas = []

# Mapping of umbrella nodes to their actual numbers (scene order: 6,7,10,9,8)
var umbrella_number_mapping = {
	"umbrella1": 6,
	"umbrella2": 7,
	"umbrella3": 10,
	"umbrella4": 9,
	"umbrella5": 8
}

var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label

# Umbrella nodes
@onready var umbrella1 = $Umbrella1
@onready var umbrella2 = $Umbrella2
@onready var umbrella3 = $Umbrella3
@onready var umbrella4 = $Umbrella4
@onready var umbrella5 = $Umbrella5

func _ready():
	completed_umbrellas.clear()
	current_umbrella_index = 0
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the umbrellas in order: 6, 7, 8, 9, 10"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	setup_umbrella_handlers()

func setup_umbrella_handlers():
	if umbrella1:
		umbrella1.pressed.connect(_on_umbrella_pressed.bind(umbrella_number_mapping["umbrella1"], umbrella1, "umbrella1"))
	if umbrella2:
		umbrella2.pressed.connect(_on_umbrella_pressed.bind(umbrella_number_mapping["umbrella2"], umbrella2, "umbrella2"))
	if umbrella3:
		umbrella3.pressed.connect(_on_umbrella_pressed.bind(umbrella_number_mapping["umbrella3"], umbrella3, "umbrella3"))
	if umbrella4:
		umbrella4.pressed.connect(_on_umbrella_pressed.bind(umbrella_number_mapping["umbrella4"], umbrella4, "umbrella4"))
	if umbrella5:
		umbrella5.pressed.connect(_on_umbrella_pressed.bind(umbrella_number_mapping["umbrella5"], umbrella5, "umbrella5"))

func start_timer() -> void:
	if timer_label:
		timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		if timer_label:
			timer_label.text = "⏰ Done!"
		if feedback_label:
			feedback_label.text = "⏱️Time's up!"
		timer_active = false
		game_over(false)
		return
	
	if timer_label:
		timer_label.text = str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func _on_umbrella_pressed(umbrella_number: int, umbrella_node: Control, umbrella_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_umbrella_order[current_umbrella_index]
	print("Pressed %s (shows %d), Expected: %d" % [umbrella_name, umbrella_number, expected_number])
	
	if umbrella_number == expected_number:
		on_correct_umbrella(umbrella_number, umbrella_node)
	else:
		on_wrong_umbrella(umbrella_number, expected_number, umbrella_node)

func on_correct_umbrella(umbrella_number: int, umbrella_node: Control):
	if !timer_active:
		return
	
	completed_umbrellas.append(umbrella_number)
	current_umbrella_index += 1
	
	umbrella_node.disabled = true
	await pop_umbrella_visual(umbrella_node)
	umbrella_node.visible = false
	
	if completed_umbrellas.size() >= correct_umbrella_order.size():
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All umbrellas tapped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		if feedback_label and current_umbrella_index < correct_umbrella_order.size():
			feedback_label.text = "✅ Great! Now tap %d" % correct_umbrella_order[current_umbrella_index]

func on_wrong_umbrella(umbrella_number: int, expected_number: int, umbrella_node: Control):
	if !timer_active:
		return
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! Tap %d first." % expected_number
	
	shake_umbrella(umbrella_node)
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_umbrella_visual(umbrella_node: Control):
	var tween = create_tween()
	tween.parallel().tween_property(umbrella_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(umbrella_node, "rotation", deg_to_rad(10), 0.1)
	tween.tween_property(umbrella_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(umbrella_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(umbrella_node, "rotation", deg_to_rad(-15), 0.3)
	await tween.finished

func shake_umbrella(umbrella_node: Control) -> void:
	var original_pos = umbrella_node.position
	var tween = create_tween()
	tween.tween_property(umbrella_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(umbrella_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(umbrella_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(umbrella_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if umbrella1: umbrella1.visible = false
	if umbrella2: umbrella2.visible = false
	if umbrella3: umbrella3.visible = false
	if umbrella4: umbrella4.visible = false
	if umbrella5: umbrella5.visible = false
	
	var popup_instance: Node = null
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
	
	if success:
		ProgressManager.save_progress("math", true)
		Global.refresh_everything_after_stage_completion("math", true)
	else:
		ProgressManager.save_progress("math", false)
		Global.refresh_everything_after_stage_completion("math", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		if current_umbrella_index < correct_umbrella_order.size():
			feedback_label.text = "Tap %d next!" % correct_umbrella_order[current_umbrella_index]
		else:
			feedback_label.text = "Tap the umbrellas in order: 6, 7, 8, 9, 10"

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
