## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Elevator Outside Button
## - Opens the elevator, then takes the player up as a cutscene (see
##   ElevatorRide): they walk in, press the inside button and ride up to the
##   office. The office elevator they arrive in ends it once its doors are open.

extends Interactable

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")


## The office elevator's outline shape for this button, in the elevator's own
## space (same model): a small box right on the button. Our own box is just
## the (bigger) click area.
var OUTLINE_SHAPE := Transform3D(Basis.from_scale(Vector3.ONE * 0.0692717), Vector3(1.00033, 1.14701, 1.36919))

func _ready() -> void:
	# the click box we sit under stays "visible" (on no render layer, never
	# seen) or the outline would think the button is hidden
	get_parent().visible = true
	get_parent().layers = 0
	use_outline_stand_in(make_outline_shape($"../..", OUTLINE_SHAPE))
	super._ready()   # Interactable setup (click hookup, outline)
	is_interactable = false


func _on_interacted(_body: Variant) -> void:
	var el = $"../.."
	AudioManager.play_sound(AudioManager.ElevatorDing)
	AudioManager.play_sound(AudioManager.ElevatorOpenDoor)
	is_interactable = false
	$"../../AnimationPlayer".play("Take 001")
	$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,3,0))
	el.up = true
	var inside_button = $"../../InsideButton/InsideButton"
	await ElevatorRide.ride_in(self, el.ride_marker(), $"../../ElevatorCollisions/DoorCollision",
		$"../../AnimationPlayer", inside_button, inside_button.start_ride)
