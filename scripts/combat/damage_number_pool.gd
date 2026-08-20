class_name DamageNumberPool
extends Control

const BigNumber = preload("res://scripts/utilities/big_number.gd")
const Settings = preload("res://autoload/settings.gd")

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
var reduced_motion: bool = false


func _ready() -> void:
	ensure_pool()


func ensure_pool() -> void:
	## Idempotent so the pool can be built without a running scene tree, which is
	## what lets the lane rules be tested headlessly.
	if not _labels.is_empty():
		return
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


## Lanes are named positions around the enemy's own rectangle, not screen
## coordinates, so they move and scale with whatever is being fought. Order is
## fixed and the choice is round-robin, which keeps a deterministic sequence
## testable while still spreading numbers across both sides.
const LANES: Array[String] = [
	"lower_left", "middle_right", "upper_left", "lower_right", "middle_left", "upper_right",
]
const LANE_OFFSETS := {
	"upper_left": Vector2(-0.62, -0.18),
	"middle_left": Vector2(-0.72, 0.34),
	"lower_left": Vector2(-0.56, 0.82),
	"upper_right": Vector2(0.62, -0.18),
	"middle_right": Vector2(0.72, 0.34),
	"lower_right": Vector2(0.56, 0.82),
	"upper_center": Vector2(0.0, -0.34),
}
const MAX_SAME_SIDE: int = 2

var enemy_rect: Rect2 = Rect2()
var exclusions: Array[Rect2] = []
var _lane_index: int = 0
var _side_run: int = 0
var _last_side: String = ""
var _lane_history: Array[String] = []
var _kind_history: Array[String] = []
var _occupied: Dictionary = {}


func lane_side(lane: String) -> String:
	if lane.ends_with("_left"):
		return "left"
	if lane.ends_with("_right"):
		return "right"
	return "center"


func lane_position(lane: String, half_size: Vector2 = Vector2(90.0, 30.0)) -> Vector2:
	## A lane resolved against the enemy's live bounds, then pushed back inside
	## the arena and away from the HUD rectangles it must never cover.
	var rect: Rect2 = enemy_rect if enemy_rect.size.x > 1.0 else Rect2(size * 0.5, Vector2(120, 120))
	var offset: Vector2 = LANE_OFFSETS.get(lane, Vector2.ZERO)
	var point: Vector2 = rect.position + rect.size * 0.5 + rect.size * offset
	var half: Vector2 = half_size
	point.x = clampf(point.x, half.x + 6.0, maxf(half.x + 6.0, size.x - half.x - 6.0))
	point.y = clampf(point.y, half.y + 6.0, maxf(half.y + 6.0, size.y - half.y - 6.0))
	for blocked: Rect2 in exclusions:
		var box := Rect2(point - half, half * 2.0)
		if blocked.intersects(box):
			# Slide out of the blocked band the shorter way, staying on screen.
			if point.y < blocked.position.y + blocked.size.y * 0.5:
				point.y = maxf(half.y + 6.0, blocked.position.y - half.y - 8.0)
			else:
				point.y = minf(size.y - half.y - 6.0, blocked.position.y + blocked.size.y + half.y + 8.0)
	return point


func next_lane() -> String:
	## Round-robin with two rules layered on it. The side rule comes first: a
	## third number in a row on one side is never allowed while the other side
	## exists, even when every lane is still busy, because that is the failure a
	## player actually notices. Avoiding a lane that still holds a live number is
	## the softer preference and yields to it.
	var free_and_alternating: String = ""
	var alternating: String = ""
	for offset: int in LANES.size():
		var lane: String = LANES[(_lane_index + offset) % LANES.size()]
		var side: String = lane_side(lane)
		var side_blocked: bool = side == _last_side and _side_run >= MAX_SAME_SIDE
		if side_blocked:
			continue
		if alternating.is_empty():
			alternating = lane
		if int(_occupied.get(lane, 0)) == 0:
			free_and_alternating = lane
			break
	var chosen: String = free_and_alternating
	if chosen.is_empty():
		chosen = alternating
	if chosen.is_empty():
		chosen = LANES[_lane_index % LANES.size()]
	_lane_index = (LANES.find(chosen) + 1) % LANES.size()
	return chosen


func show_damage(amount: BigNumber, kind: String, origin: Vector2) -> void:
	show_damage_in_lane(amount, kind, next_lane())


func show_damage_in_lane(amount: BigNumber, kind: String, lane: String) -> void:
	if _labels.is_empty():
		return
	var side: String = lane_side(lane)
	_side_run = _side_run + 1 if side == _last_side else 1
	_last_side = side
	_lane_history.append(lane)
	_kind_history.append(kind)
	if _lane_history.size() > 64:
		_lane_history.remove_at(0)
	if _kind_history.size() > 64:
		_kind_history.remove_at(0)

	var label: Label = _labels[_next_index]
	_next_index = (_next_index + 1) % POOL_SIZE
	if _tweens.has(label):
		(_tweens[label] as Tween).kill()
	var previous_lane: String = str(label.get_meta("lane", ""))
	if not previous_lane.is_empty():
		_occupied[previous_lane] = maxi(0, int(_occupied.get(previous_lane, 0)) - 1)
	label.set_meta("lane", lane)
	_occupied[lane] = int(_occupied.get(lane, 0)) + 1

	var critical: bool = kind == "critical"
	label.text = Settings.format_big_number(amount)
	if critical:
		label.text = "%s %s" % [Settings.t("hud.critical"), label.text]
	label.modulate = Color.WHITE
	# A critical carries a word as well as a number, so it needs a wider box or
	# the extra text hangs off the edge of the screen where nobody can read it.
	label.size = Vector2(360.0 if critical else 180.0, 60.0)
	# A small fan so several numbers in the same lane stay separately readable
	# without leaving the lane.
	var fan: Vector2 = Vector2(float(_side_run - 1) * (14.0 if side == "right" else -14.0), float(_side_run - 1) * -12.0)
	label.position = lane_position(lane, label.size * 0.5) - label.size * 0.5 + fan
	label.visible = true
	label.add_theme_color_override("font_color", _color_for(kind))
	label.add_theme_font_size_override("font_size", 46 if critical else 32)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 10 if critical else 8)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

	# Left lanes drift left and up, right lanes right and up; a critical travels
	# further. Reduced motion shortens every distance without hiding the number.
	var reach: float = FLOAT_DISTANCE * (1.35 if critical else 1.0) * (0.45 if reduced_motion else 1.0)
	var sideways: float = (reach * 0.42) * (1.0 if side == "right" else -1.0)
	if side == "center":
		sideways = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	_tweens[label] = tween
	tween.tween_property(label, "position:y", label.position.y - reach, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:x", label.position.x + sideways, FLOAT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_DURATION).set_delay(0.18)
	tween.chain().tween_callback(_release.bind(label))


func lane_history() -> Array[String]:
	return _lane_history.duplicate()


func kind_history() -> Array[String]:
	## Which kind produced each number, so a measurement can tell a tap's own
	## damage apart from the falcon's, which fires on its own schedule.
	return _kind_history.duplicate()


func live_label_count() -> int:
	var count: int = 0
	for label: Label in _labels:
		if label.visible:
			count += 1
	return count


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
	var lane: String = str(label.get_meta("lane", ""))
	if not lane.is_empty():
		_occupied[lane] = maxi(0, int(_occupied.get(lane, 0)) - 1)
		label.set_meta("lane", "")
	label.visible = false
	_tweens.erase(label)
