extends Node3D
@export var hallway: PackedScene
@export var segment_length: float = 11.8
@export var segments_ahead: int = 3
@export var segments_behind: int = 2
@export var recycle_buffer: float = 8.0
@export var direction: Vector3 = Vector3(0, 0, 1)  # along Z
@onready var player: CharacterBody3D = $"/root/Node3D/Player"

# Audio fade variables
var audio_fade_timer: float = 0.0
var audio_fade_check_interval: float = 10.0
var audio_fade_state: int = 0  # 0=normal, 1=fading_out, 2=muted, 3=fading_in
var audio_fade_elapsed: float = 0.0
var audio_fade_duration: float = 1.0
var audio_mute_timer: float = 0.0
var audio_mute_duration: float = 10.0
var audio_original_volumes: Dictionary = {}

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
		seg.global_position = _dir * (i * segment_length)
		add_child(seg)
		segments.append(seg)
		_reroll_segment_lights(seg)
	
	# Store original volumes of all audio players
	_store_audio_volumes(get_tree().root)

func _store_audio_volumes(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node not in audio_original_volumes:
			audio_original_volumes[node] = node.volume_db
			print("Found audio player: ", node.name, " with volume: ", node.volume_db)
	for child in node.get_children():
		_store_audio_volumes(child)

func _get_all_audio_players() -> Array:
	var players = []
	_collect_audio_players(get_tree().root, players)
	return players

func _collect_audio_players(node: Node, players: Array) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		players.append(node)
	for child in node.get_children():
		_collect_audio_players(child, players)

func _process(delta: float) -> void:
	var player_pos_along = player.global_position.dot(_dir)
	
	# Handle audio fade logic
	_handle_audio_fade(delta)
	
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
		
		# Store volumes of any new audio players
		_store_audio_volumes(first_seg)

func _handle_audio_fade(delta: float) -> void:
	# Increment the timer
	audio_fade_timer += delta
	
	# Check every 10 seconds if we should trigger a fade
	if audio_fade_timer >= audio_fade_check_interval and audio_fade_state == 0:
		audio_fade_timer = 0.0
		# 1 in 3 chance for easier testing (change back to 10 if you want)
		if randi() % 5 == 0:
			print("Starting audio fade out!")
			audio_fade_state = 1
			audio_fade_elapsed = 0.0
	
	# Handle active fading states
	if audio_fade_state == 1:  # Fading out
		audio_fade_elapsed += delta
		var fade_progress = clamp(audio_fade_elapsed / audio_fade_duration, 0.0, 1.0)
		
		var players = _get_all_audio_players()
		for audio_player in players:
			if is_instance_valid(audio_player):
				var original_vol = audio_original_volumes.get(audio_player, 0.0)
				audio_player.volume_db = lerp(original_vol, -80.0, fade_progress)
		
		if fade_progress >= 1.0:
			print("Fade out complete, muting for 10 seconds")
			audio_fade_state = 2
			audio_mute_timer = 0.0
	
	elif audio_fade_state == 2:  # Muted
		audio_mute_timer += delta
		if audio_mute_timer >= audio_mute_duration:
			print("Starting audio fade in!")
			audio_fade_state = 3
			audio_fade_elapsed = 0.0
	
	elif audio_fade_state == 3:  # Fading in
		audio_fade_elapsed += delta
		var fade_progress = clamp(audio_fade_elapsed / audio_fade_duration, 0.0, 1.0)
		
		var players = _get_all_audio_players()
		for audio_player in players:
			if is_instance_valid(audio_player):
				var original_vol = audio_original_volumes.get(audio_player, 0.0)
				audio_player.volume_db = lerp(-80.0, original_vol, fade_progress)
		
		if fade_progress >= 1.0:
			print("Fade in complete, back to normal")
			audio_fade_state = 0

func _reroll_segment_lights(node: Node) -> void:
	if node.has_method("reroll"):
		node.reroll()
	for child in node.get_children():
		_reroll_segment_lights(child)
