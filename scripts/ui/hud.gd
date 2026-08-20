extends Control

const SkillSystemLogic = preload("res://scripts/progression/skill_system.gd")

const SAFE_TOP: int = 48
const SAFE_BOTTOM: int = 24
## Approved rear-view composition. The axis both actors stand on, where each
## one's feet sit, and the share of the arena height each encounter class fills.
## The bands are ranges: a tall narrow silhouette takes the upper value, a wide
## one the lower, so every shape fits without a per-boss constant.
const COMBAT_AXIS: float = 0.5
const HERO_ANCHOR_Y: float = 0.94
const HERO_HEIGHT_RATIO: float = 0.26
const ENEMY_ANCHOR_Y: float = 0.52
const ENEMY_HEIGHT_BAND := Vector2(0.18, 0.25)
const BOSS_HEIGHT_BAND := Vector2(0.32, 0.42)
const ENEMY_MAX_WIDTH: float = 0.44
const BOSS_MAX_WIDTH: float = 0.62
const FALCON_SCALE: float = 0.46
var hero_anchor: Vector2 = Vector2.ZERO
const HERO_METRICS_PATH: String = "res://resources/hero_sprite_metrics.json"
var _hero_metrics: Dictionary = {}
var _hero_pose: String = "idle"
var _debug_layout: bool = OS.get_cmdline_args().has("--debug-layout") or OS.get_cmdline_user_args().has("--debug-layout")
const SKILL_IDS: Array[String] = [
	"sand_fury",
	"falcon_storm",
	"golden_wind",
	"time_fracture",
	"ancestor_call",
	"critical_eclipse",
]
@onready var safe_area: MarginContainer = %SafeArea
@onready var bottom_margin: MarginContainer = %BottomMargin
@onready var combat_area: Control = %CombatArea
@onready var hero: TextureRect = %Hero
@onready var falcon: TextureRect = %Falcon
@onready var enemy: TextureRect = %Enemy
@onready var enemy_hp_label: Label = %EnemyHPLabel
@onready var enemy_hp: ProgressBar = %EnemyHP
@onready var skill_buttons: Array[Button] = [
	%Skill1,
	%Skill2,
	%Skill3,
	%Skill4,
	%Skill5,
	%Skill6,
]
@onready var settings_button: Button = %Settings
@onready var inventory_button: Button = %Inventory
@onready var support_dps_button: Button = %HeroDPS
@onready var relics_button: Button = %Relics
@onready var inventory_panel: InventoryPanel = %InventoryPanel
@onready var settings_panel: SettingsPanel = %SettingsPanel
@onready var heroes_panel: HeroesPanel = %HeroesPanel
@onready var skills_panel: SkillsPanel = %SkillsPanel
@onready var combat_background: ColorRect = %DesertBackground
@onready var world_name: Label = %WorldName

var skill_system: SkillSystem
## Back-to-front parallax layers and how much wider than the viewport each one
## is drawn; the wider a layer, the further it travels across a world.
const PARALLAX_LAYERS: Array[String] = ["sky", "distant", "arena", "foreground"]
const PARALLAX_OVERSCAN: Array[float] = [1.0, 1.18, 1.0, 1.12]
var _world_layers: Dictionary = {}
var _skill_faces: Dictionary = {}
const SKILL_ICON_HEIGHT := 62.0
## The master canvas the layers are authored on, and how far down that canvas
## the visible crop sits: 0 shows the top of the sky, 1 the foreground edge.
const MASTER_SIZE := Vector2i(1080, 1920)
const ARENA_CROP_BIAS := 0.62
var current_music_ref: String = ""
var current_world: Dictionary = {}


