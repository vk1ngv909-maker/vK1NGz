extends SceneTree
## Proves the damage-number pool bounds allocation: node count must STABILISE
## under sustained rapid tapping, not grow without limit.

var failed: int = 0
func ck(l: String, c: bool, got: String = "") -> void:
	if c: print("  ok   ", l)
	else:
		failed += 1; print("  FAIL ", l, "  got=", got)

func _init() -> void:
	var Pool = load("res://scripts/combat/damage_number_pool.gd")
	var BN = load("res://scripts/utilities/big_number.gd")
	var host := Control.new()
	get_root().add_child(host)
	var pool = Pool.new()
	host.add_child(pool)
	await process_frame

	var after_ready: int = pool.get_child_count()
	ck("pool pre-allocates", after_ready > 0, str(after_ready))

	# Blast far more numbers than the pool size, repeatedly.
	var kinds := ["normal", "critical", "falcon"]
	for burst in range(20):
		for i in range(50):
			pool.show_damage(BN.from_float(float(i + 1)), kinds[i % 3], Vector2(100, 200))
		await process_frame
	var after_burst: int = pool.get_child_count()
	ck("node count stable after 1000 hits", after_burst == after_ready,
		"start=%d now=%d" % [after_ready, after_burst])

	# Let tweens finish, then blast again — still must not grow.
	for i in range(30):
		await process_frame
	for i in range(200):
		pool.show_damage(BN.from_float(7.0), "normal", Vector2(50, 50))
	await process_frame
	var final_count: int = pool.get_child_count()
	ck("node count stable after 1200 total", final_count == after_ready,
		"start=%d final=%d" % [after_ready, final_count])

	print("POOL: FAIL %d" % failed if failed > 0 else "POOL: all passed (stable at %d nodes)" % after_ready)
	quit(1 if failed > 0 else 0)
