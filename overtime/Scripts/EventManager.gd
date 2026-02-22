## No Exit
## Overtime Studios
## Last upadated 1/23/26 by Justin Ferreira
## Event Manager Script
## - This script manages actual dialog that is going to be 
## fed into where dialog is called, also specfic event functions
## are held here so that triggering responses to these events can
## be found and tweaked easier

extends Node

var Comingfromelevator = false
var ElevatorDoorOpen = false
var CameFromGarage = false

## Janitor Dialog

#didn't speak before elevator
var janitor_didnt_speak_text: String = "Hey wait up!"

#multidialog
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

## Key Fob

var key_fob_no_keys: String = "Damn where did I put those keys?"

## Random Npc Busy Dialog

var random_npc_busy_dialog: Array[String] = ["I'm busy.","I'm working right now.","Can't you see I'm working.","There's lots to be done.","Paperwork paperwork paperwork","I'm really busy right now."]

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

var loop0_no_battery: String = "Huh the cars not starting I better check my battery"

## Office wake up Dialog

var office_wake_up_loop0: String = "Oh, must have dozed off. Is the day still not over? It’s always the last day that feels like forever. Might as well pack up."
var office_wake_up_loop0_hint: String = "Click to skip dialog"

var office_wake_up_loop1: Array[String] = ["Oh thank god…oh thank god it was just a dream. Ok…Ok, good. I need to stop pulling all-nighters like that. It’s screwing with my head.",
"It looks like I already took everything down.",
"Why would I come back up ... It doesn’t matter, I’m leaving for good"]

var office_wake_up_no_keys: String = "Where did I leave my keys?"

## Minigame

#Hotwire 

var hotwire_reminder: String = "I better hot wire my own car like I always do right under the steering wheel."

var hotwire_finished: String = "Great now I can start my car and get out of here, cause hot wiring tottally does not start the car."

#Battery

var battery_minigame_resetzone: String = "Oh I probbaly shouldn't do that"

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

#Sticky Notes
var stickynotes_first_pick_dialog: String  = "Maybe I can finally start drawing again. I mean, I got nothing else better to do in the mean time, so why not."
var stickynotes_normal_dialog: String  = "Maybe I can finally start drawing again. I mean, I got nothing else better to do in the mean time, so why not."

#Mug1A
var mug1a_first_pick_dialog: String  = "That was a fun pottery class. Wish I had more time to make something else besides a mug."
var mug1a_normal_dialog: String  = "That was a fun pottery class. Wish I had more time to make something else besides a mug."

#Mug2A
var mug2a_first_pick_dialog: String  = "I forgot why I have two mugs. Well, guess it doesn't matter anymore."
var mug2a_normal_dialog: String  = "I forgot why I have two mugs. Well, guess it doesn't matter anymore."

#Picture Frame 1
var pictureframe1_first_pick_dialog: String  = "What would they think? Probably go on some kind of tirade about “building their business with their own two hands,” or some meaningless garbage like that."
var pictureframe1_normal_dialog: String  = "What would they think? Probably go on some kind of tirade about “building their business with their own two hands,” or some meaningless garbage like that."

## Office Elevator

#spirnt hint toggle

var elevator_hint_1: String = "Hold shift, to sprint"

#sprint hint hold

var elevator_hint_2: String = "Use shift to toggle sprint"

#doesnt have keys

var elevator_no_keys: String = "Wait, I think I forgot my keys at my cubicle. Definitely need to grab those before leaving this hell hole"


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
