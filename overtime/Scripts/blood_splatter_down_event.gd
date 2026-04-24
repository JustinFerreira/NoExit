extends Node3D

@onready var blood_splatter = $BloodSplatter/blood
@onready var blood_floor = $BloodFloor
var activated = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$".".visible = false
	blood_splatter.visible = false
	blood_splatter.emitting = false  # ensure off
	blood_floor.visible = false   


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if not activated and (area.is_in_group("player") or area.name == "Player"):
		$".".visible = true
		blood_splatter.visible = true
		blood_splatter.emitting = true  # ensure off
		blood_floor.visible = true   
		await get_tree().create_timer(3).timeout
		blood_splatter.emitting = false  # ensure off
		blood_floor.visible = false   
		activated = true
