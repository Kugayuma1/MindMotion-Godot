# TextureButton script for color by numbers - WITH DISAPPEARING EFFECT
extends TextureButton

@export var color: Color = Color.RED
@export var color_number: int = 1  # The number associated with this color
var is_dragging = false
var original_modulate: Color

func _ready():
	add_to_group("color_buttons")
	# Store original appearance
	original_modulate = modulate
	
	# Connect signals
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_button_down():
	is_dragging = true
	# Make the button semi-transparent when picked up
	modulate = Color(1, 1, 1, 0.3)  # 30% opacity
	print("Color button ", color_number, " picked up - button faded")

func _on_button_up():
	AudioManager.play_sound("button_click")
	is_dragging = false
	# Restore the button's original appearance
	modulate = original_modulate
	print("Color button ", color_number, " released - button restored")

func _process(delta):
	if is_dragging:
		# Optional: Add any dragging effects here
		pass