func _ready() -> void:
	add_to_group("hud")
	safe_area.add_theme_constant_override("margin_top", SAFE_TOP)
	bottom_margin.add_theme_constant_override("margin_bottom", SAFE_BOTTOM)
	combat_area.resized.connect(_layout_combat)
	combat_background.resized.connect(_layout_world_layers)
	# The layers are deliberately taller and wider than the combat window so
	# they have room to parallax; without clipping they would paint over the
	# HUD bars above and below.
	combat_background.clip_contents = true
	%GoldIcon.texture = load("res://assets/sprites/ui/coin.webp") as Texture2D
	_apply_overlay_contrast()
	_setup_skills()
	settings_button.pressed.connect(settings_panel.open_panel)
	inventory_button.pressed.connect(inventory_panel.open_panel)
	%Heroes.pressed.connect(heroes_panel.open_panel)
	%Skills.pressed.connect(skills_panel.open_panel)
	support_dps_button.pressed.connect(_on_support_dps_pressed)
	relics_button.pressed.connect(_on_relics_pressed)
	refresh_localized_text()
	_layout_combat.call_deferred()


func _process(_delta: float) -> void:
	if skill_system == null:
		return
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	sync_skill_effects()
	_refresh_skill_buttons(now_ms)


func _setup_skills() -> void:
	skill_system = SkillSystemLogic.new()
	var loaded: Dictionary = SaveManager.data
	if loaded.is_empty():
		loaded = SaveManager.load()
	var run_state: Dictionary = loaded["run_state"]
	var timestamps: Variant = run_state.get("skill_timestamps", {})
	if timestamps is Dictionary:
		skill_system.from_dict(timestamps as Dictionary)
	for index: int in skill_buttons.size():
		skill_buttons[index].pressed.connect(_on_skill_pressed.bind(SKILL_IDS[index]))
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	_refresh_skill_buttons(now_ms)


func debug_activate_skills(ids: PackedStringArray) -> void:
	## Test-only: activate skills through the same path the buttons use, so
	## ACTIVE and COOLDOWN states can be captured from the real running UI.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	for id: String in ids:
		skill_system.activate(id, now_ms)
	_refresh_skill_buttons(now_ms)


func debug_force_cooldown(ids: PackedStringArray) -> void:
	## Test-only: activate then jump past the duration so the button shows the
	## COOLDOWN state rather than ACTIVE.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	for id: String in ids:
		skill_system.activate(id, now_ms)
	var later: int = now_ms + 20000
	skill_system.tick(later)
	_refresh_skill_buttons(later)


func debug_skill_showcase() -> void:
	## Test-only: one frame that carries all four states at once — READY,
	## ACTIVE, COOLDOWN and LOCKED — so the hierarchy can be judged side by side
	## instead of across four screenshots.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	skill_system.activate("falcon_storm", now_ms, 100)
	var golden: Dictionary = skill_system.skills.get("golden_wind", {})
	skill_system.activate("golden_wind", now_ms - int(golden.get("duration_ms", 0)) - 1000, 100)
	skill_system.tick(now_ms)
	sync_skill_effects()
	_refresh_skill_buttons(now_ms)


func debug_skill_state(id: String, state: String) -> void:
	## Test-only: put ONE skill into the requested lifecycle state through the
	## same skill system the buttons use, then report the modifier it produces so
	## the screenshot can be checked against a real number.
	# Same clock the HUD's own _process uses; a different one expires the skill
	# on the next frame and the capture would show READY over an active skill.
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	skill_system.tick(now_ms)
	if state == "cooldown":
		# Activated far enough in the past that the duration has already run out
		# while the cooldown still has time left, which is exactly the state the
		# real UI shows after a skill ends.
		var definition: Dictionary = skill_system.skills.get(id, {})
		skill_system.activate(id, now_ms - int(definition.get("duration_ms", 0)) - 1000, 100)
		skill_system.tick(now_ms)
	elif state == "active":
		skill_system.activate(id, now_ms, 100)
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	var timer_before: float = float(arena.get("combat").get("boss_time_left")) if arena != null else 0.0
	sync_skill_effects()
	var timer_after: float = float(arena.get("combat").get("boss_time_left")) if arena != null else 0.0
	print("SKILL_TIMER %s state=%s boss_time_before=%.1f boss_time_after=%.1f" % [id, state, timer_before, timer_after])
	_refresh_skill_buttons(now_ms)
	print("SKILL %s state=%s tap=%.2f falcon=%.2f gold=%.2f support=%.2f crit_dmg=%.2f active=%s cooldown=%s" % [
		id, state,
		float(skill_system.tap_damage_multiplier()), float(skill_system.falcon_rate_multiplier()),
		float(skill_system.gold_multiplier()), float(skill_system.support_dps_multiplier()),
		float(skill_system.crit_damage_multiplier()),
		skill_system.is_active(id), skill_system.is_on_cooldown(id)])


