## No Exit
## Overtime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Box Script
## - This is the script for the pickup item box

extends ExaminableItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#make it so when it is not Loop 0 box is invisible
	#maybe make it so it is deleted from scene? save space?
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		PlayerManager.set(player_manager_reference, null)
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	start_flashing()
	normal_dialog = EventManager.box_pickup_hint
	

func _process(delta: float) -> void:
	#stop flashing when player is about to interact
	if PlayerManager.player.interact_ray.get_collider() == self || PlayerManager.ExamingItem == self:
		stop_flashing()
	else:
		start_flashing()

func _on_interacted(body: Variant) -> void:
	
	super._on_interacted(body)
	#pick up sound
	AudioManager.play_sound(AudioManager.ImportantItemStinger)
	#show next Dialog
	#PlayerManager.CharacterHintDialog(EventManager.box_pickup, EventManager.box_pickup_hint)
	#add to inventory
	PlayerManager.AddToInventory("Box", 0.5, true)
