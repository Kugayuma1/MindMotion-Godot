extends TextureRect

@export var item_name: String = ""  # Set this to "Banana", "Broccoli", or "Blueberry"
@export var correct_answers: Array[String] = []  # Which items this cart accepts

var is_dragging = false
var drag_offset = Vector2.ZERO
var original_position = Vector2.ZERO
var original_parent: Control

func _ready():
	# Store original position and parent
	original_position = position
	original_parent = get_parent()
	
	# Connect mouse signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging
				is_dragging = true
				drag_offset = event.position
				# Move to front
				move_to_front()
				# Change cursor
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				# Stop dragging
				if is_dragging:
					_handle_drop()
				is_dragging = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
	elif event is InputEventMouseMotion and is_dragging:
		# Update position while dragging
		global_position = event.global_position - drag_offset

func _on_mouse_entered():
	if not is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited():
	if not is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _handle_drop():
	# Check if dropped on any drop zone
	var drop_zone = _get_drop_zone_under_mouse()
	
	if drop_zone and drop_zone.has_method("try_drop_item"):
		var success = drop_zone.try_drop_item(self)
		if not success:
			_return_to_original_position()
	else:
		_return_to_original_position()

func _get_drop_zone_under_mouse() -> Control:
	# Get the mouse position
	var mouse_pos = get_global_mouse_position()
	
	# Check specifically for CartDropZone
	var cart_drop_zone = get_tree().get_first_node_in_group("cart_drop_zone")
	if cart_drop_zone and _is_point_inside_control(mouse_pos, cart_drop_zone):
		return cart_drop_zone
	
	# Alternative: Check by finding the Cart container and its CartDropZone child
	var cart_node = get_node("../../Cart")  # Adjust path based on your scene structure
	if cart_node:
		var drop_zone = cart_node.get_node("CartDropZone")
		if drop_zone and _is_point_inside_control(mouse_pos, drop_zone):
			return drop_zone
	
	return null

func _is_point_inside_control(point: Vector2, control: Control) -> bool:
	var rect = Rect2(control.global_position, control.size)
	return rect.has_point(point)

func _return_to_original_position():
	# Create a smooth tween back to original position
	var tween = create_tween()
	tween.tween_property(self, "global_position", original_parent.global_position + original_position, 0.3)

func get_item_name() -> String:
	return item_name

func reset_position():
	position = original_position