func debug_button_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for button: Button in skill_buttons:
		out.append(button.text.replace("\n", "/"))
	return out


func _on_skill_pressed(id: String) -> void:
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system.activate(id, now_ms, _max_stage()):
		sync_skill_effects()
		_save_skills()
		EventBus.tutorial_action.emit("activate_skill")
	_refresh_skill_buttons(now_ms)


func _skill_face(index: int) -> Dictionary:
	## Icon, name and state labels live inside the button so each skill reads as
	## a picture first and a word second; a row of six text blocks was
	## unreadable at a glance on a phone.
	if _skill_faces.has(index):
		return _skill_faces[index]
	var button: Button = skill_buttons[index]
	button.text = ""
	button.clip_contents = true
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 8.0
	box.offset_bottom = -6.0
	box.add_theme_constant_override("separation", 2)
	button.add_child(box)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0.0, SKILL_ICON_HEIGHT)
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = load("res://assets/sprites/ui/skill_%s.webp" % SKILL_IDS[index]) as Texture2D
	box.add_child(icon)
	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	var state_label := Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	state_label.add_theme_font_size_override("font_size", 16)
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(state_label)
	_skill_faces[index] = {"icon": icon, "name": name_label, "state": state_label}
	return _skill_faces[index]


func _skill_style(border: int, border_colour: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border_colour
	style.border_width_left = border
	style.border_width_right = border
	style.border_width_top = border
	style.border_width_bottom = border
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	return style


func _refresh_skill_buttons(now_ms: int) -> void:
	for index: int in skill_buttons.size():
		var id: String = SKILL_IDS[index]
		var button: Button = skill_buttons[index]
		var face: Dictionary = _skill_face(index)
		var icon: TextureRect = face["icon"]
		var name_label: Label = face["name"]
		var state_label: Label = face["state"]
		name_label.text = Settings.t("skill.%s" % id)
		# Six cards share the width, so on a 720-wide phone the type has to come
		# down or the skill names clip. Sized from the card, not hardcoded.
		var card_width: float = button.size.x if button.size.x > 1.0 else 160.0
		var name_size: int = clampi(int(card_width * 0.115), 12, 19)
		name_label.add_theme_font_size_override("font_size", name_size)
		state_label.add_theme_font_size_override("font_size", maxi(11, name_size - 2))
		icon.custom_minimum_size = Vector2(0.0, clampf(card_width * 0.42, 34.0, SKILL_ICON_HEIGHT))
		var unlocked: bool = skill_system.is_unlocked(id, _max_stage())
		var style: StyleBoxFlat
		# Four treatments that differ in ICON as well as in text, so the state is
		# not carried by colour alone: full colour, full colour inside a heavy
		# ring, drained, and a flat silhouette.
		if not unlocked:
			var requirement: int = int(((skill_system.skills[id] as Dictionary).get("unlock_condition", {}) as Dictionary).get("max_stage", 1))
			icon.modulate = Color(0.20, 0.19, 0.26, 1.0)
			state_label.text = "%s\n%s" % [Settings.t("ui.state.locked"), Settings.t("ui.unlock_stage") % requirement]
			state_label.add_theme_color_override("font_color", Color(0.62, 0.60, 0.70))
			style = _skill_style(2, Color(0.30, 0.29, 0.36), Color(0.07, 0.07, 0.10, 0.85))
		elif skill_system.is_active(id):
			var definition: Dictionary = skill_system.skills.get(id, {})
			var active_until_ms: int = int(skill_system.activated_at_ms[id]) + int(definition.get("duration_ms", 0))
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			state_label.text = "%s  %s" % [Settings.t("hud.active"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(active_until_ms, now_ms))]
			state_label.add_theme_color_override("font_color", Color(0.86, 1.0, 0.90))
			style = _skill_style(6, Color(0.55, 0.95, 0.68), Color(0.10, 0.24, 0.16, 0.95))
		elif skill_system.is_on_cooldown(id):
			icon.modulate = Color(0.42, 0.42, 0.48, 1.0)
			state_label.text = "%s  %s" % [Settings.t("hud.cooldown"), Settings.t("hud.seconds_short") % Settings.format_number(_remaining_seconds(int(skill_system.cooldown_until_ms[id]), now_ms))]
			state_label.add_theme_color_override("font_color", Color(0.72, 0.70, 0.78))
			style = _skill_style(2, Color(0.34, 0.33, 0.42), Color(0.09, 0.09, 0.12, 0.9))
		else:
			icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			state_label.text = Settings.t("hud.ready")
			state_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.72))
			style = _skill_style(4, Color(0.92, 0.74, 0.32), Color(0.14, 0.12, 0.09, 0.92))
		name_label.add_theme_color_override("font_color", Color(0.96, 0.95, 1.0) if unlocked else Color(0.60, 0.58, 0.68))
		for slot: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(slot, style)
		button.disabled = state_label.text != Settings.t("hud.ready")


