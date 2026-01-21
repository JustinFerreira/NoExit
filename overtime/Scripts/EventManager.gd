## OverTime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Event Manager Script
## - This script manages actual dialog that is going to be 
## fed into where dialog is called, also specfic event functions
## are held here so that triggering responses to these events can
## be found and tweaked easier

extends Node

## Janitor Dialog

var janitor_text_array: Array[String] = [
	"Last day, right?",
	"Quite a familiar sight, watching a kid turn their back on this, and pardon my French",
	"lumpy pile of dog shit",
	"Let me guess, your heart wasn't in it? Corporate life didn't suit you?",
	"Oh, it doesn't matter. Just a quick word of advice.",
	"This life has a knack for following you.",
	"It's kinda like chronic depression or my ex-wife",
	"Once it's got its claws in you, it won't want to let go."
]


## Solo Hints

var car_distance: String = "Must be too far to hear the car."

## Reminders?

var forgot_keys: String = "Where did I leave my keys?"

var need_battery_and_gas: String = "Oh no! I don't have a battery or any gas! I better go get the spares that I think are on bottom floor."

var need_battery: String = "Oh no I have to fix my battery"

var need_gas: String = "Oh no I have to get my gas"


## Loop0

var loop0_get_in_car: String = "Can't wait to get home let me start this car and get out of here!"

var loop0_hood_no_battery: String = "Huh I guess I have no battery"

## Minigame

var hotwire_reminder: String = "I better hot wire my own car like I always do right under the steering wheel."

## Pickup Dialogs

#Box Dialogs

var box_pickup: String = "I've got to pack up all this stuff!"

var box_pickup_hint: String = "With your box equipped now you can pick up these items from your desk. hold E to see Inventory, and see your Box is highlighted red as equipped items are highlighted red."

#Key Dialogs

var keys_pickup_early: String = "I should pick up all my stuff from my desk."

var keys_pickup: String = "Great now I can head to the elevator and get to my car."

var keys_pickup_hint: String = "Use the scroll on the mouse to change your equipped item. If the item you pick up is equippable it will automaticly be equipped."

## Examine Item Dialogs

#Stapler 
var stapler_first_pick_dialog: String  = "Eh, I can probably take this. Corporate can cry about for all care."
var stapler_normal_dialog: String  = "Eh, I can probably take this. Corporate can cry about for all care."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
