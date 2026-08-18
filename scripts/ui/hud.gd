extends Control

const SAFE_TOP: int = 48
const SAFE_BOTTOM: int = 24
const ACTOR_WIDTH_RATIO: float = 0.20
const ACTOR_HEIGHT_RATIO: float = 0.26
const FALCON_SCALE: float = 0.60

@onready var safe_area: MarginContainer = %SafeArea
@onready var bottom_margin: MarginContainer = %BottomMargin
@onready var combat_area: Control = %CombatArea
@onready var hero: ColorRect = %Hero
@onready var falcon: ColorRect = %Falcon
@onready var enemy: ColorRect = %Enemy
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var enemy_hp: ProgressBar = %EnemyHP


func _ready() -> void:
	safe_area.add_theme_constant_override("margin_top", SAFE_TOP)
	bottom_margin.add_theme_constant_override("margin_bottom", SAFE_BOTTOM)
	combat_area.resized.connect(_layout_combat)
	_layout_combat.call_deferred()


func _layout_combat() -> void:
	var area_size: Vector2 = combat_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	# Actor dimensions are derived only from the live combat rectangle. These
	# ratios stay below the brief's 22% width and 28% height limits.
	var actor_size := Vector2(
		area_size.x * ACTOR_WIDTH_RATIO,
		area_size.y * ACTOR_HEIGHT_RATIO
	)
	var hero_position := Vector2(
		area_size.x * 0.10,
		area_size.y * 0.60
	)
	var enemy_position := Vector2(
		area_size.x * 0.70,
		area_size.y * 0.52
	)

	hero.size = actor_size
	hero.position = hero_position
	enemy.size = actor_size
	enemy.position = enemy_position

	var falcon_size := actor_size * FALCON_SCALE
	falcon.size = falcon_size
	falcon.position = Vector2(
		maxf(0.0, hero_position.x - falcon_size.x * 0.45),
		maxf(0.0, hero_position.y - falcon_size.y * 1.25)
	)

	var hp_width := actor_size.x * 1.20
	var hp_height := maxf(32.0, area_size.y * 0.045)
	var hp_x := clampf(
		enemy_position.x + (actor_size.x - hp_width) * 0.5,
		0.0,
		area_size.x - hp_width
	)
	var hp_y := maxf(30.0, enemy_position.y - hp_height - 34.0)
	enemy_hp_label.position = Vector2(hp_x, hp_y - 28.0)
	enemy_hp_label.size = Vector2(hp_width, 26.0)
	enemy_hp.position = Vector2(hp_x, hp_y)
	enemy_hp.size = Vector2(hp_width, hp_height)
