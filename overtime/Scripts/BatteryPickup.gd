## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## BatteryPickup Script
## - This is the script for the pickup item battery

extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	visible = false
	if not PlayerManager.Loop0:
		visible = true
		start_flashing()
	
func _process(delta: float) -> void:
	pass
		

func _on_interacted(body: Variant) -> void:
	AnimationManager.HoodFlash.toggle_interactable(true)
	#pick up sound
	AudioManager.play_sound(AudioManager.ItemPickup)
	#add to inventory
	PlayerManager.AddToInventory("Battery", 1.0)
	#changes player state (EventManager?)
	PlayerManager.gotBattery = true
	#turns Hood Flash on (EventManager?)
	AnimationManager.HoodFlash.start_flashing()
	
	#get rid of object in scene 
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
