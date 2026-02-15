## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Scipt
## - the parking garage is set up depending on
## this script and works differently depending on loop

extends Node3D

@onready var target = $Player
@export var fog_remover: FogVolume


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if PlayerManager.sprint_engaged:
		PlayerManager.player.is_sprinting = PlayerManager.sprint_engaged
	PlayerManager.Office = false
	PlayerManager.ParkingGarage = true
	PlayerManager.player = get_tree().current_scene.get_node("Player") 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if fog_remover:
		fog_remover.position = target.position
	if SettingsManager.KillerDisabled:
		return
	get_tree().call_group("enemy" , "target_position" , target.global_transform.origin)
	
