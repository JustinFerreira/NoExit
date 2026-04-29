extends Interactable

var is_light_flashing = false
var flash_timer = 0.0
var flash_duration = 3.0
var original_light_colors = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if is_light_flashing:
		flash_timer += delta
		
		if flash_timer >= flash_duration:
			# End flashing and restore white light
			for light_panel_root in PlayerManager.OfficeLights:
				var omni_light = light_panel_root.find_child("OmniLight3D", true, false)
				if omni_light and omni_light is OmniLight3D:
					omni_light.light_color = Color.WHITE
			is_light_flashing = false
		else:
			# Alternate between blue and red (switch every 0.2 seconds for faster flashing)
			var should_be_blue = int(flash_timer / 0.2) % 2 == 0
			
			for light_panel_root in PlayerManager.OfficeLights:
				var omni_light = light_panel_root.find_child("OmniLight3D", true, false)
				if omni_light and omni_light is OmniLight3D:
					omni_light.light_color = Color.BLUE if should_be_blue else Color.RED


func _on_interacted(body: Variant) -> void:
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
