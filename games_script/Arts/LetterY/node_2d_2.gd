extends Node2D

# ---------------- DRAG & DROP ----------------
var dragging_color: Color 
var dragging_color_number: int
var is_dragging = false
var drag_source: TextureButton
var drag_preview: Control
var motivational_10s_played := false
var motivational_5s_played := false


# ---------------- TIMER ----------------
var countdown := 15
var timer_active := false
# Use get_node with error handling instead of @onready
var timer_label: Label
var main_label: Label
var target_node: Node2D
var original_main_text: String
var timer_tween: Tween  # Keep reference to timer tween

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
	
	# Debug collision shapes
	debug_draw_polygon_bounds()
	
	# Debug info - More detailed
	print("\n=== GAME SETUP DEBUG ===")
	print("Timer Label found: ", timer_label != null, " - ", timer_label)
	print("Main Label found: ", main_label != null, " - ", main_label)
	print("Target Node found: ", target_node != null, " - ", target_node)
	if target_node:
		print("Polygons in target node: ", get_polygon_count())
	else:
		print("❌ No target node - searching entire scene for polygons...")
		var all_polygons = get_tree().get_nodes_in_group("colorable_polygons")
		print("Total polygons in scene: ", all_polygons.size())
	print("========================\n")

# ---------------- INDIVIDUAL LABEL MANAGEMENT ----------------
# This function is called by the polygon when it gets colored
func on_polygon_colored(polygon_unique_id: String):
	print("📞 on_polygon_colored called for ID: ", polygon_unique_id)
	# Find the label with matching unique_id
	var labels = get_tree().get_nodes_in_group("number_labels")
	print("🔍 Found ", labels.size(), " labels in group")
	for label in labels:
		if label.has_method("get") and label.get("label_id") == polygon_unique_id:
			print("✅ Found matching label, hiding it")
			if label.has_method("hide_with_animation"):
				label.hide_with_animation()
			else:
				label.visible = false
			break

# This function is called by the polygon when it gets reset
func on_polygon_reset(polygon_unique_id: String):
	print("📞 on_polygon_reset called for ID: ", polygon_unique_id)
	# Find the label with matching unique_id
	var labels = get_tree().get_nodes_in_group("number_labels")
	for label in labels:
		if label.has_method("get") and label.get("label_id") == polygon_unique_id:
			print("✅ Found matching label, showing it")
			if label.has_method("show_with_animation"):
				label.show_with_animation()
			else:
				label.visible = true
			break

# ---------------- TIMER ----------------
func start_timer() -> void:
	print("🕐 Starting timer...")
	if timer_label:
		timer_label.text = "15s"
		timer_label.visible = true
		print("✅ Timer label set to: ", timer_label.text)
	else:
		print("❌ Timer label not found!")
		
	countdown = 15
	timer_active = true
	game_completed = false
	
	motivational_10s_played = false
	motivational_5s_played = false
	
	# Start the timer loop
	timer_loop()

func timer_loop():
	while timer_active and countdown > 0 and not game_completed:
		await get_tree().create_timer(1.0).timeout
		
		if not timer_active or game_completed:
			break
			
		countdown -= 1
		update_timer_display()
		
		
		if countdown == 10 and not motivational_10s_played:
			AudioManager.play_sound("motivational_10s")
			motivational_10s_played = true
			print("🎵 Playing 10-second motivational audio")
		
		if countdown == 5 and not motivational_5s_played:
			AudioManager.play_sound("motivational_5s")
			motivational_5s_played = true
			print("🎵 Playing 5-second motivational audio")

		
		# Check win condition each second
		check_win_condition()
	
	# Timer finished
	if timer_active and not game_completed:
		time_up()

func update_timer_display():
	if timer_label and countdown >= 0:
		timer_label.text = "" + str(countdown) + "s"
		print("Timer: ", countdown, "s")

func time_up():
	print("Time's up!")
	if timer_label:
		timer_label.text = "Times Up"
		timer_label.modulate = Color.RED
	if main_label:
		main_label.text = "Time's up!"
		main_label.modulate = Color.RED
	timer_active = false
	game_over()

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

