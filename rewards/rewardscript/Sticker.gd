# Enhanced Sticker.gd - Add unlock/lock functionality
extends Control
class_name Sticker

var sticker_texture: Texture2D
var associated_letter: String = ""  # NEW: Which letter unlocks this sticker
var is_unlocked: bool = false       # NEW: Lock/unlock state

@onready var texture_rect = $TextureRect

var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	add_to_group("stickers")  # For easy access
	setup_sticker()
	update_lock_status()

func setup_sticker():
	if not sticker_texture:
		push_warning("No sticker texture provided")
		return
	
	if not texture_rect:
		push_error("TextureRect node not found")
		return
	
	# Configure texture rectangle
	texture_rect.texture = sticker_texture
	texture_rect.custom_minimum_size = Vector2(300, 300)
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	
	# Set container size
	custom_minimum_size = Vector2(320, 320)
	
	# Create border style
	create_border_style()

func create_border_style():
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(1, 1, 1, 0.1)
	
	var border_width = 1
	border_style.set_border_width_all(border_width)
	border_style.border_color = Color(0.8, 0.8, 0.8, 0.5)
	border_style.set_corner_radius_all(4)
	
	add_theme_stylebox_override("panel", border_style)

func set_sticker_data(texture: Texture2D, letter: String):
	sticker_texture = texture
	associated_letter = letter
	setup_sticker()
	check_unlock_status()

func check_unlock_status():
	# Check if the associated letter is completed
	if associated_letter == "":
		is_unlocked = true  # Default stickers (no letter requirement)
		return
	
	# Check with Global's letter completion cache
	is_unlocked = Global.letter_completion_cache.get(associated_letter, false)
	update_lock_status()

func update_lock_status():
	# Simply dim the sticker when locked
	if texture_rect:
		if is_unlocked:
			texture_rect.modulate = Color.WHITE  # Full color when unlocked
		else:
			texture_rect.modulate = Color(0.4, 0.4, 0.4, 0.6)  # Heavily dimmed when locked

func _gui_input(event):
	# Only allow interaction if unlocked
	if not is_unlocked:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			start_drag(event.position)
		else:
			stop_drag()
	
	elif event is InputEventMouseMotion and is_dragging:
		global_position = get_global_mouse_position() - drag_offset

func start_drag(mouse_pos):
	if not is_unlocked:
		return
		
	is_dragging = true
	drag_offset = mouse_pos
	
	var main = get_tree().get_first_node_in_group("main")
	if main and get_parent() != main:
		var current_global_pos = global_position
		reparent(main)
		global_position = current_global_pos
		move_to_front()

func stop_drag():
	is_dragging = false
	
	var board = get_tree().get_first_node_in_group("board")
	if board:
		var board_rect = board.get_global_rect()
		if board_rect.has_point(global_position):
			if get_parent() != board:
				var current_global_pos = global_position
				reparent(board)
				position = current_global_pos - board.global_position

# NEW: Method to refresh unlock status (call when letter completion updates)
func refresh_unlock_status():
	check_unlock_status()
