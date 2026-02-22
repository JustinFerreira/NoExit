## No Exit
## Overtime Studios
## Last upadated 2/21/26 by Justin Ferreira
## Car Key Script
## - Script The Car Keys Examinable Pickup Item
## The keys overwrite a lot of existing functions
## but also uses the previous versions with a super call
## There are some changes because how the item is used

extends ExaminableItem


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#put Loops in Event Manager?
	if not PlayerManager.Loop0:
		PlayerManager.set(player_manager_reference, null)
		get_parent().visible = false
		_on_interaction_complete()
		return
	super._ready()
	
func _process(delta: float) -> void:
	#checks if there is more deskitems than needed so keys will flash
	#should change this so that everytime an item is picked up it checks instead of process
	#also add CarKeyFlash to Animation Manager
	#Chnage this to event manager!!!
	if PlayerManager.DeskItems.size() < 3 || PlayerManager.ExamingItem == self:
		stop_flashing()
	elif not PlayerManager.player.interact_ray.get_collider() == self:
		start_flashing()
	else:
		stop_flashing()
	
func _on_interacted(body: Variant) ->  void:
	if PlayerManager.DeskItems.size() >= 3:
		super._on_interacted(body)
		if AnimationManager.ElevatorButtonFlash:
			AnimationManager.ElevatorButtonFlash.visible = true
		PlayerManager.AddToInventory("Car Keys", 0.5, true)
		PlayerManager.gotKeys = true
		AudioManager.play_sound(AudioManager.ImportantItemStinger)
		
		PlayerManager.CharacterHintDialog(EventManager.keys_pickup,EventManager.keys_pickup_hint)
	else:
		PlayerManager.CharacterDialog(EventManager.keys_pickup_early)