# PRECISE GEOMETRIC COLLISION DETECTION - IGNORE BOUNDING BOXES COMPLETELY
func check_drop_target():
	var mouse_pos = get_global_mouse_position()
	
	# Get polygons from target node OR entire scene
	var polygons = []
	if target_node:
		polygons = get_all_polygons_in_node(target_node)
	else:
		polygons = get_tree().get_nodes_in_group("colorable_polygons")
	
	# Find the MOST PRECISE polygon hit - ignore bounding boxes
	var best_hit_polygon = null
	var smallest_area = INF
	
	for polygon in polygons:
		if polygon and polygon.has_method("can_accept_drop") and polygon.can_accept_drop():
			# Use ultra-precise detection that completely ignores bounding boxes
			if is_point_in_polygon_ultra_precise(mouse_pos, polygon):
				# Calculate polygon area to pick the smallest (most specific) one
				var area = calculate_polygon_area(polygon)
				if area < smallest_area:
					smallest_area = area
					best_hit_polygon = polygon
				print("🎯 HIT DETECTED: ", polygon.name, " (area: ", area, ")")
	
	# Apply color only to the most precise hit
	if best_hit_polygon:
		print("🏆 SELECTED: ", best_hit_polygon.name, " (smallest area)")
		var success = best_hit_polygon.apply_color(dragging_color, dragging_color_number)
		if success:
			call_deferred("check_win_condition")
		return
	
	print("❌ No precise polygon hit detected")

# Ultra-precise geometric collision detection function (ignores bounding boxes)
func is_point_in_polygon_ultra_precise(point: Vector2, polygon: Polygon2D) -> bool:
	# Convert global mouse position to polygon's local space
	var local_point = polygon.to_local(point)
	
	# Get the polygon's actual shape points
	var polygon_points = polygon.polygon
	
	# Early exit if no points
	if polygon_points.size() < 3:
		return false
	
	# Use the most precise ray-casting method
	var intersections = 0
	var n = polygon_points.size()
	
	# Cast a ray from the point to the right and count intersections
	for i in range(n):
		var p1 = polygon_points[i]
		var p2 = polygon_points[(i + 1) % n]
		
		# Check if ray intersects with edge
		if ((p1.y > local_point.y) != (p2.y > local_point.y)):
			var x_intersect = (p2.x - p1.x) * (local_point.y - p1.y) / (p2.y - p1.y) + p1.x
			if local_point.x < x_intersect:
				intersections += 1
	
	# Point is inside if odd number of intersections
	return (intersections % 2) == 1

# Calculate polygon area to determine which is most specific
func calculate_polygon_area(polygon: Polygon2D) -> float:
	var points = polygon.polygon
	if points.size() < 3:
		return 0.0
	
	var area = 0.0
	var n = points.size()
	
	# Use shoelace formula
	for i in range(n):
		var j = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	
	return abs(area) / 2.0

# Alternative ray-casting method for ultimate precision
func is_point_in_polygon_raycast(point: Vector2, polygon: Polygon2D) -> bool:
	var local_point = polygon.to_local(point)
	var polygon_points = polygon.polygon
	
	if polygon_points.size() < 3:
		return false
	
	var intersections = 0
	var n = polygon_points.size()
	
	# Cast a ray from the point to the right and count intersections
	for i in range(n):
		var p1 = polygon_points[i]
		var p2 = polygon_points[(i + 1) % n]
		
		# Check if ray intersects with edge
		if ((p1.y > local_point.y) != (p2.y > local_point.y)):
			var x_intersect = (p2.x - p1.x) * (local_point.y - p1.y) / (p2.y - p1.y) + p1.x
			if local_point.x < x_intersect:
				intersections += 1
	
	# Point is inside if odd number of intersections
	var result = (intersections % 2) == 1
	if result:
		print("🎯 RAYCAST HIT: ", polygon.name, " (", intersections, " intersections)")
	return result

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

# Keep the old method as backup
func is_point_in_polygon(point: Vector2, polygon: Polygon2D) -> bool:
	var local_point = polygon.to_local(point)
	return Geometry2D.is_point_in_polygon(local_point, polygon.polygon)

# ---------------- WIN CONDITION ----------------
func check_win_condition():
	if game_completed:
		return
	
	# Get polygons from target node OR entire scene if target node not found
	var polygons = []
	if target_node:
		polygons = get_all_polygons_in_node(target_node)
	else:
		# Fallback: get all polygons from entire scene
		polygons = get_tree().get_nodes_in_group("colorable_polygons")
		print("🔍 Using fallback: found ", polygons.size(), " polygons in entire scene")
	
	var total_polygons = polygons.size()
	var correctly_colored_polygons = 0
	
	if total_polygons == 0:
		print("❌ No polygons found!")
		return
	
	# Count CORRECTLY colored polygons
	for polygon in polygons:
		if polygon.has_method("is_correctly_colored") and polygon.is_correctly_colored():
			correctly_colored_polygons += 1
	
	print("✅ Correctly colored polygons: ", correctly_colored_polygons, "/", total_polygons)
	
	# WIN CONDITION: All polygons correctly colored
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

