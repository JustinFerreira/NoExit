## No Exit
## Overtime Studios
## Office Button
## - Something clickable in the rogue office that one of the office jobs
##   handles (OfficeJobs.gd): the mail tray, the copiers, the filing
##   cabinet, the documents to copy, the coffee machine, the vending
##   machine, the gun in the fridge. `job` says which; clicking it tells
##   everyone in group "office_jobs" (on_office_button(self)).
## - Goes on a StaticBody3D with a collision shape, outlined with `mesh`.
##   OfficeWing.gd / OfficeJobs.gd make these: OfficeButton.make(...).

extends Interactable

## Which job handles it ("mail_tray", "copier", "filing", "document",
## "coffee", "vending", "fridge_gun").
@export var job: String = ""
## Anything the job wants to keep with it (a document's id...).
var data := {}

func _on_interacted(_body: Variant) -> void:
	get_tree().call_group("office_jobs", "on_office_button", self)

## A click box `size` (local to `parent`, centred at `at`) for `job`,
## outlined with `outline` (a MeshInstance3D - or none).
static func make(parent: Node3D, job_name: String, at: Vector3, size: Vector3, outline: MeshInstance3D = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Button_" + job_name
	body.set_script(load("res://Scripts/Office/OfficeButton.gd"))
	body.job = job_name
	if outline:
		body.has_outline = true
		body.mesh = outline
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	body.add_child(cs)
	parent.add_child(body)
	body.position = at
	return body
