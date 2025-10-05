extends Control

# UI References
@onready var master_slider: HSlider = $Container/ValueLabel/HSlider
@onready var master_label: Label = $Container/ValueLabel
@onready var music_slider: HSlider = $Container/ValueLabel2/HSlider
@onready var music_label: Label = $Container/ValueLabel2
@onready var sound_slider: HSlider = $Container/ValueLabel3/HSlider
@onready var sound_label: Label = $Container/ValueLabel3
@onready var back_button: TextureButton = $BackButton

var is_master_dragging: bool = false
var is_music_dragging: bool = false
var is_sound_dragging: bool = false

func _ready():
	setup_sliders()
	load_current_settings()
	connect_signals()

func setup_sliders():
	# Configure slider ranges (0-100 for percentage)
	master_slider.min_value = 0
	master_slider.max_value = 100
	master_slider.step = 1
	
	music_slider.min_value = 0
	music_slider.max_value = 100
	music_slider.step = 1
	
	sound_slider.min_value = 0
	sound_slider.max_value = 100
	sound_slider.step = 1

func load_current_settings():
	# Load current values from Global (which syncs with AudioManager)
	master_slider.value = Global.get_master_volume_percent()
	music_slider.value = Global.get_music_volume_percent()
	sound_slider.value = Global.get_sound_volume_percent()
	
	# Update labels
	update_labels()

func connect_signals():
	# Connect slider value changes
	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sound_slider.value_changed.connect(_on_sound_volume_changed)
	
	master_slider.drag_started.connect(func(): is_master_dragging = true)
	master_slider.drag_ended.connect(_on_master_drag_ended)
	
	music_slider.drag_started.connect(func(): is_music_dragging = true)
	music_slider.drag_ended.connect(_on_music_drag_ended)
	
	sound_slider.drag_started.connect(func(): is_sound_dragging = true)
	sound_slider.drag_ended.connect(_on_sound_drag_ended)
	
	back_button.pressed.connect(_on_back_pressed)


func _on_master_volume_changed(value: float):
	Global.set_master_volume(value / 100.0)
	update_labels()

func _on_music_volume_changed(value: float):
	Global.set_music_volume(value / 100.0)
	update_labels()

func _on_sound_volume_changed(value: float):
	Global.set_sound_volume(value / 100.0)
	update_labels()

func _on_master_drag_ended(value_changed: bool):
	is_master_dragging = false
	if value_changed:
		AudioManager.play_sound("button_click")

func _on_music_drag_ended(value_changed: bool):
	is_music_dragging = false
	if value_changed:
		AudioManager.play_sound("button_click")

func _on_sound_drag_ended(value_changed: bool):
	is_sound_dragging = false
	if value_changed:
		AudioManager.play_sound("button_click")

func _on_back_pressed():
	AudioManager.play_sound("button_click")
	# Return to previous scene or close settings
	get_tree().change_scene_to_file("res://scenes/StudentMain.tscn")

func update_labels():
	master_label.text = str(int(master_slider.value)) + "%"
	music_label.text = str(int(music_slider.value)) + "%"
	sound_label.text = str(int(sound_slider.value)) + "%"