func show_temporary_message(message: String, color: Color, duration: float = 2.0):
	if main_label:
		var original_text = main_label.text
		var original_color = main_label.modulate
		
		main_label.text = message
		main_label.modulate = color
		
		await get_tree().create_timer(duration).timeout
		
		if not game_completed:  # Don't restore if game ended
			main_label.text = original_text
			main_label.modulate = original_color

# ---------------- RESTART ----------------
func restart_game():
	print("🔄 Restarting game...")
	game_completed = false
	timer_active = false
	countdown = 15
	
	motivational_10s_played = false
	motivational_5s_played = false
	
	if timer_label:
		timer_label.text = "15s"
		timer_label.modulate = Color.WHITE
		timer_label.visible = true
	if main_label:
		main_label.text = original_main_text
		main_label.modulate = Color.WHITE
		main_label.scale = Vector2.ONE
	
	# Reset all polygons in target node
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		for polygon in polygons:
			if polygon.has_method("reset_color"):
				polygon.reset_color()
	
	# Reset all number labels when restarting
	var labels = get_tree().get_nodes_in_group("number_labels")
	for label in labels:
		if label.has_method("show_with_animation"):
			label.show_with_animation()
		else:
			label.visible = true
	
	start_timer()

func _input(event):
	if event.is_action_pressed("ui_accept") and game_completed:
		restart_game()

# ---------------- DEBUG FUNCTIONS ----------------
func debug_status():
	print("\n=== DEBUG STATUS ===")
	print("Game completed: ", game_completed)
	print("Timer active: ", timer_active)
	print("Countdown: ", countdown)
	print("Target node exists: ", target_node != null)
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		print("Total polygons: ", polygons.size())
		for i in range(polygons.size()):
			var p = polygons[i]
			if p.has_method("debug_status"):
				p.debug_status()
	print("==================\n")

# DEBUGGING HELPER: Visualize polygon collision areas
func debug_draw_polygon_bounds():
	if not target_node:
		return
		
	print("\n=== POLYGON COLLISION DEBUG ===")
	var polygons = get_all_polygons_in_node(target_node)
	for polygon in polygons:
		# Draw the actual polygon points
		var points = polygon.polygon
		if points.size() >= 3:
			print("🔍 ", polygon.name, " has ", points.size(), " vertex points")
			
			# Calculate and show bounding box
			var min_x = points[0].x
			var max_x = points[0].x
			var min_y = points[0].y
			var max_y = points[0].y
			
			for point in points:
				min_x = min(min_x, point.x)
				max_x = max(max_x, point.x)
				min_y = min(min_y, point.y)
				max_y = max(max_y, point.y)
			
			var bounds = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
			print("   Bounding box: ", bounds)
			print("   Center: ", bounds.get_center())
		else:
			print("❌ ", polygon.name, " has invalid polygon shape (", points.size(), " points)")
		
		# Check if Area2D collision matches
		var area2d_children = polygon.get_children().filter(func(child): return child is Area2D)
		if area2d_children.size() > 0:
			var area2d = area2d_children[0]
			var collision_children = area2d.get_children().filter(func(child): return child is CollisionPolygon2D)
			if collision_children.size() > 0:
				var collision_polygon = collision_children[0]
				var collision_points = collision_polygon.polygon
				if collision_points.size() != points.size():
					print("⚠️  COLLISION MISMATCH: Visual=", points.size(), " vs Collision=", collision_points.size(), " points")
				else:
					print("✅ Area2D collision shape matches visual polygon")
					# Check if points are actually the same
					var points_match = true
					for i in range(min(points.size(), collision_points.size())):
						if points[i].distance_to(collision_points[i]) > 0.1:
							points_match = false
							break
					if not points_match:
						print("⚠️  Points don't match exactly - collision may be approximate")
			else:
				print("❌ Area2D found but no CollisionPolygon2D")
		else:
			print("ℹ️  No Area2D child - pure geometric detection will be used")
	print("===============================\n")

# Helper functions to find nodes
func find_node_by_name(node_name: String) -> Node:
	# Try direct child first
	if has_node(node_name):
		return get_node(node_name)
	
	# Search in scene tree
	var found = get_tree().get_first_node_in_group(node_name.to_lower())
	if found:
		return found
	
	# Recursive search
	return search_node_recursive(get_tree().current_scene, node_name)

func find_node_containing_name(partial_name: String) -> Node:
	return search_node_with_partial_name(get_tree().current_scene, partial_name.to_lower())

func find_node_with_polygons() -> Node2D:
	return search_for_polygon_container(get_tree().current_scene)

func search_for_polygon_container(node: Node) -> Node2D:
	# Check if this node has polygons
	if node is Node2D and get_all_polygons_in_node(node).size() > 0:
		return node
	
	# Check children
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
