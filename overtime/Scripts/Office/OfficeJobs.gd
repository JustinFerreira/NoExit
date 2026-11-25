## No Exit
## Overtime Studios
## Office Jobs
## - The rogue office's little jobs and stations (Office.gd adds it, after
##   OfficeWing / OfficeLife). Clicks reach it from OfficeButton.gd (group
##   "office_jobs").
##     Mail       - the tray in the mail room gives MAIL_COUNT letters, each
##                  for one of the staff ("Letter for Pam"); hand each one to
##                  them (OfficeWorker asks deliver_mail) for MAIL_REWARD
##                  coins, MAIL_BONUS more for the last one. Once a round.
##     Copies     - DOC_COUNT documents left on tables round the office
##                  (OfficeWing.doc_spots); pick them all up, put them
##                  through a copier, file the copies in the copy room's
##                  filing cabinet: COPY_REWARD coins. Once a round.
##     Coffee     - the kitchen coffee machine fills the player's mug (from
##                  their desk - picked up in rogue mode) and they drink it:
##                  stamina full, and it runs down slower for a while
##                  (PlayerManager.drink_coffee).
##     Vending    - a snack for SNACK_PRICE coin (PlayerManager.SNACK: hold
##                  it, F to eat - some health back).
##     The fridge - there's a revolver in it. Taking it ends the run.
## - Also sets up the player's desk: the mug can be taken, the computer can
##   be used (DeskComputer.gd).
## - What's been done this round is kept in RogueRun.office_data["jobs"]
##   (the office reloads when the player comes back up in the elevator).

extends Node

const OfficeQuests := preload("res://Scripts/Office/OfficeQuests.gd")
const OFFICE_BUTTON := preload("res://Scripts/Office/OfficeButton.gd")

const MAIL_COUNT := 3
const MAIL_REWARD := 2
const MAIL_BONUS := 2
const LETTER := "Letter for %s"
const DOC_COUNT := 3
const COPY_REWARD := 8
const DOCUMENT := "Document"
const COPIES := "Copies"
const COPY_TIME := 3.0
const SNACK_PRICE := 1
const MUG := "Mug"

var level: Node3D
var wing: Node
var _copying := false
var _dead := false

## This round's job state (fresh when the round changes).
static func jobs() -> Dictionary:
	var d: Dictionary = RogueRun.office_data
	if not d.has("jobs") or d.jobs.get("round", -1) != RogueRun.round_number:
		d["jobs"] = {"round": RogueRun.round_number, "mail_taken": false, "mail": [], "docs": [], "docs_taken": [], "copied": false, "filed": false}
	return d.jobs

## A worker was clicked: hand them their letter if the player has it.
## Returns what they say ("" = no letter for them).
static func deliver_mail(worker: String) -> String:
	var item := LETTER % worker
	if not PlayerManager.has_item(item):
		return ""
	PlayerManager.RemoveItemByName(item)
	var j := jobs()
	j.mail.erase(worker)
	var coins := MAIL_REWARD
	var extra := ""
	if j.mail.is_empty():
		coins += MAIL_BONUS
		extra = " That's all the mail."
	PlayerManager.add_coins(coins)
	AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
	return "%s: %s (+%d coins)%s" % [worker, ["Mail? For me? Nobody sends me mail.", "Finally, I've been waiting on this.", "Thanks. Probably another bill.", "Ooh, a letter. How retro."].pick_random(), coins, extra]

## Is the player carrying a letter for this worker?
static func has_letter_for(worker: String) -> bool:
	return PlayerManager.has_item(LETTER % worker)

func _ready() -> void:
	name = "OfficeJobs"
	add_to_group("office_jobs")
	level = get_parent()
	_start.call_deferred()

func _start() -> void:
	wing = get_tree().get_first_node_in_group("office_wing")
	_setup_desk()
	await get_tree().process_frame
	_spawn_documents()

## ---------------------------------------------------------------------
## The player's desk
## ---------------------------------------------------------------------

func _setup_desk() -> void:
	var cub := level.get_node_or_null("NavigationRegion3D/Cubicle")
	if cub == null:
		return
	# the mug can be taken (in the story it goes in the box)
	var mug = cub.get_node_or_null("Mug1A/Mug1A/Mug1A")
	if mug and "store_in_box" in mug:
		mug.store_in_box = false
		mug.pickup_on_close = true
		mug.inventory_name = MUG
		mug.dialog_from_event_manager = ""
		mug.examine_dialog = "My mug. Could really use a coffee."
	# the computer can be used
	var pc := cub.get_node_or_null("MComputerCombinedUnwrapped") as MeshInstance3D
	if pc:
		var body := StaticBody3D.new()
		body.name = "DeskComputer"
		body.set_script(load("res://Scripts/Office/DeskComputer.gd"))
		body.has_outline = true
		body.mesh = pc
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = pc.get_aabb().size
		cs.shape = sh
		body.add_child(cs)
		pc.add_child(body)
		body.position = pc.get_aabb().get_center()

