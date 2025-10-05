extends Node3D

@export var hallway: PackedScene
@export var segment_length: float = 11.8
@export var segments_ahead: int = 3
@export var segments_behind: int = 2
@export var recycle_buffer: float = 8.0
@export var direction: Vector3 = Vector3(0, 0, 1)  # along Z

@onready var player: CharacterBody3D = $"/root/Node3D/Player"

var segments: Array[Node3D] = []
var _dir: Vector3

func _ready() -> void:
	randomize()

	if hallway == null:
		push_error("Hallway not assigned")
		return

	# Normalize movement direction
	_dir = direction.normalized()
	if _dir.length() == 0:
		_dir = Vector3(1, 0, 0)

	# Use player's starting position as origin
	#var spawn_origin = player.global_position

	# Spawn initial segments: behind, at player, ahead
	for i in range(-segments_behind, segments_ahead + 1):
		var seg = hallway.instantiate()
		seg.global_position =  _dir * (i * segment_length)
		add_child(seg)
		segments.append(seg)
		_reroll_segment_lights(seg)

func _process(_delta: float) -> void:
	var player_pos_along = player.global_position.dot(_dir)

	# Find the segment farthest behind
	var first_seg: Node3D = segments[0]
	for seg in segments:
		if seg.global_position.dot(_dir) < first_seg.global_position.dot(_dir):
			first_seg = seg

	# Recycle it to the front if far enough behind
	if player_pos_along - first_seg.global_position.dot(_dir) > segment_length + recycle_buffer:
		segments.erase(first_seg)

		# Find the farthest ahead segment
		var farthest: Node3D = segments[0]
		for seg in segments:
			if seg.global_position.dot(_dir) > farthest.global_position.dot(_dir):
				farthest = seg

		# Move recycled segment in front
		first_seg.global_position = farthest.global_position + _dir * segment_length
		segments.append(first_seg)
		_reroll_segment_lights(first_seg)

func _reroll_segment_lights(node: Node) -> void:
	if node.has_method("reroll"):
		node.reroll()
	for child in node.get_children():
		_reroll_segment_lights(child)
