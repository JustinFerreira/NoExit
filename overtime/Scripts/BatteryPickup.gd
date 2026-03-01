## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## BatteryPickup Script
## - This is the script for the pickup item battery

extends ExaminableItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if PlayerManager.Loop0:
		PlayerManager.set(player_manager_reference, null)
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	start_flashing()
	normal_dialog = EventManager.batterypickup_normal_dialog
	
func _process(delta: float) -> void:
	if PlayerManager.ExamingItem == self || PlayerManager.examining == true:
		stop_flashing()
	elif not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else:
		stop_flashing()
		

func _on_interacted(body: Variant) -> void:
	super._on_interacted(body)
	AnimationManager.HoodFlash.toggle_interactable(true)
	#pick up sound
	AudioManager.play_sound(AudioManager.ImportantItemStinger)
	#add to inventory
	PlayerManager.AddToInventory("Battery", 1.0)
	#changes player state (EventManager?)
	PlayerManager.gotBattery = true
	#turns Hood Flash on (EventManager?)
	AnimationManager.HoodFlash.start_flashing()
