extends StaticBody3D

var orginal_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.WireNegativeFlashAnimationPlayer = $AnimationPlayer
	AnimationManager.WireNegativeFlash = $WireNegativeFlash
	AnimationManager.ActivateWireNegativeFlashAnimationPlayer()
	AnimationManager.WireNegativeFlashAnimationPlayer.play("WireNegativeFlash")
	PlayerManager.NegativeWire = self
	$Area3D.body_entered.connect(_on_area_body_entered)
	orginal_position = self.global_position
	if self.is_in_group("grabbable"):
		pass
	else:
		self.add_to_group("grabbable")
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_area_body_entered(body):
	# This function will be called when a body enters the Area3D
	#print("MeshInstance's Area3D detected body: ", body.name)
	# Check if the body is one of the StaticBody3D nodes we are interested in
	if body.is_in_group("battery_minigame"): # You can use groups or check by name
		handle_collision(body)

func handle_collision(colliding_body):
	# Your collision handling logic here
	#print("Handling collision between ", self.name, " and ", colliding_body.name)
	if colliding_body.name == "NegativeBattery":
		AudioManager.play_sound(AudioManager.GetSocket(), -24)
		PlayerManager.player.grabbed_object = null
		PlayerManager.NegativeConnected = true
		PlayerManager.TestConnection()
		AnimationManager.NegativeBatteryFlash.visible = false
		self.remove_from_group("grabbable")
		self.remove_from_group("battery_minigame")
		self.visible = false
	if PlayerManager.NegativeConnected == false &&  (colliding_body.name == "PositiveBattery" or colliding_body.is_in_group("resetzone")):
		AnimationManager.HideResetZones()
		PlayerManager.CharacterDialog("Oh I probbaly shouldn't do that")
		PlayerManager.player.grabbed_object = null
		self.position = orginal_position
		AnimationManager.NegativeBatteryFlash.visible = false
	if colliding_body.name == "WirePositive":
		AnimationManager.HideResetZones()
		PlayerManager.CharacterDialog("Oh I probbaly shouldn't do that")
		PlayerManager.player.grabbed_object = null
		self.position = orginal_position
		AnimationManager.NegativeBatteryFlash.visible = false
