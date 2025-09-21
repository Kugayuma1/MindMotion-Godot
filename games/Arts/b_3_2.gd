# NumberLabel.gd
# Attach this script to Label nodes that show numbers
extends Label

# Exported variables (set these in the editor)
@export var polygon_number: int = 3
@export var label_id: String = "blue2"

# Internal variables
var is_hidden: bool = false
var original_modulate: Color

func _ready():
	# Store original appearance
	original_modulate = modulate
	
	# Add to group for easy finding
	add_to_group("number_labels")
	
	# Generate ID if not set
	if label_id == "blue2":
		label_id = "label_" + str(polygon_number)
	
	# Set the text
	text = str(polygon_number)
	
	print("🏷️ Label setup - Number: ", polygon_number, ", ID: ", label_id)

func hide_with_animation():
	"""Hide the label with a smooth fade out animation"""
	if is_hidden:
		return
	
	is_hidden = true
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(func(): visible = false)
	
	print("👻 Hiding label for number ", polygon_number)

func show_with_animation():
	"""Show the label with a smooth fade in animation"""
	if not is_hidden:
		return
	
	is_hidden = false
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate", original_modulate, 0.3)
	
	print("👁️ Showing label for number ", polygon_number)

func pulse_effect():
	"""Create a pulse effect for the label"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

func shake_effect():
	"""Shake the label (for wrong color feedback)"""
	var original_pos = position
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(self, "position", original_pos + Vector2(4, 0), 0.05)
	tween.tween_property(self, "position", original_pos - Vector2(4, 0), 0.05)
	tween.tween_callback(func(): position = original_pos)

func reset_appearance():
	"""Reset the label to its original state"""
	modulate = original_modulate
	scale = Vector2(1.0, 1.0)
	visible = true
	is_hidden = false
