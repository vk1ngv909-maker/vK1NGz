# Goal
Create the boot scene and a portrait HUD blockout for a Godot 4.3 idle game,
1080x1920, so a real screenshot can be captured and inspected.

# Files to create
- scenes/boot/boot.tscn + scripts/ui/boot.gd
- scenes/game/game.tscn + scripts/ui/game.gd
- scenes/ui/hud.tscn + scripts/ui/hud.gd
- autoload/event_bus.gd

# Layout (per design brief, portrait 1080x1920)
Three zones using Control anchors, NOT hardcoded pixel positions:
- Top 15%: currency row (gold icon placeholder + label), stage label "Stage 1",
  settings gear button on the right.
- Middle 55%: combat area. A ColorRect placeholder background (desert sand tone),
  an enemy placeholder (rect) centred-right, a hero placeholder (rect) lower-left,
  a falcon placeholder (smaller rect) just above and beside the hero.
  An enemy HP bar (ProgressBar) above the enemy.
- Bottom 30%: an upgrade button row (Tap Damage / Hero DPS placeholders with cost
  labels), a row of 6 skill buttons, and a nav TabBar:
  Battle | Heroes | Skills | Inventory | Relics | Shop

# Requirements
- Use MarginContainer/VBoxContainer/HBoxContainer with size_flags so it scales.
- Respect safe area: add a top margin constant SAFE_TOP = 48 px.
- All placeholder rectangles must be visually distinct colors and clearly
  labelled with a Label reading "PLACEHOLDER" style text, since these are not
  final art.
- boot.gd: waits one frame, then changes scene to game.tscn.
- event_bus.gd: extends Node, declares signals:
  enemy_damaged(amount), enemy_died(), gold_changed(total), stage_changed(stage)
  Register as autoload named EventBus in project.godot.
- Typed GDScript, tabs for indentation.
- Add a screenshot helper: if the command line contains "--shot", game.gd waits
  for 2 frames then saves user://shot.png and quits.

# Constraints
- No external assets. Coloured ColorRects and Labels only.
- Hero placeholder must sit LEFT of the enemy (hero faces enemy = faces right).
- Falcon placeholder beside/above hero, never centre screen.

# Done when
This runs and writes a PNG:
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a --server-args="-screen 0 1080x1920x24" godot --path . --rendering-driver opengl3 --shot
