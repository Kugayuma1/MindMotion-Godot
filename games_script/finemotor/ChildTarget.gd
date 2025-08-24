# CHILD/DROP TARGET SCRIPT (Updated)
extends TextureRect

@export var expected_item: String = ""  # Set in inspector (e.g., "Apple", "Axe", "Ant", "Avocado")

func _ready():
	add_to_group("drop_targets")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	print("Drop target '%s' ready - expects: '%s'" % [name, expected_item])
