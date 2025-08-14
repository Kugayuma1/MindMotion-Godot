extends Control

func _ready():
	var user_type = Global.user_type.capitalize()
	$WelcomeLabel.text = "Welcome %s!" % user_type

func _on_back_pressed(): 
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn") 

func _on_login_pressed():
	get_tree().change_scene_to_file("res://scenes/Login.tscn")

func _on_signup_pressed():
	if Global.user_type == "student":
		get_tree().change_scene_to_file("res://scenes/studentsignup.tscn")
	elif Global.user_type == "teacher":
		get_tree().change_scene_to_file("res://scenes/teachersignup.tscn")
	else:
		print("Unknown user type")
