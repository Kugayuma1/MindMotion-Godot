# DONUT MATCHING GAME CONTROLLER WITH RANDOMIZED ASSIGNMENTS
extends Control

# Game settings
var game_duration := 15
var time_remaining := 15
var game_active := false
var matches_completed := 0
var total_kids := 4

# Node references
@onready var timer_display = $Time/Label
@onready var draggables = $ColorRect/GameBG/Draggables
@onready var dropzone = $DropZone

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Tracking variables
var donut_nodes = []
var kid_nodes = []
var original_positions = {}
var kid_donut_mapping = {}  # Maps kid to their required donut type (randomized)
var completed_kids = []

# Game timer
var game_timer: Timer

# Drag and drop variables
var dragging_donut: Control = null
var drag_offset: Vector2

func _ready():
	setup_game()
	initialize_donuts()
	initialize_kids()
	start_game()

func setup_game():
	# Create and configure game timer
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)
	
	# Get all donut nodes and store original positions
	for donut in draggables.get_children():
		if donut.name.to_lower().begins_with("donut"):
			donut_nodes.append(donut)
			original_positions[donut.name] = donut.global_position
	
	# Get all kid nodes
	for kid in dropzone.get_children():
		if kid.name.to_lower().begins_with("kid"):
			kid_nodes.append(kid)

func randomize_kid_requirements():
	# Clear previous mapping
	kid_donut_mapping.clear()
	
	# Create a list of available donuts
	var available_donuts = donut_nodes.duplicate()
	available_donuts.shuffle()
	
	# Assign each kid a random donut from the shuffled list
	for i in range(kid_nodes.size()):
		if i < available_donuts.size():
			var kid = kid_nodes[i]
			var donut = available_donuts[i]
			kid_donut_mapping[kid.name] = donut.name
			print("Kid %s wants: %s" % [kid.name, donut.name])
			
			# Update the visual donut shown in the kid's bubble
			update_kid_visual(kid, donut)

func update_kid_visual(kid: Control, donut: Control):
	var texture_rect = kid.get_node_or_null("TextureRect")
	if not texture_rect:
		return
	
	var donut_bubble = texture_rect.get_node_or_null("Donut")
	if donut_bubble and donut.has_meta("texture"):
		# Copy the texture from the donut to the bubble
		donut_bubble.texture = donut.get_meta("texture")
	elif donut_bubble and donut is TextureRect:
		# If donut is a TextureRect, copy its texture
		donut_bubble.texture = donut.texture

func initialize_donuts():
	for donut in donut_nodes:
		setup_draggable_donut(donut)

func setup_draggable_donut(donut: Control):
	donut.gui_input.connect(_on_donut_input.bind(donut))
	donut.mouse_entered.connect(_on_donut_hover_start.bind(donut))
	donut.mouse_exited.connect(_on_donut_hover_end.bind(donut))

func initialize_kids():
	for kid in kid_nodes:
		setup_kid_dropzone(kid)

func setup_kid_dropzone(kid: Control):
	kid.gui_input.connect(_on_kid_input.bind(kid))

func _on_donut_input(event: InputEvent, donut: Control):
	if not game_active:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(donut, event.global_position)
			else:
				end_drag(donut, event.global_position)
	elif event is InputEventMouseMotion and dragging_donut == donut:
		donut.global_position = event.global_position - drag_offset

func start_drag(donut: Control, mouse_pos: Vector2):
	dragging_donut = donut
	drag_offset = mouse_pos - donut.global_position
	donut.z_index = 100
	var tween = create_tween()
	tween.tween_property(donut, "scale", Vector2(1.1, 1.1), 0.1)

func end_drag(donut: Control, mouse_pos: Vector2):
	if dragging_donut != donut:
		return
	
	dragging_donut = null
	donut.z_index = 0
	var tween = create_tween()
	tween.tween_property(donut, "scale", Vector2.ONE, 0.1)
	check_drop_on_kid(donut, mouse_pos)

func check_drop_on_kid(donut: Control, drop_position: Vector2):
	var target_kid: Control = null
	for kid in kid_nodes:
		if kid in completed_kids:
			continue
		if kid.get_global_rect().has_point(drop_position):
			target_kid = kid
			break
	if target_kid:
		handle_donut_drop_on_kid(donut, target_kid)
	else:
		return_to_original_position(donut)

func handle_donut_drop_on_kid(donut: Control, kid: Control):
	var required_donut = kid_donut_mapping.get(kid.name, "")
	if donut.name == required_donut:
		handle_correct_match(donut, kid)
	else:
		handle_wrong_match(donut, kid)