## ---------------------------------------------------------------------
## Clicks
## ---------------------------------------------------------------------

func on_office_button(b: Node) -> void:
	match b.job:
		"mail_tray": _take_mail()
		"copier": _copy(b)
		"filing": _file()
		"document": _pick_document(b)
		"coffee": _coffee()
		"vending": _vend()
		"fridge_gun": _gun(b)

func _take_mail() -> void:
	var j := jobs()
	if j.mail_taken:
		UiManager.say("No more outgoing mail today." if j.mail.is_empty() else "Still got letters to hand out: %s." % ", ".join(j.mail))
		return
	var names: Array = OfficeQuests.staff().map(func(w): return w.name)
	names.shuffle()
	j.mail = names.slice(0, MAIL_COUNT)
	j.mail_taken = true
	for n in j.mail:
		PlayerManager.AddToInventory(LETTER % n, 0.0, false)
	AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
	UiManager.say("Today's mail. Hand these out: %s." % ", ".join(j.mail))
	PlayerManager.Hint("Mail: give each letter to the person it's for (%d coins each)" % MAIL_REWARD, 8.0)

## The copy job's documents, on DOC_COUNT of the table tops (the same ones
## all round, and only the ones not picked up yet).
func _spawn_documents() -> void:
	if wing == null or wing.doc_spots.is_empty():
		return
	var j := jobs()
	if j.copied:
		return
	if j.docs.is_empty():
		var idx := range(wing.doc_spots.size())
		idx.shuffle()
		j.docs = idx.slice(0, mini(DOC_COUNT, idx.size()))
	for i in j.docs:
		if i in j.docs_taken:
			continue
		var at: Vector3 = wing.doc_spots[i]
		var root := Node3D.new()
		root.name = "Document_%d" % i
		level.add_child(root)
		root.global_position = at
		root.rotation.y = randf() * TAU
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.4, 0.05, 0.55)   # (level units - a folder of papers)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.92, 0.78, 0.35)
		mi.material_override = m
		root.add_child(mi)
		mi.position.y = 0.03
		var label := Label3D.new()
		label.text = "COPY"
		label.font_size = 32
		label.pixel_size = 0.004
		label.rotation_degrees.x = -90
		label.modulate = Color(0.6, 0.1, 0.1)
		label.position.y = 0.06
		root.add_child(label)
		var btn := OFFICE_BUTTON.make(root, "document", Vector3(0, 0.15, 0), Vector3(0.6, 0.3, 0.7), mi)
		btn.data = {"index": i}

func _pick_document(b: Node) -> void:
	var j := jobs()
	j.docs_taken.append(b.data.index)
	PlayerManager.AddToInventory(DOCUMENT, 0.0, false)
	AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
	var have := _count(DOCUMENT)
	if have >= DOC_COUNT:
		UiManager.say("That's all of them. To the copy room.")
	else:
		UiManager.say("A document marked COPY. (%d/%d - more lying around the office)" % [have, DOC_COUNT])
	b.get_parent().queue_free()

func _copy(b: Node) -> void:
	if _copying:
		return
	var have := _count(DOCUMENT)
	if have == 0:
		UiManager.say("Nothing to copy." if not jobs().copied else "Already made today's copies.")
		return
	if have < DOC_COUNT:
		UiManager.say("I've only got %d of %d. The rest are somewhere in the office." % [have, DOC_COUNT])
		return
	_copying = true
	UiManager.say("Copying...")
	var light := _nearest_copier_light(b.global_position)
	var t := 0.0
	while t < COPY_TIME and is_inside_tree():
		if light:
			light.visible = not light.visible
		AudioManager.play_sound(load("res://Assets/Audio/SFX/Microwave/MicrowaveButton%d.mp3" % (randi() % 4 + 1)), -14.0)
		await get_tree().create_timer(0.3).timeout
		t += 0.3
	if light:
		light.visible = true
	_copying = false
	for i in DOC_COUNT:
		PlayerManager.RemoveItemByName(DOCUMENT)
		PlayerManager.AddToInventory(COPIES, 0.0, false)
	jobs().copied = true
	UiManager.say("Copies done. Now they need filing - the cabinet in here.")

