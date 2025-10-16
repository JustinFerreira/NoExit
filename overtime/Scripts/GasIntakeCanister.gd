extends MeshInstance3D

var fall_speed = 1.0
var car_filled = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#print(self.position.y)
	if self.visible == true && self.position.y >= 0.908:
		self.position.y -= fall_speed * delta
	if self.position.y <= 1.408 && self.position.y >= 1.308:
		car_filled += .1
		print(car_filled)
