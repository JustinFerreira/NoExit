## No Exit
## Overtime Studios
## Blood Spray Event (COMMON - see GarageEvent)
## - Hidden until the director lets it go off as the player walks in: blood
##   sprays down onto the floor for a few seconds and clears.

extends "res://Scripts/Events/GarageEvent.gd"

const SPRAY_TIME := 3.0

@onready var blood_splatter = $BloodSplatter/blood
@onready var blood_floor = $BloodFloor

func _init() -> void:
	tier = Tier.COMMON
	kind = "blood_spray"
	kind_cooldown = 150.0

func _ready() -> void:
	visible = false
	blood_splatter.visible = false
	blood_splatter.emitting = false
	blood_floor.visible = false

func _fire() -> void:
	visible = true
	blood_splatter.visible = true
	blood_splatter.emitting = true
	blood_floor.visible = true
	await get_tree().create_timer(SPRAY_TIME).timeout
	blood_splatter.emitting = false
	blood_floor.visible = false
