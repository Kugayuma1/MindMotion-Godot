extends TextureRect

func _ready():
	# Add this node to the cart_drop_zone group for easy finding
	add_to_group("cart_drop_zone")
	
	# Optional: Add visual feedback
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	# Optional: Change appearance when hovering
	modulate = Color(1.1, 1.1, 1.1, 1.0)  # Slightly brighter

func _on_mouse_exited():
	# Return to normal appearance
	modulate = Color(1.0, 1.0, 1.0, 1.0)
