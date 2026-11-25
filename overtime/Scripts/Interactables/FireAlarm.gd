## No Exit
## Overtime Studios
## Fire Alarm
## - Clicking it in the office flashes every office light blue/red for a few
##   seconds, then puts their colours back. Does nothing in the garage.
## - Easter egg: if there's anyone in the office to dance (group
##   "office_dancer" - Dance.gd), the lights flash for party_duration
##   instead, the elevator tune plays, and everybody gets up and dances.

extends Interactable

## How long the lights flash (seconds).
@export var flash_duration: float = 3.0
## How long each colour lasts while flashing (seconds).
@export var flash_step: float = 0.2
## How long the flashing - and the dancing - lasts when there's anyone to
## dance (seconds).
@export var party_duration: float = 12.0

const Dance := preload("res://Scripts/NPCs/Dance.gd")
var _duration := 3.0
var _music: AudioStreamPlayer

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
	# the party music fades out over the last second
	if _music and _duration - flash_timer < 1.0:
		_music.volume_db = linear_to_db(clampf(_duration - flash_timer, 0.001, 1.0)) - 8.0
	if flash_timer >= _duration:
		if _music:
			_music.queue_free()
			_music = null
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
	_duration = flash_duration
	# anyone here to dance? then it's a party
	if get_tree().get_node_count_in_group("office_dancer") > 0:
		_duration = party_duration
		Dance.party(get_tree(), party_duration)
		_music = AudioStreamPlayer.new()
		_music.stream = AudioManager.ElevatorMusic
		_music.bus = "Music"
		_music.volume_db = -8.0
		add_child(_music)
		_music.play()
	set_process(true)
