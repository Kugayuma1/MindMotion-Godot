extends Control

# Game configuration - List of words with their data
var word_data = [
	{"word": "QUEEN", "image_path": "res://Game Assets/Reading Assets/Assetsulit/43.png", "available_letters": ["N", "E", "U", "Q", "L", "A", "N", "E"]},
	{"word": "QUAIL", "image_path": "res://Game Assets/Reading Assets/Assetsulit/2NANAMAN/Quail.png", "available_letters": ["N", "E", "U", "Q", "L", "A", "I", "E"]},
]

# Current game state
var current_word_index = 0  # Tracks which word we're on
var correct_answer = ""
var answer_length = 0
var available_letters = []

# Game state
var current_answer = []
var current_slot_index = 0
var countdown := 15
var timer_active = true

# Preload popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Node references
@onready var timer_label = $Time/Label
@onready var letter_holders = [
	$LetterHolders/FirstLetter/Label,
	$LetterHolders/SecondLetter/Label,
	$LetterHolders/ThirdLetter/Label,
	$LetterHolders/FourthLetter/Label,
	$LetterHolders/FifthLetter/Label
]

@onready var letter_holder_controls = [
	$LetterHolders/FirstLetter,
	$LetterHolders/SecondLetter,
	$LetterHolders/ThirdLetter,
	$LetterHolders/FourthLetter,
	$LetterHolders/FifthLetter
]

@onready var letter_buttons = [
	$LetterButtons/LetterButton,
	$LetterButtons/LetterButton2,
	$LetterButtons/LetterButton3,
	$LetterButtons/LetterButton4,
	$LetterButtons/LetterButton5,
	$LetterButtons/LetterButton6,
	$LetterButtons/LetterButton7,
	$LetterButtons/LetterButton8
]

@onready var image_display = $ItemHolder/TextureRect  # Reference to your image/TextureRect node

var button_letters = {}
var slot_to_button = {}

func _ready():
	load_current_word()
	setup_game()
	setup_letter_holder_inputs()
	start_timer()
	Global.start_time = Time.get_ticks_msec()

func load_current_word() -> void:
	# Get the current word data based on current_word_index
	if current_word_index >= word_data.size():
		current_word_index = 0  # Loop back to the beginning if we've gone through all words
	
	var data = word_data[current_word_index]
	correct_answer = data["word"]
	answer_length = correct_answer.length()
	available_letters = data["available_letters"].duplicate()
	
	# Load and set the image
	if ResourceLoader.exists(data["image_path"]):
		image_display.texture = load(data["image_path"])
	else:
		print("Image not found: ", data["image_path"])
	
	print("Loaded word: ", correct_answer, " at index: ", current_word_index)

func setup_game() -> void:
	current_answer.clear()
	current_slot_index = 0
	button_letters.clear()
	slot_to_button.clear()
	
	# Clear all letter holder labels
	for label in letter_holders:
		label.text = ""
	
	# Set up letter buttons with available letters
	for i in range(letter_buttons.size()):
		if i < available_letters.size():
			var button = letter_buttons[i]
			var label = button.get_node("Label")
			label.text = available_letters[i]
			button.visible = true
			
			button_letters[button] = available_letters[i]
			button.gui_input.connect(_on_letter_button_input.bind(button))

func setup_letter_holder_inputs() -> void:
	for i in range(letter_holder_controls.size()):
		var holder = letter_holder_controls[i]
		holder.gui_input.connect(_on_letter_holder_input.bind(i))

func start_timer() -> void:
	timer_label.text = "15s"
	countdown = 15
	timer_active = true
	update_timer()

func update_timer() -> void:
	if countdown <= 0:
		timer_label.text = "Time's up!"
		timer_active = false
		ProgressManager.save_progress("reading", false)
		Global.refresh_everything_after_stage_completion("reading", false)
		game_over(false)
		return

	timer_label.text = " " + str(countdown) + "s"
	countdown -= 1
	await get_tree().create_timer(1.0).timeout

	if timer_active:
		update_timer()

func _on_letter_button_input(event: InputEvent, button: TextureRect) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if !timer_active:
				return
			
			if current_slot_index >= answer_length:
				return
			
			if !button.visible:
				return
			
			var letter = button_letters.get(button, "")
			if letter == "":
				return
			
			current_answer.append(letter)
			letter_holders[current_slot_index].text = letter
			slot_to_button[current_slot_index] = button
			button.visible = false
			current_slot_index += 1
			
			if current_slot_index >= answer_length:
				check_complete_answer()

func _on_letter_holder_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if !timer_active:
				return
			
			if letter_holders[slot_index].text == "":
				return
			
			var button = slot_to_button.get(slot_index)
			if button == null:
				return
			
			letter_holders[slot_index].text = ""
			button.visible = true
			current_answer.remove_at(slot_index)
			slot_to_button.erase(slot_index)
			
			for i in range(slot_index, answer_length - 1):
				if i + 1 < answer_length and letter_holders[i + 1].text != "":
					letter_holders[i].text = letter_holders[i + 1].text
					
					if slot_to_button.has(i + 1):
						slot_to_button[i] = slot_to_button[i + 1]
						slot_to_button.erase(i + 1)
					
					letter_holders[i + 1].text = ""
			
			current_slot_index = current_answer.size()

func check_complete_answer() -> void:
	var player_word = "".join(current_answer)
	
	if player_word == correct_answer:
		timer_active = false
		ProgressManager.save_progress("reading", true)
		Global.refresh_everything_after_stage_completion("reading", true)
		await get_tree().create_timer(0.5).timeout
		game_over(true)
	else:
		shake_letter_holders()
		await get_tree().create_timer(1.0).timeout
		reset_answer()

func reset_answer() -> void:
	current_answer.clear()
	current_slot_index = 0
	slot_to_button.clear()
	
	for label in letter_holders:
		label.text = ""
	
	for button in letter_buttons:
		button.visible = true

func shake_letter_holders() -> void:
	for i in range(letter_holders.size()):
		var holder = letter_holders[i].get_parent()
		var original_pos = holder.position
		var tween = create_tween()
		tween.tween_property(holder, "position", original_pos + Vector2(-10, 0), 0.05)
		tween.tween_property(holder, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
		tween.tween_property(holder, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	if has_node("LetterHolders"): $LetterHolders.visible = false
	if has_node("LetterButtons"): $LetterButtons.visible = false
	if has_node("ItemHolder"): $ItemHolder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	if success:
		if countdown >= 10:
			popup_instance = complete3_scene.instantiate()
		elif countdown >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()

	add_child(popup_instance)

func _on_quitbtn_pressed() -> void:
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:	
		print("Scene not found: ", path)

# Call this function when moving to the next word (e.g., from a completion popup)
func next_word() -> void:
	current_word_index += 1
	load_current_word()
	setup_game()
	
	if has_node("LetterHolders"): $LetterHolders.visible = true
	if has_node("LetterButtons"): $LetterButtons.visible = true
	if has_node("ItemHolder"): $ItemHolder.visible = true
	if has_node("Time"): $Time.visible = true
	if has_node("Quitbtn"): $Quitbtn.visible = true
	
	start_timer()
