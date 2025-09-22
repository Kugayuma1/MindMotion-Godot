extends Control

signal connection_lost
signal connection_restored

@onready var status_label = $TextureRect/Label
@onready var retry_button = $TextureRect/Retry
@onready var retry_label = $TextureRect/Retry/Label
@onready var exit_button = $TextureRect/Exit
@onready var timer = $Timer

var _online: bool = true
var _animating: bool = false
var _checking: bool = false

func _ready():
	visible = false
	retry_button.pressed.connect(_on_retry_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	timer.timeout.connect(_check_connection)
	timer.start(5.0)
	_check_connection()

func is_online() -> bool:
	return _online

func show_overlay():
	_show_overlay()

func hide_overlay():
	_hide_overlay()

func _check_connection() -> void:
	if _checking:
		return
	
	_checking = true
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 5.0
	
	var url = "https://connectivitycheck.gstatic.com/generate_204"
	var err = http.request(url)
	if err != OK:
		_checking = false
		http.queue_free()
		return
	
	var result = await http.request_completed
	var request_result: int = result[0]
	var response_code: int = result[1]
	
	var was_online = _online
	
	if request_result == HTTPRequest.RESULT_SUCCESS:
		_online = (response_code == 204 or response_code == 200)
	else:
		# Try backup URL
		_online = await _try_backup_connection_check()
	
	http.queue_free()
	_checking = false
	
	if was_online and not _online:
		emit_signal("connection_lost")
		_show_overlay()
	elif not was_online and _online:
		emit_signal("connection_restored")
		_hide_overlay()

func _try_backup_connection_check() -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 4.0
	
	var backup_url = "https://httpbin.org/status/200"
	var err = http.request(backup_url)
	if err != OK:
		http.queue_free()
		return false
	
	var result = await http.request_completed
	var request_result: int = result[0] 
	var response_code: int = result[1]
	
	http.queue_free()
	return (request_result == HTTPRequest.RESULT_SUCCESS and response_code == 200)

func _show_overlay():
	visible = true
	get_tree().paused = true
	if get_parent():
		get_parent().move_child(self, get_parent().get_child_count() - 1)
	status_label.text = "No Internet Connection"
	retry_label.text = "Reconnect"
	retry_button.disabled = false
	_animating = false
	timer.stop()

func _hide_overlay():
	visible = false
	get_tree().paused = false
	_animating = false
	timer.start(5.0)

func _on_retry_pressed():
	# Force reset states to prevent getting stuck
	_animating = false
	_checking = false
	
	_animating = true
	retry_button.disabled = true
	retry_label.text = "Reconnecting"
	_animate_dots()
	
	# Temporarily restart automatic timer
	get_tree().paused = false
	timer.start(1.0)
	
	await get_tree().create_timer(3.0).timeout
	
	# Always reset states
	_animating = false
	_checking = false
	retry_button.disabled = false
	retry_label.text = "Reconnect"
	
	timer.stop()
	if visible:
		get_tree().paused = true
	
	if _online:
		emit_signal("connection_restored")
		_hide_overlay()
	else:
		status_label.text = "Still No Connection"

func _animate_dots():
	_dot_animation()

func _dot_animation():
	var dots = ""
	var start_time = Time.get_ticks_msec()
	var max_duration = 4000  # 4 seconds max
	
	while _animating and visible:
		var elapsed = Time.get_ticks_msec() - start_time
		if elapsed > max_duration:
			break
			
		dots += "."
		if dots.length() > 3:
			dots = ""
		if retry_label:
			retry_label.text = "Reconnecting" + dots
		await get_tree().create_timer(0.5).timeout
	
	if retry_label:
		retry_label.text = "Reconnect"

func _on_exit_pressed():
	get_tree().quit()
