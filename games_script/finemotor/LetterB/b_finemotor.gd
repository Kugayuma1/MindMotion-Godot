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
var start_time := 0
var original_feedback_text = ""

# Cart states - add your cart images here
var cart_empty_texture = preload("res://Game Assets/Reading Assets/cart (1).png")
var cart_1_item_texture = preload("res://Game Assets/Fine Motor Assets/3.png")
var cart_2_items_texture = preload("res://Game Assets/Fine Motor Assets/2.png")
var cart_3_items_texture = preload("res://Game Assets/Fine Motor Assets/1.png")

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Store original positions for wrong items
var original_positions = {}

@onready var feedback_label = $Holder/Label  # Instructions/feedback label
@onready var timer_label = $Time/Label      # Timer label
@onready var cart_sprite = $Cart/CartDropZone  # Adjust path to your cart sprite
@onready var fruits_container = $Fruits  # Container with all fruits/vegetables

@onready var banana_label = $Cart/CartDropZone/BananaLabel      # Adjust path
@onready var broccoli_label = $Cart/CartDropZone/BroccoliLabel  # Adjust path  
@onready var blueberry_label = $Cart/CartDropZone/BlueberryLabel # Adjust path

func _ready():
	completed_matches.clear()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Drag the one that starts at letter \"B\""
	
	# Reset all labels to white at start
	reset_all_labels()
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Setup draggable food items and store original positions
	setup_draggable_items()
	store_original_positions()

func setup_draggable_items():
	if fruits_container:
		for child in fruits_container.get_children():
			if child.has_method("setup_game_controller"):
				child.setup_game_controller(self)
			# Make items draggable
			if child.has_method("set_draggable"):
				child.set_draggable(true)

func store_original_positions():
	if fruits_container:
		for child in fruits_container.get_children():
			original_positions[child.name] = child.position

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

func on_item_dropped_on_cart(item_name: String, item_node: Node):
	if !timer_active:
		return
		
	# Check if item starts with "B"
	if correct_b_items.has(item_name):
		on_correct_match(item_name, item_node)
	else:
		on_wrong_match(item_name, item_node)

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
				# Optional: Add a nice tween animation
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
	# Reset all labels to white color at game start
	if banana_label:
		banana_label.modulate = Color.WHITE
	if broccoli_label:
		broccoli_label.modulate = Color.WHITE
	if blueberry_label:
		blueberry_label.modulate = Color.WHITE

func game_over(success: bool):
	timer_active = false
	
	# Hide game UI
	if has_node("Holder"): $Holder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Fruits"): $Fruits.visible = false
	
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
		ProgressManager.save_progress("letter_b", true)
	else:
		print("⏰ Game over - Time's up!")
		ProgressManager.save_progress("letter_b", false)

func reset_feedback_label() -> void:
	if feedback_label and timer_active:
		feedback_label.text = "Drag the one that starts at letter \"B\""

# Call this function when an item is dropped on the cart
func _on_cart_drop_zone_item_dropped(item_name: String, item_node: Node):
	on_item_dropped_on_cart(item_name, item_node)
