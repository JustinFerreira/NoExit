## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Box Script
## - This is the script for the pickup item box

extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	start_flashing()
	#make it so when it is not Loop 0 box is invisible
	#maybe make it so it is deleted from scene? save space?
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		self.visible = false
		_on_interaction_complete()
		return

func _process(delta: float) -> void:
	#stop flashing when player is about to interact
	if PlayerManager.player.interact_ray.get_collider() == self:
		stop_flashing()
	else:
		start_flashing()

func _on_interacted(body: Variant) -> void:
	#pick up sound
	AudioManager.play_sound(AudioManager.ItemPickup)
	#show next Dialog
	PlayerManager.CharacterHintDialog(EventManager.box_pickup, EventManager.box_pickup_hint)
	#add to inventory
	PlayerManager.AddToInventory("Box", 0.5, true)
	
	#get rid of object in scene 
	if is_inside_tree():
		get_parent().remove_child(self)
		queue_free()
