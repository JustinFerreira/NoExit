extends ExaminableItem


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_interacted(body: Variant) ->  void:
	super._on_interacted(body)
	PlayerManager.AddToInventory("Flash Light", 0.5, true)
	AudioManager.play_sound(AudioManager.ImportantItemStinger)
