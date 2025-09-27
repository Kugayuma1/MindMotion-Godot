# MAIL SORTING GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 20 # seconds
var time_remaining := 20
var game_active := false
var mails_sorted := 0
var total_mails := 4  # Green, Red, Blue, Gray

# Node references
@onready var timer_display = $Time/Label
@onready var draggables = $Draggables
@onready var mailboxes = $Dropzone  # MailboxGreen, MailboxRed, MailboxBlue, MailboxGray

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Tracking variables
var draggable_nodes = []
var original_positions = {}
var dragging_item: Control = null
var drag_offset: Vector2

# Timer
var game_timer: Timer

func _ready():
	setup_game()
	start_game()

func setup_game():
	# Timer setup
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)

	# Store draggable nodes
	for item in draggables.get_children():
		draggable_nodes.append(item)
		original_positions[item.name] = item.global_position
		setup_draggable(item)

func setup_draggable(item: Control):
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

	check_drop(item, mouse_pos)

func check_drop(item: Control, drop_position: Vector2):
	for mailbox in mailboxes.get_children():
		if mailbox.get_global_rect().has_point(drop_position):
			if is_match(item, mailbox):
				handle_correct_drop(item)
			else:
				handle_wrong_drop(item)
			return

	return_to_original_position(item)

func is_match(item: Control, mailbox: Control) -> bool:
	# Match by color word in the name
	if item.name.to_lower().contains("green") and mailbox.name.to_lower().contains("green"):
		return true
	if item.name.to_lower().contains("red") and mailbox.name.to_lower().contains("red"):
		return true
	if item.name.to_lower().contains("blue") and mailbox.name.to_lower().contains("blue"):
		return true
	if item.name.to_lower().contains("gray") and mailbox.name.to_lower().contains("gray"):
		return true
	return false

func handle_correct_drop(item: Control):
	# Disappear when dropped correctly
	item.visible = false
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mails_sorted += 1

	if mails_sorted >= total_mails:
		await get_tree().create_timer(0.5).timeout
		win_game()

func handle_wrong_drop(item: Control):
	show_wrong_feedback(item)
	await get_tree().create_timer(0.3).timeout
	return_to_original_position(item)

func show_wrong_feedback(item: Control):
	var original_modulate = item.modulate
	var tween = create_tween()
	tween.tween_property(item, "modulate", Color.RED, 0.2)
	tween.tween_property(item, "modulate", original_modulate, 0.2)

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "global_position", original_positions[item.name], 0.5)
		item.scale = Vector2.ONE

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
	mails_sorted = 0

	for item in draggable_nodes:
		item.visible = true
		item.mouse_filter = Control.MOUSE_FILTER_PASS
		if item.name in original_positions:
			item.global_position = original_positions[item.name]
		item.scale = Vector2.ONE

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
		timer_display.text = "⏱️ " + str(time_remaining) + "s"

func win_game():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("fine_motor", true)
	Global.refresh_everything_after_stage_completion("fine_motor", true)
	var stars = calculate_star_rating()
	show_completion_screen(true, stars)

func game_over():
	game_active = false
	game_timer.stop()
	ProgressManager.save_progress("fine_motor", false)
	Global.refresh_everything_after_stage_completion("fine_motor", false)
	await get_tree().create_timer(1.0).timeout
	show_completion_screen(false, 0)

func calculate_star_rating() -> int:
	if time_remaining >= 15:
		return 3
	elif time_remaining >= 8:
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
	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
