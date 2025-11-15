extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 70.0
@export var min_volume_db: float = -80.0
@export var first_sound: AudioStream
@export var second_sound: AudioStream
@export var gas_sound: AudioStream
@export var car_beep_sound: AudioStream
@export var delay_between_sounds: float = 0.1  # Small delay between sounds

var current_sound_index: int = 0
var timer: Timer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	max_distance = max_hearing_distance
	# Create timer for sequencing sounds
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_play_next_sound)
	
	# Start the sequence
	_play_next_sound()

func _play_next_sound():
	if current_sound_index == 0:
		# Play first sound
		stream = first_sound
		## Killer can copy sounds
		if !PlayerManager.car_audio_player.was_audible:
			stream = car_beep_sound
		## Set back to default around car
		if PlayerManager.minigameThree || PlayerManager.player.Incar:
			stream = first_sound
		## Gas Minigame
		if PlayerManager.minigameTwo:
			stream = gas_sound
		play()
		current_sound_index = 1
		# Set timer for when first sound ends
		timer.start(stream.get_length() + delay_between_sounds)
		
	elif current_sound_index == 1:
		# Play second sound
		stream = second_sound
		play()
		current_sound_index = 0
		# Set timer for when second sound ends
		timer.start(stream.get_length() + delay_between_sounds)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	volume_db = PlayerManager.scaredVolumeSteps
	
	
