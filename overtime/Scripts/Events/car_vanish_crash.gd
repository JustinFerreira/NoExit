extends Node3D

var activated = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$AnimationPlayer.play("INVISIBLE")


func _on_area_3d_area_entered(area: Area3D) -> void:
	if not activated and (area.is_in_group("player") or area.name == "Player"):
		$AnimationPlayer.play("VanishCar")
		activated = true
