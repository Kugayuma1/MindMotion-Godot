# PHRASE MATCHING GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 15  # seconds
var time_remaining := 15
var game_active := false
var matches_completed := 0
var total_required_matches := 3  # based on your yellow holders

# Node references
@onready var timer_display = $Time/Label
@onready var dropzones = $DropZone
@onready var draggable_items = $Draggable
@onready var game_timer: Timer

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# The dropzones will tell us what items they expect based on their names
# For example: "Eatingdropzone" expects an item with "eating" in its name

# Tracking variables
var placed_items = {}  # tracks which items are in which zones
var original_positions = {}  # store original positions for reset

func _ready():
	setup_game()
	initialize_draggables()
	initialize_dropzones()
	start_game()

func setup_game():
	# Create and configure game timer
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)
	
	# Store original positions of draggable items
	for item in draggable_items.get_children():
		if item is Control:
			original_positions[item.name] = item.global_position

func initialize_draggables():
	# Setup each draggable item
	for item in draggable_items.get_children():
		if item is Control:
			setup_draggable_item(item)

func setup_draggable_item(item: Control):
	# Make item draggable
	item.gui_input.connect(_on_draggable_input.bind(item))
	
	# Add visual feedback properties
	item.mouse_entered.connect(_on_item_hover_start.bind(item))
	item.mouse_exited.connect(_on_item_hover_end.bind(item))

func initialize_dropzones():
	# Setup each drop zone
	for zone in dropzones.get_children():
		if zone is Control:
			setup_dropzone(zone)

func setup_dropzone(zone: Control):
	# Enable drop detection
	zone.gui_input.connect(_on_dropzone_input.bind(zone))

var dragging_item: Control = null
var drag_offset: Vector2

func _on_draggable_input(event: InputEvent, item: Control):
	if not game_active:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(item, event.global_position)
			else:
				end_drag(item, event.global_position)
	
	elif event is InputEventMouseMotion and dragging_item == item:
		item.global_position = event.global_position - drag_offset

func start_drag(item: Control, mouse_pos: Vector2):
	dragging_item = item
	drag_offset = mouse_pos - item.global_position
	
	# Bring to front
	item.z_index = 100
	
	# Visual feedback - slight scale up while dragging
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.05, 1.05), 0.1)

func end_drag(item: Control, mouse_pos: Vector2):
	if dragging_item != item:
		return
		
	dragging_item = null
	item.z_index = 0
	
	# Reset scale
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2.ONE, 0.1)
	
	# Check if dropped on a valid dropzone
	check_drop_validity(item, mouse_pos)

func check_drop_validity(item: Control, drop_position: Vector2):
	var dropped_on_zone: Control = null
	
	# Find which dropzone (if any) the item was dropped on
	for zone in dropzones.get_children():
		if zone is Control and zone.get_global_rect().has_point(drop_position):
			dropped_on_zone = zone
			break
	
	if dropped_on_zone:
		handle_drop_attempt(item, dropped_on_zone)
	else:
		# Dropped outside any zone - return to original position
		return_to_original_position(item)

func handle_drop_attempt(item: Control, zone: Control):
	var item_name = item.name.to_lower()
	var zone_name = zone.name.to_lower()
	
	# Check if this is a correct match
	if is_correct_match(item_name, zone_name):
		handle_correct_match(item, zone)
	else:
		handle_incorrect_match(item, zone)

func is_correct_match(item_name: String, zone_name: String) -> bool:
	# Extract the expected item from dropzone name
	# For example: "Eatingdropzone" -> "eating", "Rabbitdropzone" -> "rabbit"
	var expected_item = zone_name.replace("dropzone", "").to_lower()
	var dragged_item = item_name.to_lower()
	
	# Check if the dragged item matches what the dropzone expects
	return dragged_item == expected_item or expected_item in dragged_item or dragged_item in expected_item

func handle_correct_match(item: Control, zone: Control):
	# Snap item to zone center
	snap_to_zone(item, zone)
	
	# Mark as placed
	placed_items[item.name] = zone.name
	matches_completed += 1
	
	# Disable further dragging for this item
	item.gui_input.disconnect(_on_draggable_input)
	
	# Visual feedback
	show_success_feedback(item)
	
	# Check win condition
	if matches_completed >= total_required_matches:
		win_game()

func handle_incorrect_match(item: Control, zone: Control):
	# Shake animation
	shake_item(item)
	
	# Return to original position after shake
	await get_tree().create_timer(0.5).timeout
	return_to_original_position(item)

