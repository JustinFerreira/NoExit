## No Exit
## Overtime Studios
 
extends Interactable

var open = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	is_interactable = false
	AnimationManager.HoodFlash = self
	AnimationManager.HoodAnimationPlayer = $"../../HoodAnimationPlayer"
	AnimationManager.HoodCollision = $HoodCollisionShape3D
	AnimationManager.CarCollision = $"../../Body/StaticBody3D/CollisionShape3D"
	AnimationManager.ActivateHoodAnimationPlayer()
	#Fix with EventManager so that this is only the case after first interacting with inside of car before doing this

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
			

func _on_interacted(body: Variant) -> void:
	AnimationManager.HoodFlash.stop_flashing()
	AnimationManager.HoodCollision = $HoodCollisionShape3D
	AnimationManager.CarCollision = $"../../Body/StaticBody3D/CollisionShape3D"
	AnimationManager.HoodCollision.call_deferred("set_disabled", true)
	AnimationManager.CarCollision.call_deferred("set_disabled", true)
	if not open:
		AnimationManager.HoodAnimationPlayer.play("Hood")
		AudioManager.play_sound(AudioManager.HoodOpen)
		open = true
	
	
	
	#AnimationManager.DoorFlash.visible = false
	if not PlayerManager.Loop0:
		#AnimationManager.GasIntakeFlash.visible = false
		pass
	PlayerManager.Hood = self
	
	#EventManager? is this needed?
	PlayerManager.gotBattery = false
	
	$"../../HoodCam".current = true
	
	if PlayerManager.Loop0:
		#dialog for no battery in car
		PlayerManager.CharacterDialog(EventManager.loop0_hood_no_battery)
		#turn off player controls
		PlayerManager.InAnimation = true
		#turn off sound effects (need fix)
		AudioManager.cancel_loop_sfx()
		#turn killer back on
		SettingsManager.KillerDisabled = false
		#get killer to designated area
		PlayerManager.teleportEnemy = true
		
	#Fix with EventManager? or LoopManager
	if not PlayerManager.Loop0:
		AnimationManager.HoodCollision.disabled = true
		AnimationManager.CarCollision.disabled = true
		$"../../HoodCam/HoodGame".visible = true
		PlayerManager.hoodUI = $"../../HoodCam/HoodGame"
		PlayerManager.minigameThree = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		PlayerManager.MiniGameModeOn()
	
	
