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
	if "--demo-world-cycle" in args:
		# Only the active world's four layers may stay resident. Switching
		# worlds repeatedly must return texture memory to the same level rather
		# than accumulating, which a single before/after reading cannot show.
		var cycles: int = 3
		for i in args.size():
			if args[i] == "--demo-world-cycle" and i + 1 < args.size():
				cycles = clampi(int(args[i + 1]), 1, 10)
		var cycle_hud: Node = get_tree().get_first_node_in_group("hud")
		var cycle_arena: Node = get_tree().get_first_node_in_group("combat_arena")
		var world_source: Object = cycle_arena.get("worlds")
		var stages: Array[int] = [1, 40, 80]
		var baseline: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
		print("WORLDCYCLE baseline_mb=%.2f" % baseline)
		for step: int in cycles:
			for stage_value: int in stages:
				var world: Dictionary = world_source.call("world_for_stage", stage_value)
				cycle_hud.call("apply_world", world)
				for f: int in 4:
					await get_tree().process_frame
				var loaded_mb: float = float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0
				var loaded_layers: int = int(cycle_hud.call("debug_resident_layer_count"))
				# Every other world's layers must be gone, not just unreferenced.
				var foreign_cached: int = 0
				for other_stage: int in stages:
					if other_stage == stage_value:
						continue
					var other: Dictionary = world_source.call("world_for_stage", other_stage)
					for layer_name: String in ["sky", "distant", "arena", "foreground"]:
						if ResourceLoader.has_cached("res://assets/worlds/%s/%s.png" % [str(other.get("id", "")), layer_name]):
							foreign_cached += 1
				print("WORLDCYCLE cycle=%d world=%s loaded_mb=%.2f layers=%d foreign_cached=%d" % [
					step, str(world.get("id", "")), loaded_mb, loaded_layers, foreign_cached])
		# Back to a state with no world applied, to show the memory is returned.
		cycle_hud.call("_apply_world_layers", "none")
		for f3: int in 6:
			await get_tree().process_frame
		print("WORLDCYCLE final_released_mb=%.2f layers=%d" % [
			float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0,
			int(cycle_hud.call("debug_resident_layer_count"))])
		get_tree().quit()
	if "--demo-perf" in args:
		# Frame cost and texture memory with the real world and sprites loaded,
		# measured in the running game rather than estimated from file sizes.
		var samples: int = 120
		var worst: float = 0.0
		var total: float = 0.0
		for sample: int in samples:
			await get_tree().process_frame
			var frame_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
			total += frame_ms
			worst = maxf(worst, frame_ms)
		print("PERF frames=%d avg_process_ms=%.2f worst_ms=%.2f texture_mb=%.2f static_mem_mb=%.2f objects=%d" % [
			samples, total / float(samples), worst,
			float(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)) / 1048576.0,
			float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
			int(Performance.get_monitor(Performance.OBJECT_COUNT))])
		get_tree().quit()
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
