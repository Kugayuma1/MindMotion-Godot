extends TextureButton

var dragging = false
var drag_offset = Vector2()
var target_marker: Marker2D
var is_placed = false
var snap_distance = 50

@export var target_marker_path: NodePath

func _ready():
	if target_marker_path:
		target_marker = get_node(target_marker_path)
	
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down():
	if not is_placed:
		dragging = true
		drag_offset = global_position - get_global_mouse_position()
		move_to_front()

func _on_button_up():
	dragging = false
	check_snap()

func _process(_delta):
	if dragging:
		global_position = get_global_mouse_position() + drag_offset

func check_snap():
	# Only snap to THIS piece's designated marker
	if target_marker and global_position.distance_to(target_marker.global_position) < snap_distance:
		position = target_marker.position
		is_placed = true
		disabled = true
		get_parent().check_completion()
