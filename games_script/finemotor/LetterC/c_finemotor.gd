extends Control

var correct_color_matches = {
	"Orange": "Orange",
	"Purple": "Purple", 
	"Red": "Red",
	"Gray": "Gray"
}

var completed_matches = []
var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label  # Instructions/feedback label
@onready var timer_label = $Time/Label      # Timer label

func _ready():
	completed_matches.clear()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Match the food to the same color paw!"
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Setup draggable food items
	setup_draggable_items()

func setup_draggable_items():
	# Get all food items - adjust path to your food container
	var food_container = $Food  # Adjust this path to match your scene structure
	
	if food_container:
		for child in food_container.get_children():
			if child.has_method("setup_game_controller"):
				child.setup_game_controller(self)

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
		timer_label.text = "" + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout
	if timer_active:
		update_timer()

func on_correct_match(food_name: String, paw_name: String):
	if !timer_active:
		return
		
	if !completed_matches.has(food_name):
		completed_matches.append(food_name)
		print("🎉 Correct! %s matched with %s" % [food_name, paw_name])
		
		if feedback_label:
			feedback_label.text = "✅Correct match!"
		
		# Check if all color matches are completed
		if completed_matches.size() == correct_color_matches.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "🎉 Very Good! All matched!"
			game_over(true)
		else:
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()

func on_wrong_match(food_name: String, paw_name: String, paw_node):
	if !timer_active:
		return
		
	print("❌ Wrong! %s doesn't match %s" % [food_name, paw_name])
	
	if feedback_label:
		feedback_label.text = "❌ Wrong color! Try again."
	
	shake_child(paw_node)
	
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func shake_child(child_node: Node) -> void:
	if !child_node:
		return
		
	var original_pos = child_node.position
	var tween = create_tween()
	tween.tween_property(child_node, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(child_node, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
	tween.tween_property(child_node, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	timer_active = false
	
	# Hide game UI
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Paws"): $Paws.visible = false
	if has_node("Food"): $Food.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	var popup_instance: Node = null
	
	# Popup logic based on remaining time
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()  # ⭐⭐⭐
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()  # ⭐⭐
		else:
			popup_instance = complete1_scene.instantiate()  # ⭐
	else:
		popup_instance = retry_scene.instantiate()      # ❌ always 1 star on fail
	
	if popup_instance:
		add_child(popup_instance)
	
	# Save progress
	if success:
		print("🎉 Game completed successfully!")
		ProgressManager.save_progress("fine_motor", true)
	else:
		print("⏰ Game over - Time's up!")
		ProgressManager.save_progress("fine_motor", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		feedback_label.text = "Match the food to the same color paw!"


func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
