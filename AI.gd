extends CharacterBody3D

# --- AI Parameters ---
@export var move_speed: float = 3.5
@export var chase_time: float = 5.0
@export var despawn_look_time: float = 2.0
@export var kill_distance: float = 2.0
@export var look_angle_threshold: float = 0.8 # 1 = directly forward, 0 = sideways
@export var max_back_look_counter: int = 5  # increase front spawn chance if player looks back frequently

# --- Scene References ---
@onready var player = get_parent().get_node("Player")
@onready var player_light = player.get_node("Light") # adjust if your player has a Light node
@onready var ambient_audio = get_parent().get_node("AudioStreamPlayer3D") # adjust to your node name

# --- AI State ---
var is_chasing = false
var time_chasing = 0.0
var time_being_looked_at = 0.0
var can_kill = false
var times_player_looked_back = 0

func _ready():
	randomize()
	spawn_relative_to_player()

func spawn_relative_to_player():
	if not player:
		return
	
	# Adaptive front/back spawn chance
	var front_chance = 0.5 + clamp(times_player_looked_back * 0.1, 0, 0.5)
	var spawn_side = "front" if randf() < front_chance else "back"
	var spawn_distance = 8.0
	
	if spawn_side == "back":
		global_position = player.global_position - player.global_transform.basis.z * spawn_distance
		is_chasing = true
		if ambient_audio:
			ambient_audio.volume_db = -80  # silence ambient
		print("AI spawned behind player — chasing initiated!")
	else:
		global_position = player.global_position + player.global_transform.basis.z * spawn_distance
		can_kill = true
		print("AI spawned in front of player — player must hide!")

	look_at(player.global_position)

func _physics_process(delta):
	if not player:
		return
	
	# Track if player is “looking back” (toward AI spawn behind)
	if is_player_looking_behind():
		times_player_looked_back += 1
	else:
		times_player_looked_back = max(times_player_looked_back - delta, 0)
	
	# Check if player is hiding (light off)
	var player_hidden = is_player_hiding()
	if player_hidden:
		print("Player is hiding — light is off")
	else:
		print("Player is exposed — light is on")
	
	# --- Chasing Behavior ---
	if is_chasing:
		time_chasing += delta
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		if time_chasing > chase_time:
			print("AI chase time expired — AI despawning.")
			queue_free()
			return
		
		# Check if player is looking at AI
		if is_player_looking_at_me():
			time_being_looked_at += delta
			print("Player is looking at AI... time being looked at:", time_being_looked_at)
			if time_being_looked_at >= despawn_look_time:
				print("Player looked long enough — AI despawning.")
				queue_free()
		else:
			time_being_looked_at = 0.0

	# --- Front Spawn Kill Mechanic ---
	elif can_kill:
		var dist = global_position.distance_to(player.global_position)
		if dist < kill_distance and not player_hidden:
			player_killed()

# Returns true if player is looking roughly at AI
func is_player_looking_at_me() -> bool:
	var player_forward = -player.global_transform.basis.z.normalized()
	var to_ai = (global_position - player.global_position).normalized()
	var dot = player_forward.dot(to_ai)
	return dot > look_angle_threshold

# Returns true if player is looking backward (mostly away from AI behind)
func is_player_looking_behind() -> bool:
	var player_forward = -player.global_transform.basis.z.normalized()
	var to_ai = (global_position - player.global_position).normalized()
	var dot = player_forward.dot(to_ai)
	return dot < -0.5  # looking mostly backward

# Returns true if player's light is off
func is_player_hiding() -> bool:
	if not player_light:
		return false
	return not player_light.visible

func player_killed():
	print("Player has been caught! AI attack successful.")
	# TODO: trigger death animation, sound, or scene reload
	queue_free()
