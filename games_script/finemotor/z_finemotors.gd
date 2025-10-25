extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var zombies_cured := 0
var required_cures := 3

# Node references
@onready var timer_display = $Time/Label
@onready var dropzone = $Dropzone
@onready var draggable_items = $Draggables
@onready var game_timer: Timer
@onready var instruction_label = $Holder/Label

# Zombie drop zones
@onready var zombie1 = $Dropzone/Zombie
@onready var zombie2 = $Dropzone/Zombie2
@onready var zombie3 = $Dropzone/Zombie3

# Popup scenes - adjust paths to your reward scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Cured human textures - add your normal people images here
var cured_textures = {
	"Zombie": preload("res://Game Assets/Fine Motor Assets/BG/51.png"),
	"Zombie2": preload("res://Game Assets/Fine Motor Assets/BG/53.png"),
	"Zombie3": preload("res://Game Assets/Fine Motor Assets/BG/55.png")
}

# Tracking
var cured_zombies = []
var original_positions = {}
var all_draggable_nodes = []
var win_timer: Timer
var dragging_item: Control = null
var drag_offset: Vector2

func _ready():
	setup_game()
	Global.start_time = Time.get_ticks_msec()
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
	win_timer.wait_time = 2.0
	win_timer.one_shot = true
	win_timer.timeout.connect(_on_win_timer_timeout)
	add_child(win_timer)

	# Store original positions
	for item in draggable_items.get_children():
		all_draggable_nodes.append(item)
		original_positions[item.name] = item.global_position

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
	check_drop_on_zombie(item, mouse_pos)

func check_drop_on_zombie(item: Control, drop_position: Vector2):
	# Check if it's an antidote
	if not item.name.to_lower().begins_with("antidote"):
		return_to_original_position(item)
		return
	
	var dropped_on_zombie = false
	
	# Check each zombie zone
	if zombie1 and zombie1.get_global_rect().has_point(drop_position) and zombie1.name not in cured_zombies:
		cure_zombie(zombie1, item)
		dropped_on_zombie = true
	elif zombie2 and zombie2.get_global_rect().has_point(drop_position) and zombie2.name not in cured_zombies:
		cure_zombie(zombie2, item)
		dropped_on_zombie = true
	elif zombie3 and zombie3.get_global_rect().has_point(drop_position) and zombie3.name not in cured_zombies:
		cure_zombie(zombie3, item)
		dropped_on_zombie = true
	
	if not dropped_on_zombie:
		return_to_original_position(item)

func cure_zombie(zombie: Control, antidote: Control):
	# Mark zombie as cured
	cured_zombies.append(zombie.name)
	zombies_cured += 1
	
	# Change zombie texture to cured human
	if zombie.name in cured_textures:
		if zombie is TextureRect:
			zombie.texture = cured_textures[zombie.name]
	
	# Visual feedback
	var tween = create_tween()
	tween.tween_property(zombie, "modulate", Color(0.5, 1.5, 0.5), 0.3)
	tween.tween_property(zombie, "modulate", Color.WHITE, 0.3)
	
	# Hide and disable the used antidote
	antidote.visible = false
	antidote.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Update instruction
	if instruction_label:
		var remaining = required_cures - zombies_cured
		if remaining > 0:
			instruction_label.text = "Cure " + str(remaining) + " more zombie" + ("s" if remaining > 1 else "") + "!"
		else:
			instruction_label.text = "All zombies cured!"
	
	# Check win condition
	if zombies_cured >= required_cures:
		win_timer.start()

func return_to_original_position(item: Control):
	if item.name in original_positions:
		var tween = create_tween()
		tween.tween_property(item, "global_position", original_positions[item.name], 0.5)

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
	zombies_cured = 0
	cured_zombies.clear()
	update_timer_display()
	game_timer.start()
	
	if instruction_label:
		instruction_label.text = "Give the Gardener his things"

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

func _on_win_timer_timeout():
	if zombies_cured >= required_cures:
		win_game()

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
	if instruction_label:
		instruction_label.text = "Time's up! Try again!"
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
	for node_name in ["Dropzone", "Draggables", "Time", "Holder", "Quitbtn"]:
		if has_node(node_name):
			get_node(node_name).visible = false

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
	zombies_cured = 0
	cured_zombies.clear()

	# Reset all antidotes
	for item in all_draggable_nodes:
		if item.name in original_positions:
			item.global_position = original_positions[item.name]
			item.modulate = Color.WHITE
			item.scale = Vector2.ONE
			item.z_index = 0
			item.visible = true
			item.mouse_filter = Control.MOUSE_FILTER_PASS

	# Reset zombie appearances (you'll need to store original textures)
	# This is a placeholder - store original textures in _ready() if needed
	
	for node_name in ["Dropzone", "Draggables", "Time", "Holder"]:
		if has_node(node_name):
			get_node(node_name).visible = true

	if timer_display:
		timer_display.modulate = Color.WHITE

	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
