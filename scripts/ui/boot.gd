extends Node

const GAME_SCENE: String = "res://scenes/game/game.tscn"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if "--debug-complete-tutorial" in args:
		if SaveManager.data.is_empty():
			SaveManager.data = SaveManager.default_data()
		var permanent_state: Dictionary = SaveManager.data.get("permanent_state", {})
		permanent_state["tutorial"] = {"completed": true, "current_step": 0}
		SaveManager.data["permanent_state"] = permanent_state
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE)
