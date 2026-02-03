extends Interactable

var clickedafterexit = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	is_interactable = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interacted(body: Variant) -> void:
	if not clickedafterexit:
		AudioManager.play_sound(AudioManager.ElevatorDing)
		AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
		is_interactable = false
		clickedafterexit = true
		$"../../AnimationPlayer".play("Take 001")
	
