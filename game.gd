extends Node3D

@onready var backgroundMusic = $AudioStreamPlayer3D

# SFX players under hallway/SoundZone
@onready var sfx_players: Array = [
	$hallway/SoundZone/randomSound1,
	$hallway/SoundZone/randomSound2,
	$hallway/SoundZone/randomSound3,
	$hallway/SoundZone/randomSound4,
	$hallway/SoundZone/randomSound5
]

# --- Random noise config ---
@export var min_interval: float = 4.0     # shortest seconds between noises
@export var max_interval: float = 12.0    # longest seconds between noises
@export var play_probability: float = 0.8 # chance to play when the timer fires
@export var min_pitch: float = 0.9        # randomize pitch for variation
@export var max_pitch: float = 1.1
@export var min_db: float = -6.0          # randomize volume (in dB)
@export var max_db: float = 0.0
@export var prevent_overlap: bool = true  # stop a sound if another should fire

func _ready():
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	#backgroundMusic.play()
	randomize()
	_start_random_noise()

# Loop that plays the noise at random times with slight variation
func _start_random_noise() -> void:
	_call_random_noise_loop()

func _call_random_noise_loop() -> void:
	while true:
		var wait_time := randf_range(min_interval, max_interval)
		await get_tree().create_timer(wait_time).timeout
		if randf() <= play_probability:
			_play_random_sfx()

func _play_random_sfx() -> void:
	# pick one of the 5 SFX players at random
	var idx := randi() % sfx_players.size()
	var p: AudioStreamPlayer3D = sfx_players[idx]

	if prevent_overlap:
		# stop any currently playing SFX so the new one is sudden
		for sp in sfx_players:
			if sp.playing:
				sp.stop()

	p.pitch_scale = randf_range(min_pitch, max_pitch)
	p.volume_db = randf_range(min_db, max_db)
	p.seek(0.0)
	p.play()

func _on_sound_zone_body_entered(body: CharacterBody3D) -> void:
	if body.name == "Player":
		_play_random_sfx()
		print("hello")
