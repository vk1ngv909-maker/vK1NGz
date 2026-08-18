extends SceneTree

const BigNumber = preload("res://scripts/utilities/big_number.gd")

var passed: int = 0
var failed: int = 0


func _init() -> void:
	_test_normalization()
	_test_arithmetic()
	_test_comparison_and_clamp()
	_test_serialization()
	_test_formatting()
	_test_huge_and_invalid_values()
	print("PASS %d / FAIL %d" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + message)


func _check_value(value: BigNumber, mantissa: float, exponent: int, message: String) -> void:
	_check(is_equal_approx(value.mantissa, mantissa) and value.exponent == exponent, message)


func _test_normalization() -> void:
	_check_value(BigNumber.from_mantissa_exponent(123.45, 7), 1.2345, 9, "normalizes large mantissa")
	_check_value(BigNumber.from_mantissa_exponent(0.0125, 4), 1.25, 2, "normalizes small mantissa")
	_check_value(BigNumber.from_mantissa_exponent(-42.0, 3), -4.2, 4, "normalizes negative mantissa")
	_check_value(BigNumber.from_float(0.0), 0.0, 0, "zero has canonical representation")


func _test_arithmetic() -> void:
	var a: BigNumber = BigNumber.from_mantissa_exponent(1.5, 8)
	var b: BigNumber = BigNumber.from_mantissa_exponent(2.5, 7)
	_check_value(a.add(b), 1.75, 8, "adds across exponent gap")
	_check_value(a.sub(b), 1.25, 8, "subtracts across exponent gap")
	_check_value(a.mul(b), 3.75, 15, "multiplies mantissas and exponents")
	_check_value(a.div(b), 6.0, 0, "divides mantissas and exponents")
	_check_value(a.mul_float(2.0), 3.0, 8, "multiplies by float")
	_check_value(BigNumber.from_float(100.0).pow_float(2.5), 1.0, 5, "raises to float power")

	var huge: BigNumber = BigNumber.from_mantissa_exponent(4.0, 10000)
	var tiny: BigNumber = BigNumber.from_float(7.0)
	var wide_sum: BigNumber = huge.add(tiny)
	_check(wide_sum.equals(huge), "addition safely handles exponent gaps greater than float precision")
	_check_value(BigNumber.from_float(5.0).sub(BigNumber.from_float(8.0)), 0.0, 0, "subtraction clamps below zero")
	_check_value(BigNumber.from_float(5.0).div(BigNumber.from_float(0.0)), 0.0, 0, "division by zero returns zero")


func _test_comparison_and_clamp() -> void:
	var thousand_a: BigNumber = BigNumber.from_mantissa_exponent(1.0, 3)
	var thousand_b: BigNumber = BigNumber.from_mantissa_exponent(10.0, 2)
	_check(thousand_a.equals(thousand_b), "equal values compare equal after different input forms")
	_check(BigNumber.from_float(999.0).is_less_than(thousand_a), "less-than orders values")
	_check(thousand_a.is_greater_than(BigNumber.from_float(-1.0)), "greater-than handles signs")
	_check(BigNumber.from_float(-100.0).is_less_than(BigNumber.from_float(-10.0)), "comparison orders negative values")
	_check(BigNumber.from_float(0.0).is_less_than(BigNumber.from_float(0.1)), "zero compares below small positive values")
	_check(BigNumber.from_float(0.0).is_greater_than(BigNumber.from_float(-0.1)), "zero compares above small negative values")
	var clamped: BigNumber = BigNumber.from_float(25.0).clampi_to(BigNumber.from_float(30.0), BigNumber.from_float(40.0))
	_check(clamped.equals(BigNumber.from_float(30.0)), "clampi_to applies lower bound")
	_check(BigNumber.from_float(25.0).clampi_to(0, 10).equals(BigNumber.from_float(10.0)), "clampi_to accepts integer bounds")


func _test_serialization() -> void:
	var original: BigNumber = BigNumber.from_mantissa_exponent(7.654321, 4321)
	var restored: BigNumber = BigNumber.from_dict(original.to_dict())
	_check(restored.equals(original), "dictionary serialization round-trips")


func _test_formatting() -> void:
	var cases: Array[Array] = [
		[BigNumber.from_float(0.0), "0"],
		[BigNumber.from_float(1.0), "1"],
		[BigNumber.from_float(999.5), "999.5"],
		[BigNumber.from_mantissa_exponent(1.0, 3), "1K"],
		[BigNumber.from_mantissa_exponent(1.0, 6), "1M"],
		[BigNumber.from_mantissa_exponent(1.0, 9), "1B"],
		[BigNumber.from_mantissa_exponent(1.0, 12), "1T"],
		[BigNumber.from_mantissa_exponent(1.0, 15), "1aa"],
		[BigNumber.from_mantissa_exponent(1.0, 100), "1e100"],
		[BigNumber.from_mantissa_exponent(-1.25, 6), "-1.25M"]
	]
	for test_case: Array in cases:
		var value: BigNumber = test_case[0] as BigNumber
		var expected: String = test_case[1] as String
		_check(value.format() == expected, "formats %s as %s" % [value.to_dict(), expected])


func _test_huge_and_invalid_values() -> void:
	var enormous: BigNumber = BigNumber.from_mantissa_exponent(1.0, 10000)
	_check(enormous.is_valid(), "1e10000 remains valid")
	_check(enormous.format() == "1e10000", "1e10000 formats without materializing a float value")
	_check(not BigNumber.from_float(NAN).is_valid(), "NaN mantissa is invalid")
	_check(not BigNumber.from_float(INF).is_valid(), "infinite mantissa is invalid")
