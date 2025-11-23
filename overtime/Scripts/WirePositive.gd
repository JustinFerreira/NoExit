extends StaticBody3D

var orginal_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.WirePositiveFlashAnimationPlayer = $AnimationPlayer
	AnimationManager.WirePositiveFlash = $WirePositiveFlash
	AnimationManager.ActivateWirePositiveFlashAnimationPlayer()
	AnimationManager.WirePositiveFlashAnimationPlayer.play("WirePositiveFlash")
	PlayerManager.PositiveWire = self
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
	if colliding_body.name == "PositiveBattery":
		AudioManager.play_sound(AudioManager.GetSocket(), -24)
		PlayerManager.player.grabbed_object = null
		PlayerManager.PositiveConnected = true
		PlayerManager.TestConnection()
		self.remove_from_group("grabbable")
		self.remove_from_group("battery_minigame")
		self.visible = false
	if PlayerManager.PositiveConnected == false && colliding_body.name == "NegativeBattery" || "RestZone" || "RestZone2" || "RestZone3" || "RestZone4":
		PlayerManager.player.grabbed_object = null
		self.position = orginal_position
	if colliding_body.name == "WireNegative":
		PlayerManager.player.grabbed_object = null
		self.position = orginal_position
