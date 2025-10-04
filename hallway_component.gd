extends Node3D

# --- Configurable variables ---
@export var hallway: PackedScene
@export var segment_length: float = 10.0
@export var segments_ahead: int = 1     # segments in front of player
@export var segments_behind: int = 1     # segments behind player
@export var recycle_buffer: float = 5.0  # extra distance before recycling
@export var direction: Vector3 = Vector3(0, 0, 1) # movement axis

@onready var player: CharacterBody3D = $"/root/Node3D/Player"

# --- Internal ---
var segments: Array = []

func _ready():
	if hallway == null:
		push_error("Hallway not assigned")
		return

	# Spawn initial segments relative to player
	for i in range(-segments_behind, segments_ahead + 1):
		var seg = hallway.instantiate()
		seg.global_position = direction * (i * segment_length)
		add_child(seg)
		segments.append(seg)


func _process(_delta):
	var player_pos = player.global_position.dot(direction)
	
	# Find the segment farthest behind
	var first_seg = segments[0]
	for seg in segments:
		if seg.global_position.dot(direction) < first_seg.global_position.dot(direction):
			first_seg = seg

	# Check if the segment is far enough behind to recycle
	if player_pos - first_seg.global_position.dot(direction) > segment_length + recycle_buffer:
		segments.erase(first_seg)
		
		# Find the segment farthest ahead
		var farthest = segments[0]
		for seg in segments:
			if seg.global_position.dot(direction) > farthest.global_position.dot(direction):
				farthest = seg
		
		# Move the recycled segment to the front
		first_seg.global_position = farthest.global_position + direction * segment_length
		segments.append(first_seg)
		print("Segment recycled")
