# omni_light_3d.gd
extends OmniLight3D

@export var min_energy: float = 0.0
@export var max_energy: float = 8.0
@export var flicker_speed: float = 0.4

var is_flickering: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	# Decide if THIS light flickers on startup
	reroll()
	# Optional: lets us find all flicker lights via group
	add_to_group("flicker_lights")

# Call this to re-pick whether the light flickers (used when a segment is recycled)
func reroll(seed: int = -1) -> void:
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	# Exactly ~1 in 5 lights flicker
	is_flickering = (rng.randi() % 5) == 0
	# print("Light flickering:", is_flickering)

func _process(delta: float) -> void:
	if is_flickering:
		# Smooth random flicker between min/max
		light_energy = lerp(light_energy, randf_range(min_energy, max_energy), flicker_speed)
	else:
		# Hold steady at the midpoint
		light_energy = (min_energy + max_energy) / 2.0
