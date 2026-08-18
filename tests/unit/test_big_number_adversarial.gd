extends SceneTree
## Independent adversarial suite for BigNumber.
## Written against the spec, NOT derived from the implementation's own tests,
## so it stays useful as a regression net if the internals are rewritten.

var failed: int = 0

func ck(label: String, cond: bool, got: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		failed += 1
		print("  FAIL ", label, "  got=", got)

func _init() -> void:
	var B := load("res://scripts/utilities/big_number.gd")
	var zero = B.from_float(0.0)
	var e100 = B.from_mantissa_exponent(1.0, 100)
	var e10k = B.from_mantissa_exponent(1.0, 10000)

	ck("1e100+1 stays 1e100", e100.add(B.from_float(1.0)).format() == "1e100")
	ck("add commutes across gap", e100.add(B.from_float(5.0)).compare(B.from_float(5.0).add(e100)) == 0)
	ck("sub clamps at zero", B.from_float(3.0).sub(B.from_float(10.0)).equals(zero))
	ck("div by zero yields zero", B.from_float(7.0).div(zero).equals(zero))
	ck("1e10000 valid", e10k.is_valid())
	ck("1e10000 round-trips", B.from_dict(e10k.to_dict()).compare(e10k) == 0)
	ck("1e10000 formats", e10k.format() == "1e10000", e10k.format())
	ck("zero times huge is zero", zero.mul(e10k).equals(zero))
	ck("1000 equals 1e3", B.from_float(1000.0).compare(B.from_mantissa_exponent(1.0, 3)) == 0)
	ck("NaN rejected", not B.from_float(NAN).is_valid())

	# 9^(2^40): exponent ~1.05e12, catches overflow and format-loop bugs
	var p = B.from_float(9.0)
	for _i in range(40):
		p = p.mul(p)
	ck("repeated squaring stays valid", p.is_valid(), p.format())
	ck("huge exponent formats scientifically", p.format().find("e") > 0, p.format())

	print("ADVERSARIAL: FAIL %d" % failed if failed > 0 else "ADVERSARIAL: all passed")
	quit(1 if failed > 0 else 0)