func _file() -> void:
	var have := _count(COPIES)
	if have == 0:
		UiManager.say("A filing cabinet. Full of files." if not jobs().filed else "Filed away. Nobody will ever read them.")
		return
	for i in have:
		PlayerManager.RemoveItemByName(COPIES)
	jobs().filed = true
	PlayerManager.add_coins(COPY_REWARD)
	AudioManager.play_sound(AudioManager.ItemPickup, -6.0)
	UiManager.say("Filed. (+%d coins)" % COPY_REWARD)

func _nearest_copier_light(at: Vector3) -> MeshInstance3D:
	var best: MeshInstance3D = null
	for l in wing.copier_lights:
		if best == null or l.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = l
	return best

static func _count(item: String) -> int:
	var n := 0
	for i in PlayerManager.Inventory:
		if i.name == item:
			n += 1
	return n

## ---------------------------------------------------------------------
## Coffee, snacks
## ---------------------------------------------------------------------

func _coffee() -> void:
	if not PlayerManager.has_item(MUG):
		UiManager.say("I need a mug. Mine's on my desk.")
		return
	PlayerManager.drink_coffee()
	AudioManager.play_sound(load("res://Assets/Audio/SFX/single_glug.mp3"), -4.0)
	UiManager.say("Burnt, bitter, perfect. (stamina full - and it lasts longer for a while)")

func _vend() -> void:
	if PlayerManager.coins < SNACK_PRICE:
		UiManager.say("It wants a coin. I don't have one.")
		return
	PlayerManager.add_coins(-SNACK_PRICE)
	PlayerManager.add_snack()
	AudioManager.play_sound(load("res://Assets/Audio/SFX/thud4.wav"), -6.0)
	UiManager.say("A snack. (-%d coin - hold it, F to eat)" % SNACK_PRICE)

## ---------------------------------------------------------------------
## The revolver in the fridge
## ---------------------------------------------------------------------

## Taking it: it comes up to the side of the head, a shot, black, and the
## run is over (the death red, then the game over screen).
func _gun(b: Node) -> void:
	if _dead or PlayerManager.dying or not is_instance_valid(PlayerManager.player):
		return
	_dead = true
	var p = PlayerManager.player
	var cam: Camera3D = p.CAMERA
	PlayerManager.InAnimation = true
	PlayerManager.dying = true
	UiManager.set_cursor_visible(false)
	UiManager.hide_dialog()
	# the gun leaves the fridge and comes up beside the head, aimed at it
	var gun: MeshInstance3D = b.get_parent()
	var held := MeshInstance3D.new()
	held.mesh = gun.mesh
	held.material_override = gun.material_override
	var size: Vector3 = gun.global_transform.basis.get_scale() * 0.7
	gun.visible = false
	b.queue_free()
	cam.add_child(held)
	held.global_transform = gun.global_transform
	var to := Transform3D(Basis.from_euler(Vector3(0.0, deg_to_rad(260), 0.0)).scaled(size), Vector3(0.5, -0.06, -0.55))
	var tw := create_tween()
	tw.tween_property(held, "transform", to, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(cam, "rotation:z", deg_to_rad(-6), 0.9)
	await tw.finished
	await get_tree().create_timer(0.8).timeout
	# the shot: everything goes black
	var shot := AudioStreamPlayer.new()
	shot.stream = _gunshot()
	shot.volume_db = 2.0
	add_child(shot)
	shot.play()
	var black := CanvasLayer.new()
	black.layer = 50
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.add_child(rect)
	add_child(black)
	if is_instance_valid(held):
		held.queue_free()
	PlayerManager.deaths += 1
	PlayerManager.lose_all_health()
	await get_tree().create_timer(3.0).timeout
	UiManager.show_game_over()

## A gunshot, made here (there's no recorded one): a crack of noise and a
## low thump, dying away fast.
static func _gunshot() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * 0.9)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var noise := randf_range(-1.0, 1.0)
		lp = lerpf(lp, noise, 0.35)   # a little darker
		var crack := (noise * 0.6 + lp * 0.6) * exp(-t * 22.0)
		var thump := sin(TAU * (55.0 + 40.0 * exp(-t * 30.0)) * t) * exp(-t * 9.0) * 0.9
		var tail := lp * exp(-t * 4.0) * 0.15
		var v := clampf((crack + thump + tail) * 1.4, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
