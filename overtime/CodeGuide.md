# No Exit — Code Guide

How the game's scripts fit together, where to find things, and how to add new ones.
Every script in `Scripts/` starts with a short header saying what it does, and its
functions and settings have `##` doc comments, so hovering them in Godot (or
opening *Search Help*) shows the same text.

## How it fits together

**Autoloads** (always loaded, reachable by name from any script — set in *Project Settings > Autoload*):

| Autoload | Job |
|---|---|
| `GameState` | Where the player is in the story: the loop, milestone flags, deaths, collected/opened/searched items, found notes. Moves the player between levels (`change_level`). The one source of truth for progress. |
| `PlayerManager` | "What is the player doing right now": settings copies, current level, the killer, dialog/minigame/hiding/examining modes, inventory and equipped item, killer-distance sound values. Its milestone/loop properties just forward to `GameState`. |
| `UiManager` | Turns every piece of UI on and off: screens (pause, journal, game over), the HUD (crosshair, dialog, hints, stamina, inventory) and minigame panels. |
| `AudioManager` | 2D music, one-shot sounds and named loops (`play_sound`, `play_sound_loop`, `stop_loop`), plus the game's sound library. |
| `SettingsManager` | Every setting as one line in `DEFS`; the settings menu builds itself from it. |
| `Journal` | Shows notes (one when read, the J list of all found notes). |
| `EventManager` | All story dialog/hint text in one place, plus small shared story switches. |
| `AnimationManager` | Animation players and flashing hint meshes for the car, battery minigame and elevators; `loop_animation()` keeps a hint animation looping. |
| `CameraManager` | The first-person and car cameras. |
| `RogueRun` | Rogue mode: the run (round, this round's car problems, best round), difficulty per round, and setting up the office (round banner) and the garage (parts placed, flat tire, killer tuning) during a run. Enemies each round (plan_enemies / _setup_enemies): 1 in rounds 1-3, sometimes 2 from round 4, sometimes 3 from round 9; each a stalker (trails the player), a hunter (wanders, drawn to the car / parts / booth - points_of_interest - and locks on only when it sees them) or the weeping angel, at its own speed; they start far from the player; extra killers are fresh copies of the killer scene, enemies not used are benched. kill_allowed(): in rounds 1-4 only a trapped or long-still player can be killed (still_limit 8 s down to 3.5), and nobody dies in a minigame in rounds 1-5. |
| `HelperManager` | Small shared helpers: fog fades, angle maths, `is_player_area()`, `set_light_panel_lit()`. nav_map_updated(tree, map) waits until the navigation map has taken in the level just loaded (on a reload it still holds the last level for a frame or two). |
| `OutlineManager` | (static helper, not an autoload) Draws every Interactable outline as one screen-space effect. |

**Base classes** — most game objects are one of these:

| Class | Use it for | Override |
|---|---|---|
| `Interactable` | Anything the player clicks. Gets the click, outlines (near / hover flash / scripted flash), `mark_success()` for puzzles, and a persist id. | `_on_interacted(body)` |
| `ExaminableItem` | Click to look at it in front of the camera, rotate it, maybe pick it up. | `_can_examine`, `_show_examine_dialog`, `_on_examine_started`, `_on_picked_up`, `_should_flash` |
| `InventoryItem`, `NoteItem`, `Door`, `AnimatedInteractable`, `SearchableInteractable`, `HidingSpot` | Ready-made Interactables — usually no code needed, just Inspector settings. | — |
| `Enemy` | Every enemy: navigation that only repaths a few times a second, vision, gravity, the shared "caught you" sequence, hiding-spot hunting. | `_enemy_ready`, `_enemy_physics`, `target_position`, `_before_kill_turn`, `_play_kill`, `_current_kill_distance`, `play_drag_out` |
| `NPC` | Desk workers and the janitor: animations, turning, dialog. | see `NPC.gd` header |

**Levels** call `target_position(player_position)` on their enemies every physics frame (see `ParkingGarage.gd`, `RealSizeLevel.gd`). Enemies decide what to do with it.

## Recipes

- **Something clickable** — put a `StaticBody3D` + `CollisionShape3D` under its mesh, attach a script that `extends Interactable`, tick `has_outline`, write `_on_interacted`.
- **A pickup** — `InventoryItem` with `item_name` set. Doors with a matching `key_name` open with it.
- **A readable note** — make a `NoteData` in `Assets/Notes/`, put a `NoteItem` in the level and drag the note onto it. Check it later with `GameState.has_note("id")`.
- **A locked puzzle door** — `ConditionDoor` and drop the puzzle pieces (`SimpleCondition`, `UIConditionItem`, `InventoryItem`, anything calling `mark_success()`) into its conditions.
- **A fridge / drawer / cupboard** — `AnimatedInteractable` (plays an animation, remembers it's open). Items inside can require it to be open first.
- **A bin to search** — `SearchableInteractable` (gives an item, a note, or "nothing here").
- **A hiding spot** — `HidingSpot` on a click box over the opening, with a `HidePoint` marker (where the eyes go, -Z = facing) and an `EntryPoint` marker just outside the opening. Enemies that see the player hide walk to `grab_position()` (`grab_distance` in front of the opening), line up and drag them out. Tune the Q/E peek per spot (`peek_out_distance`, `peek_side_distance`, `peek_up_distance`, `peek_turn_degrees` — negative turns toward the middle).
- **A one-shot scare when the player walks somewhere** — copy one of the `Scripts/Events` scripts: an `Area3D` trigger whose `area_entered` checks `HelperManager.is_player_area(area)` and an `activated` flag *before* any `await`.
- **A new enemy** — `CharacterBody3D` (+ `NavigationAgent3D` if it walks), script `extends Enemy`, override the hooks above.
- **A new kill** — see `Killer.gd`: pick it in `_before_kill_turn`, set its distance in `_current_kill_distance`, play it in `_play_kill`, and finish in `_on_animation_finished`.

## Conventions

- Header at the top of every script: `## No Exit` / `## Overtime Studios` / title / `## - what it does`.
- `##` comments directly above a function, variable, signal or export are its documentation (Godot shows them in the editor).
- Story progress goes in `GameState` (flags, loop, collected items); moment-to-moment state in `PlayerManager`.
- Scenes connect signals by method name — renaming an `_on_...` handler means re-connecting it in the scene.
- Units: real-size levels are in metres; the original story levels are about twice real size, and the garage is built in much larger units (see `ModelSizes.md`).

## Things the check-up found but left alone

These need a design decision rather than a code fix:

- **Light-break events in the garage** — 12 of the 13 never find a light to break: their `max_search_radius` (10) is tiny for the garage's scale (the nearest lights are 12–200 units away sideways). Raising it (e.g. to ~250) in `light_break_event.tscn` would make them all work.
- **`PlayerManager.DevMode` is on by default** — fine while developing; turn it off for release builds (it unlocks every loop and the dev pause menu).
- **Not used in any scene yet:** `Puzzles/ConditionGate.gd` (a finished puzzle tool) and `Ambience/OfficeLights.gd` (a noise-driven flicker).
- **Item weight** is stored with inventory items but nothing uses it.
- **Placeholder text** still in the game: the fire alarm's garage hint ("Lmao nah…") and "Get in the elevator bro".
- **The story killer** (`Killer.tscn`) still uses its old separate stab model; only `Killer_RealSize` has the new stab, drag-out and crush.

## Script index

### Ambience

| Script | What it does |
|---|---|
| `BuzzingFluorescentLight.gd` | A looping 3D buzz on a light; only heard close up (max_hearing_distance). |
| `ClockTicking.gd` | A looping 3D clock tick, heard within max_hearing_distance. |
| `OfficeLights.gd` | Makes an OmniLight3D flicker: its brightness follows a noise texture over time. Not attached to any scene yet. |
| `WaterDripping.gd` | plays a 3D sound of water dripping in the garage |

### Elevator

| Script | What it does |
|---|---|
| `ElevatorButton.gd` | This script is for the button outside of the elevator |
| `ElevatorButtonPanel.gd` | This is the Inside button of the elevator which |
| `ElevatorMusic.gd` | This plays music inside the elevator |
| `ParkingGarageElevator.gd` | this gives functionality to the elevators in the parking |
| `ParkingGarageElevatorInsideButton.gd` | This button will close elevator doors and bring player |
| `ParkingGarageElevatorOutsideButton.gd` | This button will open up the elevator |
| `ElevatorRide.gd` | Getting into an elevator as a cutscene (office going down, garage going up, from the outside button or the inside one): the player walks in, presses the inside button, steps back facing the doors and rides - always ending at the same spot so the elevator at the other end picks up the same view. No control, no looking around and enemies frozen (PlayerManager.cutscene) until the arriving elevator's doors are open. On arrival the player gets control back once the doors are 40% open (arrive_as_doors_open), not when they finish opening. |

### Enemies

| Script | What it does |
|---|---|
| `Disappearing_Enemy.gd` | Visible when first seen, disappears permanently when the player looks away |
| `Enemy.gd` | parent class for every enemy (Killer, WanderingEnemy, WeepingAngel, DisappearingEnemy). To make a new enemy: put a CharacterBody3D in a scene (add a NavigationAgent3D child if it walks), attach a script that starts with "extends Enemy", and override the hooks you need: _enemy_ready()          - your setup (instead of _ready) _enemy_physics(delta)   - your per-frame behaviour (instead of _physics_process); move_and_slide() is called for you afterwards target_position(pos)    - levels call this with the player position _before_kill_turn()     - runs when the enemy catches the player _current_kill_distance()- how far in front of the player the kill happens (default: kill_distance) _play_kill()            - the kill itself (default: game over) play_drag_out(time)     - pulling a hidden player out (default: stand) "Can the player see me" (player_can_see_me, on_player_screen) uses the camera actually on screen - a minigame's camera too (_view_camera). When it may not kill yet (RogueRun.kill_allowed) it comes no closer than HOLD_OFF and looms; being dragged out of a hiding spot always kills. Wedged on its way to a hiding spot, it reaches in from where it is. |
| `Killer.gd` | The main enemy. Chases the player (stopping follow_distance short until it's close), teleports to scare spots, can switch to "stalking" (fades out, reappears and circles the player), hunts players it saw hide, and kills with a stab or a lift-and-crush (kill_style). While hanging back, if the player walks up within lunge_distance (7 m, clear line) it lunges at 9 m/s and kills them; it gives up only if they get 14 m away or hide. Behavior STALK (trails the player; if they hide unseen it wanders) or HUNT (wanders between points of interest, locks on when it sees the player, loses them 6 s after losing sight) - set per rogue round, with speed_mult. |
| `Killer3DAudio.gd` | The killer's breathing/footstep loop: alternates first_sound and second_sound forever as a 3D sound on the killer. Its volume follows how close the killer is (PlayerManager.scaredVolumeSteps), is fixed during the opening/Loop 0, and goes silent while AudioManager.KillerShutUp is set (e.g. during a kill). |
| `BearTrap.gd` | Hidden in Loop 0. The first time the player steps in it, it snaps shut: the player is trapped (can't move) until they hold the click on the trap long enough to pry it open - the jaws open as they do (see BearTrapInteract on its StaticBody3D). |
| `BearTrapInteract.gd` | The clickable part of the bear trap (BearTrap). Once it has snapped shut, hold the click on it to pry it open: a red ring (UiManager.ACCENT) fills around the crosshair over `hold_time` while the jaws open with it; letting go or looking away springs it shut again. When full the player is free and the trap is gone. |
| `WanderingEnemy.gd` | Wanders between nodes assigned in the Inspector (drag-drop) |
| `weeping_angel.gd` | Enemy that only moves while the player is NOT looking at it. |

### Events

| Script | What it does |
|---|---|
| `GarageEvent.gd` | Base for every random garage event. Each is placed and always armed; walking into one asks the EventDirector whether it may go off right now. Tiers: COMMON (repeats after its kind_cooldown), RARE (once per run), LEGENDARY (once per playthrough, saved). min_killer_distance keeps an event from going off while the killer is near the player - if he's further than 22 m and not plainly in view he slips away into the fog instead (moved unseen past that distance) so it can still happen (payphone 40 m, killer eyes 45, elevator ghost 35, footsteps behind 30, headlights 30, ghost car 30, falling body 25, gate arm 25, car crank 20; the rest any distance). Subclasses set tier/kind in _init() and put the scare in _fire(). |
| `EventDirector.gd` | Decides when garage events may go off: a quiet spell after arriving, a random gap after each event, a chance that grows the longer it's been quiet, never close to the last one; enforces the tiers (legendaries saved in user://garage_events.cfg). Also hangs events on lights, payphones, elevators, the gate arms and parked cars at load. Keeps counts of what went off (this run and in total) and can set any event off on demand (debug_fire) for the dev pages. Static - no autoload. |
| `AmbientSoundEvent.gd` | COMMON. A sound from somewhere you can't see: footsteps behind the player that stop, or a car door slamming far off. Hung under every light at load. |
| `PayphoneRingEvent.gd` | RARE. A payphone rings for 8-14 s as the player passes. Pick it up while it rings and the killer is breathing on the line ("...Hello?"), then it goes dead. On every payphone at load. Answering holds the player still (InAnimation) for the call, sends any close killer away, and takes the handset off the phone (a copy of its mesh without that piece) until the line goes dead and it's hung back up. |
| `ElevatorGhostEvent.gd` | RARE. A closed elevator dings and opens - empty - then closes. On every garage elevator at load. |
| `GateArmEvent.gd` | RARE. A toll booth boom arm lifts by itself, hangs, and drops with a clunk. On each boom arm at load. |
| `ParkedCarEvent.gd` | A parked car as the player walks by: its locks chirp (COMMON), its engine cranks and fails (RARE) or its headlights and tail lights snap on (LEGENDARY) - at its real front, from a table of which way each car model faces (sedan and SUV +Z, pickup -X). On every parked car at load, mode random. |
| `EventSounds.gd` | Helper: one-shot 3D sounds for events, cleaned up after. |
| `LightBreakEvent.gd` | COMMON. A ceiling light (its own, or the nearest working one above) shatters as the player walks under it - glass breaking from the light - and stays out (marked broken, so a light flicker doesn't relight it). Every light gets one (EventDirector). |
| `PhoneRinging.gd` | A 3D phone ring that plays once when the level starts, then again at a random moment 20-60 s after each ring ends. |
| `StalkingArea.gd` | While the player is inside the trigger area (not in Loop 0) the killer switches to stalking: it fades out, reappears at one of the teleports and circles the player at stalking_distance instead of chasing. Leaving the area ends it; it can start again 30 s later. Not used in the fitted garage any more (the car and toll booth zones were removed). |
| `alarm_car_event.gd` | COMMON (car_alarm). A parked car's alarm goes off as the player walks by, at a random level: just that car (55%), 1-2 nearest join in (30%), a chain across the nearest 3-5 (12%), or every alarm car in the garage in waves (3%). fire_level(n) sets a given level off; sound_alarm() is just the alarm - the lights flash for exactly as long as the sound plays (the old 7 s CarAlarm animation drifted from the sound and isn't used). |
| `blood_ceiling_fall_event.gd` | LEGENDARY (falling_body). Blood sprays from the ceiling and a body drops from it and dies in the pool. The body is held frozen (not left to physics, which let it fall through), started just under the ceiling of its own floor and dropped onto that floor; while the death animation plays it's kept up so no bone sinks below the floor. |
| `blood_splatter_down_event.gd` | COMMON (blood_spray). Blood sprays down onto the floor for a few seconds. |
| `car_vanish_crash.gd` | LEGENDARY (ghost_car). An invisible car appears, crashes and vanishes. |
| `creepy_noise_emitter.gd` | COMMON (creepy_noise). A creepy 3D sound. The placed ones play from their spot; EventDirector also puts one on every ceiling light (no sound of its own) that plays one of the placed ones' sounds from 8-16 m off to the side or behind the player - so it can happen anywhere. |
| `fog_killer_eyes.gd` | LEGENDARY (killer_eyes). Fog rolls in, the killer's glowing eyes appear in it with a heavy breath, then fade. |
| `killer_teleport_area.gd` | When the player walks into the trigger area (not in Loop 0), the killer (PlayerManager.Enemy) jumps to one of the teleports (picked at random) for a scare. It won't fire again until COOLDOWN seconds after the player has left the area. |
| `lights_flash_event.gd` | COMMON (light_flicker, back after 70 s, repeatable). The working lights around the player stutter on and off - together, a few out of step, so the area really drops dark - with a buzz of sparks, then settle; broken ones stay dark. Each time a different length: a quick blip overhead (40%), a short stutter (35%), a long struggle (20%) or a really long one that almost dies (5%). |
| `PipeFallEvent.gd` | COMMON (pipe_fall, back after 200 s). A ceiling pipe ahead of the player groans, jolts, and its near end swings down with a crash (to the floor if it reaches); steam blasts from the broken joint with a hiss, thins to a leak and stops. Each pipe falls once and stays hanging. EventDirector puts it on up to 18 long pipes, 16 m apart, not the light-carrying ones. Fine with the killer close. |
| `KillerBehindEvent.gd` | COMMON (killer_behind, back after 180 s). A random enemy (the killer, the angel, any of them) that's off-screen and further away is moved, unseen, 9-14 m behind the player, out of sight; one soft footstep is the only clue. On every third ceiling light (EventDirector). |
| `walk_in_wall.gd` | A seamless portal: the end of a hallway looks like it carries on into the dark, but walking into it moves the player to the paired wall (destination_wall_buddy) somewhere else in the level, keeping their position, speed and facing relative to the wall. Exit-only walls are just landing spots (straight displacement, no turning). |

### Interactables

| Script | What it does |
|---|---|
| `AnimatedInteractable.gd` | Plays an animation when the player interacts with it: a fridge door swinging open, a drawer sliding out, a cupboard, a car boot... |
| `Box.gd` | This is the script for the pickup item box |
| `CarKeys.gd` | The car keys on the player's desk (an ExaminableItem). Pickup, inventory and sounds are set in the Inspector; this adds the keys' own dialog, makes the elevator button start flashing once they're examined, and records that the player has them. |
| `Cubicle.gd` | The player's cubicle. It flashes while the player is away from it without the car keys (there's still something to do there) and stops when they come back. |
| `ExaminableItem.gd` | Generic "click to look at it" item. Brings a copy of the item's mesh in front of the camera, lets the player rotate it, then either puts it back or picks it up. |
| `FireAlarm.gd` | Clicking it in the office flashes every office light blue/red for a few seconds, then puts their colours back. Does nothing in the garage. |
| `HidingSpot.gd` | Click it and the player ducks into the spot (under a desk, in a locker, behind boxes): the view moves smoothly to hide_point, and the player's collision and enemy kill trigger are switched off - while hidden, the player effectively IS the hiding spot. |
| `Interactable.gd` | Base class for everything the player can click: the Player's interact ray emits `interacted`, which calls the subclass's _on_interacted(). |
| `InventoryItem.gd` | Generic, reusable "pick this up" script for any object that should just be added to the player's inventory when interacted with (a key, a tool, a note, whatever). Give it a name in the Inspector and it's ready - no per-item scripting needed. |
| `NoteData.gd` | One readable note. Make one per note in res://Assets/Notes/ (right-click the folder > New > Resource... > NoteData), fill in the fields, and every note in the game lives in that one folder. |
| `NoteItem.gd` | A note in the world the player can click to read. Reading it adds it to the journal (open with J) and to GameState, so scripts can check GameState.has_note("id"). |
| `SearchableInteractable.gd` | Something the player can search: a bin, a drawer, a coat pocket, a box. |
| `door.gd` | Generic, reusable door script meant to be dropped onto ANY door-like object (room doors, cabinets, gates, closets, the car door, etc.). |
| `lamp.gd` | The flickering desk lamp on the main menu: every ~0.1 s the bulb picks a new brightness (now and then a deep dip) and the lampshade's glow follows it. |

### Audio

| Script | What it does |
|---|---|
| `SoundReach.gd` | How sound carries between the garage's split-level decks: normal on the same deck; to another deck only through the openings (ramps, barrier gaps between decks - checked with a few rays), and only near them; standing on or right by a ramp it always carries a little. Level with the sound isn't always the same floor: if no ray gets through and the listener is walled in (the stairs by the elevators), it's silent; out on the deck, cars in the way only muffle it (-6 dB). A slope only counts as a ramp if it's at least 10 m wide (the stairs are ~7 m). Used by CarKeyNoise and Killer3DAudio. |

### Levels

| Script | What it does |
|---|---|
| `LevelShadows.gd` | Brightness / ambient light can be tested live from the dev pause menu's Dev Tools page. |
| `MarkingEmptyOfficeGreybox.gd` | Put on the office level: hands its ceiling lights to PlayerManager (OfficeLights) so the fire alarm and other events can switch them. |
| `MarkingUnwrappedParkingGarage.gd` | Put on the parking garage level: hands every light in the "Lights" group to PlayerManager (ParkingGarageLights) for the blackout events. |
| `ModelLineup.gd` | Model review scene: loops every model's animation (under "Models") so animated models can be checked. |
| `Office.gd` | Sets up the office for the current loop: a fresh start (opening cutscene, intro dialog, starting items) or coming back up in the elevator from the garage. |
| `OpeningCutScene.gd` | The scene at the very start of the game: gets the state ready for a new run and plays the opening. |
| `ParkingGarage.gd` | Sets up the garage for the current loop (music, killer, which car is the player's, Loop 0 differences) and feeds the killer the player's position. Puts SecurityCamera on every wall camera. GetCar swaps the player's car with any car in the garage (any parked car under "Cars", or one of the `cars` stand-ins), lining each up by its front, middle and floor; it only takes a spot that leaves room to get round the car (in front of the hood and down both sides - _room_around; nose in or out, whichever fits), taking away a parked car hemming it in. The attached objects move and turn with it. _scatter_bear_traps moves every bear trap to a random spot each load (flat floor, 15 m apart, 12 m from the start, 6 m from the car, not in the booth). |
| `SecurityCamera.gd` | The garage's wall cameras keep turning to look at the player: the model is cut at the neck, the body pans (up to 100° either side of straight out, never into the wall) and tilts on it, the wall plate and arm stay put. |
| `CarHiding.gd` | Every car can be hidden under, from either long side: a HidingSpot on each side (click area on physics layer 7 "Clickable" - the player's aim ray sees it, nobody walks into it). Put on every car by ParkingGarage. |
| `RealSizeLevel.gd` | Real-size review levels (Real Size, Interactable Test): everything in metres, with the real-size player and killer. Free walking from the start, whether opened from Loop Select or straight from the editor, and the killer is fed the player's position like in the story levels. |
| `ShadowLab.gd` | A test room for learning how shadows behave in Godot. Walk around and use the number keys to change one thing at a time; the panel shows what each setting is and what it costs. |

### Managers

| Script | What it does |
|---|---|
| `AnimationManager.gd` | Holds the animation players and flashing hint meshes of the car, the battery minigame and the elevators, so the scripts that set them up and the ones that trigger them can find each other, plus the handlers that run when those animations finish. loop_animation() keeps a hint animation looping. |
| `AudioManager.gd` | This Script contains functions for |
| `CameraManager.gd` | Holds the player's first-person camera and the car camera so other scripts can switch between them. |
| `EventManager.gd` | Every line of story dialog and hint text in one place (so writing can be tweaked without hunting through scripts), plus small story-state switches shared between scripts (elevator doors, came from garage...). |
| `GameState.gd` | The one place that knows where the player is in the story: * loop      - which loop we're on (opening cutscene, loop 0, loop 1...) * flags     - named milestones ("got_keys", "hotwire_done", ...) * deaths |
| `HelperManager.gd` | Small shared helpers used by several scripts: fog fades, the killer's glowing eyes, angle maths, "is this the player?" checks for trigger areas, and switching ceiling light panels off and on. |
| `Journal.gd` | Shows notes on screen: * read_note(note)  - a single note, when the player clicks a NoteItem * the journal      - J opens a list of every note found so far |
| `OutlineManager.gd` | Draws every Interactable outline as a screen-space effect. |
| `PlayerManager.gd` | The shared "what is the player doing right now" state every script reads: settings copied from SettingsManager, which level they are in, the killer, dialog/minigame/hiding/examining modes, the inventory and the equipped item, and the killer-proximity values that drive the scary sounds (ProcessScared). |
| `SettingsManager.gd` | Every setting is ONE line in DEFS below. The settings menu builds itself from that list, so adding a setting is: 1. add a line to DEFS 2. add what it does to _apply() (one `match` case) |
| `UIManager.gd` | One place that turns every piece of UI on and off, so menus, dialog, the crosshair and the HUD never fight each other. |

### Minigames

| Script | What it does |
|---|---|
| `Battery.gd` | This script is attached to the Battery |
| `BatteryPickup.gd` | This is the script for the pickup item battery |
| `BatteryWire.gd` | One of the two cables in the battery minigame. The player drags it (group "grabbable"); touching its own battery terminal connects it (PlayerManager.TestConnection checks if both are on). Touching the wrong terminal, a reset zone or the other wire sparks and snaps it back. Dragging (Player.get_grab_position) keeps the clicked point exactly under the cursor on a level plane at the wire's height; a spark snaps it back to where it was picked up. |
| `WireHand.gd` | Battery minigame: the mouse pointer is hidden and a hand follows the mouse instead - relaxed, open (fingers spread) when it touches a wire, closed round it while it's dragged. Touching a wire at all (wire_touched: within its thickness + 0.1 m) is enough for a click to take it. Two hands, switched with "Battery hand" in the dev menu's Dev Tools (WireHand.use_model): the simple one built from blocks (default) or the player's arm model (ArmMenu, normal size, flat and spread when open, curls to fit round the wire). When it grabs, the wire slides into the middle of the grip (Player eases the grab offset to zero) and both hands turn across the wire, their fingers curled just enough to go round it (each finger by its length) with a little clearance - never through it; the thumb closes as far as it can while staying outside the wire (_fit_thumb), hugging it from the wrist side. Made and removed by Player as minigameThree turns on / off. |
| `CarDoor.gd` | The CarDoor script controls the interaction |
| `CarKeyNoise.gd` | The car's key-fob chirp (a 3D sound on the car): heard all over the car's deck, quieter with distance; from other decks only near the openings it comes through (SoundReach). If it can't be heard, pressing the fob shows a "the car is too far" hint. Each press also blinks the headlights twice and lights the tail lights. It clears PlayerManager.car_audio_player when it leaves the level (PlayerManager.has_car_fob checks it), so the fob key in the office shows the "only in the parking garage" hint. |
| `GasCanister.gd` | this is the pickup item |
| `GasIntake.gd` | This script is apart of the car that The sweet spot is drawn as a red-and-white target (twice the old box), always facing the camera. |
| `GasIntakeCanister.gd` | This scripts hooks up the gascanister to work |
| `Hood.gd` | This script controls the interactable object |
| `HotWireGame.gd` | The hot-wire minigame overlay (opened from the steering wheel). For now it's a single button press once it's open. |
| `SteeringWheel.gd` | starts hot wire minigame, lets player know what theyre missing |
| `WireNegative.gd` | The negative wire of the battery minigame (see BatteryWire.gd). |
| `WirePositive.gd` | The positive wire of the battery minigame (see BatteryWire.gd). |

### NPCs

| Script | What it does |
|---|---|
| `DialogNpc.gd` | built on NPC (see NPC.gd): root, play_walk/play_idle, face_direction, say_sequence come from there In rogue mode he stops the player at the elevator button only on round 1 (RogueRun.janitor_every_round = true makes it every round). |
| `NPC.gd` | parent class for every NPC (the desk workers, the janitor). To make a new NPC: put this script's child class on the NPC's clickable body (a StaticBody3D, like any Interactable), then fill in the inspector: NPC Root          - the node that moves/turns (empty = the scene root) Idle/Walk Player  - AnimationPlayers to loop (empty = none) Random Lines      - clicked = says one of these (empty = nothing) Ambient Sounds    - sounds played now and then (typing etc.) on Ambient Player Override the hooks you need: _npc_ready()            - your setup (instead of _ready) _on_interacted(body)    - what happens when clicked (default: say a random line) |
| `NpcRandomDialogue.gd` | For NPCs that just sit at their desk. |
| `NpcSounds.gd` | For NPCs that just sit at their desk. |

### Player

| Script | What it does |
|---|---|
| `Dialog.gd` | The on-screen dialog box and hint line: typewriter text, the box opening from the centre, multi-line conversations (click for the next line) and the Loop 0 "click to continue" mouse hint. |
| `Player.gd` | The first-person player: walking/sprinting with stamina, crouch, lean and look-back, head bob and footsteps, mouse look, the interact ray (with aim assist), equipped-item keys, the breathing/heartbeat sounds that follow the killer's distance, and dying when an enemy touches it. Interacting: a clickable thing under the crosshair first, then anything in group "aim_claim" that claims the aim by what's seen (claims_aim - the flat tire), then the aim-assist rays. |

### Puzzles

| Script | What it does |
|---|---|
| `ColorGatePuzzle.gd` | Three buttons, each opening its own group of color-coded doors. Only max_open_groups colors can be open at once (default 2) - opening one more closes whichever group has been open the LONGEST, no matter what order the buttons get clicked in after that. |
| `ConditionDoor.gd` | A Door that stays locked until a set of OTHER Interactables have each reported a successful interaction (see Interactable's interaction_succeeded signal / mark_success()). Drop any number of condition objects into required_conditions in the Inspector - 1, 3, 20, however many the puzzle needs - and the door unlocks once enough of them succeed. |
| `ConditionGate.gd` | Waits for a set of Interactable conditions to succeed (same condition objects ConditionDoor uses - SimpleCondition, UIConditionItem, InventoryItem, anything that calls mark_success()) and then flips a whole group of Door-family nodes at once - some unlocking, some locking - as a one-time reaction. |
| `ConditionUIPanel.gd` | Minimal, reusable popup for a "click this button to confirm" interaction - the same shape as the Hot Wire minigame's button, but generic so it isn't tied to that one minigame. Put this script on any Control that has a Button somewhere inside it, assign confirm_button in the Inspector, and call open()/close() from whatever triggers it (see UIConditionItem, which does this for you). |
| `SimpleCondition.gd` | Minimal Interactable for puzzle pieces that don't need to be picked up or do anything fancy - a switch, a button, a lever, a plain "click this" object. Clicking it reports a success, which is all a ConditionDoor (or anything else listening for interaction_succeeded) needs to count it as solved. |
| `UIConditionItem.gd` | Interactable that opens a simple confirm-button popup (see ConditionUIPanel) instead of succeeding immediately on click - the same shape as the steering wheel opening the Hot Wire minigame. Success is reported once the player clicks the button in that popup, so this item can be dropped straight into a ConditionDoor's required_conditions like anything else that calls mark_success(). |

### UI

| Script | What it does |
|---|---|
| `GameOver.gd` | The game over screen: restart or quit to the main menu. |
| `KeepAnimatedSpriteCenter.gd` | Keeps a Sprite2D in the middle of the screen, also after the window is resized. |
| `MainMenu.gd` | The main menu: new game, continue, Loop Select (unlocked loops, all of them in dev mode), the review levels, settings and quit. |
| `PauseMenu.gd` | Both pause menus (the normal one and the dev one): resume, settings, journal, quit, and the dev tools (free roam, shadows, visibility...). Adds DevPages to the dev menu. |
| `DevPages.gd` | Dev pause menu only: pages flipped with < > arrows (Paused, Dev Tools, Events, Flags, Event Map). Events: the event director's timer and how many of each kind went off. Flags: every bool on the managers and the player, live, click to flip. Event Map: the garage deck by deck with every event; left-click goes there and sets it off, right-click just goes there. In dev mode M opens the menu straight on the Event Map (M again closes it). The Events page also has "Car alarm here, level 1-4" buttons. The Event Map also marks your car and has "Go to my car" plus Battery / Gas / Tire / Hot-wire buttons that start that minigame right at the car (set up so it can be played). Its teleports (_safe_stand) put the player on the target's own floor, feet on the floor, somewhere their body fits. |
| `SettingsLabel.gd` | This script updates the number for sliders in settings menu |
| `SettingsMenu.gd` | Builds its rows from SettingsManager.DEFS - nothing to edit here when adding a setting. |
| `SliderBar.gd` | This is used to keep the sprite of the sliderbar acurate |
| `SplashScreen.gd` | This script is the first thing the player see when entering the game |

## Also noticed

- `Levels/Greyboxing/Scenes/EmergancyStairs.tscn` and `FloorStairs.tscn` don't open: they use `Assets/Dev Textures/dev_texture_misc.png`, which was deleted in an earlier commit ("Removing some stuff and cleaning").

## Rogue mode

Main menu > **Rogue Mode** (`RogueRun.start_run()`). Every round starts in `Office_Fitted`, standing in the open elevator — the office is the hub where shops and side games will go. Take the elevator down to `ParkingGarage_Fitted`, fix what's wrong with the car, get in and start it to win the round (`RogueRun.complete_round()` → back to the office, next round). Dying ends the run; the game over screen shows rounds survived and the best run (saved in `user://rogue.cfg`), and **New Run** starts over.

- **Problems:** `gas` (gas can + the gas minigame), `battery` (battery + the battery minigame), `tire` (spare tire + the tire minigame). Round 1 has one, round 2 one or two, rounds 3–4 two or three, round 5+ all three. No hot-wire in rogue mode.
- **Parts:** placed by `RogueRun.setup_garage()` — in the bottom-floor toll booth (`TollBooth.hub_points()`) with `hub_chance()` (75% in round 1, dropping 12% a round to 15%), otherwise at a random spot on the garage's navigation mesh at least `min_distance_from_car` from the car.
- **Difficulty knobs** (Inspector on the `RogueRun` autoload script): killer speed per round / max, how close the killer follows (20 → 0 over the rounds), hub chance per round. The tire minigame also needs more pumps and turns per nut each round.
- **Toll booth:** `toll_booth.tscn` (with `TollBooth.gd`) builds its own collision; its door is part of the model, so clicking it (`BoothDoor`) fades and steps you in/out.
- **Tire minigame:** `FlatTire` squashes one of the car's wheels; with a Spare Tire, clicking it opens `TireGame` on the car itself (jack, 4 lug nuts using the Nut model, pull the flat, fit the spare, tighten). The wheel is clicked through a disc along its axle that sticks out past the car body, plus FlatTire.claims_aim: the car's own collision wraps round the wheel, so aiming anywhere on the tire picks it by what's seen.
