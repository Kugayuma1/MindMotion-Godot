# PHRASE MATCHING GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 15  # seconds
var time_remaining := 15
var game_active := false
var matches_completed := 0
var total_required_matches := 3  # Rabbit, Eating, Carrot dropzones

# Node references
@onready var timer_display = $Time/Label
@onready var dropzone_container = $DropZone/Holder
@onready var draggable_container = $Draggables/Holder2
@onready var game_timer: Timer

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Tracking variables
var placed_items = {}  # tracks which items are in which zones
var original_positions = {}  # store original positions for reset
var dropzone_opacity := 0.15  # Lower opacity for empty dropzones
var dropzone_states = {}  # Track which dropzones are filled

# Drag variables
var dragging_item: Control = null
var drag_offset: Vector2

func _ready():
	reset_time_tracking()
	setup_game()
	initialize_draggables()
	initialize_dropzones()
	start_game()

func setup_game():
	# Create and configure game timer
	if not game_timer:
		game_timer = Timer.new()
		game_timer.wait_time = 1.0
		game_timer.timeout.connect(_on_timer_tick)
		add_child(game_timer)
	
	# Store original positions of draggable items (use local position)
	original_positions.clear()  # Clear first
	for item in draggable_container.get_children():
		if item is Control:
			original_positions[item.name] = item.position  # Use local position

func initialize_draggables():
	# Setup each draggable item
	for item in draggable_container.get_children():
		if item is Control:
			setup_draggable_item(item)

func setup_draggable_item(item: Control):
	# Disconnect if already connected to prevent duplicates
	if item.gui_input.is_connected(_on_draggable_input):
		item.gui_input.disconnect(_on_draggable_input)
	if item.mouse_entered.is_connected(_on_item_hover_start):
		item.mouse_entered.disconnect(_on_item_hover_start)
	if item.mouse_exited.is_connected(_on_item_hover_end):
		item.mouse_exited.disconnect(_on_item_hover_end)
	
	# Make item draggable
	item.gui_input.connect(_on_draggable_input.bind(item))
	
	# Add visual feedback properties
	item.mouse_entered.connect(_on_item_hover_start.bind(item))
	item.mouse_exited.connect(_on_item_hover_end.bind(item))
	
	# Ensure item can receive input
	item.mouse_filter = Control.MOUSE_FILTER_STOP

func initialize_dropzones():
	# Setup each drop zone with lower opacity
	for zone in dropzone_container.get_children():
		if zone is Control:
			setup_dropzone(zone)
			# Set initial lower opacity
			set_dropzone_opacity(zone, dropzone_opacity)
			dropzone_states[zone.name] = false  # Track as empty

func setup_dropzone(zone: Control):
	# Enable mouse detection for dropzones
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_dropzone_opacity(zone: Control, opacity: float):
	"""Set opacity for all children of the dropzone"""
	zone.modulate.a = opacity
	for child in zone.get_children():
		if child is Control or child is Node2D:
			child.modulate.a = opacity

func restore_dropzone_opacity(zone: Control):
	"""Restore full opacity when correct item is placed"""
	var tween = create_tween()
	tween.tween_property(zone, "modulate:a", 1.0, 0.3)
	for child in zone.get_children():
		if child is Control or child is Node2D:
			tween.parallel().tween_property(child, "modulate:a", 1.0, 0.3)

func shuffle_draggables():
	"""Randomize the positions of draggable items"""
	var draggables = draggable_container.get_children()
	var positions = []
	
	# Collect all current positions (use position relative to parent, not global)
	for item in draggables:
		if item is Control:
			positions.append(item.position)  # Use local position instead of global
	
	# Shuffle the positions array
	positions.shuffle()
	
	# Assign shuffled positions back to items
	for i in range(draggables.size()):
		if draggables[i] is Control:
			draggables[i].position = positions[i]  # Set local position
			# Update original positions so they can return here
			original_positions[draggables[i].name] = positions[i]
	
	print("Draggables shuffled to new positions")

func _on_draggable_input(event: InputEvent, item: Control):
	if not game_active:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(item, event.global_position)
			else:
				end_drag(item, event.global_position)

func _input(event: InputEvent):
	if dragging_item and event is InputEventMouseMotion:
		dragging_item.global_position = event.global_position - drag_offset

func start_drag(item: Control, mouse_pos: Vector2):
	dragging_item = item
	drag_offset = mouse_pos - item.global_position
	
	# Bring to front
	item.z_index = 100
	
	# Visual feedback - slight scale up while dragging
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Slightly brighten while dragging
	tween.parallel().tween_property(item, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func end_drag(item: Control, mouse_pos: Vector2):
	if dragging_item != item:
		return
		
	dragging_item = null
	item.z_index = 0
	
	# Reset scale and color
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2.ONE, 0.1)
	tween.parallel().tween_property(item, "modulate", Color.WHITE, 0.1)
	
	# Check if dropped on a valid dropzone
	check_drop_validity(item, mouse_pos)

