## No Exit
## Overtime Studios
## Falling Body Event (LEGENDARY - once per playthrough, see GarageEvent)
## - When the director allows it as the player walks in: blood sprays from
##   the ceiling and a second later a body drops from it and plays its
##   "death" animation, landing in the pool of blood. When the animation ends
##   the blood clears and the body stops colliding.

extends "res://Scripts/Events/GarageEvent.gd"

const FALL_DELAY := 1.0

@onready var blood_splatter = $BloodSplatter/blood
@onready var blood_floor = $BloodFloor
@onready var dying_dude = $DyingDude
@onready var dying_dude_area3D = $DyingDude/Area3D
@onready var animation_player = $DyingDude/AnimationPlayer

func _init() -> void:
	tier = Tier.LEGENDARY
	kind = "falling_body"
	min_killer_distance = 25.0

func _ready() -> void:
	blood_splatter.emitting = false
	blood_floor.visible = false
	dying_dude.visible = false
	if dying_dude is RigidBody3D:
		dying_dude.gravity_scale = 0   # never left to the physics (see _start_fall)
		dying_dude.freeze = true
	animation_player.animation_finished.connect(_on_animation_finished)

func _fire() -> void:
	blood_splatter.emitting = true
	blood_floor.visible = true
	get_tree().create_timer(FALL_DELAY).timeout.connect(_start_fall)

## The drop: not left to the physics (the body is a scaled RigidBody3D and
## used to fall straight through the floor - and it started up inside the
## deck above, out of sight). It's held frozen, put just under the ceiling
## of the event's own floor, and dropped onto that floor, speeding up like a
## real fall.
func _start_fall() -> void:
	var span := _floor_and_ceiling()
	var top := _origin_below_top()
	animation_player.play("death")
	animation_player.seek(0.0, true)   # pose it now, to measure it
	var land_y: float = span.x + BONE_CLEARANCE + _bones_below_origin()
	var start_y: float = maxf(span.y - 0.1 - top, land_y)
	dying_dude.global_position.y = start_y
	dying_dude.visible = true
	var fall := start_y - land_y
	var time := sqrt(2.0 * fall / 9.8) if fall > 0.0 else 0.0
	var tw := create_tween()
	tw.tween_property(dying_dude, "global_position:y", land_y, maxf(time, 0.05)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): AudioManager.play_sound(AudioManager.Thud4, -4.0))
	_floor_y = span.x
	await tw.finished
	_landed = true

## Once down, the death animation folds it up (knees, hands): its collision
## box doesn't follow that, so every frame the body is kept up just enough
## that none of its bones sink below the floor (BONE_CLEARANCE for the flesh
## round them).
const BONE_CLEARANCE := 0.1
var _landed := false
var _floor_y := 0.0

func _process(_delta: float) -> void:
	if not _landed or not dying_dude.visible:
		return
	dying_dude.global_position.y = _floor_y + BONE_CLEARANCE + _bones_below_origin()

## How far its lowest bone is below its origin, in the pose it's in now.
func _bones_below_origin() -> float:
	var skel: Skeleton3D = dying_dude.get_node_or_null("Skeleton3D")
	if skel == null or skel.get_bone_count() == 0:
		return _origin_above_bottom()
	var lowest := INF
	for i in skel.get_bone_count():
		lowest = minf(lowest, (skel.global_transform * skel.get_bone_global_pose(i).origin).y)
	return dying_dude.global_position.y - lowest

## (floor y, ceiling y) where the blood lands - the event's own floor.
func _floor_and_ceiling() -> Vector2:
	var space := get_world_3d().direct_space_state
	var ex: Array[RID] = [dying_dude.get_rid()]
	var at: Vector3 = blood_floor.global_position + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 6.0, 0xFFFFFFFF, ex)
	var hit := space.intersect_ray(q)
	var floor_y: float = hit.position.y if hit else global_position.y
	q = PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + 0.3, at.z), Vector3(at.x, floor_y + 12.0, at.z), 0xFFFFFFFF, ex)
	hit = space.intersect_ray(q)
	var ceil_y: float = hit.position.y if hit else floor_y + 4.0
	return Vector2(floor_y, ceil_y)

func _body_box() -> AABB:
	var shape_node: CollisionShape3D = $DyingDude/CollisionShape3D
	if shape_node and shape_node.shape:
		return shape_node.global_transform * shape_node.shape.get_debug_mesh().get_aabb()
	return AABB(dying_dude.global_position, Vector3.ZERO)

func _origin_above_bottom() -> float:
	return dying_dude.global_position.y - _body_box().position.y

func _origin_below_top() -> float:
	return _body_box().end.y - dying_dude.global_position.y

func _on_animation_finished(_anim_string: String) -> void:
	blood_splatter.emitting = false
	blood_floor.visible = false
	$DyingDude/Area3D/CollisionShape3D2.disabled = true
	$DyingDude/CollisionShape3D.disabled = true
