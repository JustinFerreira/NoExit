extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AnimationManager.CubicleFlashAnimationPlayer = $CubicleFlashAnimationPlayer
	AnimationManager.ActivateCubicleFlashAnimationPlayer()
	$CubicleFlashAnimationPlayer.play("CubicleFlash")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_area_entered(area: Area3D) -> void:
	$CubicleFlash.visible = false


func _on_area_3d_area_exited(area: Area3D) -> void:
	if not PlayerManager.has_item("Car Keys"):
		$CubicleFlash.visible = true
