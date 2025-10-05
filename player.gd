extends CharacterBody3D

# --- TCP for hand tracking ---
var listener: TCPServer = TCPServer.new()
var client: StreamPeerTCP = null

# --- Footsteps ---
@onready var foot_audio: AudioStreamPlayer3D = $Footsteps
@export var base_steps_per_sec: float = 1.8
@export var ref_speed: float = 4.0
@export var min_walk_speed: float = 0.4
@export var step_duration: float = 0.25

var _step_timer: float = 0.0
var _left_foot: bool = true
var _step_play_t: float = 0.0

# --- Camera ---
@onready var cam: Camera3D = $Camera3D
@onready var flashlight: SpotLight3D = $Camera3D/Node3D/SpotLight3D

# --- Movement ---
@export var walk_speed: float = 2.0
@export var turn_speed: float = 2.5
@export var gravity: float = 9.8

# --- Hand-controlled look ---
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0
@export var look_smooth: float = 0.1

# --- Forced look state ---
var is_forced_looking_back: bool = false
var forced_look_timer: float = 0.0
@export var forced_look_duration: float = 0.5
@export var forced_look_strength: float = 2

# --- Flashlight control ---
@export var energy_smooth: float = 0.1
@export var flashlight_max_energy: float = 8.0
@export var fade_delay: float = 1.0
var target_energy: float = 0.0
var current_energy: float = 0.0
var hand_detected: bool = false
var last_hand_time: float = 0.0
var python_process_id: int = -1

# --- AI spawn ---
@export var ai_scene: PackedScene
@export var ai_spawn_delay: float = 6.0
var ai_spawn_timer: float = 0.0
var ai_spawned: bool = false
@export var ai_despawn_delay: float = 2.0

func _ready():
	# Start TCP server
	var result := listener.listen(65432)
	if result != OK:
		print("❌ Failed to start server:", result)
	else:
		print("✅ Server listening on port 65432")

	# Launch Python hand tracking process
	var python_path := "python3"
	var script_path := ProjectSettings.globalize_path("res://python/HandTracking.py")
	python_process_id = OS.create_process(python_path, PackedStringArray([script_path]))
	if python_process_id == -1:
		print("❌ Failed to launch hand tracker")
	else:
		print("🚀 Hand tracker launched (PID:", python_process_id, ")")

func _exit_tree() -> void:
	if python_process_id != -1:
		OS.kill(python_process_id)
		print("🧹 Hand tracker closed")

func _process(delta: float) -> void:
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
			var parts := line.split(",")
			if parts.size() == 2:
				var nx := parts[0].to_float()
				var ny := parts[1].to_float()
				set_target_look(nx, ny)
				hand_detected = true
				last_hand_time = Time.get_unix_time_from_system()

	# Handle flashlight timeout fade
	var time_since_hand := Time.get_unix_time_from_system() - last_hand_time
	if time_since_hand > fade_delay:
		target_energy = 0.0

func set_target_look(nx: float, ny: float) -> void:
	var yaw_range := deg_to_rad(60.0)
	target_yaw = nx * yaw_range

	var pitch_range := deg_to_rad(40.0)
	target_pitch = clamp(-ny * pitch_range, deg_to_rad(-40.0), deg_to_rad(40.0))
	target_energy = 1.0

func _physics_process(delta: float) -> void:
	# --- Forced backward glance ---
	if is_forced_looking_back:
		 # Force camera instantly 180 degrees behind
		var behind_yaw = deg_to_rad(180)
		current_yaw = behind_yaw
		rotation.y = current_yaw
		# Keep pitch unchanged
		cam.rotation.x = current_pitch  # keep pitch unaffected

		# Stop all movement while looking back
		velocity = Vector3.ZERO

		# Count down timer
		forced_look_timer -= delta
		if forced_look_timer <= 0:
			is_forced_looking_back = false
		return  # skip normal movement

	# --- Smooth camera rotation from hand tracking ---
	current_yaw = lerp_angle(current_yaw, target_yaw, look_smooth)
	current_pitch = lerp_angle(current_pitch, target_pitch, look_smooth)
	rotation.y = current_yaw
	cam.rotation.x = current_pitch

	# --- Random nudge to look back ---
	if randf() < 0.02:
		trigger_forced_look_back()

	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# --- Movement ---
	var direction := Vector3.ZERO
	if Input.is_action_pressed("move_backward"):
		rotation.y += PI
	elif Input.is_action_pressed("move_forward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		current_yaw += turn_speed * delta
	if Input.is_action_pressed("move_right"):
		current_yaw -= turn_speed * delta

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	move_and_slide()

	# --- Flashlight smoothing ---
	current_energy = lerp(current_energy, target_energy, energy_smooth)
	if flashlight:
		flashlight.light_energy = current_energy * flashlight_max_energy

	# --- Footstep sounds ---
	if Input.is_action_pressed("move_forward"):
		var rate: float = base_steps_per_sec
		_step_timer -= delta
		if _step_timer <= 0.0:
			_play_footstep_slice()
			_step_timer = 1.0 / rate
	else:
		if foot_audio and foot_audio.playing:
			foot_audio.stop()
			_step_play_t = 0.0
		_step_timer = min(_step_timer, 0.1)

	if foot_audio and foot_audio.playing:
		_step_play_t += delta
		if _step_play_t >= step_duration:
			foot_audio.stop()
			_step_play_t = 0.0
	else:
		_step_play_t = 0.0


func trigger_forced_look_back():
	is_forced_looking_back = true
	forced_look_timer = forced_look_duration
	print("🚨 Forced backward glance triggered!")


func force_look_back(strength: float = 2.0):
	var behind_yaw = deg_to_rad(180)
	target_yaw = lerp_angle(target_yaw, behind_yaw, strength)


func _play_footstep_slice() -> void:
	if foot_audio == null:
		push_warning("[foot] Missing Footsteps node")
		return
	if foot_audio.stream == null:
		push_warning("[foot] Footsteps stream is NULL.")
		return

	# Small variation
	foot_audio.pitch_scale = randf_range(0.97, 1.03)
	foot_audio.volume_db = randf_range(-1.0, 0.0)

	# Start at a random position inside the long file
	var total_len: float = 0.0
	if "get_length" in foot_audio.stream:
		total_len = foot_audio.stream.get_length()
	var max_start: float = max(0.0, total_len - step_duration)
	var start_pos: float = randf_range(0.0, max_start) if total_len > 0.0 else 0.0

	# Alternate left/right panning
	if _left_foot:
		foot_audio.position.x = 0.12
	else:
		foot_audio.position.x = -0.12
	_left_foot = not _left_foot

	# Play the slice
	foot_audio.stop()
	foot_audio.play(start_pos)
	_step_play_t = 0.0
