extends Control

func _ready():
	# Wait a bit so splash logo shows
	AudioManager.play_music("menu")
	await get_tree().create_timer(5.0).timeout
	_check_and_continue()
	

func _check_and_continue():
	if InternetManager.is_online():
		# ✅ Connected → continue normal auth flow
		check_authentication()
	else:
		# ❌ No internet → show overlay
		InternetManager.show_overlay()

		# Wait until connection is restored
		await InternetManager.connection_restored
		check_authentication()

func check_authentication():
	if Global.is_authenticated():
		print("✅ User already authenticated: %s (%s)" % [Global.user_name, Global.user_type])

		if not Global.is_letter_cache_loaded:
			print("⏳ Waiting for letter completion data...")
			var wait_time = 0.0
			var max_wait = 3.0
			while not Global.is_letter_cache_loaded and wait_time < max_wait:
				await get_tree().create_timer(0.1).timeout
				wait_time += 0.1

		if Global.user_type == "student":
			get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")
		elif Global.user_type == "teacher":
			get_tree().change_scene_to_file("res://scenes/TeacherMain.tscn")
		else:
			get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
	else:
		print("🔐 Not authenticated, going to user selection")
		get_tree().change_scene_to_file("res://scenes/UserSelection.tscn")
