extends Interactable

@onready var animation_player
@onready var door_collision = $"../ElevatorCollisions/DoorCollision"

var fall = false
var fall_speed = 2.0
var interactd = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#animation_player.connect("animation_finished", _on_animation_finished)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fall == true:
		$"..".position.y -= fall_speed * delta
		
	print($"..".position.y)
	
	if $"..".position.y <= -50:
		print("HELLOOOOO")
		get_tree().change_scene_to_file("res://Scenes/Levels/ParkingGarageLoop1.tscn")

func _on_animation_finished(anim_name: String):
	print("Animation", anim_name)
	
	if anim_name == "DoorClosed":
		door_collision.translate(Vector3(0,-3,0))
		fall = true

func _on_interacted(body: Variant) -> void:
	if interactd == false:
		door_collision.translate(Vector3(0,-3,0))
		fall = true
		interactd = true
