# UNIFIED LETTER B GAME CONTROLLER
# All logic in one script - no separate draggable/dropzone scripts needed
extends Control

# Correct items that start with letter "B"
var correct_b_items = {
	"Banana": "Banana",
	"Broccoli": "Broccoli", 
	"Blueberry": "Blueberry"
}

var completed_matches = []
var countdown := 15
var timer_active := true
var original_feedback_text = ""

# Cart states
var cart_empty_texture = preload("res://Game Assets/Reading Assets/cart (1).png")
var cart_1_item_texture = preload("res://Game Assets/Fine Motor Assets/3.png")
var cart_2_items_texture = preload("res://Game Assets/Fine Motor Assets/2.png")
var cart_3_items_texture = preload("res://Game Assets/Fine Motor Assets/1.png")

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Node references
@onready var feedback_label = $Holder/Label
@onready var timer_label = $Time/Label
@onready var cart_sprite = $Cart/CartDropZone
@onready var fruits_container = $Fruits

@onready var banana_label = $Cart/CartDropZone/BananaLabel
@onready var broccoli_label = $Cart/CartDropZone/BroccoliLabel
@onready var blueberry_label = $Cart/CartDropZone/BlueberryLabel

# Drag variables
var dragging_item: Node = null
var drag_offset: Vector2
var original_positions = {}

func _ready():
	completed_matches.clear()
	
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Drag the one that starts at letter \"B\""
	
	reset_all_labels()
	
	# IMPORTANT: Store positions BEFORE shuffling
	store_original_positions()
	setup_all_draggables()
	shuffle_fruit_positions()
	
	start_timer()
	Global.start_time = Time.get_ticks_msec()

# ========== SETUP ==========

func store_original_positions():
	if fruits_container:
		for child in fruits_container.get_children():
			# Store the actual current position in the scene
			original_positions[child.name] = child.position

func setup_all_draggables():
	if fruits_container:
		for child in fruits_container.get_children():
			# Connect all input events to this controller
			child.gui_input.connect(_on_fruit_input.bind(child))
			child.mouse_entered.connect(_on_fruit_hover_start.bind(child))
			child.mouse_exited.connect(_on_fruit_hover_end.bind(child))
			# Make sure mouse filter allows interaction
			child.mouse_filter = Control.MOUSE_FILTER_STOP

# ========== SHUFFLE POSITIONS ==========

func shuffle_fruit_positions():
	if not fruits_container:
		return
	
	var fruits = fruits_container.get_children()
	var positions = []
	
	# Collect all current positions
	for fruit in fruits:
		positions.append(fruit.position)
	
	# Shuffle the positions array
	positions.shuffle()
	
	# Assign shuffled positions to fruits AND update original_positions
	for i in range(fruits.size()):
		if i < positions.size():
			fruits[i].position = positions[i]
			# CRITICAL FIX: Update the stored original position to the new shuffled position
			original_positions[fruits[i].name] = positions[i]

# ========== DRAG AND DROP ==========

func _on_fruit_input(event: InputEvent, fruit: Node):
	if not timer_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(fruit, event.global_position)
			else:
				end_drag(fruit, event.global_position)
	
	elif event is InputEventMouseMotion and dragging_item == fruit:
		# Update position while dragging
		fruit.global_position = event.global_position - drag_offset

func start_drag(fruit: Node, mouse_pos: Vector2):
	dragging_item = fruit
	# Calculate offset from current global position (which reflects shuffled position)
	drag_offset = mouse_pos - fruit.global_position
	fruit.z_index = 100
	var tween = create_tween()
	tween.tween_property(fruit, "scale", Vector2(1.1, 1.1), 0.1)

func end_drag(fruit: Node, mouse_pos: Vector2):
	if dragging_item != fruit:
		return
	
	dragging_item = null
	fruit.z_index = 0
	var tween = create_tween()
	tween.tween_property(fruit, "scale", Vector2.ONE, 0.1)
	
	# Check if dropped on cart
	check_drop_on_cart(fruit, mouse_pos)

