extends Node3D

var activated = false
var falling = false

@onready var blood_splatter = $BloodSplatter/blood
@onready var blood_floor = $BloodFloor
@onready var dying_dude = $DyingDude
@onready var dying_dude_area3D = $DyingDude/Area3D
@onready var animation_player = $DyingDude/AnimationPlayer
var extra_drop_applied = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	blood_splatter.emitting = false  # ensure off
	blood_floor.visible = false      # maybe initially hidden
	dying_dude.visible = false       # initially invisible
	if dying_dude is RigidBody3D:
		dying_dude.gravity_scale = 0 # disable gravity initially
		dying_dude.freeze = true      # freeze to prevent accidental movement

	animation_player.animation_finished.connect(_on_animation_finished)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	if PlayerManager.Loop0:
		return
	
	if not activated and (area.is_in_group("player") or area.name == "Player"):
		activated = true
		blood_splatter.emitting = true
		blood_floor.visible = true
		
		# Start timer to enable falling and animation after 1 sec
		var timer = Timer.new()
		timer.wait_time = 1.0
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_start_fall)
		timer.start()
	if area == dying_dude_area3D:   # check that the entering body is our dying dude
		dying_dude.linear_velocity = Vector3.ZERO
		dying_dude.gravity_scale = 0
		dying_dude.freeze = true

func _start_fall():
	dying_dude.visible = true
	var anim_length = animation_player.get_animation("death").length
	animation_player.play("death")
	
	if dying_dude is RigidBody3D:
		dying_dude.gravity_scale = 1.0
		dying_dude.freeze = false

	var mid_drop_timer = Timer.new()
	mid_drop_timer.wait_time = anim_length / 2.0  # half of total animation length
	mid_drop_timer.one_shot = true
	add_child(mid_drop_timer)
	mid_drop_timer.timeout.connect(_apply_mid_animation_drop)
	mid_drop_timer.start()

func _apply_mid_animation_drop():
	if not extra_drop_applied:
		extra_drop_applied = true
		# Translate downward by 0.3 meters
		dying_dude.translate(Vector3(0, -0.3, 0))

func _on_blood_floor_body_entered(body):
	if body == dying_dude:   # check that the entering body is our dying dude
		dying_dude.linear_velocity = Vector3.ZERO
		dying_dude.gravity_scale = 0
		dying_dude.freeze = true

func _on_animation_finished(anim_string: String):
	blood_splatter.emitting = false 
	blood_floor.visible = false   
	$DyingDude/Area3D/CollisionShape3D2.disabled = true
	$DyingDude/CollisionShape3D.disabled = true
