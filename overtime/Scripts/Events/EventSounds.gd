## No Exit
## Overtime Studios
## Event Sounds
## - One-shot 3D sounds for garage events: plays a stream at a spot and cleans
##   up after. Static helper.

## Plays `stream` at `at` (world), removed when it ends.
static func play_at(tree: SceneTree, stream: AudioStream, at: Vector3, volume_db: float = 0.0, max_distance: float = 40.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if tree == null or tree.current_scene == null or stream == null:
		return null
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.bus = "SFX"
	s.volume_db = volume_db
	s.max_distance = max_distance
	s.pitch_scale = pitch
	tree.current_scene.add_child(s)
	s.global_position = at
	s.play()
	s.finished.connect(s.queue_free)
	return s
