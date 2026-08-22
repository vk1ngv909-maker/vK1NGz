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
	if "--demo-attack-seq" in args:
		# One ordered pass through a single sword attack, saved frame by frame,
		# so the connection between the blade and the enemy can be checked
		# rather than asserted.
		var seq_arena: Node = get_tree().get_first_node_in_group("combat_arena")
		var base_path: String = out_path.get_basename()
		var labels: Array[String] = ["idle", "windup", "travel", "impact", "reaction", "recovery"]
		var waits: Array[float] = [0.0, 0.05, 0.10, 0.06, 0.10, 0.22]
		for index: int in labels.size():
			if index == 1 and seq_arena != null:
				seq_arena.call("debug_tap")
			if waits[index] > 0.0:
				await get_tree().create_timer(waits[index]).timeout
			await get_tree().process_frame
			var frame: Image = get_viewport().get_texture().get_image()
			frame.save_png("%s_%d_%s.png" % [base_path, index, labels[index]])
			print("ATTACKSEQ %d %s" % [index, labels[index]])
		get_tree().quit()
	if "--demo-clip" in args:
		# A frame dump of the real running game: every frame written here is a
		# frame the renderer actually produced, in order, with the game delta
		# that produced it recorded alongside. Still frames cannot show whether
		# the pose swap pops or the hero drifts; consecutive ones can.
		var clip_frames: int = 150
		for i in args.size():
			if args[i] == "--demo-clip" and i + 1 < args.size():
				clip_frames = clampi(int(args[i + 1]), 10, 600)
		var clip_arena: Node = get_tree().get_first_node_in_group("combat_arena")
		var clip_hud: Node = get_tree().get_first_node_in_group("hud")
		var clip_hero: Control = clip_arena.get("hero")
		var clip_base: String = out_path.get_basename()
		# Scripted beats so the clip always contains the same events: settle,
		# five rapid taps, then enough taps to kill and roll on to the next
		# enemy, then settle again.
		# Beats in frames, meant to be run under --fixed-fps 30 so one frame is
		# one thirtieth of a game second and the clip plays at the speed a
		# device would show. Five rapid taps first, then a run of taps that
		# carries the fight through a kill and on to the next enemy.
		var tap_frames: Array[int] = [40, 44, 48, 52, 56]
		var kill_frames: Array[int] = []
		for k: int in 28:
			kill_frames.append(100 + k * 4)
		var timeline: Array[String] = []
		for frame: int in clip_frames:
			if frame in tap_frames or frame in kill_frames:
				clip_arena.call("debug_tap")
			await get_tree().process_frame
			var image: Image = get_viewport().get_texture().get_image()
			image.save_png("%s_%03d.png" % [clip_base, frame])
			var entry: Dictionary = clip_hud.call("hero_metrics")
			var foot: Vector2 = clip_hero.position + HeroPlacement.body_offset(clip_hero.size.y, entry)
			# Count only the tap's own damage. The falcon and the DPS tick post
			# numbers on their own schedule, and counting those made an earlier
			# reading look like damage appeared one frame after the tap.
			var tap_damage: int = 0
			for kind_value: Variant in clip_arena.get("damage_pool").call("kind_history"):
				if str(kind_value) in ["normal", "critical"]:
					tap_damage += 1
			# How far the slash has travelled from the hero to the enemy, 0-1.
			var clip_slash: Control = clip_arena.get("slash")
			var clip_enemy: Control = clip_arena.get("enemy")
			var goal: Vector2 = clip_enemy.position + clip_enemy.size * 0.5
			var span: float = (clip_hero.position + clip_hero.size * 0.5).distance_to(goal)
			var arc: float = 0.0
			if clip_slash.visible and span > 1.0:
				arc = 1.0 - clampf((clip_slash.position + clip_slash.size * 0.5).distance_to(goal) / span, 0.0, 1.0)
			timeline.append("%d,%.5f,%s,%.3f,%.3f,%d,%d,%d,%.3f" % [
				frame, get_process_delta_time(), str(clip_hud.call("hero_pose")),
				foot.x, foot.y, int(clip_arena.get("damage_pool").call("live_label_count")),
				clip_arena.get("combat").stage, tap_damage, arc])
		var log_file: FileAccess = FileAccess.open("%s_timeline.csv" % clip_base, FileAccess.WRITE)
		if log_file != null:
			log_file.store_line("frame,delta_s,pose,foot_x,foot_y,live_numbers,stage,tap_damage_total,arc_progress")
			for row: String in timeline:
				log_file.store_line(row)
			log_file.close()
		print("CLIP frames=%d base=%s" % [clip_frames, clip_base])
		get_tree().quit()
	if "--demo-attack-verify" in args:
		# The claims a still frame cannot carry: that damage is never shown
		# before the hit connects, that the hero returns to the exact anchor
		# after sustained tapping, and that the staff bolt actually arrives.
		var va: Node = get_tree().get_first_node_in_group("combat_arena")
		var vhud: Node = get_tree().get_first_node_in_group("hud")
		var vhero: Control = va.get("hero")
		var venemy: Control = va.get("enemy")
		var vpool: Node = va.get("damage_pool")
		var travel: float = float(va.call("attack_travel_seconds"))

		# 1. damage appears only after the blade has had time to cross
		vpool.call("hide_all")
		var start: int = Time.get_ticks_usec()
		va.call("debug_tap")
		var vslash: Control = va.get("slash")
		var origin: Vector2 = vhero.position + vhero.size * 0.5
		var goal: Vector2 = venemy.position + venemy.size * 0.5
		var full: float = origin.distance_to(goal)
		# The falcon strikes on its own schedule, so counting labels would time
		# whichever number happened to appear first. Only the tap's own kinds
		# count here.
		var baseline: int = (vpool.call("kind_history") as Array).size()
		var seen_us: int = -1
		var progress: float = 0.0
		var elapsed_game: float = 0.0
		for f: int in 60:
			await get_tree().process_frame
			elapsed_game += get_process_delta_time()
			var kinds: Array = vpool.call("kind_history")
			var tapped: bool = false
			for k: int in range(baseline, kinds.size()):
				if str(kinds[k]) in ["normal", "critical"]:
					tapped = true
			if tapped:
				seen_us = Time.get_ticks_usec() - start
				var tip: Vector2 = vslash.position + vslash.size * 0.5
				progress = 1.0 - clampf(tip.distance_to(goal) / maxf(1.0, full), 0.0, 1.0)
				break
		# Frame-quantised and read one frame late under software rendering, so it
		# is reported for context only; the geometric check below is the claim.
		print("ATTACKVERIFY frame_quantised_time_to_damage_s=%.3f" % elapsed_game)
		# Wall-clock timing drifts by up to a frame under software rendering, so
		# the claim is checked geometrically as well: how far the arc had
		# travelled toward the enemy on the frame the number first existed.
		print("ATTACKVERIFY connect_travel_s=%.3f wallclock_s=%.3f arc_progress=%.2f connected_first=%s" % [
			travel, float(seen_us) / 1000000.0, progress, str(seen_us >= 0 and progress >= 0.9)])

		# 2. the hero returns to the anchor after rapid tapping
		# Settle to idle first: the attack pose has its own rectangle, so a
		# baseline sampled mid-swing measures the pose change, not drift.
		vhud.call("set_hero_pose", "idle")
		for settle_first: int in 40:
			await get_tree().process_frame
		var anchor_point: Vector2 = vhud.get("hero_anchor")
		var idle_entry: Dictionary = vhud.call("hero_metrics", "idle")
		var anchor_foot: Vector2 = anchor_point + HeroPlacement.body_offset(vhero.size.y, idle_entry)
		for tap: int in 200:
			va.call("debug_tap")
			if tap % 8 == 0:
				await get_tree().process_frame
		for settle: int in 90:
			await get_tree().process_frame
		var drift: float = vhero.position.distance_to(anchor_point)
		var settled_foot: Vector2 = vhero.position + HeroPlacement.body_offset(vhero.size.y, vhud.call("hero_metrics"))
		print("ATTACKVERIFY taps=200 anchor=%s hero=%s drift_px=%.3f foot_drift_px=%.3f pose=%s" % [
			str(anchor_point), str(vhero.position), drift,
			anchor_foot.distance_to(settled_foot), str(va.call("hero_pose"))])
		# The two poses fill their canvas differently, so the check that matters
		# is not the rectangle's corner but where the visible feet land.
		var feet: Dictionary = {}
		for pose: String in ["idle", "attack"]:
			vhud.call("set_hero_pose", pose)
			await get_tree().process_frame
			var entry: Dictionary = vhud.call("hero_metrics", pose)
			var offset: Vector2 = HeroPlacement.body_offset(vhero.size.y, entry)
			feet[pose] = vhero.position + offset
			print("ATTACKVERIFY pose=%s rect=%s pos=%s foot=%s texture=%s" % [
				pose, str(vhero.size), str(vhero.position), str(feet[pose]),
				str(vhero.texture.resource_path if vhero.texture != null else "<none>")])
		vhud.call("set_hero_pose", "idle")
		await get_tree().process_frame
		print("ATTACKVERIFY foot_gap_px=%.3f" % (feet["idle"] as Vector2).distance_to(feet["attack"]))
		print("ATTACKVERIFY pool_children=%d live=%d" % [
			vpool.get_child_count(), int(vpool.call("live_label_count"))])

		# 3. the staff bolt reaches the enemy at the moment of impact
		va.call("debug_force_attack_style", "ranged")
		print("ATTACKVERIFY style=%s" % str(va.call("attack_style")))
		va.call("debug_tap")
		await get_tree().create_timer(travel).timeout
		await get_tree().process_frame
		var bolt: Vector2 = va.call("projectile_position")
		var target: Vector2 = venemy.position + venemy.size * 0.5
		var reach: float = maxf(venemy.size.x * venemy.scale.x, venemy.size.y * venemy.scale.y) * 0.5
		print("ATTACKVERIFY bolt=%s enemy_centre=%s gap_px=%.1f enemy_reach_px=%.1f arrived=%s" % [
			str(bolt), str(target), bolt.distance_to(target), reach,
			str(bolt.distance_to(target) <= reach)])
		var ranged_frame: Image = get_viewport().get_texture().get_image()
		ranged_frame.save_png("%s_ranged.png" % out_path.get_basename())
		va.call("debug_force_attack_style", "melee")
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
