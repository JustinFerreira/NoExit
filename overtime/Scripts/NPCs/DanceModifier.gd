## No Exit
## Overtime Studios
## Dance Modifier
## - The upper half of the fire alarm dance (Dance.gd puts this on an NPC's
##   Skeleton3D while the legs step in place to the walk animation): arms
##   up over the head waving (or pumping, by style), hips bouncing and
##   twisting, head bobbing. Runs after the animation each frame
##   (SkeletonModifier3D), so it sits on top of whatever is playing.
## - Mixamo rig: the model faces +Z, its left arm is on +X.

extends SkeletonModifier3D

## 0 = both arms up waving side to side, 1 = raise the roof (pumping),
## 2 = one arm up, the other swinging (disco)
var style := 0
var speed := 1.0
var phase := 0.0
var _t := 0.0
var _last_ms := 0

func _ready() -> void:
	_last_ms = Time.get_ticks_msec()

func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	var now := Time.get_ticks_msec()
	_t += minf((now - _last_ms) / 1000.0, 0.1) * speed
	_last_ms = now
	var t := _t * TAU * 1.1 + phase      # about 1.1 beats a second
	var beat := sin(t)
	var bounce := absf(sin(t))

	# hips: a hop on every beat and a twist side to side
	var hips := sk.find_bone("mixamorig_Hips")
	if hips >= 0:
		var rest_y := absf(sk.get_bone_rest(hips).origin.y)
		var pos := sk.get_bone_pose_position(hips)
		pos.y += rest_y * 0.035 * bounce
		sk.set_bone_pose_position(hips, pos)
		var rot := sk.get_bone_pose_rotation(hips)
		sk.set_bone_pose_rotation(hips, Quaternion(Vector3.UP, sin(t * 0.5) * 0.45) * rot)

	# arms
	match style:
		0:
			_arm(sk, "mixamorig_LeftArm", 1.0, 2.5 + beat * 0.35)
			_arm(sk, "mixamorig_RightArm", -1.0, 2.5 - beat * 0.35)
		1:
			var pump := 1.9 + bounce * 0.9
			_arm(sk, "mixamorig_LeftArm", 1.0, pump)
			_arm(sk, "mixamorig_RightArm", -1.0, pump)
			_bend(sk, "mixamorig_LeftForeArm", 1.0, 1.2 - bounce * 1.0)
			_bend(sk, "mixamorig_RightForeArm", -1.0, 1.2 - bounce * 1.0)
		_:
			_arm(sk, "mixamorig_LeftArm", 1.0, 2.6 + beat * 0.25)
			_arm(sk, "mixamorig_RightArm", -1.0, 0.6 + (beat * 0.5 + 0.5) * 0.9)
			_bend(sk, "mixamorig_RightForeArm", -1.0, 0.8)

	# head bob
	var head := sk.find_bone("mixamorig_Head")
	if head >= 0:
		var gp := sk.get_bone_global_pose(head)
		gp.basis = Basis(Vector3.RIGHT, bounce * 0.25 - 0.1) * gp.basis
		sk.set_bone_global_pose(head, gp)

## Swings an upper arm out and up round the body's forward axis (`side`:
## +1 left, -1 right) by `angle` radians from hanging down.
func _arm(sk: Skeleton3D, bone: String, side: float, angle: float) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		return
	var gp := sk.get_bone_global_pose(i)
	gp.basis = Basis(Vector3.BACK, angle * side) * gp.basis
	sk.set_bone_global_pose(i, gp)

## Bends a forearm in towards the head.
func _bend(sk: Skeleton3D, bone: String, side: float, angle: float) -> void:
	var i := sk.find_bone(bone)
	if i < 0:
		return
	var gp := sk.get_bone_global_pose(i)
	gp.basis = Basis(Vector3.BACK, angle * side) * gp.basis
	sk.set_bone_global_pose(i, gp)
