extends Control


func _on_logout_pressed():
	Global.logout()  # Clear user info
	get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")


func _on_students_pressed():
	get_tree().change_scene_to_file("res://dashboard/StudentList.tscn")
