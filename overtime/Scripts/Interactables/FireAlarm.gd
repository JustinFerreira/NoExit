## No Exit
## Overtime Studios
## Fire Alarm
## - Clicking it in the office flashes every office light blue/red for a few
##   seconds, then puts their colours back. Does nothing in the garage.

extends Interactable

## How long the lights flash (seconds).
@export var flash_duration: float = 3.0
## How long each colour lasts while flashing (seconds).
@export var flash_step: float = 0.2

var is_light_flashing: bool = false
var flash_timer: float = 0.0
var original_light_colors: Dictionary = {}

## The office lights' OmniLight3Ds, found once.
var _omni_lights: Array[OmniLight3D] = []

func _ready() -> void:
	super._ready()
	set_process(false)

func _get_omni_lights() -> Array[OmniLight3D]:
	if _omni_lights.is_empty():
		for light_panel_root in PlayerManager.OfficeLights:
			if not is_instance_valid(light_panel_root):
				continue
			var omni_light = light_panel_root.find_child("OmniLight3D", true, false)
			if omni_light is OmniLight3D:
				_omni_lights.append(omni_light)
	return _omni_lights

func _process(delta: float) -> void:
	flash_timer += delta
	if flash_timer >= flash_duration:
		for omni_light in _get_omni_lights():
			omni_light.light_color = original_light_colors.get(omni_light, Color.WHITE)
		is_light_flashing = false
		set_process(false)
		return
	var flash_color := Color.BLUE if int(flash_timer / flash_step) % 2 == 0 else Color.RED
	for omni_light in _get_omni_lights():
		omni_light.light_color = flash_color

func _on_interacted(_body: Variant) -> void:
	if not PlayerManager.ParkingGarage:
		start_emergency_flash()
	else:
		PlayerManager.Hint("Lmao nah that dont work here try the office though")

## Starts the blue/red flash (ignored if it's already flashing).
func start_emergency_flash() -> void:
	if is_light_flashing:
		return
	original_light_colors.clear()
	for omni_light in _get_omni_lights():
		original_light_colors[omni_light] = omni_light.light_color
	is_light_flashing = true
	flash_timer = 0.0
	set_process(true)
