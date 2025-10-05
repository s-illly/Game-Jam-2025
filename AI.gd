extends CharacterBody3D

@export var move_speed: float = 1.2
@export var chase_time: float = 5.0
@export var despawn_look_time: float = 2.0
@export var kill_distance: float = 2.0
@export var look_angle_threshold: float = 0.8
@export var max_back_look_counter: int = 5
@export var grace_period: float = 15.0  # seconds AI waits before chasing


@onready var player: CharacterBody3D = $Player
@onready var player_light: SpotLight3D = player.get_node("Camera3D/Node3D/SpotLight3D")

var is_chasing = false
var can_kill = false
var time_chasing = 0.0
var time_being_looked_at = 0.0
var times_player_looked_back = 0
var grace_timer = 0.0

func _ready():
	randomize()
	spawn_relative_to_player()
	grace_timer = grace_period

func _physics_process(delta):
	if not player:
		return

	# Grace period before chasing
	if grace_timer > 0:
		grace_timer -= delta
		return

	# Player looking behind
	if is_player_looking_behind():
		times_player_looked_back += 1
		print("Played looked back")
	else:
		times_player_looked_back = max(times_player_looked_back - delta, 0)

	# Check hiding
	var player_hidden = is_player_hiding()

	# --- Chasing behavior ---
	if is_chasing:
		time_chasing += delta
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		
		if time_chasing > chase_time:
			queue_free()
			return
		
		if is_player_looking_at_me():
			time_being_looked_at += delta
			if time_being_looked_at >= despawn_look_time:
				queue_free()
		else:
			time_being_looked_at = 0.0

	# --- Front spawn kill ---
	elif can_kill:
		var dist = global_position.distance_to(player.global_position)
		if dist < kill_distance and not player_hidden:
			player_killed()

func spawn_relative_to_player():
	if not player:
		return

	var front_chance = 0.5 + clamp(times_player_looked_back * 0.1, 0, 0.5)
	var spawn_side = "front" if randf() < front_chance else "back"
	var spawn_distance = 8.0
	
	if spawn_side == "back":
		global_position = player.global_position - player.global_transform.basis.z * spawn_distance
		is_chasing = true
	else:
		global_position = player.global_position + player.global_transform.basis.z * spawn_distance
		can_kill = true

	look_at(player.global_position)

func is_player_looking_at_me() -> bool:
	var player_forward = -player.global_transform.basis.z.normalized()
	var to_ai = (global_position - player.global_position).normalized()
	return player_forward.dot(to_ai) > look_angle_threshold

func is_player_looking_behind() -> bool:
	var player_forward = -player.global_transform.basis.z.normalized()
	var to_ai = (global_position - player.global_position).normalized()
	return player_forward.dot(to_ai) < -0.5

func is_player_hiding() -> bool:
	if not player_light:
		print("Player is hiding")
		return true
	else:
		print("Player is not hiding")
	return player_light.light_energy <= 0.01
	
	

func player_killed():
	print("Player has been caught!")
	queue_free()
