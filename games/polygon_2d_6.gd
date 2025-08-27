# Polygon2D script for color by numbers
extends Polygon2D

var original_color: Color
@export var assigned_number: int = 3  # The number this polygon should match
@export var correct_color: Color = Color.BLUE  # The correct color for this polygon
var is_colored: bool = false
var number_label: Label

func _ready():
	original_color = color
	add_to_group("colorable_polygons")
	create_number_label()

func create_number_label():
	# Create a label to display the number
	number_label = Label.new()
	number_label.text = str(assigned_number)
	number_label.add_theme_font_size_override("font_size", 24)
	number_label.add_theme_color_override("font_color", Color.BLACK)
	number_label.add_theme_color_override("font_outline_color", Color.WHITE)
	number_label.add_theme_constant_override("outline_size", 2)
	
	# Position the label at the center of the polygon
	add_child(number_label)
	
	# Calculate the center of the polygon
	var center = Vector2.ZERO
	if polygon.size() > 0:
		for point in polygon:
			center += point
		center /= polygon.size()
	
	number_label.position = center - Vector2(12, 12)  # Offset to center the text

func apply_color(new_color: Color, color_number: int) -> bool:
	# Check if the color number matches the assigned number
	if color_number == assigned_number:
		color = new_color
		is_colored = true
		
		# Hide the number label when correctly colored
		if number_label:
			number_label.visible = false
		
		# Success animation
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color(1.3, 1.3, 1.3), 0.1)
		tween.tween_property(self, "modulate", Color.WHITE, 0.1)
		
		# Optional: Add a success sound or particle effect here
		print("Correct color applied to polygon ", assigned_number)
		return true
	else:
		# Wrong color - show error feedback
		show_error_feedback()
		print("Wrong color! This polygon needs color number ", assigned_number)
		return false

func show_error_feedback():
	# Red flash to indicate wrong color
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.BLUE, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func reset_color():
	color = original_color
	is_colored = false
	if number_label:
		number_label.visible = true

# Function to check if this polygon can accept a drop
func can_accept_drop() -> bool:
	return !is_colored  # Only accept if not already colored
