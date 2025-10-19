extends Control

# Paw color enum
enum PawColor { ORANGE, PURPLE, RED, GRAY }
enum FoodColor { ORANGE, PURPLE, RED, GRAY }

var correct_color_matches = {
	"Orange": "Orange",
	"Purple": "Purple", 
	"Red": "Red",
	"Gray": "Gray"
}

var completed_matches = []
var countdown := 15
var timer_active := true
var original_feedback_text = ""

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label
@onready var food_container = $Food
@onready var paws_container = $Paws

# Tracking variables
var food_nodes = []
var paw_nodes = []
var original_positions = {}
var dragging_food: Control = null
var drag_offset: Vector2
var food_color_map = {}  # Maps food node name to color string
var paw_color_map = {}   # Maps paw node name to color string

func _ready():
	completed_matches.clear()
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Match the food to the same color paw!"
	
	store_original_positions()
	initialize_foods()
	initialize_paws()
	shuffle_food_positions()
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()

# ========== SETUP ==========

func store_original_positions():
	if food_container:
		for child in food_container.get_children():
			food_nodes.append(child)
			original_positions[child.name] = child.position

func initialize_foods():
	for food in food_nodes:
		# Connect input events
		food.gui_input.connect(_on_food_input.bind(food))
		food.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Store color from export variable or name
		var color_string = get_food_color_from_node(food)
		food_color_map[food.name] = color_string

func initialize_paws():
	if paws_container:
		for child in paws_container.get_children():
			paw_nodes.append(child)
			
			# Store color from export variable or name
			var color_string = get_paw_color_from_node(child)
			paw_color_map[child.name] = color_string
			
			# Add to group for detection
			child.add_to_group("paw_targets")

# ========== SHUFFLE ==========

func shuffle_food_positions():
	if not food_container:
		return
	
	var foods = food_container.get_children()
	var positions = []
	
	# Collect all original positions
	for food in foods:
		if food.name in original_positions:
			positions.append(original_positions[food.name])
	
	# Shuffle the positions array
	positions.shuffle()
	
	# Assign shuffled positions to foods AND update original_positions
	for i in range(foods.size()):
		if i < positions.size():
			foods[i].position = positions[i]
			# Update the stored position to the new shuffled position
			original_positions[foods[i].name] = positions[i]

# ========== COLOR HELPERS ==========

func get_food_color_from_node(food: Control) -> String:
	# Try to get from export variable if it exists
	if food.has_meta("food_color"):
		var color = food.get_meta("food_color")
		return color_enum_to_string(color, "food")
	
	# Fallback to name-based matching
	var name_lower = food.name.to_lower()
	if "orange" in name_lower:
		return "Orange"
	elif "purple" in name_lower:
		return "Purple"
	elif "red" in name_lower:
		return "Red"
	elif "gray" in name_lower:
		return "Gray"
	
	return "Unknown"

func get_paw_color_from_node(paw: Control) -> String:
	# Try to get from export variable if it exists
	if paw.has_meta("paw_color"):
		var color = paw.get_meta("paw_color")
		return color_enum_to_string(color, "paw")
	
	# Fallback to name-based matching
	var name_lower = paw.name.to_lower()
	if "orange" in name_lower:
		return "Orange"
	elif "purple" in name_lower:
		return "Purple"
	elif "red" in name_lower:
		return "Red"
	elif "gray" in name_lower:
		return "Gray"
	
	return "Unknown"

func color_enum_to_string(value: int, type: String) -> String:
	if type == "food":
		match value:
			FoodColor.ORANGE:
				return "Orange"
			FoodColor.PURPLE:
				return "Purple"
			FoodColor.RED:
				return "Red"
			FoodColor.GRAY:
				return "Gray"
	else:
		match value:
			PawColor.ORANGE:
				return "Orange"
			PawColor.PURPLE:
				return "Purple"
			PawColor.RED:
				return "Red"
			PawColor.GRAY:
				return "Gray"
	
	return "Unknown"

