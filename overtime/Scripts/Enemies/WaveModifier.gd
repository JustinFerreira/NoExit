## No Exit
## Overtime Studios
## Wave Modifier
## - Makes a skeleton wave its right arm (on top of whatever animation it's
##   playing): the upper arm raised, the forearm swinging side to side. Used
##   by the illusion (Illusion.gd). Which way each bone has to turn is worked
##   out once, by trying (the hand highest for the raise, most to the side
##   for the swing) - so it doesn't depend on how the rig's axes were set up.

extends SkeletonModifier3D

@export var upper_arm := "bicepR"
@export var forearm := "forearmR"
@export var hand := "metacarpalR3-MIDDLE"
## Degrees the upper arm is raised, and the forearm swings either way.
@export var raise := 120.0
@export var swing := 28.0
## Swings a second.
@export var speed := 2.2

var _raise_axis := Vector3.ZERO
var _swing_axis := Vector3.ZERO
var _t := 0.0

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var up_i := sk.find_bone(upper_arm)
	var fa_i := sk.find_bone(forearm)
	var h_i := sk.find_bone(hand)
	if up_i < 0 or fa_i < 0 or h_i < 0:
		return
	var up_pose := sk.get_bone_pose_rotation(up_i)
	var fa_pose := sk.get_bone_pose_rotation(fa_i)
	if _raise_axis == Vector3.ZERO:
		_raise_axis = _best_axis(sk, up_i, up_pose, h_i, raise, func(p: Vector3): return p.y)
		sk.set_bone_pose_rotation(up_i, up_pose * Quaternion(_raise_axis, deg_to_rad(raise)))
		var side := sk.global_basis.x.normalized()
		_swing_axis = _best_axis(sk, fa_i, fa_pose, h_i, swing, func(p: Vector3): return absf(p.dot(side)))
	_t += get_process_delta_time() if is_inside_tree() else 0.016
	sk.set_bone_pose_rotation(up_i, up_pose * Quaternion(_raise_axis, deg_to_rad(raise)))
	sk.set_bone_pose_rotation(fa_i, fa_pose * Quaternion(_swing_axis, deg_to_rad(swing * sin(_t * TAU * speed * 0.5))))

## Of the six axis directions, the one turning `bone` by `degrees` that
## scores highest for the hand's world position.
func _best_axis(sk: Skeleton3D, bone: int, pose: Quaternion, hand_i: int, degrees: float, score: Callable) -> Vector3:
	var best := Vector3.RIGHT
	var best_s := -INF
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		sk.set_bone_pose_rotation(bone, pose * Quaternion(axis, deg_to_rad(degrees)))
		var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(hand_i).origin
		var s: float = score.call(p - sk.global_position)
		if s > best_s:
			best_s = s
			best = axis
	sk.set_bone_pose_rotation(bone, pose)
	return best