func sync_skill_effects() -> void:
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("apply_skill_modifiers"):
		arena.call("apply_skill_modifiers", skill_system)


func _max_stage() -> int:
	return maxi(1, int((SaveManager.data.get("permanent_state", {}) as Dictionary).get("max_stage", 1)))


func refresh_localized_text() -> void:
	%Battle.text = Settings.t("hud.battle")
	%Heroes.text = Settings.t("hud.heroes")
	%Skills.text = Settings.t("hud.skills")
	%Inventory.text = Settings.t("hud.inventory")
	%Relics.text = Settings.t("hud.relics")
	%Shop.text = Settings.t("hud.shop")
	refresh_support_dps()
	# WorldName presents the active localized world. Do not expose the art
	# placeholder label, which incorrectly called every later world a desert.
	%BackgroundLabel.text = ""
	if not current_world.is_empty():
		world_name.text = Settings.t(str(current_world.get("name_key", "")))
	%BalanceDataInvalid.visible = OS.is_debug_build() and BalanceData.balance_data_invalid
	%BalanceDataInvalid.text = Settings.t("debug.balance_data_invalid")
	%ContentDataInvalid.visible = OS.is_debug_build() and ContentValidator.content_invalid
	%ContentDataInvalid.text = Settings.t("debug.content_data_invalid")
	var now_ms: int = int(Time.get_unix_time_from_system() * 1000.0)
	if skill_system != null:
		_refresh_skill_buttons(now_ms)
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena != null and arena.has_method("refresh_localized_text"):
		arena.call("refresh_localized_text")


func apply_world(world: Dictionary) -> void:
	if world.is_empty():
		return
	current_world = world.duplicate(true)
	var palette: Dictionary = world.get("palette", {})
	var sand_html: String = str(palette.get("sand", "#C28C4C"))
	if Color.html_is_valid(sand_html):
		# Still painted underneath: a world whose parallax art is not built yet
		# keeps its flat palette rather than showing an empty rectangle.
		combat_background.color = Color.html(sand_html)
	_apply_world_layers(str(world.get("id", "")))
	var accent_html: String = str(palette.get("accent", "#FFFFFF"))
	if Color.html_is_valid(accent_html):
		world_name.add_theme_color_override("font_color", Color.html(accent_html))
	world_name.text = Settings.t(str(world.get("name_key", "")))
	%BackgroundLabel.text = ""
	current_music_ref = str(world.get("music_ref", ""))
	combat_background.set_meta("music_ref", current_music_ref)