func handle_correct_match(donut: Control, kid: Control):
	completed_kids.append(kid)
	matches_completed += 1

	# Hide draggable donut completely
	donut.visible = false
	donut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var texture_rect = kid.get_node_or_null("TextureRect")
	var donut_bubble = texture_rect.get_node_or_null("Donut") if texture_rect else null
	var ty_label = texture_rect.get_node_or_null("TyLabel") if texture_rect else null
	
	if ty_label:
		ty_label.visible = true
		ty_label.text = "Thank you!"
		ty_label.move_to_front()

		if donut_bubble:
			donut_bubble.visible = false
	else:
		if donut_bubble:
			donut_bubble.visible = false
	
	if matches_completed >= total_kids:
		await get_tree().create_timer(1.0).timeout
		win_game()

func handle_wrong_match(donut: Control, kid: Control):
	show_wrong_match_feedback(donut, kid)
	await get_tree().create_timer(0.5).timeout
	return_to_original_position(donut)

func show_wrong_match_feedback(donut: Control, kid: Control):
	var original_modulate = donut.modulate
	var tween = create_tween()
	tween.tween_property(donut, "modulate", Color.RED, 0.2)
	tween.tween_property(donut, "modulate", original_modulate, 0.2)

func return_to_original_position(donut: Control):
	if donut.name in original_positions:
		var tween = create_tween()
		tween.tween_property(donut, "global_position", original_positions[donut.name], 0.5)

func _on_donut_hover_start(donut: Control):
	if game_active and dragging_donut == null:
		var tween = create_tween()
		tween.tween_property(donut, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_donut_hover_end(donut: Control):
	if dragging_donut != donut:
		var tween = create_tween()
		tween.tween_property(donut, "modulate", Color.WHITE, 0.1)

func _on_kid_input(event: InputEvent, kid: Control):
	pass

func start_game():
	game_active = true
	time_remaining = game_duration
	matches_completed = 0
	completed_kids.clear()
	
	# Randomize which donut each kid wants at the start of each game
	randomize_kid_requirements()
	
	for kid in kid_nodes:
		var texture_rect = kid.get_node_or_null("TextureRect")
		var donut_bubble = texture_rect.get_node_or_null("Donut") if texture_rect else null
		var ty_label = texture_rect.get_node_or_null("TyLabel") if texture_rect else null
		
		if donut_bubble:
			donut_bubble.visible = true
			donut_bubble.modulate = Color.WHITE
		
		if ty_label:
			ty_label.visible = false
	
	for donut in donut_nodes:
		donut.visible = true
		donut.mouse_filter = Control.MOUSE_FILTER_PASS
		if donut.name in original_positions:
			donut.global_position = original_positions[donut.name]
	
	update_timer_display()
	game_timer.start()

func _on_timer_tick():
	time_remaining -= 1
	update_timer_display()
	if time_remaining <= 0:
		game_over()
	elif time_remaining <= 10:
		timer_display.modulate = Color.RED

func update_timer_display():
	if timer_display:
		timer_display.text = " " + str(time_remaining) + "s"

func win_game():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("fine_motor", true)
	Global.refresh_everything_after_stage_completion("fine_motor", true)
	var star_rating = calculate_star_rating()
	show_completion_screen(true, star_rating)

func game_over():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("fine_motor", false)
	Global.refresh_everything_after_stage_completion("fine_motor", false)
	await get_tree().create_timer(1.0).timeout
	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	if time_remaining >= 10:
		return 3
	elif time_remaining >= 5:
		return 2
	else:
		return 1

func show_completion_screen(success: bool, stars: int):
	if has_node("DropZone"): $DropZone.visible = false
	if has_node("Draggables"): $Draggables.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	if success:
		print("Game completed successfully!")
	else:
		print("Game over - Time's up!")
	
	var popup_instance: Node = null
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
	game_active = false
	matches_completed = 0
	completed_kids.clear()
	
	for donut in donut_nodes:
		if donut.name in original_positions:
			donut.global_position = original_positions[donut.name]
			donut.modulate = Color.WHITE
			donut.scale = Vector2.ONE
			donut.z_index = 0
			donut.visible = true
			donut.mouse_filter = Control.MOUSE_FILTER_PASS
			if not donut.gui_input.is_connected(_on_donut_input):
				donut.gui_input.connect(_on_donut_input.bind(donut))
	
	if has_node("DropZone"): $DropZone.visible = true
	if has_node("Draggables"): $Draggables.visible = true
	if has_node("Time"): $Time.visible = true
	if has_node("Holder"): $Holder.visible = true
	
	if timer_display:
		timer_display.modulate = Color.WHITE
	
	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