func snap_to_zone(item: Control, zone: Control):
	var zone_center = zone.global_position + zone.size / 2
	var item_center_offset = item.size / 2
	
	# Calculate scale to fit the dropzone (with some padding)
	var zone_size = zone.size * 0.8  # 80% of zone size for padding
	var item_size = item.size
	var scale_factor = min(zone_size.x / item_size.x, zone_size.y / item_size.y)
	scale_factor = min(scale_factor, 1.0)  # Don't scale up, only down
	
	var tween = create_tween()
	tween.parallel().tween_property(item, "global_position", zone_center - (item.size * scale_factor) / 2, 0.3)
	tween.parallel().tween_property(item, "scale", Vector2(scale_factor, scale_factor), 0.3)

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "global_position", original_positions[item.name], 0.5)

func shake_item(item: Control):
	var original_pos = item.global_position
	var tween = create_tween()
	
	tween.tween_property(item, "global_position", original_pos + Vector2(-15, 0), 0.08)
	tween.tween_property(item, "global_position", original_pos + Vector2(15, 0), 0.08)
	tween.tween_property(item, "global_position", original_pos + Vector2(-10, 0), 0.08)
	tween.tween_property(item, "global_position", original_pos, 0.08)

func show_success_feedback(item: Control):
	# Green glow effect
	var tween = create_tween()
	tween.tween_property(item, "modulate", Color.GREEN, 0.2)
	tween.tween_property(item, "modulate", Color.WHITE, 0.3)

func _on_item_hover_start(item: Control):
	if game_active and dragging_item == null:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_item_hover_end(item: Control):
	if dragging_item != item:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color.WHITE, 0.1)

func _on_dropzone_input(event: InputEvent, zone: Control):
	# Handle any specific dropzone interactions if needed
	pass

func start_game():
	game_active = true
	time_remaining = game_duration
	matches_completed = 0
	
	update_timer_display()
	game_timer.start()

func _on_timer_tick():
	time_remaining -= 1
	update_timer_display()
	
	if time_remaining <= 0:
		game_over()
	elif time_remaining <= 10:
		# Warning colors for last 10 seconds
		timer_display.modulate = Color.RED

func update_timer_display():
	if timer_display:
		timer_display.text = "⏱️ " + str(time_remaining) + "s"

func update_instruction(text: String):
	# Removed - you'll handle instructions separately
	pass

func win_game():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("reading", true)
	Global.refresh_everything_after_stage_completion("reading", true)
	# Calculate star rating based on time remaining
	var star_rating = calculate_star_rating()
	show_completion_screen(true, star_rating)

func game_over():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("reading", false)
	Global.refresh_everything_after_stage_completion("reading", false)
	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	var time_percentage = float(time_remaining) / float(game_duration)
	
	if time_remaining >= 10:  # 10+ seconds remaining = 3 stars
		return 3
	elif time_remaining >= 5:  # 5+ seconds remaining = 2 stars
		return 2
	else:
		return 1  # Less than 5 seconds = 1 star

func show_completion_screen(success: bool, stars: int):
	# Hide game elements
	if has_node("DropZone"): $DropZone.visible = false
	if has_node("Draggable"): $Draggable.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("TextureRect"): $TextureRect.visible = false
	if has_node("TextureRect5"): $TextureRect5.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	var popup_instance: Node = null
	
	# Load appropriate popup based on success and stars
	if success:
		if stars == 3:
			popup_instance = complete3_scene.instantiate()
		elif stars == 2:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()
	
	if popup_instance:
		add_child(popup_instance)
	
	print("Game completed - Success: ", success, ", Stars: ", stars)

func restart_game():
	# Reset all variables
	game_active = false
	matches_completed = 0
	placed_items.clear()
	
	# Reset item positions
	for item in draggable_items.get_children():
		if item is Control and item.name in original_positions:
			item.global_position = original_positions[item.name]
			item.modulate = Color.WHITE
			item.scale = Vector2.ONE
			
			# Reconnect input if disconnected
			if not item.gui_input.is_connected(_on_draggable_input):
				item.gui_input.connect(_on_draggable_input.bind(item))
	
	# Reset UI
	if has_node("DropZone"): $DropZone.visible = true
	if has_node("Draggable"): $Draggable.visible = true  
	if has_node("Time"): $Time.visible = true
	if has_node("TextureRect"): $TextureRect.visible = true
	if has_node("TextureRect5"): $TextureRect5.visible = true
	
	if timer_display:
		timer_display.modulate = Color.WHITE
	
	# Start new game
	start_game()


func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
