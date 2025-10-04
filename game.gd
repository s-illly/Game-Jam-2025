extends Node3D
@onready var sound = $hallway/SoundZone/AudioStreamPlayer3D
#@onready var sound2 = $AudioStreamPlayer3D2
#@onready var sound3 = $AudioStreamPlayer3D3

func _ready():
	await get_tree().create_timer(10.0).timeout
	sound.play()
	
	
	#await get_tree().create_timer(30.0).timeout
	#sound3.play()


func _on_sound_zone_body_entered(body: CharacterBody3D) -> void:
	if body.name == "Player":  # Make sure it’s your player
		sound.play()
		print("hello")
		
