extends Node2D

# ---------------- DRAG & DROP ----------------
var dragging_color: Color 
var dragging_color_number: int
var is_dragging = false
var drag_source: TextureButton
var drag_preview: Control

# ---------------- TIMER ----------------
var countdown := 15
var timer_active := false
var timer_label: Label
var main_label: Label
var target_node: Node2D
var original_main_text: String

# ---------------- GAME STATE ----------------
var game_completed := false

func _ready():
	# Wait one frame to ensure all nodes are ready
	await get_tree().process_frame
	
	# Find nodes with better error handling
	timer_label = find_node_by_name("TimerLabel")
	main_label = find_node_by_name("label_main")
	
	# Find the node containing polygons - try multiple names
	var potential_names = ["Node2D", "Node2D2", "Polygons", "GameArea"]
	for name in potential_names:
		var node = find_node_by_name(name)
		if node and get_all_polygons_in_node(node).size() > 0:
			target_node = node
			print("🎯 Found target node with polygons: ", name, " (", get_all_polygons_in_node(node).size(), " polygons)")
			break
	
	# If still not found, search for any node containing polygons
	if not target_node:
		target_node = find_node_with_polygons()
		if target_node:
			print("🎯 Found polygon container: ", target_node.name)
	
	if main_label:
		original_main_text = main_label.text
	else:
		print("❌ Main label not found! Looking for any label with 'main' in the name...")
		main_label = find_node_containing_name("main")
	
	# Connect all color buttons
	var color_buttons = get_tree().get_nodes_in_group("color_buttons")
	for button in color_buttons:
		if button.has_signal("button_down"):
			button.button_down.connect(_on_color_button_pressed.bind(button))
		if button.has_signal("button_up"):
			button.button_up.connect(_on_color_button_released)
	
	# Start game
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	
	# Debug info
	print("\n=== GAME SETUP DEBUG ===")
	print("Timer Label found: ", timer_label != null, " - ", timer_label)
	print("Main Label found: ", main_label != null, " - ", main_label)
	print("Target Node found: ", target_node != null, " - ", target_node)
	if target_node:
		print("Polygons in target node: ", get_polygon_count())
	print("========================\n")

# ---------------- INDIVIDUAL LABEL MANAGEMENT ----------------
func on_polygon_colored(polygon_unique_id: String):
	var labels = get_tree().get_nodes_in_group("number_labels")
	for label in labels:
		if label.has_method("get") and label.get("label_id") == polygon_unique_id:
			if label.has_method("hide_with_animation"):
				label.hide_with_animation()
			else:
				label.visible = false
			break

func on_polygon_reset(polygon_unique_id: String):
	var labels = get_tree().get_nodes_in_group("number_labels")
	for label in labels:
		if label.has_method("get") and label.get("label_id") == polygon_unique_id:
			if label.has_method("show_with_animation"):
				label.show_with_animation()
			else:
				label.visible = true
			break

# ---------------- TIMER ----------------
func start_timer() -> void:
	print("🕐 Node2D: Starting timer...")
	
	# Reset state
	countdown = 15
	timer_active = true
	game_completed = false
	
	# Reset UI
	if timer_label:
		timer_label.text = "⏱️ 15s"
		timer_label.modulate = Color.WHITE
		timer_label.visible = true
		print("✅ Timer label set to: ", timer_label.text)
	else:
		print("❌ Timer label not found!")
	
	if main_label:
		main_label.text = original_main_text if original_main_text else "Color by number!"
		main_label.modulate = Color.WHITE
		main_label.scale = Vector2.ONE
		print("✅ Main label reset")
	
	# Start the timer loop
	timer_loop()

func timer_loop():
	print("⏰ Timer loop started - countdown:", countdown, " active:", timer_active)
	
	while timer_active and countdown > 0 and not game_completed:
		await get_tree().create_timer(1.0).timeout
		
		# Double-check timer is still active after wait
		if not timer_active or game_completed:
			print("⏰ Timer loop exited early - active:", timer_active, " completed:", game_completed)
			break
			
		countdown -= 1
		update_timer_display()
		
		# Check win condition each second
		check_win_condition()
	
	print("⏰ Timer loop finished - active:", timer_active, " completed:", game_completed, " countdown:", countdown)
	
	# Timer finished - only trigger time_up if still active and not completed
	if timer_active and not game_completed and countdown <= 0:
		time_up()

func update_timer_display():
	if timer_label and countdown >= 0:
		timer_label.text = "⏱️ " + str(countdown) + "s"

func time_up():
	print("⏰ Time's up!")
	timer_active = false
	game_completed = true
	
	if timer_label:
		timer_label.text = "⏰ Times Up"
		timer_label.modulate = Color.RED
	if main_label:
		main_label.text = "⏰ Time's up!"
		main_label.modulate = Color.RED
	
	# Save progress as failed
	ProgressManager.save_progress("art", false)
	Global.refresh_everything_after_stage_completion("art", false)
	
	# Call Control parent to show popup
	var control_parent = get_parent()
	if control_parent and control_parent.has_method("show_popup"):
		control_parent.show_popup(false, countdown)
	else:
		print("❌ ERROR: Could not find Control parent to show popup!")

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
	
	var polygons = []
	if target_node:
		polygons = get_all_polygons_in_node(target_node)
	else:
		polygons = get_tree().get_nodes_in_group("colorable_polygons")
	
	var best_hit_polygon = null
	var smallest_area = INF
	
	for polygon in polygons:
		if polygon and polygon.has_method("can_accept_drop") and polygon.can_accept_drop():
			if is_point_in_polygon_ultra_precise(mouse_pos, polygon):
				var area = calculate_polygon_area(polygon)
				if area < smallest_area:
					smallest_area = area
					best_hit_polygon = polygon
	
	if best_hit_polygon:
		var success = best_hit_polygon.apply_color(dragging_color, dragging_color_number)
		if success:
			call_deferred("check_win_condition")

