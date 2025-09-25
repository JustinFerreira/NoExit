extends Interactable

var fall = false
var fall_speed = 2.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fall == true:
		$"..".position.y -= fall_speed * delta
		
	print($"..".position.y)


func _on_interacted(body: Variant) -> void:
	print("MOVING")
	fall = true
	
