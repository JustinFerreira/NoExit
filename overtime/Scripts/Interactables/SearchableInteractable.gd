## No Exit
## Overtime Studios
## Last updated 11/10/26 by Justin Ferreira
## Searchable Interactable
## - Something the player can search: a bin, a drawer, a coat pocket, a box.
## - Plays a search sound (optional - leave search_sound empty until there is one).
## - Gives the item set in item_name and/or the note set in `note` (opens it to
##   read and adds it to the journal), or says nothing_found_text if empty.
## - Searching again after the item was taken says already_searched_text.
## - Remembers being searched through GameState, like picked-up items.
##
## Setup: put this script on a StaticBody3D (with a CollisionShape3D) on the
## object, tick has_outline, and fill in item_name if it hides something.

extends Interactable
class_name SearchableInteractable

## Emitted after a search, with the item found ("" when nothing was there).
signal searched(item_name: String)

@export_group("Search")
## Sound played when the player searches. Leave empty until there is one.
@export var search_sound: AudioStream
## Volume of the search sound (dB).
@export var search_sound_volume_db: float = -8.0
## Seconds between clicking and the result (lets the sound play first). 0 = instant.
@export var search_time: float = 0.0

@export_group("Item")
## Item given to the player (added to the inventory, like InventoryItem).
## Leave empty and searching finds nothing.
@export var item_name: String = ""
@export var item_weight: float = 0.0
## The found item becomes the player's equipped item.
@export var is_equippable: bool = false
## Said when the item is found. %s is the item's name.
@export var found_text: String = "Found %s."
## A note found here (a NoteData from res://Assets/Notes/). It opens for
## reading and goes into the journal (J), just like a NoteItem.
@export var note: NoteData

@export_group("Dialog")
## Said when there is no item here.
@export var nothing_found_text: String = "There's nothing here."
## Said when searching again after the item was taken.
@export var already_searched_text: String = "There's nothing else here."
## Turn off interacting after the first search (no "nothing else" line).
@export var disable_after_search: bool = false

var has_been_searched: bool = false
var _searching: bool = false


func _ready() -> void:
	super._ready()
	_restore_state.call_deferred()


func _restore_state() -> void:
	if GameState.collected_how(get_persist_id()) == GameState.SEARCHED:
		has_been_searched = true
		if disable_after_search:
			_on_interaction_complete()


func _on_interacted(_body: Variant) -> void:
	if _searching:
		return
	if has_been_searched:
		UiManager.say(already_searched_text)
		return
	_searching = true
	if search_sound:
		AudioManager.play_sound(search_sound, search_sound_volume_db)
	if search_time > 0.0:
		await get_tree().create_timer(search_time).timeout
	_searching = false
	has_been_searched = true
	GameState.mark_collected(get_persist_id(), GameState.SEARCHED)

	if item_name != "":
		PlayerManager.AddToInventory(item_name, item_weight, is_equippable)
	if note:
		# opens the note to read, like picking up a NoteItem
		var first_time := GameState.find_note(note)
		Journal.read_note(note, first_time)
		mark_success()
	elif item_name != "":
		UiManager.say(found_text % item_name if "%s" in found_text else found_text)
		mark_success()
	else:
		UiManager.say(nothing_found_text)
	searched.emit(note.title if note else item_name)
	if disable_after_search:
		_on_interaction_complete()
