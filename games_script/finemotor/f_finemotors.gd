# WASTE REMOVAL GAME CONTROLLER
# Attach this to your main Control node
extends Control

# Game settings
var game_duration := 15 # seconds
var time_remaining := 15
var game_active := false
var wastes_removed := 0
var total_wastes := 5

# Node references
@onready var timer_display = $Time/Label
@onready var remove_node = $Remove

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
	reset_time_tracking()
	setup_game()
	start_game()
	motivational_5s_played = false
	motivational_10s_played = false

func setup_game():
	# Timer setup
	if not game_timer:
		game_timer = Timer.new()
		game_timer.wait_time = 1.0
		game_timer.timeout.connect(_on_timer_tick)
		add_child(game_timer)
	
	# Connect each waste item to input
	for waste in remove_node.get_children():
		if not waste.gui_input.is_connected(_on_waste_tapped):
			waste.gui_input.connect(_on_waste_tapped.bind(waste))

func _on_waste_tapped(event: InputEvent, waste: Control):
	if not game_active:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_waste_removal(waste)

func handle_waste_removal(waste: Control):
	if not waste.visible:
		return
	
	# Animate fade out
	var tween = create_tween()
	tween.tween_property(waste, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	waste.visible = false
	wastes_removed += 1
	
	if wastes_removed >= total_wastes:
		await get_tree().create_timer(0.5).timeout
		win_game()

func start_game():
	game_active = true
	time_remaining = game_duration
	wastes_removed = 0
	
	# Reset timer display color
	if timer_display:
		timer_display.modulate = Color.WHITE
	
	# Reset all waste items
	for waste in remove_node.get_children():
		waste.visible = true
		waste.modulate = Color.WHITE
	
	update_timer_display()
	game_timer.start()

func stop_timer():
	"""Stop the game timer"""
	game_active = false
	if game_timer:
		game_timer.stop()

func reset_time_tracking():
	"""Reset the global start time for accurate time tracking"""
	Global.start_time = Time.get_ticks_msec()
	print("Time tracking reset at: ", Global.start_time)

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
	stop_timer()
	
	ProgressManager.save_progress("fine_motor", true)
	Global.refresh_everything_after_stage_completion("fine_motor", true)
	
	var stars = calculate_star_rating()
	show_completion_screen(true, stars)

func game_over():
	stop_timer()
	
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
	hide_game_ui()
	
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

func hide_game_ui():
	"""Hide all game UI elements"""
	if has_node("Remove"): $Remove.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	if has_node("Holder"): $Holder.visible = false
	if has_node("Fish"): $Fish.visible = false

func show_game_ui():
	"""Show all game UI elements"""
	if has_node("Remove"): $Remove.visible = true
	if has_node("Time"): $Time.visible = true
	if has_node("Quitbtn"): $Quitbtn.visible = true
	if has_node("Holder"): $Holder.visible = true
	if has_node("Fish"): $Fish.visible = true

func restart_game():
	"""Properly restart the game with fresh state"""
	print("\n=== RESTARTING WASTE REMOVAL GAME ===")
	
	# Stop the old timer completely
	stop_timer()
	
	# Reset time tracking for new attempt
	reset_time_tracking()
	motivational_5s_played = false
	motivational_10s_played = false
	
	# Show all UI elements again
	show_game_ui()
	
	# Start fresh game
	start_game()
	
	print("=== GAME RESTARTED ===\n")

func _on_quitbtn_pressed() -> void:
	stop_timer()  # Stop timer when quitting
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)
