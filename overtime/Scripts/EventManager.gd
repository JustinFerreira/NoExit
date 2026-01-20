## OverTime Studios
## Last upadated 1/19/26 by Justin Ferreira
## Event Manager Script
## - This script manages actual dialog that is going to be 
## fed into where dialog is called, also specfic event functions
## are held here so that triggering responses to these events can
## be found and tweaked easier

extends Node

## Solo Hints

var car_distance: String = "Must be too far to hear the car."

## idk what to call this

var forgot_keys: String = "Where did I leave my keys?"


## Loop0

var loop0_get_in_car: String = "Can't wait to get home let me start this car and get out of here!"

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
