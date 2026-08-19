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
	if "--demo-falcon" in args:
		var ar: Node = get_tree().get_first_node_in_group("combat_arena")
		if ar != null and ar.has_method("debug_falcon"):
			ar.debug_falcon()
		await get_tree().process_frame
	if "--demo-boss-fail" in args:
		var ab: Node = get_tree().get_first_node_in_group("combat_arena")
		if ab != null and ab.has_method("debug_fail_boss"):
			ab.debug_fail_boss()
		await get_tree().process_frame
	if "--demo-skills" in args:
		var hud: Node = get_tree().current_scene.find_child("HUD", true, false)
		if hud == null:
			hud = find_child("HUD", true, false)
		if hud != null and hud.has_method("debug_activate_skills"):
			hud.debug_activate_skills(PackedStringArray(["sand_fury", "golden_wind"]))
		await get_tree().process_frame
	if "--demo-skills-cooldown" in args:
		var hud2: Node = get_tree().current_scene.find_child("HUD", true, false)
		if hud2 == null:
			hud2 = find_child("HUD", true, false)
		if hud2 != null and hud2.has_method("debug_force_cooldown"):
			hud2.debug_force_cooldown(PackedStringArray(["sand_fury", "critical_eclipse"]))
		await get_tree().process_frame
	if "--demo-prestige" in args:
		var ap: Node = get_tree().get_first_node_in_group("combat_arena")
		var ms: int = 200
		for i in args.size():
			if args[i] == "--demo-prestige" and i + 1 < args.size():
				ms = int(args[i + 1])
		if ap != null and ap.has_method("debug_open_prestige"):
			ap.debug_open_prestige(ms)
		await get_tree().process_frame
	if "--demo-retry" in args:
		var ar2: Node = get_tree().get_first_node_in_group("combat_arena")
		if ar2 != null and ar2.has_method("debug_retry"):
			ar2.debug_retry()
		await get_tree().process_frame
	if "--demo-falcon-seq" in args:
		# A still frame cannot show motion or a rate. This saves consecutive
		# rendered frames (movement) and then samples the strike counter over
		# real time (cadence), so both claims are measurable from the output.
		var frames: int = 12
		for i in args.size():
			if args[i] == "--demo-falcon-seq" and i + 1 < args.size():
				frames = clampi(int(args[i + 1]), 2, 40)
		var seq_arena: Node = get_tree().get_first_node_in_group("combat_arena")
		if seq_arena != null:
			seq_arena.call("debug_falcon_sequence_setup")
		var base: String = out_path.get_basename()
		var start_ms: int = Time.get_ticks_msec()
		for frame: int in frames:
			await get_tree().process_frame
			await get_tree().process_frame
			var frame_image: Image = get_viewport().get_texture().get_image()
			frame_image.save_png("%s_%02d.png" % [base, frame])
			print("FALCONSEQ frame=%02d t=%.2f %s" % [
				frame, float(Time.get_ticks_msec() - start_ms) / 1000.0,
				seq_arena.call("debug_falcon_state") if seq_arena != null else ""])
		for sample: int in 12:
			await get_tree().create_timer(0.25).timeout
			print("FALCONRATE t=%.2f %s" % [
				float(Time.get_ticks_msec() - start_ms) / 1000.0,
				seq_arena.call("debug_falcon_state") if seq_arena != null else ""])
		get_tree().quit()
	await get_tree().process_frame
	await get_tree().process_frame
	if "--debug-skill" in args:
		var hud_check: Node = get_tree().get_first_node_in_group("hud")
		if hud_check != null:
			print("SKILL_BUTTONS %s" % str(hud_check.call("debug_button_texts")))
	var shot: Image = get_viewport().get_texture().get_image()
	var err: Error = shot.save_png(out_path)
	if err != OK:
		push_error("screenshot failed: %d" % err)
	else:
		print("SHOT_SAVED %dx%d" % [shot.get_width(), shot.get_height()])
	get_tree().quit()
