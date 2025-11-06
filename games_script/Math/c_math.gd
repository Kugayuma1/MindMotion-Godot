# CHICKEN COUNTING GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var chickens_given := 0
var required_chickens := 3
var max_allowed_chickens := 5  # Allow giving more than needed to test attention

# Node references
@onready var timer_display = $Time/Label
@onready var farmer_zone = $Dropzone/Farmer
@onready var farmer_label = $Dropzone/Farmer/Label2  # Farmer's speech bubble
@onready var draggable_items = $Draggable
@onready var game_timer: Timer

# Popup scenes - you'll need to create these
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var motivational_5s_played = false
var motivational_10s_played = false
# Tracking variables
var chickens_with_farmer = []  # Array of chickens currently with farmer
var original_positions = {}  # Store original positions for reset
var chicken_nodes = []  # All chicken nodes

# Farmer messages
var farmer_messages = {
	"welcome": "Give me exactly 3 chickens, please!",
	"correct_count": "Perfect! Thank you for the 3 chickens!",
	"too_many": "Whoa! I only need 3 chickens, not more!",
	"need_more": "I still need more chickens... %d more to go!",
	"game_over": "Time's up! Try again!"
}

func _ready():
	# Don't reset time tracking here - wait until game actually starts
	setup_game()
	initialize_chickens()
	initialize_farmer_zone()
	start_game()
	motivational_5s_played = false
	motivational_10s_played = false

func reset_time_tracking() -> void:
	"""Reset the global start time for accurate time tracking"""
	Global.start_time = Time.get_ticks_msec()
	print("Time tracking reset at: ", Global.start_time)

func stop_timer() -> void:
	"""Stop the countdown timer"""
	game_active = false
	if game_timer:
		game_timer.stop()

func setup_game():
	# Remove old timer if it exists (prevents duplicate timers on restart)
	if game_timer:
		game_timer.stop()
		game_timer.queue_free()
		game_timer = null
	
	# Create and configure game timer
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)
	
	# Get all chicken nodes and store original positions
	chicken_nodes.clear()  # Clear first to prevent duplicates
	for item in draggable_items.get_children():
		if item.name.to_lower().begins_with("chicken"):
			chicken_nodes.append(item)
			original_positions[item.name] = item.global_position
	
	# Set initial farmer message
	update_farmer_message("welcome")

func initialize_chickens():
	# Setup each chicken as draggable
	for chicken in chicken_nodes:
		setup_draggable_chicken(chicken)

func setup_draggable_chicken(chicken: Control):
	# Make chicken draggable
	chicken.gui_input.connect(_on_chicken_input.bind(chicken))
	
	# Add visual feedback
	chicken.mouse_entered.connect(_on_chicken_hover_start.bind(chicken))
	chicken.mouse_exited.connect(_on_chicken_hover_end.bind(chicken))

func initialize_farmer_zone():
	# Setup farmer drop zone
	if farmer_zone:
		farmer_zone.gui_input.connect(_on_farmer_zone_input)

var dragging_chicken: Control = null
var drag_offset: Vector2

func _on_chicken_input(event: InputEvent, chicken: Control):
	if not game_active:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(chicken, event.global_position)
			else:
				end_drag(chicken, event.global_position)
	
	elif event is InputEventMouseMotion and dragging_chicken == chicken:
		chicken.global_position = event.global_position - drag_offset

func start_drag(chicken: Control, mouse_pos: Vector2):
	dragging_chicken = chicken
	drag_offset = mouse_pos - chicken.global_position
	
	# Bring to front
	chicken.z_index = 100
	
	# Visual feedback - slight scale up while dragging
	var tween = create_tween()
	tween.tween_property(chicken, "scale", Vector2(1.1, 1.1), 0.1)

