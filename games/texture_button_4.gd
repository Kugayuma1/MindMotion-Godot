# TextureButton script for color by numbers
extends TextureButton

@export var color: Color = Color.BLACK
@export var color_number: int = 4  # The number associated with this color
var is_dragging = false

func _ready():
	add_to_group("color_buttons")
	# Connect signals
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down():
	is_dragging = true

func _on_button_up():
	is_dragging = false
	# Check all polygons in the group for collision
	var polygons = get_tree().get_nodes_in_group("colorable_polygons")
	var mouse_pos = get_global_mouse_position()
	
	for polygon in polygons:
		if polygon and polygon.has_method("can_accept_drop") and polygon.can_accept_drop():
			# Check if mouse is within polygon bounds
			if is_point_in_polygon(mouse_pos, polygon):
				polygon.apply_color(color, color_number)
				break

func is_point_in_polygon(point: Vector2, polygon_node: Polygon2D) -> bool:
	# Convert global point to polygon's local space
	var local_point = polygon_node.to_local(point)
	
	# Simple bounding box check first
	var polygon_points = polygon_node.polygon
	if polygon_points.size() < 3:
		return false
	
	var min_x = polygon_points[0].x
	var max_x = polygon_points[0].x
	var min_y = polygon_points[0].y
	var max_y = polygon_points[0].y
	
	for p in polygon_points:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)
	
	# Check if point is within bounding box
	return (local_point.x >= min_x and local_point.x <= max_x and 
			local_point.y >= min_y and local_point.y <= max_y)

func _process(delta):
	if is_dragging:
		# If you want to do anything while dragging, add here
		pass
