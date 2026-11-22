## No Exit
## Overtime Studios
## Booth Door
## - The toll booth's door (made by TollBooth). Clicking it fades the screen,
##   moves the player through to the other side (inside <-> outside) facing
##   away from the door, and fades back in.

extends Interactable

## The TollBooth this door belongs to.
var booth: Node3D
var _busy := false

func _on_interacted(_body: Variant) -> void:
	var player = PlayerManager.player
	if _busy or booth == null or not is_instance_valid(player):
		return
	_busy = true
	var going_in: bool = not booth.is_inside(player.global_position)
	var spot: Vector3 = booth.inside_spot if going_in else booth.outside_spot
	var target: Vector3 = booth.global_transform * spot
	# face away from the door: into the booth when going in, out when leaving
	var away: Vector3 = target - booth.global_transform * booth.door_center
	away.y = 0.0
	AudioManager.play_sound(AudioManager.CarDoorOpen)
	var fade := _fade_layer()
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.2)
	await tw.finished
	player.global_position = target
	player.velocity = Vector3.ZERO
	if away.length_squared() > 0.0001 and player.has_method("set_look_yaw"):
		player.set_look_yaw(atan2(-away.x, -away.z))
	AudioManager.play_sound(AudioManager.CarDoorClose)
	tw = create_tween()
	tw.tween_property(fade, "color:a", 0.0, 0.25)
	await tw.finished
	fade.get_parent().queue_free()
	_busy = false

func _fade_layer() -> ColorRect:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	get_tree().root.add_child(layer)
	return rect
