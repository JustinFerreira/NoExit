## No Exit
## Overtime Studios
## Last updated 10/18/26 by Justin Ferreira
## Note Item Script
## - A note in the world the player can click to read. Reading it adds it
##   to the journal (open with J) and to GameState, so scripts can check
##   GameState.has_note("id").
##
## Setup (same layout as other interactables):
##   NoteRoot (Node3D)
##     └ NoteMesh (MeshInstance3D)
##         └ StaticBody3D   <- NoteItem.gd here, drag a NoteData onto `note`
##             └ CollisionShape3D

extends Interactable
class_name NoteItem

## Emitted after the note is opened for reading.
signal read(note: NoteData)

## The note this object shows (a NoteData from res://Assets/Notes/).
@export var note: NoteData
## If true the player takes the note: it disappears once read and stays
## gone (until a restart/new loop). If false it stays to be re-read.
@export var take_on_read: bool = false
## Played when the note is opened. Empty = AudioManager.ItemPickup.
@export var read_sound: AudioStream


func _ready() -> void:
	super._ready()
	if note == null:
		push_warning("%s: NoteItem has no note set." % name)
	_remove_if_taken.call_deferred()


func _on_interacted(_body: Variant) -> void:
	if note == null:
		return
	AudioManager.play_sound(read_sound if read_sound else AudioManager.ItemPickup)
	var first_time := GameState.find_note(note)
	Journal.read_note(note, first_time)
	read.emit(note)
	mark_success()
	if take_on_read:
		GameState.mark_collected(get_persist_id(), GameState.PICKED_UP)
		_take()


func _remove_if_taken() -> void:
	if take_on_read and is_inside_tree() and GameState.is_collected(get_persist_id()):
		_take()


func _take() -> void:
	_on_interaction_complete()
	var hide_node := get_parent() as Node3D
	if hide_node:
		hide_node.visible = false
	for shape in find_children("*", "CollisionShape3D", false, false):
		shape.set_deferred("disabled", true)
