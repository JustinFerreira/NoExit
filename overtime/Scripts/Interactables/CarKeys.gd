## No Exit
## Overtime Studios
## Last upadated 10/18/26 by Justin Ferreira
## Car Key Script
## - Script The Car Keys Examinable Pickup Item
## Pickup, inventory and sounds are set in the Inspector (ExaminableItem).
## The keys can only be examined once enough desk items are packed.

extends ExaminableItem

const DESK_ITEMS_NEEDED: int = 3

func _can_examine() -> bool:
	return true

func _on_examine_blocked() -> void:
	PlayerManager.CharacterDialog(EventManager.keys_pickup_early)

func _show_examine_dialog() -> void:
	PlayerManager.CharacterHintDialog(EventManager.keys_pickup, EventManager.keys_pickup_hint)

func _on_examine_started() -> void:
	if AnimationManager.ElevatorButtonFlash:
		AnimationManager.ElevatorButtonFlash.visible = true
	PlayerManager.firstdialog = false

func _on_picked_up() -> void:
	PlayerManager.gotKeys = true

func _should_flash() -> bool:
	return super._should_flash() and _can_examine()
