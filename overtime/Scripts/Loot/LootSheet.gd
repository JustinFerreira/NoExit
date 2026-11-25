## No Exit
## Overtime Studios
## Loot Sheet - everything about searching, in one place to edit
##
##   1. ITEMS        - the things that can be found
##   2. TABLES       - which items each type of searchable can give, and how likely
##   3. SEARCHABLES  - which objects in the levels are which type
##   4. BODIES       - how many dead bodies lie in the garage
##
## The random notes themselves are in res://Assets/Notes/RandomNotes.gd.
##
## Any other searchable (a drawer, a locker, the fridge...): put
## Scripts/Loot/LootContainer.gd on its StaticBody3D, tick has_outline, and
## set its "table" to one of the TABLES below (or a new one you add).

## ---------------------------------------------------------------------
## 1. ITEMS
## ---------------------------------------------------------------------
## "type" is what finding it does:
##   "coins" - adds to the coin count (shown in the inventory strip)
##   "item"  - puts "name" in the inventory ("equip": it can be held, Z / X)
##   "note"  - a random note from RandomNotes.gd the player hasn't read yet
##   "shield" - a second chance: caught with one, the enemy is stunned and
##             knocked back instead (carry up to PlayerManager.MAX_SHIELDS = 3)
##   "wanted" - something an office worker lost (rogue mode, garage only):
##             one of the open requests nobody's found yet - see
##             Scripts/Office/OfficeQuests.gd. Nothing if none are open.
## A new inventory item is just a new "item" line here (then add it to tables).
const ITEMS := {
	"coins": {"type": "coins"},
	"stamina_charge": {"type": "item", "name": "Stamina Charge", "equip": true},
	"note": {"type": "note"},
	"shield": {"type": "shield"},
	"wanted": {"type": "wanted"},
}

## ---------------------------------------------------------------------
## 2. TABLES
## ---------------------------------------------------------------------
## One table per type of searchable. Each line is rolled on its own, so one
## search can give several things (or nothing):
##   "item"   - a key from ITEMS
##   "chance" - 0 to 1 (0.25 = one search in four)
##   "min" / "max" - how many (optional, default 1) - e.g. coins 1-5
const TABLES := {
	"trash": [
		{"item": "coins", "chance": 0.40, "min": 1, "max": 5},
		{"item": "stamina_charge", "chance": 0.12},
		{"item": "note", "chance": 0.10},
		{"item": "shield", "chance": 0.04},
		{"item": "wanted", "chance": 0.15},
	],
	"office_bin": [
		{"item": "coins", "chance": 0.30, "min": 1, "max": 3},
		{"item": "stamina_charge", "chance": 0.08},
		{"item": "note", "chance": 0.15},
		{"item": "shield", "chance": 0.03},
	],
	"body": [
		{"item": "coins", "chance": 0.85, "min": 5, "max": 15},
		{"item": "stamina_charge", "chance": 0.45},
		{"item": "note", "chance": 0.35},
		{"item": "shield", "chance": 0.20},
		{"item": "wanted", "chance": 0.35},
	],
}

## ---------------------------------------------------------------------
## 3. SEARCHABLES
## ---------------------------------------------------------------------
## Objects in any level whose name starts with one of these become
## searchable with that table when the level loads (office and garage).
## Dead bodies always use "body".
const SEARCHABLES := {
	"SmallBin": "office_bin",
	"RubbishBin": "trash",
	"RecyclingBin": "trash",
	"TrashCan": "trash",
	"Trash": "trash",
}

## Seconds a search takes, by table (anything not listed: DEFAULT_SEARCH_TIME).
const SEARCH_TIME := {"body": 1.2}
const DEFAULT_SEARCH_TIME := 0.6

## ---------------------------------------------------------------------
## 4. BODIES
## ---------------------------------------------------------------------
## How many dead bodies lie around the garage each load (random in range).
const BODIES := Vector2i(2, 4)


## ---------------------------------------------------------------------
## (the rolling - no need to edit below here)
## ---------------------------------------------------------------------

## Rolls a table: what was found, as a list of {"item": key, "count": n}.
static func roll(table: String) -> Array:
	var out := []
	if not TABLES.has(table):
		push_warning("LootSheet: no table called '%s'." % table)
		return out
	for line in TABLES[table]:
		if not ITEMS.has(line.item):
			push_warning("LootSheet: table '%s' has an item '%s' that isn't in ITEMS." % [table, line.item])
			continue
		if randf() >= float(line.get("chance", 1.0)):
			continue
		var n := randi_range(int(line.get("min", 1)), int(line.get("max", line.get("min", 1))))
		if n > 0:
			out.append({"item": line.item, "count": n})
	return out

static func search_time(table: String) -> float:
	return float(SEARCH_TIME.get(table, DEFAULT_SEARCH_TIME))
