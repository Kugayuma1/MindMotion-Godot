extends TextureRect

var item_name: String = ""
var game_controller: Control = null
var is_dragging: bool = false
var drag_offset: Vector2

@onready var sprite = $Fruits/Broccoli  # Adjust to your sprite node

func _ready():
	# Set the item name based on the node name
	item_name = name
	
	# Connect mouse events
	gui_input.connect(_on_gui_input)

func setup_game_controller(controller: Control):
	game_controller = controller

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_offset = global_position - event.global_position
				z_index = 100  # Bring to front
			else:
				# Stop dragging
				if is_dragging:
					is_dragging = false
					z_index = 0
					check_drop_zone(event.global_position)
	
	elif event is InputEventMouseMotion and is_dragging:
		# Update position while dragging
		global_position = event.global_position + drag_offset

func check_drop_zone(drop_position: Vector2):
	# Find the cart drop zone
	var cart_drop_zone = get_tree().get_first_node_in_group("cart_drop_zone")
	
	if !cart_drop_zone:
		# Try to find cart by path if group doesn't work
		var main_scene = get_tree().current_scene
		cart_drop_zone = main_scene.get_node_or_null("Cart/CartDropZone")
	
	if cart_drop_zone and cart_drop_zone.get_global_rect().has_point(drop_position):
		# Item was dropped on cart
		if game_controller and game_controller.has_method("on_item_dropped_on_cart"):
			game_controller.on_item_dropped_on_cart(item_name, self)
	else:
		# Item was dropped elsewhere, return to original position
		if game_controller and game_controller.has_method("return_to_original_position"):
			game_controller.return_to_original_position(self)

func set_draggable(draggable: bool):
	mouse_filter = Control.MOUSE_FILTER_STOP if draggable else Control.MOUSE_FILTER_IGNORE
