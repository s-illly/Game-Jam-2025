extends CharacterBody3D

# --- Parameters ---
@export var move_speed: float = 2.5
@export var chase_time: float = 5.0
@export var despawn_look_time: float = 2.0
@export var grace_period: float = 5.0
@export var back_look_threshold: int = 3
@export var spawn_distance_min: float = 12.0
@export var spawn_distance_max: float = 20.0
@export var horizontal_offset: float = 4.0

# --- References ---
var player: CharacterBody3D
var player_light: SpotLight3D
var ambient_audio: AudioStreamPlayer3D  # optional

# --- State ---
var is_chasing = false
var can_kill = false
var grace_timer = 0.0
var times_player_looked_back = 0
var spawn_in_front = false
var despawn_timer = 0.0
var stay_duration = 3.0

# --- Add new state variables ---
var look_back_timer: float = 0.0
@export var required_look_back_time: float = 2.0  # seconds player must look back to despawn AI
@export var force_look_strength_min: float = 2.0 # min nudge strength
@export var force_look_strength_max: float = 2.0 # max nudge strength
@export var look_back_event_chance: float = 0.5  # chance per frame to nudge player

func _ready():
	randomize()
	grace_timer = grace_period
	if player:
		player_light = player.get_node_or_null("Camera3D/Node3D/SpotLight3D")
	ambient_audio = get_parent().get_node_or_null("AudioStreamPlayer3D")
	spawn_relative_to_player()


func _physics_process(delta: float) -> void:
	if not player:
		return

	# Front spawn AI behavior
	if spawn_in_front:
		despawn_timer += delta
		if despawn_timer >= stay_duration:
			queue_free()
			print("AI despawned (front spawn)")
		return

	# --- AI behind player ---
	var to_player = (player.global_position - global_position).length()

	# Player is looking at AI
	if is_player_looking_behind():
		look_back_timer += delta
		if look_back_timer >= required_look_back_time:
			queue_free()
			print("AI despawned because player looked back")
			return
	else:
		look_back_timer = 0.0
		# Randomly nudge player to look back if AI is very close
		if to_player <= 4.0 and randf() < look_back_event_chance:
			if player.has_method("force_look_back"):
				var strength = randf_range(force_look_strength_min, force_look_strength_max)
				player.force_look_back(strength)

	# Normal chasing
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	despawn_timer += delta
	if despawn_timer >= chase_time:
		queue_free()
		print("AI despawned (chase end)")
		

func spawn_relative_to_player():
	if not player:
		return

	# --- Decide spawn side ---
	if times_player_looked_back >= back_look_threshold:
		spawn_in_front = true
	else:
		spawn_in_front = randf() < 0.2  # 20% chance otherwise

	var spawn_pos = player.global_position
	var spawn_distance: float

	if spawn_in_front:
		# --- FRONT SPAWN: slightly closer distance ---
		spawn_distance = randf_range(spawn_distance_min * 0.6, spawn_distance_min * 0.9)
		spawn_pos += player.global_transform.basis.z * spawn_distance
		is_chasing = false
		can_kill = false
	else:
		# --- BEHIND SPAWN: normal chase distance ---
		spawn_distance = randf_range(spawn_distance_min, spawn_distance_max)
		spawn_pos -= player.global_transform.basis.z * spawn_distance
		is_chasing = true
		can_kill = true

	# --- Random left/right offset ---
	spawn_pos.x += randf_range(-horizontal_offset, horizontal_offset)

	# --- Raycast to find floor ---
	var ray_origin = spawn_pos + Vector3(0, 5, 0)
	var ray_end = spawn_pos + Vector3(0, -50, 0)
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = ray_origin
	ray_params.to = ray_end
	var result = space_state.intersect_ray(ray_params)
	if result.size() > 0:
		spawn_pos.y = result.position.y
	else:
		spawn_pos.y = player.global_position.y

	# --- Apply spawn position ---
	global_position = spawn_pos
	look_at(player.global_position)


func is_player_looking_behind() -> bool:
	if not player:
		return false
	var player_forward = -player.global_transform.basis.z.normalized()
	var to_ai = (global_position - player.global_position).normalized()
	return player_forward.dot(to_ai) < -0.5