func _on_fruit_hover_start(fruit: Node):
	if timer_active and dragging_item == null:
		var tween = create_tween()
		tween.tween_property(fruit, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_fruit_hover_end(fruit: Node):
	if dragging_item != fruit:
		var tween = create_tween()
		tween.tween_property(fruit, "modulate", Color.WHITE, 0.1)

# ========== DROP ZONE DETECTION ==========

func check_drop_on_cart(fruit: Node, drop_position: Vector2):
	# Check if item was dropped on the cart drop zone
	if cart_sprite and cart_sprite.get_global_rect().has_point(drop_position):
		on_item_dropped_on_cart(fruit.name, fruit)
	else:
		return_to_original_position(fruit)

func on_item_dropped_on_cart(item_name: String, item_node: Node):
	if !timer_active:
		return
	
	# Check if item starts with "B"
	if correct_b_items.has(item_name):
		on_correct_match(item_name, item_node)
	else:
		on_wrong_match(item_name, item_node)

# ========== MATCH LOGIC ==========

func on_correct_match(item_name: String, item_node: Node):
	if !timer_active:
		return
	
	if !completed_matches.has(item_name):
		completed_matches.append(item_name)
		print("🎉 Correct! %s starts with B" % item_name)
		
		if feedback_label:
			feedback_label.text = "✅ Correct! " + item_name + " starts with B!"
		
		# Hide the correctly matched item
		if item_node:
			item_node.visible = false
			item_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Update cart appearance
		update_cart_appearance()
		
		# Turn the corresponding label green
		update_label_color(item_name, Color.GREEN)
		
		# Check if all B items are found
		if completed_matches.size() == correct_b_items.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "🎉 Excellent! Found all B items!"
			game_over(true)
		else:
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()

func on_wrong_match(item_name: String, item_node: Node):
	if !timer_active:
		return
	
	print("❌ Wrong! %s doesn't start with B" % item_name)
	
	if feedback_label:
		feedback_label.text = "❌ " + item_name + " doesn't start with B!"
	
	# Return item to original position
	return_to_original_position(item_node)
	
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func return_to_original_position(item_node: Node):
	if !item_node or !original_positions.has(item_node.name):
		return
	
	var original_pos = original_positions[item_node.name]
	
	# Animate return to original position
	var tween = create_tween()
	tween.tween_property(item_node, "position", original_pos, 0.3)
	
	# Add a small shake effect
	tween.tween_callback(func(): shake_item(item_node))

func shake_item(item_node: Node) -> void:
	if !item_node:
		return
	
	var current_pos = item_node.position
	var tween = create_tween()
	tween.tween_property(item_node, "position", current_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(item_node, "position", current_pos + Vector2(5, 0), 0.05)
	tween.tween_property(item_node, "position", current_pos, 0.05)

# ========== UI UPDATES ==========

func update_cart_appearance():
	if !cart_sprite:
		return
	
	match completed_matches.size():
		0:
			cart_sprite.texture = cart_empty_texture
		1:
			cart_sprite.texture = cart_1_item_texture
		2:
			cart_sprite.texture = cart_2_items_texture
		3:
			cart_sprite.texture = cart_3_items_texture

func update_label_color(item_name: String, color: Color):
	match item_name:
		"Banana":
			if banana_label:
				banana_label.modulate = color
				var tween = create_tween()
				tween.tween_property(banana_label, "scale", Vector2(1.1, 1.1), 0.2)
				tween.tween_property(banana_label, "scale", Vector2(1.0, 1.0), 0.2)
		"Broccoli":
			if broccoli_label:
				broccoli_label.modulate = color
				var tween = create_tween()
				tween.tween_property(broccoli_label, "scale", Vector2(1.1, 1.1), 0.2)
				tween.tween_property(broccoli_label, "scale", Vector2(1.0, 1.0), 0.2)
		"Blueberry":
			if blueberry_label:
				blueberry_label.modulate = color
				var tween = create_tween()
				tween.tween_property(blueberry_label, "scale", Vector2(1.1, 1.1), 0.2)
				tween.tween_property(blueberry_label, "scale", Vector2(1.0, 1.0), 0.2)

func reset_all_labels():
	if banana_label:
		banana_label.modulate = Color.WHITE
	if broccoli_label:
		broccoli_label.modulate = Color.WHITE
	if blueberry_label:
		blueberry_label.modulate = Color.WHITE

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
		feedback_label.text = "Drag the one that starts at letter \"B\""

# ========== GAME STATE ==========

func game_over(success: bool):
	timer_active = false
	
	# Hide game UI
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Fruits"): $Fruits.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	var popup_instance: Node = null
	
	# Popup logic based on performance
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()  # ⭐⭐⭐
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()  # ⭐⭐
		else:
			popup_instance = complete1_scene.instantiate()  # ⭐
	else:
		popup_instance = retry_scene.instantiate()      # ❌ retry
	
	if popup_instance:
		add_child(popup_instance)
	
	# Save progress
	if success:
		print("🎉 Letter B game completed successfully!")
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
