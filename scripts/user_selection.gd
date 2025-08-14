extends Control


func _on_student_pressed():
	Global.set_user_type("student")
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")

func _on_teacher_pressed():
	Global.set_user_type("teacher")
	get_tree().change_scene_to_file("res://scenes/Welcome.tscn")
