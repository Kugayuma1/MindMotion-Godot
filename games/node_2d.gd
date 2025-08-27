extends Node2D

# ---------------- DRAG & DROP ----------------
var dragging_color: Color 
var dragging_color_number: int
var is_dragging = false
var drag_source: TextureButton
var drag_preview: Control

# ---------------- TIMER ----------------
var countdown := 30
var timer_active := false
@onready var timer_label = $TimerLabel   # Label under this Node2D
@onready var main_label = $label_main    # Game status label
@onready var target_node = $Node2D2      # Direct reference to Node2D2
var original_main_text: String

# ---------------- GAME STATE ----------------
var game_completed := false

func _ready():
	if main_label:
		original_main_text = main_label.text
	
	# Connect all color buttons
	var color_buttons = get_tree().get_nodes_in_group("color_buttons")
	for button in color_buttons:
		button.button_down.connect(_on_color_button_pressed.bind(button))
		button.button_up.connect(_on_color_button_released)
	
	# Start game
	start_timer()
	
	# Debug info
	print("Game Manager Ready!")
	print("Target Node (Node2D2): ", target_node)
	if target_node:
		print("Found ", get_polygon_count(), " polygons in Node2D2")

# ---------------- TIMER ----------------
func start_timer() -> void:
	if timer_label:
		timer_label.text = "⏱️ 30s"
	countdown = 30
	timer_active = true
	game_completed = false
	update_timer()

func update_timer() -> void:
	# Check win condition FIRST
	check_win_condition()
	
	if game_completed or not timer_active:
		return
		
	if countdown <= 0:
		if timer_label:
			timer_label.text = "⏰ Times Up"
		if main_label:
			main_label.text = "⏰ Time's up!"
			main_label.modulate = Color.RED
		timer_active = false
		game_over()
		return
	
	if timer_label:
		timer_label.text = "⏱️ " + str(countdown) + "s"
	countdown -= 1
	
	await get_tree().create_timer(1.0).timeout
	if timer_active and not game_completed:
		update_timer()

# ---------------- DRAG & DROP LOGIC ----------------
func _on_color_button_pressed(button: TextureButton):
	if !timer_active or game_completed:
		return
	is_dragging = true
	drag_source = button
	dragging_color = button.color
	dragging_color_number = button.color_number
	create_drag_preview(button)

func _on_color_button_released():
	if is_dragging:
		check_drop_target()
	is_dragging = false
	drag_source = null
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func check_drop_target():
	var mouse_pos = get_global_mouse_position()
	
	# Only check polygons in Node2D2
	if not target_node:
		return
		
	var polygons = get_all_polygons_in_node(target_node)
	
	for polygon in polygons:
		if polygon and polygon.has_method("can_accept_drop") and polygon.can_accept_drop():
			if is_point_in_polygon(mouse_pos, polygon):
				var success = polygon.apply_color(dragging_color, dragging_color_number)
				if success:
					# Force immediate check after each successful color application
					call_deferred("check_win_condition")
				break

func _process(delta):
	if is_dragging and drag_preview:
		drag_preview.global_position = get_global_mouse_position() - drag_preview.size / 2

func create_drag_preview(button: TextureButton):
	drag_preview = Control.new()
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = button.texture_normal
	texture_rect.size = button.size * 0.8
	texture_rect.modulate = Color(1, 1, 1, 0.8)
	drag_preview.add_child(texture_rect)
	drag_preview.size = texture_rect.size
	
	get_tree().current_scene.add_child(drag_preview)

func is_point_in_polygon(point: Vector2, polygon: Polygon2D) -> bool:
	var local_point = polygon.to_local(point)
	return Geometry2D.is_point_in_polygon(local_point, polygon.polygon)

# ---------------- SIMPLE WIN CONDITION ----------------
func check_win_condition():
	if game_completed:
		return
		
	if not target_node:
		print("ERROR: Node2D2 not found!")
		return
	
	var polygons = get_all_polygons_in_node(target_node)
	var total_polygons = polygons.size()
	var colored_polygons = 0
	
	if total_polygons == 0:
		print("No polygons found in Node2D2!")
		return
	
	# Count colored polygons
	for polygon in polygons:
		if polygon.has_method("get") and polygon.get("is_colored"):
			colored_polygons += 1
	
	print("Colored polygons: ", colored_polygons, "/", total_polygons)
	
	# WIN CONDITION: All polygons colored
	if colored_polygons >= total_polygons and total_polygons > 0:
		win_game()

func win_game():
	print("🎉 GAME WON! 🎉")
	game_completed = true
	timer_active = false
	
	var completion_time = 30 - countdown
	
	if main_label:
		main_label.text = "✅ Done!"
		main_label.modulate = Color.GREEN
	
	if timer_label:
		timer_label.text = "✅ Done in " + str(completion_time) + "s"
	
	show_celebration_effects()

# Helper function to get all polygons in a node
func get_all_polygons_in_node(node: Node) -> Array:
	var polygons = []
	for child in node.get_children():
		if child is Polygon2D:
			polygons.append(child)
		else:
			# Check nested children too
			polygons += get_all_polygons_in_node(child)
	return polygons

# Helper function to count polygons
func get_polygon_count() -> int:
	if not target_node:
		return 0
	return get_all_polygons_in_node(target_node).size()

func game_over():
	print("Game Over – Time's up!")
	game_completed = true
	show_game_over_effects()

# ---------------- VISUAL EFFECTS ----------------
func show_celebration_effects():
	if main_label:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(main_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.3)

func show_game_over_effects():
	if main_label:
		var original_pos = main_label.position
		var tween = create_tween()
		tween.set_loops(5)
		tween.tween_property(main_label, "position", original_pos + Vector2(5, 0), 0.1)
		tween.tween_property(main_label, "position", original_pos - Vector2(5, 0), 0.1)
		tween.tween_callback(func(): main_label.position = original_pos)

# ---------------- RESTART ----------------
func restart_game():
	game_completed = false
	timer_active = false
	countdown = 30
	
	if timer_label:
		timer_label.text = "⏱️ 30s"
		timer_label.modulate = Color.WHITE
	if main_label:
		main_label.text = original_main_text
		main_label.modulate = Color.WHITE
		main_label.scale = Vector2.ONE
	
	# Reset all polygons in Node2D2
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		for polygon in polygons:
			if polygon.has_method("reset_color"):
				polygon.reset_color()
	
	start_timer()

func _input(event):
	if event.is_action_pressed("ui_accept") and game_completed:
		restart_game()

# ---------------- DEBUG FUNCTIONS ----------------
func debug_status():
	print("\n=== DEBUG STATUS ===")
	print("Game completed: ", game_completed)
	print("Timer active: ", timer_active)
	print("Target node exists: ", target_node != null)
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		print("Total polygons: ", polygons.size())
		for i in range(polygons.size()):
			var p = polygons[i]
			print("  Polygon ", i+1, " is_colored: ", p.get("is_colored") if p.has_method("get") else "UNKNOWN")
	print("==================\n")

# Call this from console or add to _ready() for testing
func force_win_check():
	print("🔍 FORCING WIN CHECK...")
	check_win_condition()
