## No Exit
## Overtime Studios
## Last updated 2/14/26 by Josh Chisholm
## Office Lights
## - Makes an OmniLight3D flicker: its brightness follows a noise texture
##   over time. Not attached to any scene yet.

extends OmniLight3D

## Noise to read the flicker from (needs a NoiseTexture2D with a noise set).
@export var noise: NoiseTexture2D
var timePassed: float = 0.0

func _process(delta: float) -> void:
	if noise == null or noise.noise == null:
		return
	timePassed += delta
	light_energy = abs(noise.noise.get_noise_1d(timePassed * 2) * 10)
