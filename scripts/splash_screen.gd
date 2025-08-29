extends Control

func _ready():
	# Give a brief moment for the splash screen to show
	await get_tree().create_timer(5.0).timeout
	check_authentication()

func check_authentication():
	# Check if user is already authenticated
	if Global.is_authenticated():
		print("✅ User already authenticated: %s (%s)" % [Global.user_name, Global.user_type])
		
		# Wait for letter completion data to load before transitioning
		if not Global.is_letter_cache_loaded:
			print("⏳ Waiting for letter completion data...")
			# Wait up to 3 seconds for data to load
			var wait_time = 0.0
			var max_wait = 3.0
			
			while not Global.is_letter_cache_loaded and wait_time < max_wait:
				await get_tree().create_timer(0.1).timeout
				wait_time += 0.1
			
			if Global.is_letter_cache_loaded:
				print("✅ Letter data loaded successfully")
			else:
				print("⚠️ Letter data loading timed out, proceeding anyway")
		
		# Navigate based on user type
		if Global.user_type == "student":
			get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
		elif Global.user_type == "teacher":
			get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")
		else:
			print("⚠️ Unknown user type, going to user selection")
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
	else:
		print("🔐 User not authenticated, going to user selection")
		get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")

func _on_timer_timeout():
	check_authentication()
