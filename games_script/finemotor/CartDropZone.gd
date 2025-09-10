extends TextureRect

# CartDropZone.gd
# Attach this script to the Cart control node

@export var target_letter: String = "B"  # The letter we're looking for
@export var cart_empty_texture: Texture2D  # Texture when cart is empty
@export var cart_banana_texture: Texture2D  # Texture when banana is in cart
@export var cart_broccoli_texture: Texture2D  # Texture when broccoli is in cart
@export var cart_blueberry_texture: Texture2D  # Texture when blueberry is in cart

var texture_rect: TextureRect
var current_item: Control = null
var correct_items: Array[String] = ["Banana", "Broccoli", "Blueberry"]  # Items that start with "B"
var game_controller: Control = null  # Reference to the game controller

func _ready():
	# Add this node to the cart_drop_zone group for easy finding
	add_to_group("cart_drop_zone")
	
	# Try to find TextureRect in different ways
	texture_rect = get_node("TextureRect") as TextureRect
	if not texture_rect:
		texture_rect = find_child("TextureRect", true, false) as TextureRect
	if not texture_rect:
		# Look for any TextureRect child
		for child in get_children():
			if child is TextureRect:
				texture_rect = child as TextureRect
				break
	
	# If still no TextureRect, check if this node itself is a TextureRect
	if not texture_rect and self is TextureRect:
		texture_rect = self as TextureRect
	
	# Set initial empty cart texture
	if texture_rect and cart_empty_texture:
		texture_rect.texture = cart_empty_texture

func setup_game_controller(controller: Control):
	game_controller = controller

func try_drop_item(item: Control) -> bool:
	var item_name = ""
	if item.has_method("get_item_name"):
		item_name = item.get_item_name()
	
	# Check if the item starts with the target letter
	if item_name.begins_with(target_letter):
		_accept_item(item)
		# Notify game controller of correct match
		if game_controller and game_controller.has_method("on_correct_match"):
			game_controller.on_correct_match(item_name)
		return true
	else:
		# Item doesn't start with target letter, reject it
		_reject_item()
		# Notify game controller of wrong match
		if game_controller and game_controller.has_method("on_wrong_match"):
			game_controller.on_wrong_match(item_name)
		return false

func _accept_item(item: Control):
	# Remove previous item if any
	if current_item:
		current_item.reset_position()
		current_item.visible = true
	
	# Set new current item
	current_item = item
	var item_name = item.get_item_name()
	
	# Change cart texture based on the item
	if texture_rect:
		match item_name:
			"Banana":
				if cart_banana_texture:
					texture_rect.texture = cart_banana_texture
			"Broccoli":
				if cart_broccoli_texture:
					texture_rect.texture = cart_broccoli_texture
			"Blueberry":
				if cart_blueberry_texture:
					texture_rect.texture = cart_blueberry_texture
	
	# Hide the dragged item
	item.visible = false
	
	# Optional: Add success feedback
	_show_success_feedback()

func _reject_item():
	# Optional: Add rejection feedback (like a shake animation)
	_show_rejection_feedback()

func _show_success_feedback():
	# Create a scale animation for success
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func _show_rejection_feedback():
	# Create a shake animation for rejection
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(-10, 0), 0.05)
	tween.tween_property(self, "position", original_pos + Vector2(10, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)

func clear_cart():
	if current_item:
		current_item.visible = true
		current_item.reset_position()
		current_item = null
	
	# Reset to empty cart texture
	if texture_rect and cart_empty_texture:
		texture_rect.texture = cart_empty_texture
