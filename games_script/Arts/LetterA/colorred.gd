extends TextureButton

var color: Color = Color(0, 0, 1) # Blue color in RGB

func get_drag_data(position):
	# Use the same picture as preview while dragging
	var preview = TextureRect.new()
	preview.texture = texture_normal
	preview.rect_size = Vector2(50, 50)
	set_drag_preview(preview)
	return color
