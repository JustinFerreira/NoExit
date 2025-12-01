extends OmniLight3D

@export var noise: NoiseTexture2D
var timePassed := 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	timePassed += delta
	
	var sampledNoise = noise.noise.get_noise_1d(timePassed*2)
	light_energy = abs(sampledNoise * 10)
	pass
