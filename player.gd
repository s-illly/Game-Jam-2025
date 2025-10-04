extends CharacterBody3D

# --- TCP for hand tracking ---
var listener: TCPServer = TCPServer.new()
var client: StreamPeerTCP = null

# --- Camera ---
@onready var cam: Camera3D = $Camera3D

# --- Movement ---
@export var walk_speed: float = 4.0
@export var jump_speed: float = 8.0
@export var gravity: float = 24.0
@export var turn_speed: float = 2.5  # optional, for keyboard turning

# --- Hand-controlled look ---
var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0
@export var look_smooth: float = 0.1  # lerp factor for smoothing

func _ready():
	var result := listener.listen(65432)
	if result != OK:
		print("Failed to start server: ", result)
	else:
		print("Server is listening on port 65432")

func _process(delta):
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
				var nx = parts[0].to_float()  # -1..1 normalized X
				var ny = parts[1].to_float()  # -1..1 normalized Y
				set_target_look(nx, ny)

func set_target_look(nx: float, ny: float) -> void:
	# Map X -1..1 to yaw range (-60° to 60°)
	var yaw_range = deg_to_rad(60.0)
	target_yaw = nx * yaw_range

	# Map Y -1..1 to pitch range (-40° to 40°)
	var pitch_range = deg_to_rad(40.0)
	target_pitch = clamp(-ny * pitch_range, deg_to_rad(-40), deg_to_rad(40))

func _physics_process(delta: float) -> void:
	# --- Smoothly interpolate camera/player rotation ---
	current_yaw = lerp_angle(current_yaw, target_yaw, look_smooth)
	current_pitch = lerp_angle(current_pitch, target_pitch, look_smooth)

	rotation.y = current_yaw
	cam.rotation.x = current_pitch

	# --- Keyboard movement (W/S) ---
	var direction = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		direction -= transform.basis.z
	if Input.is_action_pressed("move_backward"):
		direction += transform.basis.z
	if Input.is_action_pressed("move_left"):
		current_yaw += turn_speed * delta
	if Input.is_action_pressed("move_right"):
		current_yaw -= turn_speed * delta

	direction = direction.normalized()
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed

	# --- Move the player ---
	move_and_slide()