func check_drop_validity(item: Control, drop_position: Vector2):
	var dropped_on_zone: Control = null
	
	# Find which dropzone (if any) the item was dropped on
	for zone in dropzone_container.get_children():
		if zone is Control and zone.get_global_rect().has_point(drop_position):
			dropped_on_zone = zone
			break
	
	if dropped_on_zone:
		handle_drop_attempt(item, dropped_on_zone)
	else:
		# Dropped outside any zone - return to original position
		return_to_original_position(item)

func handle_drop_attempt(item: Control, zone: Control):
	# Check if zone is already filled
	if dropzone_states.get(zone.name, false):
		shake_item(item)
		await get_tree().create_timer(0.3).timeout
		return_to_original_position(item)
		return
	
	var item_name = item.name.to_lower()
	var zone_name = zone.name.to_lower()
	
	# Check if this is a correct match
	if is_correct_match(item_name, zone_name):
		handle_correct_match(item, zone)
	else:
		handle_incorrect_match(item, zone)

func is_correct_match(item_name: String, zone_name: String) -> bool:
	# The correct answer based on the phrase: "The Rabbit is eating a Carrot"
	# Match specific pairs:
	# "Rabbit" draggable -> "RabbitDrop" dropzone
	# "Eating" draggable -> "EatingDrop" dropzone
	# "Carrot" draggable -> "CarrotDrop" dropzone
	
	# Clean up the names - remove spaces and convert to lowercase
	var clean_item = item_name.to_lower().replace(" ", "").strip_edges()
	var clean_zone = zone_name.to_lower().replace(" ", "").strip_edges()
	
	# Debug print to help troubleshoot
	print("Matching: Item='", clean_item, "' with Zone='", clean_zone, "'")
	
	# Check for matches with the Drop suffix
	if "rabbit" in clean_item and "rabbitdrop" in clean_zone:
		return true
	elif "eating" in clean_item and "eatingdrop" in clean_zone:
		return true
	elif "carrot" in clean_item and "carrotdrop" in clean_zone:
		return true
	
	return false

func handle_correct_match(item: Control, zone: Control):
	# Mark as placed
	placed_items[item.name] = zone.name
	dropzone_states[zone.name] = true
	matches_completed += 1
	
	# Restore dropzone opacity
	restore_dropzone_opacity(zone)
	
	# Visual feedback then hide item
	show_success_feedback(item)
	
	# Wait for success animation then hide the draggable
	await get_tree().create_timer(0.4).timeout
	
	# Fade out and hide the draggable item
	var tween = create_tween()
	tween.tween_property(item, "modulate:a", 0.0, 0.3)
	await tween.finished
	item.visible = false
	
	# Check win condition
	if matches_completed >= total_required_matches:
		await get_tree().create_timer(0.3).timeout  # Small delay before showing victory
		win_game()

func handle_incorrect_match(item: Control, zone: Control):
	# Shake animation
	shake_item(item)
	
	# Return to original position after shake
	await get_tree().create_timer(0.5).timeout
	return_to_original_position(item)

func snap_to_zone(item: Control, zone: Control):
	var zone_center = zone.global_position + zone.size / 2
	var item_center = item.size / 2
	
	var tween = create_tween()
	tween.tween_property(item, "global_position", zone_center - item_center, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "position", original_positions[item.name], 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func shake_item(item: Control):
	var original_pos = item.position  # Use local position
	var tween = create_tween()
	
	# Flash red during shake
	tween.parallel().tween_property(item, "modulate", Color.INDIAN_RED, 0.1)
	
	tween.tween_property(item, "position", original_pos + Vector2(-15, 0), 0.06)
	tween.tween_property(item, "position", original_pos + Vector2(15, 0), 0.06)
	tween.tween_property(item, "position", original_pos + Vector2(-10, 0), 0.06)
	tween.tween_property(item, "position", original_pos, 0.06)
	
	# Return to white color
	tween.parallel().tween_property(item, "modulate", Color.WHITE, 0.2)

func show_success_feedback(item: Control):
	# Green glow effect
	var tween = create_tween()
	tween.tween_property(item, "modulate", Color.LIME_GREEN, 0.15)
	tween.tween_property(item, "modulate", Color.WHITE, 0.25)
	
	# Small bounce effect
	var original_scale = item.scale
	tween.parallel().tween_property(item, "scale", original_scale * 1.15, 0.15)
	tween.tween_property(item, "scale", original_scale, 0.15)

func _on_item_hover_start(item: Control):
	if game_active and dragging_item == null:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color(1.15, 1.15, 1.15), 0.1)