func end_drag(chicken: Control, mouse_pos: Vector2):
	if dragging_chicken != chicken:
		return
		
	dragging_chicken = null
	chicken.z_index = 0
	
	# Reset scale
	var tween = create_tween()
	tween.tween_property(chicken, "scale", Vector2.ONE, 0.1)
	
	# Check if dropped on farmer
	check_drop_on_farmer(chicken, mouse_pos)

func check_drop_on_farmer(chicken: Control, drop_position: Vector2):
	var dropped_on_farmer = false
	
	# Check if dropped on farmer zone
	if farmer_zone and farmer_zone.get_global_rect().has_point(drop_position):
		dropped_on_farmer = true
	
	if dropped_on_farmer:
		handle_chicken_drop_on_farmer(chicken)
	else:
		# Check if chicken was previously with farmer and now dropped elsewhere
		if chicken in chickens_with_farmer:
			return_chicken_from_farmer(chicken)
		else:
			# Just return to original position if not with farmer
			return_to_original_position(chicken)

func return_chicken_from_farmer(chicken: Control):
	# Remove chicken from farmer's collection
	if chicken in chickens_with_farmer:
		chickens_with_farmer.erase(chicken)
		chickens_given -= 1
	
	# Make chicken visible again and enable interaction
	chicken.visible = true
	chicken.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Return to original position
	return_to_original_position(chicken)
	
	# Update farmer message
	if chickens_given < required_chickens:
		var remaining = required_chickens - chickens_given
		update_farmer_message("need_more", [remaining])

func position_chicken_with_farmer(chicken: Control):
	# Make chicken disappear (farmer "takes" the chicken)
	chicken.visible = false
	
	# Disable further interaction
	chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE

func evaluate_chicken_count():
	if chickens_given > required_chickens:
		# Too many chickens! Return all and scold
		update_farmer_message("too_many")
		# Wait a moment then return all chickens
		await get_tree().create_timer(2.0).timeout
		return_all_chickens()
		update_farmer_message("welcome")
	elif chickens_given == required_chickens:
		# Perfect! Player gave exactly 3 chickens - WIN IMMEDIATELY!
		update_farmer_message("correct_count")
		# Small delay for visual feedback then win
		await get_tree().create_timer(0.5).timeout
		win_game()
	else:
		# Still need more chickens
		var remaining = required_chickens - chickens_given
		update_farmer_message("need_more", [remaining])

func return_all_chickens():
	# Return all chickens to their original positions
	for chicken in chickens_with_farmer.duplicate():  # Use duplicate to avoid modifying array while iterating
		return_chicken_from_farmer(chicken)
	
	# Clear the array and reset count
	chickens_with_farmer.clear()
	chickens_given = 0

func handle_chicken_drop_on_farmer(chicken: Control):
	# If chicken is already with farmer, ignore
	if chicken in chickens_with_farmer:
		return
	
	# Add chicken to farmer
	chickens_with_farmer.append(chicken)
	chickens_given += 1
	
	# Make chicken disappear
	position_chicken_with_farmer(chicken)
	
	# Check the count and respond accordingly
	evaluate_chicken_count()

func return_to_original_position(chicken: Control):
	if chicken.name in original_positions:
		var tween = create_tween()
		tween.tween_property(chicken, "global_position", original_positions[chicken.name], 0.5)

func update_farmer_message(message_key: String, args: Array = []):
	if farmer_label:
		var message = farmer_messages[message_key]
		if args.size() > 0:
			message = message % args
		farmer_label.text = message

