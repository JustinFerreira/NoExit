extends Node3D
## Model review scene: loops every model's animation so animated models can be checked.

func _ready() -> void:
	# only the models: the player's own UI animations must be left alone
	var models: Node = get_node_or_null("Models")
	if models == null:
		models = find_child("Models", true, false)
	if models == null:
		return
	for ap: AnimationPlayer in models.find_children("*", "AnimationPlayer", true, false):
		var anims := ap.get_animation_list()
		if anims.is_empty():
			continue
		var anim_name: String = anims[0]
		ap.animation_finished.connect(func(_n: StringName) -> void: ap.play(anim_name))
		ap.play(anim_name)
