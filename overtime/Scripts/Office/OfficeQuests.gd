## No Exit
## Overtime Studios
## Office Quests
## - Who works in the office this run (the staff roster) and what they've
##   lost: a worker asks the player to find something (an item from
##   WANTED_ITEMS); it can then turn up searching trash or bodies in the
##   garage (LootSheet "wanted" - garage only); handing it over pays
##   coins.
## - Everything is kept in RogueRun.office_data, so it lasts the whole run
##   (back to nothing on a new run) - the office itself is rebuilt every
##   time it loads.
## - Found items go in the inventory like anything else. The inventory is
##   fresh every round, so the ones not handed in yet are put back when
##   the office loads (restore_carried).
## - Static helpers only - OfficeLife.gd / OfficeWorker.gd / LootContainer
##   call them.

## How many requests can be open at once.
const MAX_OPEN := 2
## Coins for handing one in: random in this range, + REWARD_PER_ROUND a round.
const REWARD := Vector2i(8, 14)
const REWARD_PER_ROUND := 1

## What can go missing: item -> [the ask, the thanks]
const WANTED_ITEMS := {
	"Reading Glasses": ["I can't read a thing - I think I left my reading glasses in my car. Down in the garage somewhere.", "My glasses! Finally I can see my spreadsheets."],
	"Lucky Mug": ["My lucky mug went missing. Last I had it I was walking to my car...", "My mug! The coffee never tasted right without it."],
	"Wedding Ring": ["I lost my wedding ring in the garage. If my wife finds out... please.", "You found it! You just saved my marriage."],
	"Lunchbox": ["Someone took my lunchbox down to the garage. Who does that?", "My lunch! Still... mostly edible."],
	"Employee Badge": ["I dropped my badge in the garage. Can't get back in tomorrow without it.", "My badge! I owe you one."],
	"Headphones": ["My headphones fell out of my bag in the garage. I can't work in this silence.", "Oh, sweet noise. Thank you."],
	"Family Photo": ["I had a photo of my kids in my car. It's gone. Must be down in the garage.", "There they are. Thank you, really."],
	"Pocket Watch": ["My grandfather's pocket watch... I lost it in the garage.", "It's still ticking. Thank you."],
	"Wallet": ["My wallet's gone. Probably fell out by my car in the garage.", "Everything's still in it! Here, take some for your trouble."],
	"Stress Ball": ["I need my stress ball. It rolled off somewhere in the garage. I NEED it.", "Ahh. Squeeze. Thank you."],
	"Fountain Pen": ["My good pen is somewhere in the garage. The company pens are garbage.", "My pen! Now I can sign things with dignity."],
	"Spare Keys": ["I can't find my spare keys. I think they're in the garage.", "My keys! Now I just need to remember which car is mine."],
}

## Staff names to pick from, and the jobs they mostly do.
const NAMES := ["Dale", "Pam", "Rick", "Sandra", "Neil", "Trish", "Gary", "Linda", "Marcus", "Joan", "Phil", "Denise", "Walt", "Rita", "Stan", "Bev"]
## courier: carries papers between desks; copier: lives in the copy room;
## snacker: kitchen and break room; social: meetings and chats
const ROLES := ["courier", "courier", "copier", "copier", "snacker", "snacker", "social", "social"]
## The man in the break room selling stamina charges (always there).
const VENDOR_NAME := "Gus"

static func _data() -> Dictionary:
	var d: Dictionary = RogueRun.office_data
	if not d.has("staff"):
		d["staff"] = []
		d["quests"] = {}     # worker name -> {item, reward, found}
		d["used"] = []       # items already asked for this run
	return d

## The office's workers this run: [{name, role, tint, size}] (made once).
static func staff() -> Array:
	var d := _data()
	if d.staff.is_empty():
		var names := NAMES.duplicate()
		names.shuffle()
		for i in ROLES.size():
			d.staff.append({
				"name": names[i],
				"role": ROLES[i],
				"tint": Color.from_hsv(randf(), randf_range(0.06, 0.2), randf_range(0.8, 1.0)),   # (the whole model - skin too - so only a hint)
				"size": randf_range(0.93, 1.04),
			})
	return d.staff

## Tops the open requests up to MAX_OPEN (a new worker asks for a new item).
static func refresh() -> void:
	var d := _data()
	var free_workers: Array = []
	for w in staff():
		if not d.quests.has(w.name):
			free_workers.append(w.name)
	free_workers.shuffle()
	while d.quests.size() < MAX_OPEN and not free_workers.is_empty():
		var pool: Array = []
		for item in WANTED_ITEMS:
			if not d.used.has(item):
				pool.append(item)
		if pool.is_empty():
			return
		var item: String = pool.pick_random()
		d.used.append(item)
		d.quests[free_workers.pop_back()] = {
			"item": item,
			"reward": randi_range(REWARD.x, REWARD.y) + REWARD_PER_ROUND * (RogueRun.round_number - 1),
			"found": false,
		}

## The request this worker has open ({} = none).
static func quest_of(worker: String) -> Dictionary:
	return _data().quests.get(worker, {})

static func ask_line(item: String) -> String:
	return WANTED_ITEMS.get(item, ["Have you seen my %s?" % item, "Thanks!"])[0]

## Searching in the garage: one of the wanted items nobody has found yet
## ("" = none, or not in the garage). Marks it found.
static func garage_drop() -> String:
	if not RogueRun.active or not PlayerManager.ParkingGarage:
		return ""
	var open: Array = []
	for w in _data().quests:
		if not _data().quests[w].found:
			open.append(w)
	if open.is_empty():
		return ""
	var q: Dictionary = _data().quests[open.pick_random()]
	q.found = true
	return q.item

## Found items not handed in yet go back in the (fresh) inventory.
static func restore_carried() -> void:
	for w in _data().quests:
		var q: Dictionary = _data().quests[w]
		if q.found and not PlayerManager.has_item(q.item):
			PlayerManager.AddToInventory(q.item, 0.0, false)
	UiManager.refresh_inventory()

## Is the player carrying this worker's item?
static func can_hand_in(worker: String) -> bool:
	var q := quest_of(worker)
	return not q.is_empty() and q.found and PlayerManager.has_item(q.item)

## Hands the item over: out of the inventory, coins in, request closed.
## Returns what they say back ("" = nothing to hand in).
static func hand_in(worker: String) -> String:
	if not can_hand_in(worker):
		return ""
	var q := quest_of(worker)
	PlayerManager.RemoveItemByName(q.item)
	PlayerManager.add_coins(q.reward)
	_data().quests.erase(worker)
	AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
	return "%s (+%d coins)" % [WANTED_ITEMS.get(q.item, ["", "Thanks!"])[1], q.reward]
