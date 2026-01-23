## No Exit
## Overtime Studios
 
extends Interactable

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.HoodFlash = $CarHoodVisual
	AnimationManager.HoodFlashAnimationPlayer = $"../../HoodFlashAnimationPlayer"
	AnimationManager.ActivateHoodFlashAnimationPlayer()
	AnimationManager.HoodFlashAnimationPlayer.play("HoodFlash")
	is_interactable = false
	#Fix with EventManager so that this is only the case after first interacting with inside of car before doing this
	if PlayerManager.Loop0 == true:
		is_interactable = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#EventManager should be used so when battery is gotten this happens instead of always checking in process
	if PlayerManager.gotBattery == true:
		is_interactable = true
	
			

func _on_interacted(body: Variant) -> void:
	AnimationManager.HoodFlash.visible = false
	AnimationManager.DoorFlash.visible = false
	if not PlayerManager.Loop0:
		AnimationManager.GasIntakeFlash.visible = false
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
		#Prepare minigame to be displayed as in Battery and Wires
		if !PlayerManager.PositiveConnected:
			PlayerManager.PositiveWire.visible = true
		if !PlayerManager.NegativeConnected:
			PlayerManager.NegativeWire.visible = true
		$"../../HoodCam/HoodGame".visible = true
		PlayerManager.hoodUI = $"../../HoodCam/HoodGame"
		PlayerManager.Battery.visible = true
		PlayerManager.minigameThree = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		PlayerManager.MiniGameModeOn()
	
	
