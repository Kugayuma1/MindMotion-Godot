# AudioManager.gd - Add this as an AutoLoad singleton
extends Node

# Audio players
@onready var music_player: AudioStreamPlayer
@onready var sound_player: AudioStreamPlayer

# Volume settings (0.0 to 1.0)
var master_volume: float = 1.0
var music_volume: float = 1.0
var sound_volume: float = 1.0

# Current music track
var current_music: AudioStream
var is_music_playing: bool = false
var previous_music: String = ""

# Audio resources - Add your audio files here
var music_tracks = {
	"menu": preload("res://audio/music/Falling Behind (Instrumental).mp3"),
	"game": preload("res://audio/music/gamebg1.mp3"),
	"clap": preload("res://audio/music/Clap.mp3"),
	"wave": preload("res://audio/music/wave.mp3")
}

var sound_effects = {
	"button_click": preload("res://audio/sounds/pop1.mp3"),
	"motivational_5s": preload("res://audio/sounds/10secs.mp3"),
	"motivational_10s": preload("res://audio/sounds/luvvoice.com-20251103-aHbLGC.mp3")
}

func _ready():
	# Create audio players
	music_player = AudioStreamPlayer.new()
	sound_player = AudioStreamPlayer.new()
	
	add_child(music_player)
	add_child(sound_player)
	
	music_player.finished.connect(_on_music_finished)
	
	if Global:
		master_volume = Global.master_volume
		music_volume = Global.music_volume
		sound_volume = Global.sound_volume
	
	# Apply initial volumes
	update_volumes()

# Auto-loop music when it finishes
func _on_music_finished():
	if is_music_playing and current_music and not music_player.stream_paused:
		music_player.play()

# Play background music
func play_music(track_name: String, fade_in: bool = true):
	if track_name in music_tracks:
		var new_track = music_tracks[track_name]
		
		# Don't restart if same track is already playing
		if current_music == new_track and music_player.playing:
			return  # Exit early - don't restart
			
		current_music = new_track
		music_player.stream = current_music
		
		# Calculate target volume based on settings
		var final_music_volume = master_volume * music_volume
		var target_db = linear_to_db(final_music_volume) if final_music_volume > 0.001 else -80
		
		if fade_in:
			# Fade in effect
			var tween = create_tween()
			music_player.volume_db = -80
			music_player.play()
			tween.tween_method(_set_music_volume_db, -80, target_db, 1.0)
		else:
			music_player.volume_db = target_db
			music_player.play()
		
		is_music_playing = true
	else:
		print("Music track not found: ", track_name)

# Play temporary music (like stage music) - saves current music to resume later
func play_temp_music(track_name: String, fade_in: bool = true):
	# Only save previous music if we're actually switching to a different track
	if track_name in music_tracks:
		var new_track = music_tracks[track_name]
		
		# If same track is already playing, don't do anything
		if current_music == new_track and music_player.playing:
			return  # Music already playing, no need to restart
		
		# Save current music before switching
		if is_music_playing and current_music:
			for key in music_tracks:
				if music_tracks[key] == current_music:
					previous_music = key
					break
	
	# Play the temporary music
	play_music(track_name, fade_in)

# Resume previous music (returns to background music after temp music)
func resume_previous_music(fade_in: bool = true):
	if previous_music != "":
		play_music(previous_music, fade_in)
		previous_music = ""
	else:
		# Fallback to menu music if no previous music
		play_music("menu", fade_in)

# Stop background music
func stop_music(fade_out: bool = true):
	if not music_player.playing:
		return
		
	if fade_out:
		var current_db = music_player.volume_db
		var tween = create_tween()
		tween.tween_method(_set_music_volume_db, current_db, -80, 1.0)
		tween.tween_callback(music_player.stop)
	else:
		music_player.stop()
	
	is_music_playing = false

# Pause music temporarily (for popups, motion detection)
func pause_music():
	if music_player.playing:
		music_player.stream_paused = true

# Unpause music
func unpause_music():
	if music_player.stream_paused:
		music_player.stream_paused = false

# Stop current music and resume background music
func stop_and_resume_background():
	stop_music(true)
	await get_tree().create_timer(1.0).timeout  # Wait for fade
	resume_previous_music(true)

# Play sound effect
func play_sound(sound_name: String):
	if sound_name in sound_effects:
		# Create a temporary audio player for overlapping sounds
		var temp_player = AudioStreamPlayer.new()
		add_child(temp_player)
		
		temp_player.stream = sound_effects[sound_name]
		
		# Apply volume based on master and sound settings
		var final_sound_volume = master_volume * sound_volume
		if final_sound_volume > 0.001:
			temp_player.volume_db = linear_to_db(final_sound_volume)
		else:
			temp_player.volume_db = -80
		
		temp_player.play()
		
		# Remove the temporary player when done
		temp_player.finished.connect(temp_player.queue_free)
	else:
		print("Sound effect not found: ", sound_name)

# Set master volume (0.0 to 1.0)
func set_master_volume(volume: float):
	master_volume = clamp(volume, 0.0, 1.0)
	update_volumes()

# Set music volume (0.0 to 1.0)
func set_music_volume(volume: float):
	music_volume = clamp(volume, 0.0, 1.0)
	update_volumes()

# Set sound volume (0.0 to 1.0)
func set_sound_volume(volume: float):
	sound_volume = clamp(volume, 0.0, 1.0)
	update_volumes()

# Update all volume levels
func update_volumes():
	if music_player:
		var final_music_volume = master_volume * music_volume
		if final_music_volume > 0.001:
			music_player.volume_db = linear_to_db(final_music_volume)
		else:
			music_player.volume_db = -80
	# Sound effects volume is applied when they're played

# Helper function for music fade effects
func _set_music_volume_db(volume_db: float):
	music_player.volume_db = volume_db

# Get volume as percentage (for UI sliders)
func get_master_volume_percent() -> int:
	return int(master_volume * 100)

func get_music_volume_percent() -> int:
	return int(music_volume * 100)

func get_sound_volume_percent() -> int:
	return int(sound_volume * 100)
