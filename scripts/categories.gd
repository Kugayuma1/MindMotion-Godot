extends Control


func _ready():
	$LetterLabel.text = "Letter %s" % Global.current_letter

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scenes/LevelSelection.tscn")

func _on_reading_pressed():
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/" + letter_lower + "_reading.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
		
func _on_fine_motor_pressed() :
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/" + letter_lower + "_finemotors.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
	
func _on_math_pressed():
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/" + letter_lower + "_math.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
	
func _on_arts_pressed():
	var letter_lower = Global.current_letter.to_lower()
	var path = "res://games/" + letter_lower + "_arts.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
