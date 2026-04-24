extends Node3D

@export var sound: AudioStream
var activated = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if sound != null:
		$AudioStreamPlayer3D.stream = sound


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if not activated and (area.is_in_group("player") or area.name == "Player"):
		$AnimationPlayer.play("CarAlarm")
		activated = true
