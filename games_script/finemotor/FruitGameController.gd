# FruitGameController.gd
# Main controller for the fruit drag and drop game
extends Control

var correct_items = ["Banana", "Broccoli", "Blueberry"]  # Items that start with "B"
var completed_matches = []
var countdown := 15
var timer_active := true
var start_time := 0
var original_feedback_text = ""

# Preload reward scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

@onready var feedback_label = $Holder/Label  # Instructions/feedback label
@onready var timer_label = $Time/Label      # Timer label
@onready var fruits_container = $Fruits     # Container with draggable fruits
@onready var cart_container = $Cart         # Container with cart/drop zone

func _ready():
	completed_matches.clear()
	
	# Store original feedback text for reset
	if feedback_label:
		original_feedback_text = feedback_label.text
		feedback_label.text = "Drag the ones that start at letter \"B\""
	
	start_timer()
	Global.start_time = Time.get_ticks_msec() 
	
	# Setup draggable food items
	setup_draggable_items()
	# Setup cart drop zone
	setup_cart_drop_zone()

func setup_draggable_items():
	if fruits_container:
		for child in fruits_container.get_children():
			if child is Control:
				# Add the draggable script and set item names
				if not child.has_method("get_item_name"):
					child.set_script(preload("res://games_script/finemotor/banana.gd"))
					child.set_script(preload("res://games_script/finemotor/carrot.gd"))
					child.set_script(preload("res://games_script/finemotor/cucumber.gd"))
					child.set_script(preload("res://games_script/finemotor/broccoli.gd"))
					child.set_script(preload("res://games_script/finemotor/blueberry.gd"))
					child.set_script(preload("res://games_script/finemotor/coconut.gd"))
					
					# Set item names based on node names
					match child.name.to_lower():
						"carrot":
							child.item_name = "Carrot"
						"banana":
							child.item_name = "Banana"
						"cucumber":
							child.item_name = "Cucumber"
						"broccoli":
							child.item_name = "Broccoli"
						"blueberry":
							child.item_name = "Blueberry"
						"coconut":
							child.item_name = "Coconut"
				
				# Connect to game controller
				if child.has_method("setup_game_controller"):
					child.setup_game_controller(self)

func setup_cart_drop_zone():
	if cart_container:
		var cart_drop_zone = null
		# Find the CartDropZone child
		cart_drop_zone = cart_container.get_node("CartDropZone")
		
		if not cart_drop_zone:
			# If CartDropZone not found, check if cart_container itself has the method
			if cart_container.has_method("try_drop_item"):
				cart_drop_zone = cart_container
			else:
				# Look through children
				for child in cart_container.get_children():
					if child.has_method("try_drop_item"):
						cart_drop_zone = child
						break
		
		if cart_drop_zone and cart_drop_zone.has_method("setup_game_controller"):
			cart_drop_zone.setup_game_controller(self)
		else:
			print("Warning: CartDropZone not found or doesn't have setup_game_controller method")

func show_all_fruits():
	if fruits_container:
		for child in fruits_container.get_children():
			if child is Control:
				child.visible = true

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

func on_correct_match(item_name: String):
	if !timer_active:
		return
		
	if !completed_matches.has(item_name):
		completed_matches.append(item_name)
		print("🎉 Correct! %s starts with B" % [item_name])
		
		if feedback_label:
			feedback_label.text = "✅Correct! " + item_name + " starts with B!"
		
		# Check if all B items are completed
		var b_items_in_scene = []
		for item in correct_items:
			if has_item_in_scene(item):
				b_items_in_scene.append(item)
		
		if completed_matches.size() == b_items_in_scene.size():
			timer_active = false
			if feedback_label:
				feedback_label.text = "🎉 Very Good! All B items found!"
			game_over(true)
		else:
			await get_tree().create_timer(1.5).timeout
			reset_feedback_label()

func on_wrong_match(item_name: String):
	if !timer_active:
		return
		
	print("❌ Wrong! %s doesn't start with B" % [item_name])
	
	if feedback_label:
		feedback_label.text = "❌ Wrong! " + item_name + " doesn't start with B!"
	
	# Find the cart and shake it
	var cart_node = cart_container
	if cart_node:
		shake_child(cart_node)
	
	await get_tree().create_timer(1.5).timeout
	reset_feedback_label()

func has_item_in_scene(item_name: String) -> bool:
	if not fruits_container:
		return false
		
	for child in fruits_container.get_children():
		if child.has_method("get_item_name") and child.get_item_name() == item_name:
			return true
	return false

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
	if has_node("Cart"): $Cart.visible = false
	if has_node("Fruits"): $Fruits.visible = false
	
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
		feedback_label.text = "Drag the ones that start at letter \"B\""
