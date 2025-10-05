extends Node3D

# --- AI Spawner Config ---
@export var ai_scene: PackedScene
@export var player_path: NodePath  # assign Player node in Inspector
@export var spawn_interval: float = 8.0
@export var max_active_ai: int = 2
@export var spawn_distance_min: float = 10.0
@export var spawn_distance_max: float = 18.0
@export var side_offset_max: float = 4.0

# --- Internal ---
var player: Node3D
var active_ai: Array = []
var timer: float = 0.0

func _ready():
	if not ai_scene:
		push_error("AI scene not assigned!")
		return

	player = get_node_or_null(player_path)
	if not player:
		push_error("Player not found!")
		return

func _process(delta):
	if not player or not ai_scene:
		return

	timer += delta

	if timer >= spawn_interval and active_ai.size() < max_active_ai:
		spawn_ai()
		timer = 0.0

	# Cleanup freed AI
	for ai in active_ai.duplicate():
		if not ai or ai.is_queued_for_deletion():
			active_ai.erase(ai)

func spawn_ai():
	var ai_instance = ai_scene.instantiate()
	if not ai_instance:
		return

	ai_instance.player = player

	# --- Random spawn direction ---
	var spawn_side = randi_range(0, 3)
	var direction: Vector3

	match spawn_side:
		0:
			direction = -player.global_transform.basis.z.normalized()  # Behind
		1:
			direction = player.global_transform.basis.z.normalized()   # Front
		2:
			direction = -player.global_transform.basis.x.normalized()  # Left
		3:
			direction = player.global_transform.basis.x.normalized()   # Right

	var spawn_distance = randf_range(spawn_distance_min, spawn_distance_max)
	var spawn_position = player.global_position + direction * spawn_distance

	# --- Add small horizontal randomness ---
	spawn_position.x += randf_range(-side_offset_max, side_offset_max)
	spawn_position.z += randf_range(-side_offset_max, side_offset_max)

	# --- Raycast to find floor height ---
	var space_state = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.new()
	ray_params.from = spawn_position + Vector3(0, 5, 0)
	ray_params.to = spawn_position + Vector3(0, -30, 0)

	var result = space_state.intersect_ray(ray_params)
	if result.size() > 0:
		spawn_position.y = result.position.y
	else:
		spawn_position.y = player.global_position.y  # fallback

	# --- Clamp to reasonable bounds (stay in hallway width) ---
	spawn_position.x = clamp(spawn_position.x, -side_offset_max * 3, side_offset_max * 3)
	spawn_position.z = clamp(spawn_position.z, -100, 100)

	# --- Place AI ---
	ai_instance.global_position = spawn_position
	add_child(ai_instance)
	active_ai.append(ai_instance)

	print("✅ AI spawned safely at:", spawn_position)
