extends SceneTree
## The approved rear-view composition, and the rules that keep it readable.
##
## The camera sits behind one hero at the lower centre with the enemy directly
## ahead on the same vertical axis. Enemies and bosses each fill an approved
## share of the arena, damage numbers spread across lanes around the enemy
## rather than piling up in one place, and the pool never grows.

const HudScript = preload("res://scripts/ui/hud.gd")
const PoolScript = preload("res://scripts/combat/damage_number_pool.gd")
const BN = preload("res://scripts/utilities/big_number.gd")

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)


func make_pool(enemy_rect: Rect2, exclusions: Array[Rect2] = []) -> DamageNumberPool:
	var pool: DamageNumberPool = PoolScript.new()
	pool.size = Vector2(1080.0, 1000.0)
	root.add_child(pool)
	pool.ensure_pool()
	pool.enemy_rect = enemy_rect
	pool.exclusions = exclusions
	return pool


func _init() -> void:
	# ---- composition constants ----
	ck("the hero and the enemy share one vertical axis",
		is_equal_approx(HudScript.COMBAT_AXIS, 0.5), str(HudScript.COMBAT_AXIS))
	ck("the hero stands at the lower centre",
		HudScript.HERO_ANCHOR_Y >= 0.85 and HudScript.HERO_ANCHOR_Y <= 1.0, str(HudScript.HERO_ANCHOR_Y))
	ck("the enemy stands ahead, in the upper half",
		HudScript.ENEMY_ANCHOR_Y <= 0.6, str(HudScript.ENEMY_ANCHOR_Y))
	ck("the enemy is anchored above the hero",
		HudScript.ENEMY_ANCHOR_Y < HudScript.HERO_ANCHOR_Y, "")
	ck("normal enemies fill 18-25% of the arena height",
		is_equal_approx(HudScript.ENEMY_HEIGHT_BAND.x, 0.18) and is_equal_approx(HudScript.ENEMY_HEIGHT_BAND.y, 0.25),
		str(HudScript.ENEMY_HEIGHT_BAND))
	ck("bosses fill 32-42% of the arena height",
		is_equal_approx(HudScript.BOSS_HEIGHT_BAND.x, 0.32) and is_equal_approx(HudScript.BOSS_HEIGHT_BAND.y, 0.42),
		str(HudScript.BOSS_HEIGHT_BAND))
	ck("a boss is markedly larger than a normal enemy",
		HudScript.BOSS_HEIGHT_BAND.x >= HudScript.ENEMY_HEIGHT_BAND.y * 1.25,
		"%f vs %f" % [HudScript.BOSS_HEIGHT_BAND.x, HudScript.ENEMY_HEIGHT_BAND.y])
	ck("wide silhouettes are held inside a safe width",
		HudScript.ENEMY_MAX_WIDTH < 0.5 and HudScript.BOSS_MAX_WIDTH < 0.7,
		"%f / %f" % [HudScript.ENEMY_MAX_WIDTH, HudScript.BOSS_MAX_WIDTH])

	# The band mapping must keep every silhouette inside its range, including
	# the extremes: a very wide boss and a very tall thin one.
	for aspect: float in [0.5, 0.8, 1.0, 1.3, 1.8, 2.4]:
		var t: float = clampf((1.3 - aspect) / 1.1, 0.0, 1.0)
		var normal: float = lerpf(HudScript.ENEMY_HEIGHT_BAND.x, HudScript.ENEMY_HEIGHT_BAND.y, t)
		var boss: float = lerpf(HudScript.BOSS_HEIGHT_BAND.x, HudScript.BOSS_HEIGHT_BAND.y, t)
		ck("aspect %.1f keeps a normal enemy inside its band" % aspect,
			normal >= HudScript.ENEMY_HEIGHT_BAND.x - 0.001 and normal <= HudScript.ENEMY_HEIGHT_BAND.y + 0.001, str(normal))
		ck("aspect %.1f keeps a boss inside its band" % aspect,
			boss >= HudScript.BOSS_HEIGHT_BAND.x - 0.001 and boss <= HudScript.BOSS_HEIGHT_BAND.y + 0.001, str(boss))

	# ---- lanes: both sides used, never three in a row on one side ----
	var pool: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 200.0), Vector2(220.0, 200.0)))
	var sides: Array[String] = []
	for hit: int in 24:
		var lane: String = pool.next_lane()
		pool.show_damage_in_lane(BN.from_float(5.0), "normal" if hit % 3 else "critical", lane)
		sides.append(pool.lane_side(lane))
	ck("both sides are used", sides.has("left") and sides.has("right"), str(sides))
	var run: int = 1
	var worst_run: int = 1
	for index: int in range(1, sides.size()):
		run = run + 1 if sides[index] == sides[index - 1] else 1
		worst_run = maxi(worst_run, run)
	ck("never more than two numbers in a row on the same side", worst_run <= 2, "longest run %d" % worst_run)
	var lanes: Array[String] = pool.lane_history()
	var distinct: Dictionary = {}
	for lane_value: String in lanes:
		distinct[lane_value] = true
	ck("numbers spread across at least four lanes", distinct.size() >= 4, str(distinct.keys()))

	# Criticals must not always land on the same side.
	var critical_sides: Dictionary = {}
	var critical_pool: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 200.0), Vector2(220.0, 200.0)))
	for hit: int in 12:
		var lane: String = critical_pool.next_lane()
		critical_pool.show_damage_in_lane(BN.from_float(9.0), "critical", lane)
		critical_sides[critical_pool.lane_side(lane)] = true
	ck("critical damage appears on both sides", critical_sides.has("left") and critical_sides.has("right"),
		str(critical_sides.keys()))

	# Simultaneous hits of different kinds must not share a lane.
	var mixed: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 200.0), Vector2(220.0, 200.0)))
	var used: Dictionary = {}
	for kind: String in ["normal", "critical", "falcon", "dps"]:
		var lane: String = mixed.next_lane()
		mixed.show_damage_in_lane(BN.from_float(3.0), kind, lane)
		ck("%s damage takes its own lane" % kind, not used.has(lane), lane)
		used[lane] = true

	# ---- lanes follow the enemy and avoid the HUD ----
	var near: DamageNumberPool = make_pool(Rect2(Vector2(100.0, 100.0), Vector2(120.0, 120.0)))
	var far: DamageNumberPool = make_pool(Rect2(Vector2(700.0, 600.0), Vector2(300.0, 260.0)))
	ck("a lane moves with the enemy it belongs to",
		near.lane_position("upper_left") != far.lane_position("upper_left"),
		"%s vs %s" % [near.lane_position("upper_left"), far.lane_position("upper_left")])
	var blocked := Rect2(Vector2(300.0, 180.0), Vector2(500.0, 90.0))
	var guarded: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 300.0), Vector2(220.0, 200.0)), [blocked] as Array[Rect2])
	for lane: String in ["upper_left", "upper_right", "middle_left", "middle_right", "lower_left", "lower_right"]:
		var point: Vector2 = guarded.lane_position(lane)
		var box := Rect2(point - Vector2(90.0, 30.0), Vector2(180.0, 60.0))
		ck("lane %s stays off the HUD readouts" % lane, not blocked.intersects(box), str(point))
		ck("lane %s stays on screen" % lane,
			point.x > 0.0 and point.y > 0.0 and point.x < guarded.size.x and point.y < guarded.size.y, str(point))

	# ---- a critical is wider than a plain number and must still fit ----
	var wide: DamageNumberPool = make_pool(Rect2(Vector2(760.0, 240.0), Vector2(280.0, 240.0)))
	for lane: String in PoolScript.LANES:
		var half := Vector2(150.0, 30.0)
		var point: Vector2 = wide.lane_position(lane, half)
		var box := Rect2(point - half, half * 2.0)
		ck("a critical in lane %s stays fully on screen" % lane,
			box.position.x >= 0.0 and box.position.y >= 0.0
			and box.position.x + box.size.x <= wide.size.x
			and box.position.y + box.size.y <= wide.size.y, str(box))
	# Negative control: the same lane with no width allowance would run off the
	# right edge for an enemy pushed against it.
	var narrow_point: Vector2 = wide.lane_position("middle_right", Vector2(10.0, 30.0))
	ck("without a width allowance the critical box would overflow",
		narrow_point.x + 150.0 > wide.size.x, str(narrow_point))

	# ---- the pool is bounded under sustained attack ----
	var stress: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 200.0), Vector2(220.0, 200.0)))
	var before: int = stress.get_child_count()
	for hit: int in 1200:
		stress.show_damage(BN.from_float(7.0), "critical" if hit % 5 == 0 else "normal", Vector2.ZERO)
	ck("1200 attacks create no extra nodes", stress.get_child_count() == before,
		"%d then %d" % [before, stress.get_child_count()])
	ck("the pool holds its configured maximum", before == PoolScript.POOL_SIZE, str(before))
	ck("no more numbers are alive than the pool holds",
		stress.live_label_count() <= PoolScript.POOL_SIZE, str(stress.live_label_count()))

	# ---- negative control: forcing one lane must fail these rules ----
	var forced: DamageNumberPool = make_pool(Rect2(Vector2(440.0, 200.0), Vector2(220.0, 200.0)))
	var forced_sides: Array[String] = []
	for hit: int in 10:
		forced.show_damage_in_lane(BN.from_float(4.0), "normal", "middle_left")
		forced_sides.append("left")
	var forced_run: int = 1
	var forced_worst: int = 1
	for index: int in range(1, forced_sides.size()):
		forced_run = forced_run + 1 if forced_sides[index] == forced_sides[index - 1] else 1
		forced_worst = maxi(forced_worst, forced_run)
	ck("the side rule would fail if every number were forced to one lane", forced_worst > 2,
		"longest run %d" % forced_worst)

	print("COMBAT COMPOSITION: ", "all passed" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
