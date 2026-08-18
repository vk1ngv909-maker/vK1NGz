# Goal
Implement a BigNumber (mantissa/exponent) layer in typed GDScript for a Godot 4.3
idle game, plus a headless test suite that proves it correct.

# Files to create
- scripts/utilities/big_number.gd   (class_name BigNumber, extends RefCounted)
- tests/unit/test_big_number.gd     (extends SceneTree, run headless)

# Requirements for big_number.gd
Normalized mantissa in [1,10) with integer exponent; zero is mantissa=0, exp=0.
Must support values to 1e10000 (do NOT rely on float range for the value itself).

Static constructors: from_float(v: float), from_mantissa_exponent(m: float, e: int)
Methods (all typed, all return new BigNumber, never mutate):
- add(other), sub(other), mul(other), div(other)
- mul_float(f: float), pow_float(f: float)
- compare(other) -> int   (-1, 0, 1)
- is_greater_than(other) -> bool, is_less_than(other) -> bool, equals(other) -> bool
- clampi_to(minv, maxv) -> BigNumber
- is_valid() -> bool       (false for NaN/INF mantissa)
- to_dict() -> Dictionary / static from_dict(d) -> BigNumber   (serialization)
- format() -> String

format() rules:
- below 1000 -> up to 2 decimals, trailing zeros trimmed ("999.5", "42")
- then suffixes K, M, B, T, then aa, ab, ac ... (3-digit groups)
- at exponent >= 63 or beyond suffix table -> scientific like "1.23e100"
- negative numbers keep the sign

Division by zero must return zero and push_error, never crash or produce INF.
Subtraction that would go below zero returns zero (game currency never negative).

# Requirements for the test file
extends SceneTree, func _init() runs all tests then quit().
Use assert-style helper that prints "PASS n / FAIL n" and sets exit code non-zero
on any failure via OS.exit_code. Cover at minimum:
- normalization, add/sub/mul/div correctness across exponent gaps
- add where exponents differ by >17 (small operand must not vanish incorrectly)
- sub clamping at zero, div by zero
- comparison ordering incl. equal values with different internal forms
- round-trip to_dict/from_dict equality
- format() for 0, 1, 999.5, 1e3, 1e6, 1e9, 1e12, 1e15, 1e100
- 1e10000 constructed and formatted without INF/NaN
- is_valid() false for NaN/INF inputs

# Constraints
- Typed GDScript only, Godot 4.3 syntax, no external addons
- Under ~400 lines for big_number.gd
- Tabs for indentation (Godot convention)

# Done when
`godot --headless --path . --script res://tests/unit/test_big_number.gd` prints
PASS counts with 0 failures and exits 0.
