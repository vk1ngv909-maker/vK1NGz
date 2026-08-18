class_name DamageNumberPool
extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")

const POOL_SIZE: int = 32
const FLOAT_DISTANCE: float = 90.0
const FLOAT_DURATION: float = 0.65
const NORMAL_COLOR: Color = Color(1.0, 0.94, 0.55)
const CRITICAL_COLOR: Color = Color(1.0, 0.25, 0.08)
const FALCON_COLOR: Color = Color(0.25, 0.9, 1.0)
const DPS_COLOR: Color = Color(0.55, 0.95, 0.65)

var _labels: Array[Label] = []
var _tweens: Dictionary = {}
var _next_index: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in POOL_SIZE:
		var label: Label = Label.new()
		label.name = "DamageNumber%02d" % index
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 20
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(180.0, 60.0)
		add_child(label)
		_labels.append(label)


func show_damage(amount: BigNumber, kind: String, origin: Vector2) -> void:
	if _labels.is_empty():
		return
	var label: Label = _labels[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	if _tweens.has(label):
		(_tweens[label] as Tween).kill()
	label.text = amount.format()
	label.modulate = Color.WHITE
	# Scatter each number so rapid taps stay individually readable instead of
	# stacking into an illegible pile at one point.
	var jitter: Vector2 = Vector2(randf_range(-46.0, 46.0), randf_range(-28.0, 14.0))
	label.position = origin - label.size * Vector2(0.5, 0.5) + jitter
	label.visible = true
	label.add_theme_color_override("font_color", _color_for(kind))
	label.add_theme_font_size_override("font_size", 34 if kind == "critical" else 26)
	var tween: Tween = create_tween().set_parallel(true)
	_tweens[label] = tween
	tween.tween_property(label, "position:y", label.position.y - FLOAT_DISTANCE, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:x", label.position.x + jitter.x * 0.35, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION).set_delay(0.18)
	tween.chain().tween_callback(_release.bind(label))


func _color_for(kind: String) -> Color:
	if kind == "critical":
		return CRITICAL_COLOR
	if kind == "falcon":
		return FALCON_COLOR
	if kind == "dps":
		return DPS_COLOR
	return NORMAL_COLOR


func hide_all() -> void:
	for label: Label in _labels:
		label.visible = false
	for tween_value: Variant in _tweens.values():
		(tween_value as Tween).kill()
	_tweens.clear()


func _release(label: Label) -> void:
	label.visible = false
	_tweens.erase(label)
