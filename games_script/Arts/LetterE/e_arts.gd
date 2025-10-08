# E_Arts Control Script with Popup System
extends Control

# ---------------- DRAG & DROP ----------------
var dragging_color: Color 
var dragging_color_number: int
var is_dragging = false
var drag_source: TextureButton
var drag_preview: Control

# ---------------- TIMER ----------------
var countdown := 15
var timer_active := false
@onready var timer_label = $TimerLabel   # Label under this Control
@onready var main_label = $label_main    # Game status label
@onready var target_node = $Node2D2      # Direct reference to Node2D2
var original_main_text: String

# ---------------- GAME STATE ----------------
var game_completed := false

# ---------------- POPUP SCENES ----------------
# Preload popup star scenes (adjust the paths as needed!)
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")
var popup_instance: Control = null

# ---------------- BACKGROUND CONTROL ----------------
# Reference to main game elements that should be hidden during popup
@onready var game_elements = []  # We'll populate this in _ready()
@export var preserve_background_elements: Array[String] = []  # Manually specify background elements to keep
@export var auto_detect_backgrounds: bool = true  # Automatically detect backgrounds

func _ready():
	if main_label:
		original_main_text = main_label.text
	
	# Collect all main game elements to hide during popup
	collect_game_elements()
	
	# Connect all color buttons
	var color_buttons = get_tree().get_nodes_in_group("color_buttons")
	for button in color_buttons:
		button.button_down.connect(_on_color_button_pressed.bind(button))
		button.button_up.connect(_on_color_button_released)
	
	# Start game
	start_timer()
	Global.start_time = Time.get_ticks_msec()
	
	# Debug info
	print("E_Arts Game Manager Ready!")
	print("Target Node (Node2D2): ", target_node)
	if target_node:
		print("Found ", get_polygon_count(), " polygons in Node2D2")

# ---------------- COLLECT GAME ELEMENTS ----------------
func collect_game_elements():
	# Collect all direct children of this Control node that should be hidden during popup
	for child in get_children():
		# Skip popup instances and background elements
		var skip_child = false
		
		# Skip popups
		if child.name.contains("Complete") or child.name.contains("Retry"):
			skip_child = true
		
		# Check manually specified background elements to preserve
		for bg_element_name in preserve_background_elements:
			if child.name == bg_element_name:
				skip_child = true
				print("Keeping manually specified background element: ", child.name)
				break
		
		# Auto-detect backgrounds if enabled
		if not skip_child and auto_detect_backgrounds:
			# Skip background elements (retain them during popup)
			var background_names = ["background", "Background", "BG", "bg", "BackgroundImage", "BackgroundTexture", "Backdrop"]
			for bg_name in background_names:
				if child.name.to_lower().contains(bg_name.to_lower()):
					skip_child = true
					print("Auto-detected background element: ", child.name)
					break
			
			# Skip TextureRect that might be background (check position and size)
			if not skip_child and child is TextureRect:
				var texture_rect = child as TextureRect
				# If it's positioned near origin and large, likely a background
				if texture_rect.position.distance_to(Vector2.ZERO) < 100 and texture_rect.size.x > 400:
					skip_child = true
					print("Auto-detected background TextureRect: ", child.name)
			
			# Skip ColorRect that might be background
			if not skip_child and child is ColorRect:
				var color_rect = child as ColorRect
				# If it's large and positioned near origin, likely a background
				if color_rect.position.distance_to(Vector2.ZERO) < 100 and color_rect.size.x > 400:
					skip_child = true
					print("Auto-detected background ColorRect: ", child.name)
		
		if not skip_child:
			game_elements.append(child)
	
	# Add specific UI elements if they exist (but not backgrounds)
	var ui_elements = ["TextureRect2", "TextureRect3", "TextureRect4", "Quitbtn"]
	for element_name in ui_elements:
		if has_node(element_name):
			var element = get_node(element_name)
			# Don't add if it's in preserve list
			if element not in game_elements and element.name not in preserve_background_elements:
				game_elements.append(element)
	
	print("Collected ", game_elements.size(), " game elements to hide during popup")

func start_timer() -> void:
	if timer_label:
		timer_label.text = "⏱️ 15s"
	countdown = 15
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
		# Save progress as failed and show retry popup
		ProgressManager.save_progress("art", false)
		Global.refresh_everything_after_stage_completion("art", false)
		game_over(false)  # Show retry popup when time runs out
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
		# Clean up canvas layer if it exists
		var canvas_layer = drag_preview.get_meta("canvas_layer", null)
		if canvas_layer:
			canvas_layer.queue_free()
		else:
			drag_preview.queue_free()
		drag_preview = null

