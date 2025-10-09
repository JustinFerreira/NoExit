extends Node3D

@onready var animation_player = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerManager.player = $"../Player"
	PlayerManager.ApplyPlayerRotation()
	#Play Open Animation and on Animation finish Move door Collision
	animation_player.connect("animation_finished", _on_animation_finished)
	$AnimationPlayer.play("Take 001")
	if PlayerManager.gotKeys:
		PlayerManager.ResetInventory()
		PlayerManager.AddToInventory("DoorKey", 0.5)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_animation_finished(anim_name: String):
	#print("Animation", anim_name)
	
	if anim_name == "Take 001":
		$ElevatorCollisions/DoorCollision.translate(Vector3(0,3,0))
		PlayerManager.Dialog("Where did I leave that blue car that I drive all the time?")
