## No Exit
## Overtime Studios
## Loot Container
## - A SearchableInteractable whose contents are rolled when it's searched,
##   from its table in LootSheet.gd (coins, stamina charges, a random note
##   from RandomNotes.gd, any inventory item listed there). The bins
##   (LootSpots.attach_bins) and dead bodies (DeadBody.gd) use it; put it on
##   any other searchable and pick its table.
## - Searched once: after that "There's nothing else here." (remembered
##   through GameState like any searchable).

extends SearchableInteractable

const LOOT_SHEET := preload("res://Scripts/Loot/LootSheet.gd")
<<<<<<< HEAD
const OFFICE_QUESTS := preload("res://Scripts/Office/OfficeQuests.gd")
=======
>>>>>>> origin/main

## Which table in LootSheet.TABLES to roll ("trash", "office_bin", "body"...).
@export var table: String = "trash"

func _ready() -> void:
	if table == "body":
		nothing_found_text = "Nothing useful on them."
		already_searched_text = "I've already gone through their pockets."
	super._ready()

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
	if not is_instance_valid(self) or not is_inside_tree():
		return
	has_been_searched = true
	GameState.mark_collected(get_persist_id(), GameState.SEARCHED)

	var found: Array[String] = []
	var found_note: NoteData = null
	var shield_left := false   # a shield they had no room for
	for got in LOOT_SHEET.roll(table):
		var item: Dictionary = LOOT_SHEET.ITEMS[got.item]
		var n: int = got.count
		match item.type:
			"coins":
				PlayerManager.add_coins(n)
				found.append("%d coin%s" % [n, "" if n == 1 else "s"])
			"item":
				for i in n:
					if item.name == PlayerManager.STAMINA_CHARGE:
						PlayerManager.add_stamina_charge()
					else:
						PlayerManager.AddToInventory(item.name, 0.0, item.get("equip", false))
				found.append(("a %s" % item.name) if n == 1 else ("%d %ss" % [n, item.name]))
			"shield":
				var got_n := 0
				for i in n:
					if PlayerManager.add_shield():
						got_n += 1
				if got_n > 0:
					found.append("a Shield" if got_n == 1 else "%d Shields" % got_n)
				else:
					shield_left = true
<<<<<<< HEAD
			"wanted":
				# something an office worker lost (garage only, open requests)
				var w := OFFICE_QUESTS.garage_drop()
				if w != "":
					PlayerManager.AddToInventory(w, 0.0, false)
					found.append("someone's %s" % w)
=======
>>>>>>> origin/main
			"note":
				if found_note == null:
					found_note = GameState.random_unfound_note()

	if found.is_empty() and found_note == null:
		UiManager.say("There's a shield here, but I can't carry any more." if shield_left else nothing_found_text)
	else:
		if not found.is_empty():
			AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
			UiManager.say("Found %s." % _join(found))
		if found_note:
			# opens to read and goes in the journal, like any note
			var first_time := GameState.find_note(found_note)
			Journal.read_note(found_note, first_time)
		mark_success()
	searched.emit(found_note.title if found_note else ", ".join(found))
	if disable_after_search:
		_on_interaction_complete()

static func _join(parts: Array[String]) -> String:
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " and " + parts[-1]