func _texture_aspect(rect: TextureRect, fallback: float) -> float:
	## Width over height of the art actually loaded, so scaling follows the
	## sprite's own bounds instead of one number for every creature.
	if rect == null or rect.texture == null:
		return fallback
	var size: Vector2 = rect.texture.get_size()
	if size.y <= 0.0:
		return fallback
	return size.x / size.y


func _apply_world_layers(world_id: String) -> void:
	## Four separate layers, back to front. A world without built art simply has
	## no textures and falls back to the flat palette colour behind them.
	for layer_name: String in PARALLAX_LAYERS:
		var rect: TextureRect = _world_layer(layer_name)
		var path: String = "res://assets/worlds/%s/%s.png" % [world_id, layer_name]
		var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		rect.texture = texture
		rect.visible = texture != null
	_layout_world_layers()


func debug_resident_layer_count() -> int:
	## How many parallax layer textures are actually held right now. The rects
	## are reused between worlds; only their textures are loaded and released.
	var count: int = 0
	for layer_name: String in PARALLAX_LAYERS:
		var rect: TextureRect = _world_layers.get(layer_name) as TextureRect
		if rect != null and is_instance_valid(rect) and rect.texture != null:
			count += 1
	return count


func _world_layer(layer_name: String) -> TextureRect:
	var existing: TextureRect = _world_layers.get(layer_name) as TextureRect
	if existing != null and is_instance_valid(existing):
		return existing
	var rect := TextureRect.new()
	rect.name = "Layer%s" % layer_name.capitalize()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	# Without IGNORE_SIZE a TextureRect refuses to shrink below its texture, so
	# on a smaller screen the arena layer stayed at master size and its band
	# fell outside the visible window.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.clip_contents = false
	combat_background.add_child(rect)
	combat_background.move_child(rect, _world_layers.size())
	_world_layers[layer_name] = rect
	return rect


func _layout_world_layers() -> void:
	## Nearer layers are drawn wider than the viewport and shifted further, so
	## advancing through a world pans them at different speeds instead of
	## sliding one flat picture.
	var area: Vector2 = combat_background.size
	if area.x <= 0.0 or area.y <= 0.0:
		return
	var progress: float = _world_progress()
	for index: int in PARALLAX_LAYERS.size():
		var layer_name: String = PARALLAX_LAYERS[index]
		var rect: TextureRect = _world_layers.get(layer_name) as TextureRect
		if rect == null or not is_instance_valid(rect):
			continue
		var overscan: float = PARALLAX_OVERSCAN[index]
		# Keep the art's own 9:16 shape. The combat area is much squarer than
		# that, so the layer is taller than the window and is slid up until the
		# arena floor -- the part the actors stand on -- is the part on screen.
		var layer_width: float = area.x * overscan
		var layer_height: float = layer_width * float(MASTER_SIZE.y) / float(MASTER_SIZE.x)
		rect.size = Vector2(layer_width, layer_height)
		var travel: float = area.x * (overscan - 1.0)
		rect.position = Vector2(-travel * progress, -maxf(0.0, layer_height - area.y) * ARENA_CROP_BIAS)


func _world_progress() -> float:
	## Position inside the current world, 0 at its first stage and 1 at its last.
	if current_world.is_empty():
		return 0.0
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	if arena == null:
		return 0.0
	var state: Object = arena.get("combat")
	if state == null:
		return 0.0
	var from: float = float(current_world.get("stage_from", 1))
	var to: float = float(current_world.get("stage_to", from + 1.0))
	return clampf((float(state.get("stage")) - from) / maxf(1.0, to - from), 0.0, 1.0)


func _backing(alpha: float, pad: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.03, 0.07, alpha)
	style.content_margin_left = pad
	style.content_margin_right = pad
	style.content_margin_top = pad * 0.4
	style.content_margin_bottom = pad * 0.4
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	return style


