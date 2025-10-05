extends CharacterBody3D

# --- TCP for hand tracking ---
var listener: TCPServer = TCPServer.new()
var client: StreamPeerTCP = null

# --- Camera ---
@onready var cam: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Node3D/SpotLight3D

# --- Movement ---
@export var walk_speed: float = 2.0
@export var turn_speed: float = 2.5

# --- Hand-controlled look ---
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0
@export var look_smooth: float = 0.1

# --- Flashlight control ---
@export var energy_smooth: float = 0.1
@export var flashlight_max_energy: float = 8.0
@export var fade_delay: float = 1.0  # seconds before fade starts
var target_energy: float = 0.0
var current_energy: float = 0.0
var hand_detected: bool = false
var last_hand_time: float = 0.0
var python_process_id: int = -1

# --- AI Spawn Config ---
@export var ai_scene: PackedScene  # assign in inspector
var ai_instance: Node3D = null
var ai_visible_timer: float = 0.0

func _ready():
	# Start TCP server
	var result := listener.listen(65432)
	if result != OK:
		print("❌ Failed to start server:", result)
	else:
		print("✅ Server listening on port 65432")

	# --- Launch Python hand tracking process ---
	var python_path = "python3"  # use "python" on Windows
	var script_path = ProjectSettings.globalize_path("res://python/HandTracking.py")

	# Start process in the background
	python_process_id = OS.create_process(python_path, PackedStringArray([script_path]))
	if python_process_id == -1:
		print("❌ Failed to launch hand tracker")
	else:
		print("🚀 Hand tracker launched (PID:", python_process_id, ")")

func _exit_tree():
	# Kill Python process when game closes
	if python_process_id != -1:
		OS.kill(python_process_id)
		print("🧹 Hand tracker closed")

func _process(delta):
	hand_detected = false

	# Accept new client
	if client == null and listener.is_connection_available():
		client = listener.take_connection()
		print("Python connected!")

	# Receive hand tracking messages
	if client != null and client.get_available_bytes() > 0:
		var message := client.get_utf8_string(client.get_available_bytes()).strip_edges()
		for line in message.split("\n", false):
			if line == "":
				continue
			var parts = line.split(",")
			if parts.size() == 2:
				var nx = parts[0].to_float()
				var ny = parts[1].to_float()
				set_target_look(nx, ny)
				hand_detected = true
				last_hand_time = Time.get_unix_time_from_system()

	# --- Flashlight fade when no hand detected ---
	var time_since_hand = Time.get_unix_time_from_system() - last_hand_time
	if time_since_hand > fade_delay:
		target_energy = 0.0
	else:
		target_energy = 1.0

	# --- If hand is NOT detected for too long, spawn AI briefly ---
	if time_since_hand > 2.0:  # after 2 seconds no hand seen
		if ai_instance == null and ai_scene:
			spawn_ai_in_front()
	else:
		if ai_instance != null:
			despawn_ai()

	# --- Despawn AI after visible duration ---
	if ai_instance:
		ai_visible_timer += delta
		if ai_visible_timer >= 3.0:  # visible for 3 seconds
			despawn_ai()

func spawn_ai_in_front():
	ai_instance = ai_scene.instantiate()
	if ai_instance == null:
		return

	# Position AI a bit in front of the player
	var front_offset = -cam.global_transform.basis.z.normalized() * 5.0
	var spawn_pos = global_position + front_offset
	spawn_pos.y = global_position.y
	ai_instance.global_position = spawn_pos

	get_parent().add_child(ai_instance)
	ai_visible_timer = 0.0
	print("👁️ AI appeared in front!")

func despawn_ai():
	if ai_instance and ai_instance.is_inside_tree():
		ai_instance.queue_free()
	ai_instance = null
	print("💨 AI disappeared")

func set_target_look(nx: float, ny: float) -> void:
	# Map X -1..1 to yaw range (-60° to 60°)
	var yaw_range = deg_to_rad(60.0)
	target_yaw = nx * yaw_range

	# Map Y -1..1 to pitch range (-40° to 40°)
	var pitch_range = deg_to_rad(40.0)
	target_pitch = clamp(-ny * pitch_range, deg_to_rad(-40), deg_to_rad(40))

func _physics_process(delta: float) -> void:
	# --- Smooth rotation ---
	current_yaw = lerp_angle(current_yaw, target_yaw, look_smooth)
	current_pitch = lerp_angle(current_pitch, target_pitch, look_smooth)
	rotation.y = current_yaw
	cam.rotation.x = current_pitch

	# --- Smooth flashlight ---
	current_energy = lerp(current_energy, target_energy, energy_smooth)
	if flashlight:
		flashlight.light_energy = current_energy * flashlight_max_energy

	# --- Movement ---
	var direction = Vector3.ZERO
	var is_looking_back = abs(rad_to_deg(current_yaw)) > 90.0  # turned around?

	if Input.is_action_pressed("move_forward"):
		if not is_looking_back:
			direction -= transform.basis.z
		else:
			print("🚫 Can't move forward while looking backward!")

	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z

	if Input.is_action_pressed("move_left"):
		current_yaw += turn_speed * delta
	if Input.is_action_pressed("move_right"):
		current_yaw -= turn_speed * delta

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()
