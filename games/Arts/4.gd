# NumberLabel.gd - Attach this script to a Label node
extends Label

@export var polygon_number: int = 1    # The number to display on the label
@export var unique_id: String = ""     # Unique identifier to match with specific polygon

func _ready():
	# Add this label to a group so the main scene can find it
	add_to_group("number_labels")
	
	# Set the label text to show the polygon number
	text = str(polygon_number)
	
	# Generate unique ID if not set (you should set this manually in the editor)
	if unique_id == "":
		unique_id = str(get_instance_id())
		print("Warning: Label for number ", polygon_number, " has no unique_id set! Generated: ", unique_id)

func hide_label():
	# Fade out animation
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(func(): visible = false)

func show_label():
	# Fade in animation
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
