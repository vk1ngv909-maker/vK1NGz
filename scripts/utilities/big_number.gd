class_name BigNumber
extends RefCounted

## A base-10 floating-point value whose exponent is not limited by float range.
## Non-zero values have abs(mantissa) in [1, 10); zero is always (0, 0).

const MAX_SIGNIFICANT_DIGITS: int = 17
const SUFFIXES: PackedStringArray = [
	"", "K", "M", "B", "T", "aa", "ab", "ac", "ad", "ae", "af",
	"ag", "ah", "ai", "aj", "ak", "al", "am", "an", "ao", "ap"
]

var mantissa: float = 0.0
var exponent: int = 0


func _init(m: float = 0.0, e: int = 0) -> void:
	mantissa = m
	exponent = e
	_normalize()


static func from_float(v: float) -> BigNumber:
	return new(v, 0)


static func from_mantissa_exponent(m: float, e: int) -> BigNumber:
	return new(m, e)


static func from_dict(d: Dictionary) -> BigNumber:
	if not d.has("mantissa") or not d.has("exponent"):
		push_error("BigNumber.from_dict: dictionary must contain mantissa and exponent")
		return new()
	return new(float(d["mantissa"]), int(d["exponent"]))


func add(other: BigNumber) -> BigNumber:
	if not is_valid() or not other.is_valid():
		return new(NAN, 0)
	if mantissa == 0.0:
		return other._copy_normalized()
	if other.mantissa == 0.0:
		return _copy_normalized()

	var high: BigNumber = self
	var low: BigNumber = other
	if other.exponent > exponent:
		high = other
		low = self
	var gap: int = high.exponent - low.exponent
	if gap > MAX_SIGNIFICANT_DIGITS:
		return high._copy_normalized()
	var combined: float = high.mantissa + low.mantissa * pow(10.0, -gap)
	return new(combined, high.exponent)


func sub(other: BigNumber) -> BigNumber:
	var result: BigNumber = add(new(-other.mantissa, other.exponent))
	if result.is_valid() and result.mantissa < 0.0:
		return new()
	return result


func mul(other: BigNumber) -> BigNumber:
	if not is_valid() or not other.is_valid():
		return new(NAN, 0)
	if mantissa == 0.0 or other.mantissa == 0.0:
		return new()
	return new(mantissa * other.mantissa, exponent + other.exponent)


func div(other: BigNumber) -> BigNumber:
	if other.mantissa == 0.0:
		push_error("BigNumber.div: division by zero")
		return new()
	if not is_valid() or not other.is_valid():
		return new(NAN, 0)
	if mantissa == 0.0:
		return new()
	return new(mantissa / other.mantissa, exponent - other.exponent)


func mul_float(f: float) -> BigNumber:
	if not is_finite(f) or not is_valid():
		return new(NAN, 0)
	if f == 0.0 or mantissa == 0.0:
		return new()
	return new(mantissa * f, exponent)


func pow_float(f: float) -> BigNumber:
	if not is_valid() or not is_finite(f):
		return new(NAN, 0)
	if mantissa == 0.0:
		if f < 0.0:
			push_error("BigNumber.pow_float: zero cannot be raised to a negative power")
			return new()
		return from_float(1.0 if f == 0.0 else 0.0)

	var sign_value: float = 1.0
	if mantissa < 0.0:
		var rounded_power: float = round(f)
		if not is_equal_approx(f, rounded_power):
			push_error("BigNumber.pow_float: a negative value requires an integer power")
			return new(NAN, 0)
		if int(rounded_power) % 2 != 0:
			sign_value = -1.0

	var base_log: float = log(abs(mantissa)) / log(10.0) + float(exponent)
	var result_log: float = base_log * f
	if not is_finite(result_log):
		return new(NAN, 0)
	var result_exponent: int = int(floor(result_log))
	var result_mantissa: float = sign_value * pow(10.0, result_log - result_exponent)
	return new(result_mantissa, result_exponent)


func compare(other: BigNumber) -> int:
	if not is_valid() or not other.is_valid():
		return 0
	var a: BigNumber = _copy_normalized()
	var b: BigNumber = other._copy_normalized()
	if a.mantissa == b.mantissa and a.exponent == b.exponent:
		return 0
	if a.mantissa == 0.0:
		return -1 if b.mantissa > 0.0 else 1
	if b.mantissa == 0.0:
		return 1 if a.mantissa > 0.0 else -1
	if a.mantissa >= 0.0 and b.mantissa < 0.0:
		return 1
	if a.mantissa < 0.0 and b.mantissa >= 0.0:
		return -1
	if a.mantissa >= 0.0:
		if a.exponent != b.exponent:
			return 1 if a.exponent > b.exponent else -1
		return 1 if a.mantissa > b.mantissa else -1
	if a.exponent != b.exponent:
		return -1 if a.exponent > b.exponent else 1
	return -1 if a.mantissa < b.mantissa else 1


func is_greater_than(other: BigNumber) -> bool:
	return compare(other) > 0


func is_less_than(other: BigNumber) -> bool:
	return compare(other) < 0


func equals(other: BigNumber) -> bool:
	return compare(other) == 0


func clampi_to(minv: Variant, maxv: Variant) -> BigNumber:
	var minimum: BigNumber = _bound_to_big_number(minv)
	var maximum: BigNumber = _bound_to_big_number(maxv)
	if compare(minimum) < 0:
		return minimum._copy_normalized()
	if compare(maximum) > 0:
		return maximum._copy_normalized()
	return _copy_normalized()


func is_valid() -> bool:
	return is_finite(mantissa)


func to_dict() -> Dictionary:
	return {"mantissa": mantissa, "exponent": exponent}


func format() -> String:
	if not is_valid():
		return "Invalid"
	if mantissa == 0.0:
		return "0"
	var normalized: BigNumber = _copy_normalized()
	var sign_prefix: String = "-" if normalized.mantissa < 0.0 else ""
	var magnitude: float = abs(normalized.mantissa)
	if normalized.exponent < 3:
		var ordinary: float = magnitude * pow(10.0, normalized.exponent)
		return sign_prefix + _format_decimal(ordinary)
	if normalized.exponent >= 63:
		return sign_prefix + _format_decimal(magnitude) + "e" + str(normalized.exponent)

	var group: int = int(floor(float(normalized.exponent) / 3.0))
	if group >= SUFFIXES.size():
		return sign_prefix + _format_decimal(magnitude) + "e" + str(normalized.exponent)
	var grouped_value: float = magnitude * pow(10.0, normalized.exponent - group * 3)
	return sign_prefix + _format_decimal(grouped_value) + SUFFIXES[group]


func _normalize() -> void:
	if not is_finite(mantissa):
		return
	if mantissa == 0.0:
		exponent = 0
		return
	while abs(mantissa) >= 10.0:
		mantissa /= 10.0
		exponent += 1
	while abs(mantissa) < 1.0:
		mantissa *= 10.0
		exponent -= 1


func _copy_normalized() -> BigNumber:
	return new(mantissa, exponent)


static func _format_decimal(value: float) -> String:
	var text: String = "%.2f" % value
	while text.ends_with("0"):
		text = text.left(-1)
	if text.ends_with("."):
		text = text.left(-1)
	return text


static func _bound_to_big_number(value: Variant) -> BigNumber:
	if value is BigNumber:
		return value as BigNumber
	if value is int or value is float:
		return new(float(value), 0)
	push_error("BigNumber.clampi_to: bounds must be BigNumber or numeric")
	return new()
