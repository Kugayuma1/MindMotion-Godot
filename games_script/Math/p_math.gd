extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var pencils_given := 0
var required_pencils := 5

# Node references (based on your scene)
@onready var timer_display = $Time/Label
@onready var kid_zone = $Dropzone/Kid
@onready var kid_label = $Dropzone/TextureRect/Label2
@onready var draggable_items = $Draggables
@onready var game_timer: Timer

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Tracking
var pencils_with_kid = []
var original_positions = {}
var all_draggable_nodes = []
var win_timer: Timer
var dragging_item: Control = null
var drag_offset: Vector2

# Kid messages
var kid_messages = {
	"welcome": "Give me exactly 5 pencils, please!",
	"correct_count": "Perfect! Thank you for the 5 pencils!",
	"too_many": "Whoa! I only need 5 pencils, not more!",
	"need_more": "I still need more pencils... %d more to go!",
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

	# Win timer
	win_timer = Timer.new()
	win_timer.wait_time = 3.0
	win_timer.one_shot = true
	win_timer.timeout.connect(_on_win_timer_timeout)
	add_child(win_timer)

	# Store items
	for item in draggable_items.get_children():
		all_draggable_nodes.append(item)
		original_positions[item.name] = item.global_position

	update_kid_message("welcome")

func initialize_items():
	for item in all_draggable_nodes:
		setup_draggable_item(item)

func setup_draggable_item(item: Control):
	item.mouse_filter = Control.MOUSE_FILTER_PASS  
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
	check_drop_on_kid(item, mouse_pos)

func check_drop_on_kid(item: Control, drop_position: Vector2):
	if kid_zone and kid_zone.get_global_rect().has_point(drop_position):
		handle_item_drop_on_kid(item)
	else:
		if item in pencils_with_kid:
			return_item_from_kid(item)
		else:
			return_to_original_position(item)

func handle_item_drop_on_kid(item: Control):
	if not item.name.to_lower().begins_with("pencil"):
		return_to_original_position(item)
		return

	if item in pencils_with_kid:
		return

	if win_timer.time_left > 0:
		win_timer.stop()

	pencils_with_kid.append(item)
	pencils_given += 1
	position_item_with_kid(item)
	evaluate_pencil_count()

func position_item_with_kid(item: Control):
	item.visible = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE

func return_item_from_kid(item: Control):
	if item in pencils_with_kid:
		pencils_with_kid.erase(item)
		pencils_given -= 1
	item.visible = true
	item.mouse_filter = Control.MOUSE_FILTER_PASS
	return_to_original_position(item)
	if pencils_given < required_pencils:
		var remaining = required_pencils - pencils_given
		update_kid_message("need_more", [remaining])

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "global_position", original_positions[item.name], 0.5)

func evaluate_pencil_count():
	if pencils_given > required_pencils:
		update_kid_message("too_many")
		await get_tree().create_timer(2.0).timeout
		return_all_pencils()
		update_kid_message("welcome")
	elif pencils_given == required_pencils:
		update_kid_message("correct_count")
		win_game()
	else:
		var remaining = required_pencils - pencils_given
		update_kid_message("need_more", [remaining])

func return_all_pencils():
	if win_timer.time_left > 0:
		win_timer.stop()
	for item in pencils_with_kid.duplicate():
		return_item_from_kid(item)
	pencils_with_kid.clear()
	pencils_given = 0

func start_win_timer():
	win_timer.start()

func _on_win_timer_timeout():
	if pencils_given == required_pencils:
		win_game()

func update_kid_message(message_key: String, args: Array = []):
	if kid_label:
		var message = kid_messages[message_key]
		if args.size() > 0:
			message = message % args
		kid_label.text = message

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
	pencils_given = 0
	pencils_with_kid.clear()
	update_timer_display()
	game_timer.start()
	update_kid_message("welcome")

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
	ProgressManager.save_progress("math", false)
	Global.refresh_everything_after_stage_completion("math", false)
	update_kid_message("game_over")
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
	pencils_given = 0
	pencils_with_kid.clear()

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

	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
