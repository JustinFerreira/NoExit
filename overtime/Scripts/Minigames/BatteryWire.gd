## No Exit
## Overtime Studios
## Battery Wire (base for WirePositive / WireNegative)
## - One of the two cables in the battery minigame. The player drags it
##   (group "grabbable"); touching its own battery terminal connects it
##   (PlayerManager.TestConnection checks if both are on). Touching the wrong
##   terminal, a reset zone or the other wire sparks and snaps it back.
## - WirePositive.gd / WireNegative.gd just pick which side this is.

extends StaticBody3D

## true = the positive (red) wire, false = the negative one.
var positive: bool = true
## Where it snaps back to after a spark (where it was last picked up from).
var original_position: Vector3

func _ready() -> void:
	# hidden until the hood is open (AnimationManager shows the battery and
	# both wires when it finishes opening) - otherwise they poke out through
	# the closed hood
	visible = false
	var side := "Positive" if positive else "Negative"
	AnimationManager.set("Wire%sFlash" % side, get_node("Wire%sFlash" % side))
	AnimationManager.loop_animation($AnimationPlayer, "Wire%sFlash" % side)
	if positive:
		PlayerManager.PositiveWire = self
	else:
		PlayerManager.NegativeWire = self
	$Area3D.body_entered.connect(_on_area_body_entered)
	original_position = global_position
	if not is_in_group("grabbable"):
		add_to_group("grabbable")

func _on_area_body_entered(body: Node) -> void:
	if body.is_in_group("battery_minigame"):
		handle_collision(body)

func _connected() -> bool:
	return PlayerManager.PositiveConnected if positive else PlayerManager.NegativeConnected

func _other_connected() -> bool:
	return PlayerManager.NegativeConnected if positive else PlayerManager.PositiveConnected

## This wire's flash, its battery terminal's flash, and the other wire's flash.
func _own_flash() -> Node3D:
	return AnimationManager.WirePositiveFlash if positive else AnimationManager.WireNegativeFlash
func _terminal_flash() -> Node3D:
	return AnimationManager.PositiveBatteryFlash if positive else AnimationManager.NegativeBatteryFlash
func _other_flash() -> Node3D:
	return AnimationManager.WireNegativeFlash if positive else AnimationManager.WirePositiveFlash

## Reacts to touching a battery terminal, a reset zone or the other wire.
func handle_collision(colliding_body: Node) -> void:
	var own_terminal := "PositiveBattery" if positive else "NegativeBattery"
	var wrong_terminal := "NegativeBattery" if positive else "PositiveBattery"
	var other_wire := "WireNegative" if positive else "WirePositive"
	if colliding_body.name == own_terminal:
		AudioManager.play_sound(AudioManager.GetSocket(), -24)
		PlayerManager.player.grabbed_object = null
		if positive:
			PlayerManager.PositiveConnected = true
		else:
			PlayerManager.NegativeConnected = true
		PlayerManager.TestConnection()
		if not _other_connected():
			_other_flash().visible = true
		_terminal_flash().visible = false
		remove_from_group("grabbable")
		remove_from_group("battery_minigame")
		visible = false
	var wrong_spot: bool = not _connected() and (colliding_body.name == wrong_terminal or colliding_body.is_in_group("resetzone"))
	if wrong_spot or colliding_body.name == other_wire:
		_spark_and_reset()

## Spark, a line of dialog, and the wire snaps back to where it started.
func _spark_and_reset() -> void:
	AnimationManager.HideResetZones()
	PlayerManager.CharacterDialog(EventManager.battery_minigame_resetzone)
	AudioManager.play_sound(AudioManager.GetSpark())
	PlayerManager.player.grabbed_object = null
	global_position = original_position
	_terminal_flash().visible = false
	_own_flash().visible = true
	if not _other_connected():
		_other_flash().visible = true

## Remembers where it is now as the spot to snap back to.
func SetOriginalPos() -> void:
	original_position = global_position
