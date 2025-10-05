extends Control

# Game configuration
var correct_answer = "LION"  # The word to guess
var answer_length = 4  # Number of letter slots
var available_letters = ["K", "L", "R", "I", "O", "Y", "Z", "N"]  # Letters shown to player

# Game state
var current_answer = []  # Array to track filled letters
var current_slot_index = 0  # Which slot to fill next
var countdown := 15
var timer_active = true

# Preload popup scenes
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")

var popup_instance: Control = null

# Node references
@onready var timer_label = $Time/Label  # Adjust path based on your timer UI
@onready var letter_holders = [
	$LetterHolders/FirstLetter/Label,
	$LetterHolders/SecondLetter/Label,
	$LetterHolders/ThirdLetter/Label,
	$LetterHolders/FourthLetter/Label
]

@onready var letter_holder_controls = [
	$LetterHolders/FirstLetter,
	$LetterHolders/SecondLetter,
	$LetterHolders/ThirdLetter,
	$LetterHolders/FourthLetter
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

var button_letters = {}  # Maps TextureRect to its letter
var slot_to_button = {}  # Maps slot index to the button that filled it

func _ready():
	setup_game()
	setup_letter_holder_inputs()
	start_timer()
	Global.start_time = Time.get_ticks_msec()

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
			
			# Store the letter for this TextureRect
			button_letters[button] = available_letters[i]
			
			# Make TextureRect clickable
			button.gui_input.connect(_on_letter_button_input.bind(button))

func setup_letter_holder_inputs() -> void:
	# Make letter holders clickable for deletion
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
			
			# Check if we still have empty slots
			if current_slot_index >= answer_length:
				return
			
			# Check if this button is still visible (not already used)
			if !button.visible:
				return
			
			# Get the letter for this button
			var letter = button_letters.get(button, "")
			if letter == "":
				return
			
			# Add letter to current answer
			current_answer.append(letter)
			
			# Update the label in the current slot
			letter_holders[current_slot_index].text = letter
			
			# Map this slot to the button for deletion later
			slot_to_button[current_slot_index] = button
			
			# Hide the button that was pressed
			button.visible = false
			
			# Move to next slot
			current_slot_index += 1
			
			# Check if word is complete
			if current_slot_index >= answer_length:
				check_complete_answer()

func _on_letter_holder_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if !timer_active:
				return
			
			# Check if this slot has a letter
			if letter_holders[slot_index].text == "":
				return
			
			# Get the button that filled this slot
			var button = slot_to_button.get(slot_index)
			if button == null:
				return
			
			# Clear the slot
			letter_holders[slot_index].text = ""
			
			# Show the button again
			button.visible = true
			
			# Remove from current answer
			current_answer.remove_at(slot_index)
			
			# Remove from slot mapping
			slot_to_button.erase(slot_index)
			
			# Shift all letters after this slot to the left
			for i in range(slot_index, answer_length - 1):
				if i + 1 < answer_length and letter_holders[i + 1].text != "":
					# Move letter from next slot to current slot
					letter_holders[i].text = letter_holders[i + 1].text
					
					# Update slot mapping
					if slot_to_button.has(i + 1):
						slot_to_button[i] = slot_to_button[i + 1]
						slot_to_button.erase(i + 1)
					
					# Clear the next slot
					letter_holders[i + 1].text = ""
			
			# Update current slot index
			current_slot_index = current_answer.size()

func check_complete_answer() -> void:
	var player_word = "".join(current_answer)
	
	if player_word == correct_answer:
		# Correct answer!
		timer_active = false
		ProgressManager.save_progress("reading", true)
		Global.refresh_everything_after_stage_completion("reading", true)
		await get_tree().create_timer(0.5).timeout
		game_over(true)
	else:
		# Wrong answer - shake and reset
		shake_letter_holders()
		await get_tree().create_timer(1.0).timeout
		reset_answer()

func reset_answer() -> void:
	# Clear current answer
	current_answer.clear()
	current_slot_index = 0
	slot_to_button.clear()
	
	# Clear letter holder labels
	for label in letter_holders:
		label.text = ""
	
	# Show all buttons again
	for button in letter_buttons:
		button.visible = true

func shake_letter_holders() -> void:
	for i in range(letter_holders.size()):
		var holder = letter_holders[i].get_parent()  # Get the Control node
		var original_pos = holder.position
		var tween = create_tween()
		tween.tween_property(holder, "position", original_pos + Vector2(-10, 0), 0.05)
		tween.tween_property(holder, "position", original_pos + Vector2(10, 0), 0.05).set_delay(0.05)
		tween.tween_property(holder, "position", original_pos, 0.05).set_delay(0.10)

func game_over(success: bool):
	# Hide UI elements
	if has_node("LetterHolders"): $LetterHolders.visible = false
	if has_node("LetterButtons"): $LetterButtons.visible = false
	if has_node("ItemHolder"): $ItemHolder.visible = false
	if has_node("Time"): $Time.visible = false
	if has_node("Quitbtn"): $Quitbtn.visible = false
	
	if success:
		# Award stars based on remaining time
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
