extends CanvasLayer

@onready var dot1 = $CenterContainer/HBoxContainer/HBoxContainer/Dot1
@onready var dot2 = $CenterContainer/HBoxContainer/HBoxContainer/Dot2
@onready var dot3 = $CenterContainer/HBoxContainer/HBoxContainer/Dot3
@onready var animated_sprite = $CenterContainer/HBoxContainer/AnimatedSprite2D

var current_dot = 0
var dot_timer = 0.0
var dot_interval = 0.4  # Time between dot animations
var dot_offset = -5  # How many pixels to move up

func _ready():
	hide()  # Hidden by default
	
func _process(delta):
	if visible:
		dot_timer += delta
		if dot_timer >= dot_interval:
			dot_timer = 0.0
			animate_dots()

func animate_dots():
	# Reset all dots to normal position
	dot1.position.y = 0
	dot2.position.y = 0
	dot3.position.y = 0
	
	# Move current dot up
	match current_dot:
		0:
			dot1.position.y = dot_offset
		1:
			dot2.position.y = dot_offset
		2:
			dot3.position.y = dot_offset
	
	# Move to next dot
	current_dot = (current_dot + 1) % 3

func show_loading():
	show()
	if animated_sprite:
		animated_sprite.play()  # Start walking animation
	
func hide_loading():
	hide()
	if animated_sprite:
		animated_sprite.stop()