func _on_chicken_hover_start(chicken: Control):
	if game_active and dragging_chicken == null:
		var tween = create_tween()
		tween.tween_property(chicken, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_chicken_hover_end(chicken: Control):
	if dragging_chicken != chicken:
		var tween = create_tween()
		tween.tween_property(chicken, "modulate", Color.WHITE, 0.1)

func _on_farmer_zone_input(event: InputEvent):
	# Handle any specific farmer zone interactions if needed
	pass

func start_game():
	# Reset time tracking RIGHT HERE when game actually starts
	reset_time_tracking()
	
	game_active = true
	time_remaining = game_duration
	chickens_given = 0
	chickens_with_farmer.clear()
	
	update_timer_display()
	game_timer.start()
	update_farmer_message("welcome")
	
	print("Game started! Timer begins NOW at: ", Global.start_time)

func _on_timer_tick():
	if not game_active:  # ← ADD THIS CHECK
		return
		
	time_remaining -= 1

	var elapsed_time = game_duration - time_remaining
	# Play motivational sounds at specific marks
	if elapsed_time == 5 and !motivational_5s_played:
		AudioManager.play_sound("motivational_5s")
		motivational_5s_played = true
		print("Playing 5-second motivational audio")
	elif elapsed_time == 10 and !motivational_10s_played:
		AudioManager.play_sound("motivational_10s")
		motivational_10s_played = true
		print("Playing 10-second motivational audio")
	update_timer_display()
	
	if time_remaining <= 0:
		game_over()
	elif time_remaining <= 10:
		# Warning colors for last 10 seconds
		timer_display.modulate = Color.RED


func update_timer_display():
	if timer_display:
		timer_display.text = " " + str(time_remaining) + "s"

func win_game():
	# Stop timer FIRST before any async operations
	stop_timer()
	game_active = false
	
	# Calculate star rating based on time remaining and attempts
	var star_rating = calculate_star_rating()
	
	# Save progress
	print("🎉 Game completed successfully!")
	ProgressManager.save_progress("math", true)
	Global.refresh_everything_after_stage_completion("math", true)
	
	show_completion_screen(true, star_rating)

func game_over():
	# Stop timer FIRST before any async operations
	stop_timer()
	game_active = false
	
	update_farmer_message("game_over")
	
	# Save failed attempt
	print("⏰ Game over - Time's up!")
	ProgressManager.save_progress("math", false)
	Global.refresh_everything_after_stage_completion("math", false)
	
	await get_tree().create_timer(1.0).timeout
	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	var time_percentage = float(time_remaining) / float(game_duration)
	
	if time_remaining >= 10:  # 20+ seconds remaining = 3 stars
		return 3
	elif time_remaining >= 5:  # 10+ seconds remaining = 2 stars
		return 2
	else:
		return 1  # Less than 10 seconds = 1 star

func show_completion_screen(success: bool, stars: int):
	# Hide game elements
	if has_node("Dropzone"): $Dropzone.visible = false
	if has_node("Draggable"): $Draggable.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Holder"): $Holder.visible = false
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
	print("\n=== RESTARTING CHICKEN COUNTING GAME ===")
	
	# Stop and remove old timer completely
	if game_timer:
		game_timer.stop()
		game_timer.queue_free()
		game_timer = null
	
	# Don't reset time tracking here - wait until start_game() is called
	
	# Reset all variables
	game_active = false
	chickens_given = 0
	chickens_with_farmer.clear()
	
	# Reset chicken positions and properties
	for chicken in chicken_nodes:
		if chicken.name in original_positions:
			chicken.global_position = original_positions[chicken.name]
			chicken.modulate = Color.WHITE
			chicken.scale = Vector2.ONE
			chicken.z_index = 0
			chicken.visible = true
			chicken.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Reset UI visibility
	if has_node("Dropzone"): $Dropzone.visible = true
	if has_node("Draggable"): $Draggable.visible = true  
	if has_node("Time"): $Time.visible = true
	if has_node("Holder"): $Holder.visible = true
	if has_node("Quitbtn"): $Quitbtn.visible = true
	
	if timer_display:
		timer_display.modulate = Color.WHITE
	
	# Recreate timer
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)
	
	motivational_5s_played = false
	motivational_10s_played = false
	
	# Start new game (this will reset time tracking)
	start_game()
	
	print("=== GAME RESTARTED ===\n")

func _on_quitbtn_pressed() -> void:
	stop_timer()  # ← ADD THIS to stop timer when quitting
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
