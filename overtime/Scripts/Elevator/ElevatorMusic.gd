## No Exit
## Overtime Studios
## Elevator Music
## - The muzak inside an elevator. Only heard close up (max_hearing_distance).
## - Keeps playing across levels: when the level changes (GameState's
##   leaving_level) the song's position is remembered, and the elevator music
##   in the next level picks up from exactly that spot - so riding the
##   elevator between floors the song carries straight on.

extends AudioStreamPlayer3D

@export var max_hearing_distance: float = 4.0

## Song position handed from the level being left to the next one (-1 = none).
static var _carried_position := -1.0

func _ready() -> void:
	max_distance = max_hearing_distance
	GameState.leaving_level.connect(_on_leaving_level)
	if _carried_position >= 0.0 and stream and _carried_position < stream.get_length():
		play(_carried_position)
		# every elevator in this level starts from it, then it's used up
		_clear_carry.call_deferred()
	else:
		play()

func _on_leaving_level() -> void:
	if playing:
		_carried_position = get_playback_position()

static func _clear_carry() -> void:
	_carried_position = -1.0
