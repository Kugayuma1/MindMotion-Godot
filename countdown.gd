extends Control

# Configuration
var countdown := 3  # Start from 3, 2, 1, GO!
var game_scene_path := ""

@onready var countdown_label = $CountdownLabel

func _ready():
	# Get the game scene path from metadata
	game_scene_path = get_meta("game_scene_path", "")
	
	# Setup label styling - keep it centered and fixed size
	if countdown_label:
		countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		countdown_label.scale = Vector2(1.0, 1.0)  # Keep consistent size
	
	start_countdown()

func start_countdown() -> void:
	display_count()

func display_count() -> void:
	if countdown > 0:
		countdown_label.text = str(countdown)
		animate_blink()
		countdown -= 1
		await get_tree().create_timer(1.0).timeout
		display_count()
	else:
		# Show "GO!" before transitioning
		countdown_label.text = "GO!"
		animate_blink()
		await get_tree().create_timer(0.8).timeout
		transition_to_game()

func animate_blink() -> void:
	# Simple blink effect - fade in quickly
	countdown_label.modulate.a = 0.0
	
	var tween = create_tween()
	# Quick fade in
	tween.tween_property(countdown_label, "modulate:a", 1.0, 0.15)

func transition_to_game() -> void:
	# Load the actual game scene (timer starts when game's _ready() is called)
	if ResourceLoader.exists(game_scene_path):
		get_tree().change_scene_to_file(game_scene_path)
	else:
		print("Error: Game scene not found: ", game_scene_path)
		# Fallback to categories
		get_tree().change_scene_to_file("res://scenes/Categories.tscn")
