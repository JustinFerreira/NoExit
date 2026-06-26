##No Exit
## Overtime Studios
## Last updated 2/14/26 by Justin Ferreira
## Splash Screen Script
## - This script is the first thing the player see when entering the game
## this screen show off logo and studio

extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if PlayerManager.DevMode == true:
		get_tree().change_scene_to_file.call_deferred("res://Menus/MainMenu.tscn")
		return
	animation_player.connect("animation_finished", _on_animation_finished)
	$AnimationPlayer.play("Splash")

func _on_animation_finished(anim_name: String):
	if anim_name == "Splash":
		get_tree().change_scene_to_file("res://Menus/MainMenu.tscn")
		
