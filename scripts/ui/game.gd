extends Node
## Game root. Captures a real rendered frame when run with --shot, so portrait
## layouts are verified from pixels rather than assumed from scene files.

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if "--shot" not in args:
		return
	var out_path: String = "user://shot.png"
	for i in args.size():
		if args[i] == "--shot-out" and i + 1 < args.size():
			out_path = args[i + 1]
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var shot: Image = get_viewport().get_texture().get_image()
	var err: Error = shot.save_png(out_path)
	if err != OK:
		push_error("screenshot failed: %d" % err)
	else:
		print("SHOT_SAVED %dx%d" % [shot.get_width(), shot.get_height()])
	get_tree().quit()