func _apply_overlay_contrast() -> void:
	## Combat text sits on painted daylight, where a plain coloured label washes
	## out. Every overlay gets an outline and a shadow, and the ones that carry
	## numbers a player reads mid-fight also get a dark translucent plate.
	var plated: Array[Label] = [world_name, %BossWarning, %BossCountdown, %EnemyHPLabel, %GoldAmount, %Stage]
	for label: Label in plated:
		label.add_theme_stylebox_override("normal", _backing(0.62, 18))
		label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.05, 0.95))
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 3)
	# Bigger currency and stage type, kept on their filled plates: shrinking the
	# labels to their text collapsed them to empty boxes in the top bar.
	# Sized from the viewport: 30pt fits a 1080-wide bar, but clipped
	# "Stage 100 — BOSS" on a 720-wide phone.
	var readout_size: int = 30 if get_viewport_rect().size.x >= 1000.0 else 22
	for readout: Label in [%GoldAmount, %Stage]:
		readout.add_theme_font_size_override("font_size", readout_size)
		readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The enemy bar was a pale rectangle on pale grass. Dark trough, bright fill.
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.05, 0.04, 0.08, 0.78)
	trough.border_color = Color(0.02, 0.02, 0.04, 0.9)
	trough.set_border_width_all(3)
	trough.set_corner_radius_all(10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.28, 0.30, 1.0)
	fill.set_corner_radius_all(8)
	enemy_hp.add_theme_stylebox_override("background", trough)
	enemy_hp.add_theme_stylebox_override("fill", fill)
	# The upgrade row is the widest tap target on the screen; give it presence
	# instead of leaving two small captions in a large empty band.
	for action: Button in [%TapDamage, support_dps_button]:
		action.add_theme_font_size_override("font_size", 24)
		action.custom_minimum_size = Vector2(0.0, 108.0)
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.13, 0.12, 0.18, 1.0)
		panel.border_color = Color(0.36, 0.32, 0.46, 1.0)
		panel.set_border_width_all(3)
		panel.set_corner_radius_all(14)
		panel.content_margin_left = 12
		panel.content_margin_right = 12
		for slot: String in ["normal", "hover", "pressed", "focus"]:
			action.add_theme_stylebox_override(slot, panel)
		var dim := panel.duplicate() as StyleBoxFlat
		dim.bg_color = Color(0.09, 0.09, 0.12, 1.0)
		dim.border_color = Color(0.24, 0.22, 0.30, 1.0)
		action.add_theme_stylebox_override("disabled", dim)
	%BossWarning.add_theme_color_override("font_color", Color(1.0, 0.55, 0.42))
	%BossCountdown.add_theme_color_override("font_color", Color(1.0, 0.93, 0.72))
	%EnemyHPLabel.add_theme_color_override("font_color", Color(1.0, 0.98, 0.98))
	world_name.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))


func refresh_support_dps() -> void:
	## The button shows the roster's real damage per second. It used to print a
	## placeholder sentence, which is the one thing a player must never be shown.
	var arena: Node = get_tree().get_first_node_in_group("combat_arena")
	var total: Object = null
	if arena != null:
		var state: Object = arena.get("combat")
		if state != null:
			total = state.get("support_total_dps")
	var shown: String = Settings.format_big_number(total) if total != null else Settings.format_number(0)
	support_dps_button.text = Settings.t("hud.hero_dps") % shown


func _remaining_seconds(until_ms: int, now_ms: int) -> int:
	return maxi(0, int(ceil(float(until_ms - now_ms) / 1000.0)))


func _save_skills() -> void:
	var save_data: Dictionary = SaveManager.data.duplicate(true)
	if save_data.is_empty():
		save_data = SaveManager.default_data()
	(save_data["run_state"] as Dictionary)["skill_timestamps"] = skill_system.to_dict()
	(save_data["permanent_state"] as Dictionary)["last_seen_utc"] = int(Time.get_unix_time_from_system())
	SaveManager.save(save_data)


func _on_support_dps_pressed() -> void:
	EventBus.tutorial_action.emit("support_dps")


