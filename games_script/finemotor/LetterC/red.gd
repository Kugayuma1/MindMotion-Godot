extends TextureRect
enum PawColor { ORANGE, PURPLE, RED, GRAY }
@export var paw_color: PawColor = PawColor.RED

var has_food: bool = false
var original_modulate: Color

func _ready():
	# Add to group so draggable items can find paws
	add_to_group("paw_targets")
	original_modulate = modulate

func get_paw_color_string() -> String:
	match paw_color:
		PawColor.ORANGE:
			return "Orange"
		PawColor.PURPLE:
			return "Purple"
		PawColor.RED:
			return "Red"
		PawColor.GRAY:
			return "Gray"
	return "Unknown"

func _process(delta):
	# Visual feedback when food item is hovering over paw
	var food_items = get_tree().get_nodes_in_group("food_items")  # Add food items to this group
	var mouse_pos = get_global_mouse_position()
	var paw_rect = Rect2(global_position, size)
	var is_hovering = false
	
	for food in food_items:
		if food.dragging and paw_rect.has_point(mouse_pos):
			is_hovering = true
			break
	
	if is_hovering and !has_food:
		modulate = Color(1.2, 1.2, 1.2)  # Brighten when hovering
	else:
		modulate = original_modulate
