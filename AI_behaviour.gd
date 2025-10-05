extends CharacterBody3D

# --- Parameters ---
@export var move_speed: float = 2.0
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

func _ready():
	randomize()
	grace_timer = grace_period
	if player:
		player_light = player.get_node_or_null("Camera3D/Node3D/SpotLight3D")
	ambient_audio = get_parent().get_node_or_null("AudioStreamPlayer3D")
	spawn_relative_to_player()

func _physics_process(delta):
	if not player:
		return

	# Grace period before AI acts
	if grace_timer > 0:
		grace_timer -= delta
		return

	# --- Front spawn behavior (non-chasing) ---
	if spawn_in_front:
		# Disappear if player’s light is off or after a few seconds
		if player_light and player_light.light_energy <= 0.01:
			queue_free()
			return
		despawn_timer += delta
		if despawn_timer >= stay_duration:
			queue_free()
			print("Despawned AI (front)")
		return

	# --- Chasing behavior ---
	if is_chasing:
		var direction = (player.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()

		# Random ambient mute for tension
		if ambient_audio and randf() < 0.01:
			ambient_audio.volume_db = -80

		despawn_timer += delta
		if despawn_timer >= chase_time:
			queue_free()
			print("Despawned AI (chase end)")
	else:
		# AI that’s behind but not actively chasing (rare)
		despawn_timer += delta
		if despawn_timer >= stay_duration:
			queue_free()
			print("Despawned AI (passive)")

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
