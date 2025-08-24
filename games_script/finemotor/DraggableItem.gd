# DRAGGABLE ITEM SCRIPT (Updated with timer integration)
extends TextureRect

var dragging: bool = false
var offset: Vector2
var original_position: Vector2
var game_controller  # Reference to main game controller

func _ready():
	original_position = position
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup_game_controller(controller):
	game_controller = controller

func _gui_input(event):
	# Don't allow dragging if timer is not active
	if game_controller and !game_controller.timer_active:
		return
		
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - offset

func _input(event):
	# Don't allow dragging if timer is not active
	if game_controller and !game_controller.timer_active:
		return
		
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		var item_rect = Rect2(global_position, size)
		
		if item_rect.has_point(mouse_pos):
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				dragging = true
				offset = mouse_pos - global_position
				move_to_front()
				get_viewport().set_input_as_handled()
				
			elif not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and dragging:
				dragging = false
				check_drop_target()
				get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - offset

func check_drop_target():
	# Don't process drops if timer is not active
	if game_controller and !game_controller.timer_active:
		reset_position()
		return
		
	var drop_targets = get_tree().get_nodes_in_group("drop_targets")
	var mouse_pos = get_global_mouse_position()
	
	for target in drop_targets:
		var target_rect = Rect2(target.global_position, target.size)
		
		if target_rect.has_point(mouse_pos):
			if target.expected_item == name:
				# Correct match!
				if game_controller:
					game_controller.on_correct_match(name, target.name)
				
				# Position item nicely on the target
				global_position = target.global_position + (target.size / 2) - (size / 2)
				
				# Optional: Add a small delay for visual feedback
				await get_tree().create_timer(0.3).timeout
				queue_free()
				return
			else:
				# Wrong match!
				if game_controller:
					game_controller.on_wrong_match(name, target.name, target)
				
				reset_position()
				return
	
	# Not dropped on any target
	reset_position()

func reset_position():
	position = original_position
