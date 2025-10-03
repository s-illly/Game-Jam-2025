extends RigidBody3D

var listener: TCPServer = TCPServer.new()
var client: StreamPeerTCP = null

var v : Vector3 = Vector3.ZERO
var move_dir: Vector3 = Vector3.ZERO
var target_speed := 0.0
var acceleration := 20.0
var friction := 10.0
var max_speed := 6.0 

var jump_strength := 8.0
var is_grounded := false
var ground_check_distance := 1.1

var turn_cooldown := 2.0
var turn_timer := 0.0

func _ready():
	var result := listener.listen(65432)
	if result != OK:
		print("Failed to start server: ", result)
	else:
		print("Server is listening on port 65432")

func _process(delta):
	if client == null and listener.is_connection_available():
		client = listener.take_connection()
		print("Python connected!")

	if client != null and client.get_available_bytes() > 0:
		var message := client.get_utf8_string(client.get_available_bytes()).strip_edges()
		print("Received from Python:", message)	
		handle_command(message)
	
	if turn_timer > 0.0:
		turn_timer -= delta	

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	update_grounded_check()

	# Current horizontal velocity (no vertical)
	var horizontal_vel = v
	horizontal_vel.y = 0.0

	# Desired velocity
	var desired_velocity = move_dir.normalized() * target_speed

	# Accelerate toward target
	var accel = acceleration * state.step
	horizontal_vel = horizontal_vel.lerp(desired_velocity, accel)

	# Apply friction when no input
	if move_dir == Vector3.ZERO:
		horizontal_vel = horizontal_vel.lerp(Vector3.ZERO, friction * state.step)

	# Combine with vertical
	v.x = horizontal_vel.x
	v.z = horizontal_vel.z

	# Preserve Y velocity (from jump/gravity)
	v.y = state.linear_velocity.y

	# Apply final velocity
	state.linear_velocity = v

func handle_command(cmd: String):
	match cmd:
		"slow walking forward":
			target_speed = 2.0
			move_forward()
		"fast walking forward":
			target_speed = 6.0
			move_forward()
		"slow walking backward":
			target_speed = 2.0
			move_backward()
		"fast walking backward":
			target_speed = 6.0
			move_backward()
		"turning left":
			turn_left()
		"turning right":
			turn_right()
		"jump":
			jump()
		"stop", "idle":
			jump()

func move_forward():
	move_dir = -transform.basis.z

func move_backward():
	move_dir = transform.basis.z

func stop():
	move_dir = Vector3.ZERO
	target_speed = 0.0

func turn_left():
	if turn_timer <= 0.0:
		rotate_y(deg_to_rad(-90))
		turn_timer = turn_cooldown

func turn_right():
	if turn_timer <= 0.0:
		rotate_y(deg_to_rad(90))
		turn_timer = turn_cooldown

func jump():
	if is_grounded:
		v.y = jump_strength
		is_grounded = false  # avoid double-jumping

func update_grounded_check():
	var from = global_transform.origin
	var to = from - Vector3.UP * ground_check_distance

	var query = PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.exclude = [self]

	var space = get_world_3d().direct_space_state
	var result = space.intersect_ray(query)
	is_grounded = result.size() > 0
