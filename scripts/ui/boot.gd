extends Node

const GAME_SCENE: String = "res://scenes/game/game.tscn"


func _ready() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)