func _on_relics_pressed() -> void:
	var permanent_state: Dictionary = SaveManager.data.get("permanent_state", {})
	if int(permanent_state.get("max_stage", 1)) >= 25:
		EventBus.tutorial_action.emit("prestige_intro")


func hero_metrics(pose: String = "") -> Dictionary:
	## Alpha bounds for the pose currently on the hero, or for a named pose.
	## Falls back to the whole canvas so a missing metrics file degrades into a
	## plain centred sprite rather than a crash.
	if _hero_metrics.is_empty():
		_load_hero_metrics()
	var key: String = pose
	if key.is_empty():
		key = "attack" if _hero_pose == "attack" else "idle"
	return _hero_metrics.get(key, {})


func _load_hero_metrics() -> void:
	var file: FileAccess = FileAccess.open(HERO_METRICS_PATH, FileAccess.READ)
	if file == null:
		push_error("hero sprite metrics missing: %s" % HERO_METRICS_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		push_error("hero sprite metrics unreadable: %s" % HERO_METRICS_PATH)
		file.close()
		return
	file.close()
	_hero_metrics = (json.data as Dictionary).get("sprites", {})


func _hero_rect_size(body_height: float, pose: String = "") -> Vector2:
	var entry: Dictionary = hero_metrics(pose)
	if entry.is_empty():
		return Vector2(body_height * _texture_aspect(hero, 0.62), body_height)
	var side: float = HeroPlacement.rect_side(body_height, entry)
	return Vector2(side * _texture_aspect(hero, 1.0), side)


func hero_anchor_for(pose: String) -> Vector2:
	## Where a pose WOULD stand, without switching to it. The attack pose fills
	## its canvas differently from the idle pose, so a swing has to aim at the
	## attack pose's own anchor or the hero jumps on the frame it swaps.
	var area_size: Vector2 = combat_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return hero_anchor
	var body_height: float = area_size.y * HERO_HEIGHT_RATIO
	var rect_size: Vector2 = _hero_rect_size(body_height, pose)
	return _hero_position_for(rect_size, area_size.x * COMBAT_AXIS, area_size.y * HERO_ANCHOR_Y, pose)


func _hero_position_for(rect_size: Vector2, axis_x: float, ground_y: float, pose: String = "") -> Vector2:
	## Place the rectangle so the body's own bottom edge lands on the ground
	## line and its own horizontal centre lands on the combat axis.
	var entry: Dictionary = hero_metrics(pose)
	if entry.is_empty():
		return Vector2(axis_x - rect_size.x * 0.5, ground_y - rect_size.y)
	var offset: Vector2 = HeroPlacement.body_offset(rect_size.y, entry)
	return Vector2(axis_x - offset.x, ground_y - offset.y)


func set_hero_pose(pose: String) -> void:
	## The pose changes the visible body's size and offset inside the same
	## square, so the layout is redone for it. Called by the arena on every
	## swing; the anchor it recomputes is the one the hero returns to.
	var next: String = pose if pose in ["idle", "attack"] else "idle"
	if next == _hero_pose:
		return
	_hero_pose = next
	var path: String = str(hero_metrics(next).get("path", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		hero.texture = load(path) as Texture2D
	_layout_combat()


func hero_pose() -> String:
	return _hero_pose


func _layout_combat() -> void:
	var area_size: Vector2 = combat_area.size
	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	# Approved composition: the camera sits behind the player. The hero stands
	# at the lower centre, the enemy directly ahead in the upper middle, and
	# both share one vertical axis so the attack lane runs straight up the
	# screen. The falcon flies beside the hero, clear of that lane.
	var axis: float = area_size.x * COMBAT_AXIS
	# The hero art sits inside transparent padding on a 2048 square, and the two
	# poses do not fill that square identically. Sizing and placing by the
	# canvas would let the visible body drift between them, so both are driven
	# from the baked alpha bounds: the body height is what lands in the band,
	# and the body's bottom-centre is what lands on the anchor.
	var body_height: float = area_size.y * HERO_HEIGHT_RATIO
	var hero_size: Vector2 = _hero_rect_size(body_height)
	hero.size = hero_size
	hero.position = _hero_position_for(hero_size, axis, area_size.y * HERO_ANCHOR_Y)
	hero_anchor = hero.position

	var arena_node: Node = get_tree().get_first_node_in_group("combat_arena")
	var is_boss: bool = false
	if arena_node != null:
		var state: Object = arena_node.get("combat")
		if state != null:
			is_boss = bool(state.get("is_boss"))
	# Sprite-bound aware: the height band comes from the encounter class, then a
	# wide or irregular silhouette is pulled back until it fits the safe width,
	# so a broad boss never spills over the HUD or its own name.
	var band: Vector2 = BOSS_HEIGHT_BAND if is_boss else ENEMY_HEIGHT_BAND
	var aspect: float = _texture_aspect(enemy, 1.0)
	var enemy_height: float = area_size.y * lerpf(band.x, band.y, clampf((1.3 - aspect) / 1.1, 0.0, 1.0))
	# The arena scales each creature by its authored size_scale. Dividing it out
	# here means the band describes what is actually drawn, not the rectangle
	# before scaling, so every enemy really lands inside its approved range.
	var creature_scale: float = 1.0
	if arena_node != null and arena_node.has_method("enemy_size_scale"):
		creature_scale = clampf(float(arena_node.call("enemy_size_scale")), 0.5, 2.0)
	enemy_height /= creature_scale
	var max_width: float = area_size.x * (BOSS_MAX_WIDTH if is_boss else ENEMY_MAX_WIDTH)
	var enemy_size := Vector2(enemy_height * aspect, enemy_height)
	if enemy_size.x * creature_scale > max_width:
		enemy_size = Vector2(max_width / creature_scale, max_width / creature_scale / maxf(0.05, aspect))
	enemy.size = enemy_size
	enemy.position = Vector2(axis - enemy_size.x * 0.5, area_size.y * ENEMY_ANCHOR_Y - enemy_size.y)

	var falcon_size := Vector2(hero_size.x * FALCON_SCALE, hero_size.y * FALCON_SCALE)
	falcon.size = falcon_size
	# Beside and slightly above the hero, outside the straight line between the
	# hero and the enemy.
	# Beside the hero at shoulder height, well clear of the straight line from
	# the hero up to the enemy.
	falcon.position = Vector2(
		clampf(hero.position.x - falcon_size.x * 1.15, 4.0, area_size.x - falcon_size.x - 4.0),
		clampf(hero.position.y + hero_size.y * 0.06, 4.0, area_size.y - falcon_size.y - 4.0))

	if _debug_layout:
		print("LAYOUT arena=%s hero=%s@%s enemy=%s@%s enemy_scale=%s boss=%s aspect=%.2f falcon=%s@%s tex=%s vis=%s" % [
			area_size, hero.size, hero.position, enemy.size, enemy.position, enemy.scale, is_boss, aspect,
			falcon.size, falcon.position, falcon.texture != null, falcon.visible])
	if arena_node != null and arena_node.has_method("place_enemy_name"):
		arena_node.call("place_enemy_name")

	var hp_width: float = minf(area_size.x * 0.72, maxf(enemy_size.x * 1.25, area_size.x * 0.46))
	var hp_height: float = maxf(30.0, area_size.y * 0.038)
	var hp_x: float = clampf(axis - hp_width * 0.5, 4.0, area_size.x - hp_width - 4.0)
	# Below the world title and, in a boss fight, below the banner and countdown
	# as well: the readout may never sit on top of the timer.
	var reserved_top: float = area_size.y * (0.16 if is_boss else 0.07)
	var hp_y: float = maxf(reserved_top, enemy.position.y - hp_height - 40.0)
	enemy_hp_label.position = Vector2(hp_x, hp_y - 30.0)
	enemy_hp_label.size = Vector2(hp_width, 28.0)
	enemy_hp.position = Vector2(hp_x, hp_y)
	enemy_hp.size = Vector2(hp_width, hp_height)
