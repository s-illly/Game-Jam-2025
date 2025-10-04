# hallway_components.gd
extends Node3D

# --- Configurable variables ---
@export var hallway: PackedScene
@export var segment_length: float = 10.0
@export var segments_ahead: int = 1      # segments in front of player
@export var segments_behind: int = 1     # segments behind player
@export var recycle_buffer: float = 5.0  # extra distance before recycling
@export var direction: Vector3 = Vector3(0, 0, 1) # movement axis

@onready var player: CharacterBody3D = $"/root/Node3D/Player"

# --- Internal ---
var segments: Array[Node3D] = []
var _dir: Vector3

func _ready() -> void:
	randomize()  # make RNG non-deterministic across runs

	if hallway == null:
		push_error("Hallway not assigned")
		return

	# Normalize direction once (avoid scaling dot products)
	_dir = direction
	if _dir.length() == 0.0:
		_dir = Vector3.FORWARD
	else:
		_dir = _dir.normalized()

	# Spawn initial segments relative to player
	for i in range(-segments_behind, segments_ahead + 1):
		var seg: Node3D = hallway.instantiate()
		seg.global_position = _dir * (i * segment_length)
		add_child(seg)
		segments.append(seg)
		_reroll_segment_lights(seg)  # decide flicker per light on initial spawn

func _process(_delta: float) -> void:
	var player_pos_along := player.global_position.dot(_dir)

	# Find the segment farthest behind
	var first_seg: Node3D = segments[0]
	for seg in segments:
		if seg.global_position.dot(_dir) < first_seg.global_position.dot(_dir):
			first_seg = seg

	# If far enough behind, recycle it to the front
	if player_pos_along - first_seg.global_position.dot(_dir) > segment_length + recycle_buffer:
		segments.erase(first_seg)

		# Find the segment farthest ahead
		var farthest: Node3D = segments[0]
		for seg in segments:
			if seg.global_position.dot(_dir) > farthest.global_position.dot(_dir):
				farthest = seg

		# Move recycled segment to the front
		first_seg.global_position = farthest.global_position + _dir * segment_length
		segments.append(first_seg)
		print("Segment recycled")

		# Re-pick which lights flicker in this recycled segment
		_reroll_segment_lights(first_seg)

# Recursively walk a segment and re-roll any light that supports `reroll()`
func _reroll_segment_lights(node: Node) -> void:
	if node.has_method("reroll"):
		node.reroll()  # omni_light_3d.gd provides this
	for child in node.get_children():
		_reroll_segment_lights(child)
