extends Interactable

var is_light_flashing: bool = false
var flash_timer: float = 0.0
var flash_duration: float = 3.0
var original_light_colors: Dictionary = {}

# The office lights' OmniLight3Ds, found once (the flash used to search
# every light panel every frame).
var _omni_lights: Array[OmniLight3D] = []

func _get_omni_lights() -> Array[OmniLight3D]:
	if _omni_lights.is_empty():
		for light_panel_root in PlayerManager.OfficeLights:
			if not is_instance_valid(light_panel_root):
				continue
			var omni_light = light_panel_root.find_child("OmniLight3D", true, false)
			if omni_light is OmniLight3D:
				_omni_lights.append(omni_light)
	return _omni_lights


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_light_flashing:
		flash_timer += delta
		
		if flash_timer >= flash_duration:
			# End flashing and restore white light
			for omni_light in _get_omni_lights():
				omni_light.light_color = Color.WHITE
			is_light_flashing = false
		else:
			# Alternate between blue and red (switch every 0.2 seconds for faster flashing)
			var should_be_blue = int(flash_timer / 0.2) % 2 == 0
			
			var flash_color := Color.BLUE if should_be_blue else Color.RED
			for omni_light in _get_omni_lights():
				omni_light.light_color = flash_color


func _on_interacted(_body: Variant) -> void:
	if not PlayerManager.ParkingGarage:
		start_emergency_flash()
	else:
		PlayerManager.Hint("Lmao nah that dont work here try the office though")
	
	
	

func start_emergency_flash():
	if is_light_flashing:
		return
	
	# Store original colors before flashing
	original_light_colors.clear()
	for light_panel_root in PlayerManager.OfficeLights:
		var omni_light = light_panel_root.find_child("OmniLight3D", true, false)
		if omni_light and omni_light is OmniLight3D:
			original_light_colors[omni_light] = omni_light.light_color
	
	is_light_flashing = true
	flash_timer = 0.0
