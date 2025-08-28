extends Polygon2D

var original_color: Color
@export var assigned_number: int = 2      # The number this polygon should match
@export var correct_color: Color = Color.YELLOW  # The correct color for this polygon
var is_colored: bool = false
var current_applied_color: Color  # Track what color was actually applied
var number_label: Label

func _ready():
	original_color = color
	current_applied_color = original_color
	add_to_group("colorable_polygons")
	create_number_label()
	
	# Debug print to help verify setup
	print("Polygon ", assigned_number, " expects color: ", correct_color)

func create_number_label():
	number_label = Label.new()
	number_label.text = str(assigned_number)
	number_label.add_theme_font_size_override("font_size", 24)
	number_label.add_theme_color_override("font_color", Color.BLACK)
	number_label.add_theme_color_override("font_outline_color", Color.WHITE)
	number_label.add_theme_constant_override("outline_size", 2)
	add_child(number_label)
	
	# Position label at polygon center
	var center = Vector2.ZERO
	if polygon.size() > 0:
		for point in polygon:
			center += point
		center /= polygon.size()
	number_label.position = center - Vector2(12, 12)

func apply_color(new_color: Color, color_number: int) -> bool:
	# Check if the dropped color number matches this polygon's assigned number
	if color_number == assigned_number:
		color = new_color
		current_applied_color = new_color
		is_colored = true
		
		if number_label:
			number_label.visible = false
		
		# Check if it's the correct color and provide feedback
		if is_correctly_colored():
			print("✅ Polygon ", assigned_number, " colored CORRECTLY with ", new_color)
			show_correct_feedback()
		else:
			print("⚠️ Polygon ", assigned_number, " colored with WRONG color. Expected: ", correct_color, " Got: ", new_color)
			show_wrong_color_feedback()
		
		return true
	else:
		# Wrong number - color doesn't belong here
		show_error_feedback()
		notify_wrong_color()
		print("❌ Wrong color number! Polygon ", assigned_number, " got color number ", color_number)
		return false

# NEW FUNCTION: Check if the applied color is the correct color for this polygon
func is_correctly_colored() -> bool:
	if not is_colored:
		return false
	
	# Compare colors with some tolerance for floating point precision
	var color_tolerance = 0.01
	return (
		abs(current_applied_color.r - correct_color.r) < color_tolerance and
		abs(current_applied_color.g - correct_color.g) < color_tolerance and
		abs(current_applied_color.b - correct_color.b) < color_tolerance
	)

func show_correct_feedback():
	# Green flash for correct color
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.GREEN, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func show_wrong_color_feedback():
	# Orange flash for wrong color (but right number)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.ORANGE, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func show_error_feedback():
	# Red flash for wrong number
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# Shake polygon
	var original_pos = position
	var shake_tween = create_tween()
	shake_tween.set_loops(3)
	shake_tween.tween_property(self, "position", original_pos + Vector2(2, 0), 0.05)
	shake_tween.tween_property(self, "position", original_pos - Vector2(2, 0), 0.05)
	shake_tween.tween_callback(func(): position = original_pos)

func notify_wrong_color():
	var scene = get_tree().current_scene
	if scene.has_method("show_temporary_message"):
		scene.show_temporary_message("❌ Wrong color!", Color.RED, 1.0)
		
		# Shake the main label too
		if scene.has_node("label_main"):
			var label = scene.get_node("label_main")
			var original_pos = label.position
			var tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(label, "position", original_pos + Vector2(4, 0), 0.05)
			tween.tween_property(label, "position", original_pos - Vector2(4, 0), 0.05)
			tween.tween_callback(func(): label.position = original_pos)

func reset_color():
	color = original_color
	current_applied_color = original_color
	is_colored = false
	modulate = Color.WHITE
	if number_label:
		number_label.visible = true

func can_accept_drop() -> bool:
	return !is_colored

func show_success_effect():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

# DEBUG FUNCTION: Call this to check current state
func debug_status():
	print("Polygon ", assigned_number, ":")
	print("  - is_colored: ", is_colored)
	print("  - current_applied_color: ", current_applied_color)
	print("  - correct_color: ", correct_color)
	print("  - is_correctly_colored(): ", is_correctly_colored())
