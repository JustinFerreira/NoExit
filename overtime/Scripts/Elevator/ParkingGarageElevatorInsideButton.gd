## No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Parking Garage Elevator Inside Button
## - This button will close elevator doors and bring player
## to the Office

extends Interactable

const ElevatorRide = preload("res://Scripts/Elevator/ElevatorRide.gd")

var rising: bool = false

var huh: float = 0


## The office elevator's outline box for the panel, in the elevator's own space
## (same model). Our own box is just the click area.
var OUTLINE_SHAPE := Transform3D(Basis.from_scale(Vector3(0.42837, 0.336117, 0.0416481)), Vector3(-0.71832, 1.00532, 1.21599))

## How long the ride up lasts, from the doors finishing closing (same as
## the ride down). The elevator itself never moves.
const RIDE_SECONDS := 5.0

func _ready() -> void:
	# outlined like the office panel: the face toward the inside of the
	# elevator of a box over the buttons (never drawn itself)
	# the click box we sit under stays "visible" (on no render layer, never
	# seen) or the outline would think the button is hidden
	get_parent().visible = true
	get_parent().layers = 0
	use_outline_stand_in(make_outline_shape($"../..", OUTLINE_SHAPE), $"../../ElevatorCollisions/FloorCollision".global_position)
	super._ready()   # Interactable setup (click hookup, outline)

func _process(delta: float) -> void:
	if rising:
		if huh == 0.0:
			# the doors are shut: load the office now, during the ride, so
			# arriving doesn't freeze
			GameState.preload_level(RogueRun.office_scene("res://Levels/Office.tscn"))
		huh += delta


	if huh >= RIDE_SECONDS:
		rising = false
		huh = 0
		AudioManager.cancel_music()
		AudioManager.cancel_loop_sfx()
		# Arrive in the office elevator facing the same way relative to the
		# elevator as the player is now.
		GameState.change_level(RogueRun.office_scene("res://Levels/Office.tscn"), "ElevatorSpawn",
			$"../..".ride_marker_node())

func _on_interacted(_body: Variant) -> void:
	if not $"../..".inside || $"../..".outside:
		PlayerManager.Hint("Get in the Elevator")
		return
	if PlayerManager.cutscene:
		return
	# the ride cutscene from where they stand (see ElevatorRide)
	ElevatorRide.ride_in(self, $"../..".ride_marker(), $"../../ElevatorCollisions/DoorCollision", null, self, start_ride)

## Closes the doors and starts the ride up (clicking the button, or the ride
## cutscene pressing it for the player).
func start_ride() -> void:
	var el = $"../.."
	if not el.up:
		return   # already closing
	el.inside = true
	el.outside = false
	_on_interaction_complete()
	$"../..".up = false
	$"../../ElevatorCollisions/DoorCollision".translate(Vector3(0,-3,0))

	EventManager.Comingfromelevator = true
	$"../../AnimationPlayer".play_backwards("Take 001")
	AudioManager.play_sound(AudioManager.ElevatorCloseDoor)
	# only the elevator is heard while the doors are shut
	AudioManager.shut_out_world($"../..")


