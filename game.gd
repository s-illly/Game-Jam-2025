extends Node3D
@onready var sound = $hallway/SoundZone/AudioStreamPlayer3D
@onready var backgroundMusic = $AudioStreamPlayer3D


func _ready():
	backgroundMusic.play()
	await get_tree().create_timer(10.0).timeout
	sound.play()


func _on_sound_zone_body_entered(body: CharacterBody3D) -> void:
	if body.name == "Player":  # Make sure it’s your player
		sound.play()
		print("hello")
		
