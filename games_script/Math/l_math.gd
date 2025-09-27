extends Control

# Correct order for lollipops
var correct_lollipop_order = [11, 12, 13, 14, 15]
var current_lollipop_index = 0
var completed_lollipops = []

# Mapping of lollipop nodes to their actual numbers
var lollipop_number_mapping = {
	"lollipop1": 11, 
	"lollipop2": 12,   
	"lollipop3": 14, 
	"lollipop4": 13,  
	"lollipop5": 15
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

# Lollipop nodes
@onready var lollipop1 = $Lollipop1
@onready var lollipop2 = $Lollipop2
@onready var lollipop3 = $Lollipop3
@onready var lollipop4 = $Lollipop4
@onready var lollipop5 = $Lollipop5

func _ready():
	completed_lollipops.clear()
	current_lollipop_index = 0
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Tap the lollipops in order: 11, 12, 13, 14, 15"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	setup_lollipop_handlers()

func setup_lollipop_handlers():
	if lollipop1:
		lollipop1.pressed.connect(_on_lollipop_pressed.bind(lollipop_number_mapping["lollipop1"], lollipop1, "lollipop1"))
	if lollipop2:
		lollipop2.pressed.connect(_on_lollipop_pressed.bind(lollipop_number_mapping["lollipop2"], lollipop2, "lollipop2"))
	if lollipop3:
		lollipop3.pressed.connect(_on_lollipop_pressed.bind(lollipop_number_mapping["lollipop3"], lollipop3, "lollipop3"))
	if lollipop4:
		lollipop4.pressed.connect(_on_lollipop_pressed.bind(lollipop_number_mapping["lollipop4"], lollipop4, "lollipop4"))
	if lollipop5:
		lollipop5.pressed.connect(_on_lollipop_pressed.bind(lollipop_number_mapping["lollipop5"], lollipop5, "lollipop5"))

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

func _on_lollipop_pressed(lollipop_number: int, lollipop_node: Control, lollipop_name: String):
	if !timer_active:
		return
	
	var expected_number = correct_lollipop_order[current_lollipop_index]
	print("Pressed %s (shows %d), Expected: %d" % [lollipop_name, lollipop_number, expected_number])
	
	if lollipop_number == expected_number:
		on_correct_lollipop(lollipop_number, lollipop_node)
	else:
		on_wrong_lollipop(lollipop_number, expected_number, lollipop_node)

func on_correct_lollipop(lollipop_number: int, lollipop_node: Control):
	if !timer_active:
		return
	
	completed_lollipops.append(lollipop_number)
	current_lollipop_index += 1
	
	lollipop_node.disabled = true
	await pop_lollipop_visual(lollipop_node)
	lollipop_node.visible = false
	
	if completed_lollipops.size() >= correct_lollipop_order.size():
		if feedback_label:
			feedback_label.text = "🎉 Excellent! All lollipops tapped!"
		timer_active = false
		await get_tree().create_timer(1.5).timeout
		game_over(true)
	else:
		if feedback_label and current_lollipop_index < correct_lollipop_order.size():
			feedback_label.text = "✅ Great! Now tap %d" % correct_lollipop_order[current_lollipop_index]

func on_wrong_lollipop(lollipop_number: int, expected_number: int, lollipop_node: Control):
	if !timer_active:
		return
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! Tap %d first." % expected_number
	
	shake_lollipop(lollipop_node)
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func pop_lollipop_visual(lollipop_node: Control):
	var tween = create_tween()
	tween.parallel().tween_property(lollipop_node, "scale", Vector2(1.4, 1.4), 0.1)
	tween.parallel().tween_property(lollipop_node, "rotation", deg_to_rad(10), 0.1)
	tween.tween_property(lollipop_node, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(lollipop_node, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(lollipop_node, "rotation", deg_to_rad(-15), 0.3)
	await tween.finished

func shake_lollipop(lollipop_node: Control) -> void:
	var original_pos = lollipop_node.position
	var tween = create_tween()
	tween.tween_property(lollipop_node, "position", original_pos + Vector2(-15, 0), 0.1)
	tween.tween_property(lollipop_node, "position", original_pos + Vector2(15, 0), 0.1)
	tween.tween_property(lollipop_node, "position", original_pos + Vector2(-10, 0), 0.1)
	tween.tween_property(lollipop_node, "position", original_pos, 0.1)

func game_over(success: bool):
	timer_active = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if lollipop1: lollipop1.visible = false
	if lollipop2: lollipop2.visible = false
	if lollipop3: lollipop3.visible = false
	if lollipop4: lollipop4.visible = false
	if lollipop5: lollipop5.visible = false
	
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
		if current_lollipop_index < correct_lollipop_order.size():
			feedback_label.text = "Tap %d next!" % correct_lollipop_order[current_lollipop_index]
		else:
			feedback_label.text = "Tap the lollipops in order: 11, 12, 13, 14, 15"
			
func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