func is_point_in_polygon_ultra_precise(point: Vector2, polygon: Polygon2D) -> bool:
	var local_point = polygon.to_local(point)
	var polygon_points = polygon.polygon
	
	if polygon_points.size() < 3:
		return false
	
	var intersections = 0
	var n = polygon_points.size()
	
	for i in range(n):
		var p1 = polygon_points[i]
		var p2 = polygon_points[(i + 1) % n]
		
		if ((p1.y > local_point.y) != (p2.y > local_point.y)):
			var x_intersect = (p2.x - p1.x) * (local_point.y - p1.y) / (p2.y - p1.y) + p1.x
			if local_point.x < x_intersect:
				intersections += 1
	
	return (intersections % 2) == 1

func calculate_polygon_area(polygon: Polygon2D) -> float:
	var points = polygon.polygon
	if points.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = points.size()
	
	for i in range(n):
		var j = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	
	return abs(area) / 2.0

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

# ---------------- WIN CONDITION ----------------
func check_win_condition():
	if game_completed:
		return
	
	var polygons = []
	if target_node:
		polygons = get_all_polygons_in_node(target_node)
	else:
		polygons = get_tree().get_nodes_in_group("colorable_polygons")
	
	var total_polygons = polygons.size()
	var correctly_colored_polygons = 0
	
	if total_polygons == 0:
		return
	
	for polygon in polygons:
		if polygon.has_method("is_correctly_colored") and polygon.is_correctly_colored():
			correctly_colored_polygons += 1
	
	if correctly_colored_polygons >= total_polygons and total_polygons > 0:
		win_game()

func win_game():
	print("🎉 GAME WON! 🎉")
	game_completed = true
	timer_active = false
	
	var completion_time = 15 - countdown
	
	if main_label:
		main_label.text = "✅ Done!"
		main_label.modulate = Color.GREEN
	
	if timer_label:
		timer_label.text = "✅ Done in " + str(completion_time) + "s"
		timer_label.modulate = Color.GREEN
	
	show_celebration_effects()
	
	# Save progress as successful
	ProgressManager.save_progress("art", true)
	Global.refresh_everything_after_stage_completion("art", true)
	
	# Call Control parent to show popup
	var control_parent = get_parent()
	if control_parent and control_parent.has_method("show_popup"):
		control_parent.show_popup(true, countdown)
	else:
		print("❌ ERROR: Could not find Control parent to show popup!")

# ---------------- VISUAL EFFECTS ----------------
func show_celebration_effects():
	if main_label:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(main_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.3)

# ---------------- RESTART ----------------
func restart_game():
	print("🔄 Node2D: Restarting game...")
	
	# STOP timer immediately
	timer_active = false
	game_completed = false
	
	# Wait for old timer loop to exit
	await get_tree().process_frame
	
	# Reset polygons
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		print("🔄 Resetting ", polygons.size(), " polygons")
		for polygon in polygons:
			if polygon.has_method("reset_color"):
				polygon.reset_color()
	
	# Reset number labels
	var labels = get_tree().get_nodes_in_group("number_labels")
	for label in labels:
		if label.has_method("show_with_animation"):
			label.show_with_animation()
		else:
			label.visible = true
	
	# Wait another frame
	await get_tree().process_frame
	
	# Start fresh timer
	start_timer()
	print("✅ Node2D: Game restarted! Timer active:", timer_active, " Countdown:", countdown)

# ---------------- HELPER FUNCTIONS ----------------
func get_all_polygons_in_node(node: Node) -> Array:
	var polygons = []
	for child in node.get_children():
		if child is Polygon2D:
			polygons.append(child)
		else:
			polygons += get_all_polygons_in_node(child)
	return polygons

func get_polygon_count() -> int:
	if not target_node:
		return 0
	return get_all_polygons_in_node(target_node).size()

func find_node_by_name(node_name: String) -> Node:
	if has_node(node_name):
		return get_node(node_name)
	
	var found = get_tree().get_first_node_in_group(node_name.to_lower())
	if found:
		return found
	
	return search_node_recursive(get_tree().current_scene, node_name)

func find_node_containing_name(partial_name: String) -> Node:
	return search_node_with_partial_name(get_tree().current_scene, partial_name.to_lower())

func find_node_with_polygons() -> Node2D:
	return search_for_polygon_container(get_tree().current_scene)

func search_for_polygon_container(node: Node) -> Node2D:
	if node is Node2D and get_all_polygons_in_node(node).size() > 0:
		return node
	
	for child in node.get_children():
		var result = search_for_polygon_container(child)
		if result:
			return result
	return null

func search_node_recursive(node: Node, target_name: String) -> Node:
	if node.name.to_lower() == target_name.to_lower():
		return node
	
	for child in node.get_children():
		var result = search_node_recursive(child, target_name)
		if result:
			return result
	return null

func search_node_with_partial_name(node: Node, partial_name: String) -> Node:
	if partial_name in node.name.to_lower():
		return node
	
	for child in node.get_children():
		var result = search_node_with_partial_name(child, partial_name)
		if result:
			return result
	return null
