# C_Arts Control Script - POPUP MANAGER ONLY
# The Node2D child handles all game logic
extends Control

# ---------------- POPUP SCENES ----------------
var complete1_scene = preload("res://reward scene/Complete1.tscn")
var complete2_scene = preload("res://reward scene/Complete2.tscn")
var complete3_scene = preload("res://reward scene/Complete3.tscn")
var retry_scene = preload("res://reward scene/Retry.tscn")
var popup_instance: Control = null

# ---------------- REFERENCES ----------------
@onready var game_manager = $Node2D2  # The Node2D that runs the actual game
@onready var game_elements = []  # Elements to hide during popup

# ---------------- BACKGROUND CONTROL ----------------
@export var preserve_background_elements: Array[String] = []
@export var auto_detect_backgrounds: bool = true

func _ready():
	print("🎮 C_Arts Control Manager Ready (Popup Manager)")
	collect_game_elements()
	
	# Let the Node2D handle all game logic
	if not game_manager:
		print("❌ ERROR: Node2D2 not found! Make sure it exists as a child of this Control node")

# ---------------- COLLECT GAME ELEMENTS ----------------
func collect_game_elements():
	for child in get_children():
		var skip_child = false
		
		# Skip popups and the game manager Node2D
		if child.name.contains("Complete") or child.name.contains("Retry") or child.name == "Node2D2":
			skip_child = true
		
		# Check manually specified background elements to preserve
		for bg_element_name in preserve_background_elements:
			if child.name == bg_element_name:
				skip_child = true
				print("Keeping manually specified background element: ", child.name)
				break
		
		# Auto-detect backgrounds if enabled
		if not skip_child and auto_detect_backgrounds:
			var background_names = ["background", "Background", "BG", "bg", "BackgroundImage", "BackgroundTexture", "Backdrop"]
			for bg_name in background_names:
				if child.name.to_lower().contains(bg_name.to_lower()):
					skip_child = true
					print("Auto-detected background element: ", child.name)
					break
			
			# Skip TextureRect that might be background
			if not skip_child and child is TextureRect:
				var texture_rect = child as TextureRect
				if texture_rect.position.distance_to(Vector2.ZERO) < 100 and texture_rect.size.x > 400:
					skip_child = true
					print("Auto-detected background TextureRect: ", child.name)
			
			# Skip ColorRect that might be background
			if not skip_child and child is ColorRect:
				var color_rect = child as ColorRect
				if color_rect.position.distance_to(Vector2.ZERO) < 100 and color_rect.size.x > 400:
					skip_child = true
					print("Auto-detected background ColorRect: ", child.name)
		
		if not skip_child:
			game_elements.append(child)
	
	# ✅ Include all children of Node2D2 (game_manager)
	if game_manager and is_instance_valid(game_manager):
		for node in game_manager.get_children():
			if node is Node2D or node is Control or node is CanvasItem:
				game_elements.append(node)
		print("Also collected", game_manager.get_child_count(), "elements from Node2D2")

	print("Collected", game_elements.size(), "total game elements to hide during popup")

# ---------------- POPUP SYSTEM ----------------
# Called by Node2D2 when game ends
func show_popup(success: bool, remaining_time: int):
	print("🎭 Showing popup - success:", success, " time:", remaining_time)
	
	# Hide all game elements
	hide_game_elements()
	
	# Choose appropriate popup scene
	if success:
		if remaining_time >= 10:
			popup_instance = complete3_scene.instantiate()
		elif remaining_time >= 5:
			popup_instance = complete2_scene.instantiate()
		else:
			popup_instance = complete1_scene.instantiate()
	else:
		popup_instance = retry_scene.instantiate()
	
	# Add popup to scene
	if popup_instance:
		add_child(popup_instance)
		move_child(popup_instance, -1)
		print("✅ Popup instantiated and added")

func hide_game_elements():
	for element in game_elements:
		if element and is_instance_valid(element):
			element.visible = false
	print("Hidden", game_elements.size(), "game elements")

func show_game_elements():
	for element in game_elements:
		if element and is_instance_valid(element):
			element.visible = true
	print("Shown", game_elements.size(), "game elements")

# ---------------- RESTART FUNCTIONALITY ----------------
# Called by popup restart button
func restart_game():
	print("🔄 Control: Restart requested")
	
	# Remove popup
	if popup_instance and is_instance_valid(popup_instance):
		popup_instance.queue_free()
		popup_instance = null
	
	# Show game elements
	show_game_elements()
	
	# Tell the Node2D game manager to restart
	if game_manager and game_manager.has_method("restart_game"):
		game_manager.restart_game()
		print("✅ Control: Restart delegated to Node2D2")
	else:
		print("❌ ERROR: Could not find game_manager.restart_game()")

# ---------------- QUIT BUTTON ----------------
func _on_quitbtn_pressed() -> void:
	var path = "res://scenes/Categories.tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		print("Scene not found: ", path)
