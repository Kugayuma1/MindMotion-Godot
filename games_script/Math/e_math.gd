extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var eggplants_given := 0
var required_eggplants := 5

# Node references (based on your scene)
@onready var timer_display = $Time/Label
@onready var lady_zone = $Dropzone/Lady
@onready var lady_label = $Dropzone/TextureRect/Label2
@onready var draggable_items = $Draggables
@onready var holder_label = $Holder/Label  # Add this for the requirement display
@onready var game_timer: Timer

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Tracking
var eggplants_with_lady = []
var original_positions = {}
var all_draggable_nodes = []
var win_timer: Timer
var dragging_item: Control = null
var drag_offset: Vector2

# Lady messages
var lady_messages = {
	"welcome": "Give me exactly %d eggplants, please!",
	"correct_count": "Perfect! Thank you for the %d eggplants!",
	"too_many": "Whoa! I only need %d eggplants, not more!",
	"need_more": "I still need more eggplants... %d more to go!",
	"game_over": "Time's up! Try again!"
}

func _ready():
	setup_game()
	initialize_items()
	start_game()

func setup_game():
	# Timer
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)

	# Win timer (still here but won't be used anymore)
	win_timer = Timer.new()
	win_timer.wait_time = 3.0
	win_timer.one_shot = true
	win_timer.timeout.connect(_on_win_timer_timeout)
	add_child(win_timer)

	# Store items
	for item in draggable_items.get_children():
		all_draggable_nodes.append(item)
		original_positions[item.name] = item.global_position

	update_lady_message("welcome")

func initialize_items():
	for item in all_draggable_nodes:
		setup_draggable_item(item)

func setup_draggable_item(item: Control):
	item.mouse_filter = Control.MOUSE_FILTER_PASS  # Make TextureRect clickable
	item.gui_input.connect(_on_item_input.bind(item))
	item.mouse_entered.connect(_on_item_hover_start.bind(item))
	item.mouse_exited.connect(_on_item_hover_end.bind(item))

func _on_item_input(event: InputEvent, item: Control):
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
	item.z_index = 100
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2(1.1, 1.1), 0.1)

func end_drag(item: Control, mouse_pos: Vector2):
	if dragging_item != item:
		return
	dragging_item = null
	item.z_index = 0
	var tween = create_tween()
	tween.tween_property(item, "scale", Vector2.ONE, 0.1)
	check_drop_on_lady(item, mouse_pos)

func check_drop_on_lady(item: Control, drop_position: Vector2):
	if lady_zone and lady_zone.get_global_rect().has_point(drop_position):
		handle_item_drop_on_lady(item)
	else:
		if item in eggplants_with_lady:
			return_item_from_lady(item)
		else:
			return_to_original_position(item)

func handle_item_drop_on_lady(item: Control):
	if not item.name.to_lower().begins_with("eggplant"):
		return_to_original_position(item)
		return

	if item in eggplants_with_lady:
		return

	if win_timer.time_left > 0:
		win_timer.stop()

	eggplants_with_lady.append(item)
	eggplants_given += 1
	position_item_with_lady(item)
	evaluate_eggplant_count()

func position_item_with_lady(item: Control):
	item.visible = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE

func return_item_from_lady(item: Control):
	if item in eggplants_with_lady:
		eggplants_with_lady.erase(item)
		eggplants_given -= 1
	item.visible = true
	item.mouse_filter = Control.MOUSE_FILTER_PASS
	return_to_original_position(item)
	if eggplants_given < required_eggplants:
		var remaining = required_eggplants - eggplants_given
		update_lady_message("need_more", [remaining])

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "global_position", original_positions[item.name], 0.5)

func evaluate_eggplant_count():
	if eggplants_given > required_eggplants:
		update_lady_message("too_many", [required_eggplants])
		await get_tree().create_timer(2.0).timeout
		return_all_eggplants()
		update_lady_message("welcome", [required_eggplants])
	elif eggplants_given == required_eggplants:
		update_lady_message("correct_count", [required_eggplants])
		win_game()
	else:
		var remaining = required_eggplants - eggplants_given
		update_lady_message("need_more", [remaining])

func return_all_eggplants():
	if win_timer.time_left > 0:
		win_timer.stop()
	for item in eggplants_with_lady.duplicate():
		return_item_from_lady(item)
	eggplants_with_lady.clear()
	eggplants_given = 0

func start_win_timer():
	win_timer.start()

func _on_win_timer_timeout():
	if eggplants_given == required_eggplants:
		win_game()

func update_lady_message(message_key: String, args: Array = []):
	if lady_label:
		var message = lady_messages[message_key]
		if args.size() > 0:
			message = message % args
		lady_label.text = message

func _on_item_hover_start(item: Control):
	if game_active and dragging_item == null:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color(1.2, 1.2, 1.2), 0.1)

func _on_item_hover_end(item: Control):
	if dragging_item != item:
		var tween = create_tween()
		tween.tween_property(item, "modulate", Color.WHITE, 0.1)

func start_game():
	game_active = true
	time_remaining = game_duration
	eggplants_given = 0
	eggplants_with_lady.clear()
	
	# Randomize how many eggplants the lady wants (between 3 and 5)
	required_eggplants = randi_range(3, 5)
	print("Lady wants: %d eggplants" % required_eggplants)
	
	# Update the holder label to show the requirement
	if holder_label:
		holder_label.text = "Give the lady: %d eggplants" % required_eggplants
	
	update_timer_display()
	game_timer.start()
	update_lady_message("welcome", [required_eggplants])

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

	ProgressManager.save_progress("math", true)
	Global.refresh_everything_after_stage_completion("math", true)

	var star_rating = calculate_star_rating()
	show_completion_screen(true, star_rating)

func game_over():
	game_active = false
	game_timer.stop()
	update_lady_message("game_over")
	await get_tree().create_timer(1.0).timeout

	ProgressManager.save_progress("math", false)

	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	if time_remaining >= 10:
		return 3
	elif time_remaining >= 5:
		return 2
	else:
		return 1

func show_completion_screen(success: bool, stars: int):
	if has_node("Dropzone"): $Dropzone.visible = false
	if has_node("Draggables"): $Draggables.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false

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

func restart_game():
	game_active = false
	eggplants_given = 0
	eggplants_with_lady.clear()

	for item in all_draggable_nodes:
		if item.name in original_positions:
			item.global_position = original_positions[item.name]
			item.modulate = Color.WHITE
			item.scale = Vector2.ONE
			item.z_index = 0
			item.visible = true
			item.mouse_filter = Control.MOUSE_FILTER_PASS
			if not item.gui_input.is_connected(_on_item_input):
				item.gui_input.connect(_on_item_input.bind(item))

	if has_node("Dropzone"): $Dropzone.visible = true
	if has_node("Draggables"): $Draggables.visible = true  
	if has_node("Time"): $Time.visible = true
	if has_node("Holder"): $Holder.visible = true

	if timer_display:
		timer_display.modulate = Color.WHITE
	
	# Stop the timer before starting a new game
	game_timer.stop()
	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
