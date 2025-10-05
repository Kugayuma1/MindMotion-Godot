extends Polygon2D

var original_color: Color
@export var assigned_number: int = 3      
@export var correct_color: Color = Color.YELLOW  
var is_colored: bool = false
var current_applied_color: Color  
var my_label: Label  # Reference to child label

# Area2D reference for precise collision detection
var area_2d: Area2D
var is_mouse_over: bool = false

func _ready():
	original_color = color
	current_applied_color = original_color
	add_to_group("colorable_polygons")
	
	# Find the child label automatically
	find_child_label()
	
	# Find and setup Area2D child
	setup_area2d()
	
	print("Polygon ", assigned_number, " expects color: ", correct_color)
	if my_label:
		print("  - Found child label: ", my_label.name)
	else:
		print("  - WARNING: No child label found!")

func find_child_label():
	"""Automatically find the Label child node"""
	for child in get_children():
		if child is Label:
			my_label = child
			print("Found child label: ", child.name)
			break
	
	# If no direct Label child, check in Area2D children too
	if not my_label and area_2d:
		for child in area_2d.get_children():
			if child is Label:
				my_label = child
				print("Found label in Area2D: ", child.name)
				break

func setup_area2d():
	# Find Area2D child node
	area_2d = get_node("Area2D") if has_node("Area2D") else null
	
	if area_2d:
		# Connect Area2D signals for precise collision detection
		if not area_2d.mouse_entered.is_connected(_on_area_mouse_entered):
			area_2d.mouse_entered.connect(_on_area_mouse_entered)
		if not area_2d.mouse_exited.is_connected(_on_area_mouse_exited):
			area_2d.mouse_exited.connect(_on_area_mouse_exited)
		
		# Make sure CollisionPolygon2D has the same points as Polygon2D
		var collision_polygon = area_2d.get_node("CollisionPolygon2D") if area_2d.has_node("CollisionPolygon2D") else null
		if collision_polygon:
			collision_polygon.polygon = polygon
			print("CollisionPolygon2D synced for polygon ", assigned_number)
		else:
			print("CollisionPolygon2D not found for polygon ", assigned_number)
	else:
		print("Area2D not found for polygon ", assigned_number)

func _on_area_mouse_entered():
	is_mouse_over = true
	if not is_colored:
		modulate = Color(1.1, 1.1, 1.1)

func _on_area_mouse_exited():
	is_mouse_over = false
	if not is_colored:
		modulate = Color.WHITE

# Check if mouse is currently over this polygon
func is_mouse_over_polygon() -> bool:
	return is_mouse_over

# Enhanced apply_color function that only works when mouse is over the polygon
func apply_color_at_position(new_color: Color, color_number: int, mouse_pos: Vector2) -> bool:
	if not is_mouse_over:
		return false
	return apply_color(new_color, color_number)

func apply_color(new_color: Color, color_number: int) -> bool:
	print("Apply color called - Color number: ", color_number, " Assigned: ", assigned_number)
	
	if color_number == assigned_number:
		color = new_color
		current_applied_color = new_color
		is_colored = true
		
		print("Color applied successfully to polygon ", assigned_number)
		
		# Hide the child label directly
		hide_my_label()
		
		if is_correctly_colored():
			print("Polygon ", assigned_number, " colored CORRECTLY")
			show_correct_feedback()
		else:
			print("Polygon ", assigned_number, " colored with WRONG color")
			show_wrong_color_feedback()
		
		return true
	else:
		show_error_feedback()
		notify_wrong_color()
		print("Wrong color number! Polygon ", assigned_number, " got color number ", color_number)
		return false

func hide_my_label():
	"""Hide the child label"""
	if my_label:
		print("Hiding child label: ", my_label.name)
		if my_label.has_method("hide_with_animation"):
			my_label.hide_with_animation()
		else:
			my_label.visible = false
	else:
		print("WARNING: No child label to hide for polygon ", assigned_number)

func show_my_label():
	"""Show the child label"""
	if my_label:
		print("Showing child label: ", my_label.name)
		if my_label.has_method("show_with_animation"):
			my_label.show_with_animation()
		else:
			my_label.visible = true
	else:
		print("WARNING: No child label to show for polygon ", assigned_number)

func is_correctly_colored() -> bool:
	if not is_colored:
		return false
	
	var color_tolerance = 0.01
	return (
		abs(current_applied_color.r - correct_color.r) < color_tolerance and
		abs(current_applied_color.g - correct_color.g) < color_tolerance and
		abs(current_applied_color.b - correct_color.b) < color_tolerance
	)

func show_correct_feedback():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func show_wrong_color_feedback():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.ORANGE, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func show_error_feedback():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	var original_pos = position
	var shake_tween = create_tween()
	shake_tween.set_loops(3)
	shake_tween.tween_property(self, "position", original_pos + Vector2(2, 0), 0.05)
	shake_tween.tween_property(self, "position", original_pos - Vector2(2, 0), 0.05)
	shake_tween.tween_callback(func(): position = original_pos)

func notify_wrong_color():
	var scene = get_tree().current_scene
	if scene and scene.has_method("show_temporary_message"):
		scene.show_temporary_message("Wrong color!", Color.RED, 1.0)

func reset_color():
	print("Resetting polygon ", assigned_number)
	color = original_color
	current_applied_color = original_color
	is_colored = false
	modulate = Color.WHITE
	
	# Show the child label again
	show_my_label()

func can_accept_drop() -> bool:
	return true

func show_success_effect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func debug_status():
	print("Polygon ", assigned_number, ":")
	print("  - is_colored: ", is_colored)
	print("  - current_applied_color: ", current_applied_color)
	print("  - correct_color: ", correct_color)
	print("  - is_correctly_colored(): ", is_correctly_colored())
	print("  - is_mouse_over: ", is_mouse_over)
	print("  - my_label: ", my_label)
