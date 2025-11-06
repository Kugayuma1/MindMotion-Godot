# LEAVES REMOVAL GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var leaves_removed := 0
var total_leaves := 7  # Leaves1–Leaves7

# Node references
@onready var timer_display = $Time/Label
@onready var remove_node = $Remove  # Contains Leaves nodes

# Popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn") 
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

# Timer
var game_timer: Timer
var motivational_5s_played = false
var motivational_10s_played = false

func _ready():
	setup_game()
	Global.start_time = Time.get_ticks_msec()
	start_game()
	var motivational_5s_played = false
	var motivational_10s_played = false

func setup_game():
	# Timer setup
	game_timer = Timer.new()
	game_timer.wait_time = 1.0
	game_timer.timeout.connect(_on_timer_tick)
	add_child(game_timer)

	# Connect each leaf to input event
	for leaf in remove_node.get_children():
		leaf.gui_input.connect(_on_leaf_tapped.bind(leaf))

func _on_leaf_tapped(event: InputEvent, leaf: Control):
	if not game_active:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_leaf_removal(leaf)

func handle_leaf_removal(leaf: Control):
	if not leaf.visible:
		return
	
	# Animate fade-out and disappear
	var tween = create_tween()
	tween.tween_property(leaf, "modulate:a", 0.0, 0.3)
	await tween.finished

	leaf.visible = false
	leaves_removed += 1

	if leaves_removed >= total_leaves:
		await get_tree().create_timer(0.5).timeout
		win_game()

func start_game():
	game_active = true
	time_remaining = game_duration
	leaves_removed = 0

	for leaf in remove_node.get_children():
		leaf.visible = true
		leaf.modulate = Color.WHITE

	update_timer_display()
	game_timer.start()

func _on_timer_tick():
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
		timer_display.modulate = Color.RED

func update_timer_display():
	if timer_display:
		timer_display.text = "" + str(time_remaining) + "s"

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
	if time_remaining >= 10:
		return 3
	elif time_remaining >= 5:
		return 2
	else:
		return 1

func show_completion_screen(success: bool, stars: int):
	if has_node("Remove"): $Remove.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Fish"): $Fish.visible = false

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
	var motivational_5s_played = false
	var motivational_10s_played = false
	start_game()

func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