func _on_item_hover_end(item: Control):
	if dragging_item != item:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color.WHITE, 0.1)

func reset_time_tracking() -> void:
	"""Reset the global start time for accurate time tracking"""
	Global.start_time = Time.get_ticks_msec()
	print("Time tracking reset at: ", Global.start_time)

func stop_timer() -> void:
	"""Stop the countdown timer"""
	game_active = false
	if game_timer:
		game_timer.stop()

func start_game():
	game_active = true
	time_remaining = game_duration
	matches_completed = 0
	
	shuffle_draggables()
	
	update_timer_display()
	if game_timer:
		game_timer.start()

func _on_timer_tick():
	if not game_active:
		return
		
	time_remaining -= 1
	update_timer_display()
	
	if time_remaining <= 0:
		game_over()
	elif time_remaining <= 5:
		# Warning colors for last 5 seconds
		timer_display.modulate = Color.ORANGE_RED
		# Pulse effect
		var tween = create_tween().set_loops()
		tween.tween_property(timer_display, "scale", Vector2(1.1, 1.1), 0.5)
		tween.tween_property(timer_display, "scale", Vector2.ONE, 0.5)
	elif time_remaining <= 10:
		timer_display.modulate = Color.ORANGE

func update_timer_display():
	if timer_display:
		timer_display.text = " " + str(time_remaining) + "s"

func win_game():
	stop_timer()
	
	# Save progress
	ProgressManager.save_progress("reading", true)
	Global.refresh_everything_after_stage_completion("reading", true)
	
	# Calculate star rating based on time remaining
	var star_rating = calculate_star_rating()
	show_completion_screen(true, star_rating)

func game_over():
	stop_timer()
	
	# Save failed attempt
	ProgressManager.save_progress("reading", false)
	Global.refresh_everything_after_stage_completion("reading", false)
	
	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	if time_remaining >= 10:  # 10+ seconds remaining = 3 stars
		return 3
	elif time_remaining >= 5:  # 5+ seconds remaining = 2 stars
		return 2
	else:
		return 1  # Less than 5 seconds = 1 star

func show_completion_screen(success: bool, stars: int):
	# Hide game elements
	if has_node("DropZone"): $DropZone.visible = false
	if has_node("Draggables"): $Draggables.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Contents"): $Contents.visible = false
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
	print("\n=== RESTARTING PHRASE MATCHING GAME ===")
	
	# Stop the old timer
	stop_timer()
	
	# Reset time tracking
	reset_time_tracking()
	
	# Reset all variables
	matches_completed = 0
	placed_items.clear()
	dragging_item = null
	
	# Reset dropzone states and opacity
	for zone in dropzone_container.get_children():
		if zone is Control:
			dropzone_states[zone.name] = false
			set_dropzone_opacity(zone, dropzone_opacity)
	
	# First, store the ORIGINAL positions before any modifications
	var initial_positions = {}
	for item in draggable_container.get_children():
		if item is Control:
			# Get the position from the editor (before shuffle)
			if item.name not in original_positions:
				initial_positions[item.name] = item.position
			else:
				initial_positions[item.name] = original_positions[item.name]
	
	# Reset item positions and properties to their initial state
	for item in draggable_container.get_children():
		if item is Control:
			item.visible = true
			item.modulate = Color.WHITE
			item.modulate.a = 1.0  # Reset alpha
			item.scale = Vector2.ONE
			item.z_index = 0
			
			# Reset to initial position
			if item.name in initial_positions:
				item.position = initial_positions[item.name]
	
	# Update original_positions with current positions before shuffle
	original_positions.clear()
	for item in draggable_container.get_children():
		if item is Control:
			original_positions[item.name] = item.position
	
	# Reinitialize draggables to reconnect signals
	initialize_draggables()
	
	# Reset UI
	if has_node("DropZone"): $DropZone.visible = true
	if has_node("Draggables"): $Draggables.visible = true  
	if has_node("Time"): $Time.visible = true
	if has_node("Contents"): $Contents.visible = true
	if has_node("Quitbtn"): $Quitbtn.visible = true
	
	if timer_display:
		timer_display.modulate = Color.WHITE
		timer_display.scale = Vector2.ONE
	
	# Start new game (this will shuffle)
	start_game()
	
	print("=== GAME RESTARTED ===\n")

func _on_quitbtn_pressed() -> void:
	stop_timer()  # Stop timer when quitting
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