func check_drop_target():
	var mouse_pos = get_global_mouse_position()
	
	# Only check polygons in Node2D2
	if not target_node:
		return
		
	var polygons = get_all_polygons_in_node(target_node)
	
	# Find the topmost polygon at mouse position
	var topmost_polygon = null
	var highest_z = -999999
	var latest_index = -1
	
	for polygon in polygons:
		if polygon and polygon.has_method("can_accept_drop") and polygon.can_accept_drop():
			if is_point_in_polygon(mouse_pos, polygon):
				# Check if this polygon is "higher" than current topmost
				var should_select = false
				
				if polygon.z_index > highest_z:
					should_select = true
				elif polygon.z_index == highest_z:
					# Same z-index, use node order (later = on top)
					if polygon.get_index() > latest_index:
						should_select = true
				
				if should_select:
					topmost_polygon = polygon
					highest_z = polygon.z_index
					latest_index = polygon.get_index()
	
	# Apply color to the topmost polygon only
	if topmost_polygon:
		var result = topmost_polygon.apply_color(dragging_color, dragging_color_number)
		if result:
			call_deferred("check_win_condition")

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
	
	# Add to a CanvasLayer for top rendering
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer number = renders on top
	get_tree().current_scene.add_child(canvas_layer)
	canvas_layer.add_child(drag_preview)
	
	# Store reference to canvas layer for cleanup
	drag_preview.set_meta("canvas_layer", canvas_layer)

func is_point_in_polygon(point: Vector2, polygon: Polygon2D) -> bool:
	var local_point = polygon.to_local(point)
	return Geometry2D.is_point_in_polygon(local_point, polygon.polygon)

# ---------------- WIN CONDITION ----------------
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
	print("🎉 E_ARTS GAME WON! 🎉")
	game_completed = true
	timer_active = false
	
	var completion_time = 15 - countdown
	
	if main_label:
		main_label.text = "✅ Done!"
		main_label.modulate = Color.GREEN
	
	if timer_label:
		timer_label.text = "✅ Done in " + str(completion_time) + "s"
	
	# Save progress as successful
	ProgressManager.save_progress("art", true)
	Global.refresh_everything_after_stage_completion("art", true)
	# Show appropriate popup based on completion time
	game_over(true)

# ---------------- POPUP SYSTEM ----------------
func game_over(success: bool):
	print("E_Arts game over called with success: ", success)
	
	# Hide all game elements
	hide_game_elements()
	
	# Choose appropriate popup scene based on success and performance
	if success:
		# Determine star rating based on remaining time
		if countdown >= 10:  # Completed with 10+ seconds remaining
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:  # Completed with 5+ seconds remaining
			popup_instance = complete2_scene.instantiate()
		else:  # Completed with less than 5 seconds remaining
			popup_instance = complete1_scene.instantiate()
	else:
		# Failed (time ran out)
		popup_instance = retry_scene.instantiate()
	
	# Add popup to the scene tree - add directly to this Control node
	if popup_instance:
		add_child(popup_instance)
		# Make sure popup is on top
		move_child(popup_instance, -1)
		print("E_Arts popup instantiated and added to scene")

func hide_game_elements():
	# Hide all collected game elements
	for element in game_elements:
		if element and is_instance_valid(element):
			element.visible = false
	print("Hidden ", game_elements.size(), " game elements")

func show_game_elements():
	# Show all collected game elements (for restart)
	for element in game_elements:
		if element and is_instance_valid(element):
			element.visible = true
	print("Shown ", game_elements.size(), " game elements")

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

# ---------------- RESTART FUNCTIONALITY ----------------
func restart_game():
	game_completed = false
	timer_active = false
	countdown = 15
	
	# Remove existing popup
	if popup_instance and is_instance_valid(popup_instance):
		popup_instance.queue_free()
		popup_instance = null
	
	# Show game elements again
	show_game_elements()
	
	# Reset UI elements
	if timer_label:
		timer_label.text = "⏱️ 15s"
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

# ---------------- VISUAL EFFECTS ----------------
func show_celebration_effects():
	if main_label:
		var tween = create_tween()
		tween.set_loops(3)
		tween.tween_property(main_label, "scale", Vector2(1.2, 1.2), 0.3)
		tween.tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.3)

# ---------------- DEBUG FUNCTIONS ----------------
func debug_status():
	print("\n=== E_ARTS DEBUG STATUS ===")
	print("Game completed: ", game_completed)
	print("Timer active: ", timer_active)
	print("Target node exists: ", target_node != null)
	print("Game elements count: ", game_elements.size())
	if target_node:
		var polygons = get_all_polygons_in_node(target_node)
		print("Total polygons: ", polygons.size())
		for i in range(polygons.size()):
			var p = polygons[i]
			print("  Polygon ", i+1, " is_colored: ", p.get("is_colored") if p.has_method("get") else "UNKNOWN")
	print("===========================\n")

# Call this from console or add to _ready() for testing
func force_win_check():
	print("🔍 FORCING E_ARTS WIN CHECK...")
	check_win_condition()

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
