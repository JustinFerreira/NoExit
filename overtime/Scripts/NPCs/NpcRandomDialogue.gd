## No Exit
## Overtime Studios
## Last updated 10/19/26 by Justin Ferreira
## Npc Random Dialogue Script
## - For NPCs that just sit at their desk.
## so they can spit out random stuff on interaction
## - built on NPC (idle animation and typing sounds are set in its inspector)

extends NPC


func _on_interacted(_body: Variant) -> void:
	GetRandomDialog()

## One of this NPC's lines, picked at random.
func GetRandomDialog():
	# Lines set in the inspector win; otherwise the shared "busy" lines.
	say_random(random_lines if not random_lines.is_empty() else EventManager.random_npc_busy_dialog)