# ========== DRAG AND DROP ==========

func _on_food_input(event: InputEvent, food: Control):
	if not timer_active or completed_matches.has(food.name):
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(food, event.global_position)
				get_viewport().set_input_as_handled()
			else:
				end_drag(food, event.global_position)
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and dragging_food == food:
		food.global_position = event.global_position - drag_offset
		get_viewport().set_input_as_handled()

func start_drag(food: Control, mouse_pos: Vector2):
	dragging_food = food
	drag_offset = mouse_pos - food.global_position
	food.z_index = 100
	var tween = create_tween()
	tween.tween_property(food, "scale", Vector2(1.1, 1.1), 0.1)

func end_drag(food: Control, mouse_pos: Vector2):
	if dragging_food != food:
		return
	
	dragging_food = null
	food.z_index = 0
	var tween = create_tween()
	tween.tween_property(food, "scale", Vector2.ONE, 0.1)
	
	check_drop_on_paw(food, mouse_pos)

func check_drop_on_paw(food: Control, drop_position: Vector2):
	for paw in paw_nodes:
		var paw_rect = Rect2(paw.global_position, paw.size)
		
		if paw_rect.has_point(drop_position):
			handle_drop(food, paw)
			return
	
	# Not dropped on any paw, return to original position
	return_to_original_position(food)

func _process(delta):
	# Handle continuous dragging with mouse motion
	if dragging_food and timer_active:
		var mouse_pos = get_global_mouse_position()
		dragging_food.global_position = mouse_pos - drag_offset

func handle_drop(food: Control, paw: Control):
	var food_color = food_color_map.get(food.name, "Unknown")
	var paw_color = paw_color_map.get(paw.name, "Unknown")
	
	if food_color == paw_color:
		on_correct_match(food.name, paw.name, food, paw)
	else:
		on_wrong_match(food.name, paw.name, paw, food)

# ========== MATCH HANDLING ==========

func on_correct_match(food_name: String, paw_name: String, food: Control, paw: Control):
	if !timer_active:
		return
	
	if !completed_matches.has(food_name):
		completed_matches.append(food_name)
		print("🎉 Correct! %s matched with %s" % [food_name, paw_name])
		
		if feedback_label:
			feedback_label.text = "✅ Correct match!"
		
		# Hide food item and position on paw
		food.global_position = paw.global_position + (paw.size / 2) - (food.size / 2)
		food.modulate = Color(1, 1, 1, 0.8)
		food.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Check if all color matches are completed
		if completed_matches.size() == correct_color_matches.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "🎉 Very Good! All matched!"
			game_over(true)
		else:
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()

func on_wrong_match(food_name: String, paw_name: String, paw: Control, food: Control):
	if !timer_active:
		return
	
	print("❌ Wrong! %s doesn't match %s" % [food_name, paw_name])
	
	if feedback_label:
		feedback_label.text = "❌ Wrong color! Try again."
	
	shake_item(paw)
	return_to_original_position(food)
	
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func shake_item(item: Node) -> void:
	if !item:
		return
	
	var original_pos = item.position
	var tween = create_tween()
	tween.tween_property(item, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(item, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(item, "position", original_pos, 0.05)

func return_to_original_position(food: Control):
	if food.name in original_positions:
		var tween = create_tween()
		tween.tween_property(food, "position", original_positions[food.name], 0.3)

# ========== TIMER ==========

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

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		feedback_label.text = "Match the food to the same color paw!"

# ========== GAME STATE ==========

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
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()
	
	if popup_instance:
		add_child(popup_instance)
	
	# Save progress
	if success:
		print("🎉 Game completed successfully!")
		ProgressManager.save_progress("fine_motor", true)
		Global.refresh_everything_after_stage_completion("fine_motor", true)
	else:
		print("⏰ Game over - Time's up!")
		ProgressManager.save_progress("fine_motor", false)
		Global.refresh_everything_after_stage_completion("fine_motor", false)

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
