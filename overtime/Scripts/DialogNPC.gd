extends Interactable

# Rotation variables
@export var rotation_speed: float = 2.0  # Adjust this to control turn speed
var is_rotating: bool = false
var target_rotation: float = 0.0

var text_array: Array[String] = [
	"Sup I'm the coolest janitor dude you'll ever meet. I clean, clean some more and clean again.",
	"Whats your name",
	"Thats the coolest name ive ever heard",
	"Maybe we should Kiss?",
	"JK JK JK JK",
	"Unless ;)"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_rotating:
		# Smoothly rotate toward target rotation
		var current_rotation = $"../..".rotation.y
		$"../..".rotation.y = lerp_angle(current_rotation, target_rotation, rotation_speed * delta)
		
		# Check if we're close enough to the target rotation
		if abs(angle_difference(current_rotation, target_rotation)) < 0.05:
			$"../..".rotation.y = target_rotation
			is_rotating = false

func _on_interacted(body: Variant) -> void:
	PlayerManager.MultiDialog(text_array)
	
	# Calculate target rotation (looking away from player)
	if PlayerManager.player:
		var current_transform = $"../..".global_transform
		var target_transform = current_transform.looking_at(PlayerManager.player.global_position, Vector3.UP)
		target_transform = target_transform.rotated(Vector3.UP, PI)  # Flip 180 degrees
		
		# Get the target rotation
		target_rotation = target_transform.basis.get_euler().y
		is_rotating = true

# Helper function to calculate angle difference
func angle_difference(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)
