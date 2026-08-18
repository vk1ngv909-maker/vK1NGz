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
	# --demo-taps N drives real taps through the arena before capturing, so the
	# screenshot shows combat in motion (damage numbers, recoil, flash) rather
	# than a static HUD. Static layouts are not evidence of game feel.
	var taps: int = 0
	for i in args.size():
		if args[i] == "--demo-taps" and i + 1 < args.size():
			taps = int(args[i + 1])
	if taps > 0:
		var arena: Node = get_tree().get_first_node_in_group("combat_arena")
		if arena == null:
			arena = find_child("CombatArea", true, false)
		for t in taps:
			if arena != null and arena.has_method("debug_tap"):
				arena.debug_tap()
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
