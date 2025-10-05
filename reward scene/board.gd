extends Panel

func _ready():
	add_to_group("board")
	
	# Make the panel invisible by creating an empty/transparent style
	var style = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", style)
	
	# Alternative method - uncomment this line instead if you prefer transparency:
	# modulate = Color(1, 1, 1, 0)  # Makes panel completely transparent
	
	print("Panel is now invisible but fully functional!")

# Optional: If you want to toggle visibility later
func make_visible():
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color.BLACK
	add_theme_stylebox_override("panel", style)

func make_invisible():
	var style = StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", style)
