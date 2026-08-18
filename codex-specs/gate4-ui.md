# Goal
Gate 4 UI: inventory panel, salvage confirmation, offline rewards dialog,
settings panel. All must be capturable for visual evidence.

# Files
- scenes/ui/inventory_panel.tscn + scripts/ui/inventory_panel.gd
- scenes/ui/offline_rewards_dialog.tscn + scripts/ui/offline_rewards_dialog.gd
- scenes/ui/settings_panel.tscn + scripts/ui/settings_panel.gd
- localization/strings.en.csv, localization/strings.ar.csv

# Inventory panel
- Grid of owned items. Each cell: name, rarity colour band, item score, and
  BADGES for locked / favorite / equipped that are readable WITHOUT colour
  (use a text or glyph marker, not colour alone).
- EMPTY STATE: when there are no items, show a clear message, not a blank grid.
- Selecting an item opens a compare view showing the selected item beside the
  equipped item in the same slot, with per-stat deltas rendered as +x / -x and
  a clear "UPGRADE" or "DOWNGRADE" verdict from compare().
- Buttons: Equip, Lock/Unlock, Favorite/Unfavorite, Salvage.
- Salvage on a rare/epic/legendary or favorite item opens a CONFIRMATION dialog
  that names the item, states the action is permanent, and has clearly
  distinguishable Cancel and Confirm buttons (Cancel must be the safe default).
- Panel must have a visible close button.

# Offline rewards dialog
Shows: time away (human readable), gold earned, and — only when the cap applied
— an explicit "capped at 8 hours" line. One Collect button. After collecting,
show a clear confirmation state and disable the button so it cannot be pressed
twice.

# Settings panel
Sliders: master, music, sfx, ui volume. Toggles: vibration, reduced flashing,
damage numbers. A language selector (en / ar). All values persist through
SaveManager into permanent_state. Reduced flashing must actually reduce the
combat flash intensity, and damage-numbers-off must actually hide them.

# Localization
strings.en.csv and strings.ar.csv with columns: key,en / key,ar.
Cover every UI string added here plus existing HUD labels. Use
`tr("key")` in scripts, never hardcoded production text.
Arabic file may contain real Arabic for the keys you can translate confidently;
otherwise mark the value as the English text prefixed with "AR:" so missing
translations are VISIBLE rather than silently English.

# Debug hooks for capture (test-only)
On combat_arena or hud, add:
  debug_open_inventory(), debug_open_inventory_empty(),
  debug_open_compare(), debug_open_salvage_confirm(),
  debug_open_offline(seconds_away: int), debug_open_settings(),
  debug_set_language(code: String)
and wire matching command line flags in combat_arena's existing
_open_debug_* pattern: --debug-inventory, --debug-inventory-empty,
--debug-compare, --debug-salvage, --debug-offline N, --debug-settings,
--debug-lang ar

# Layout constraints
Everything must fit with 16px margins at 720x1280, 1080x1920 and 1080x2400.
Use containers, never fixed offsets. Touch targets minimum 88px high.

# Constraints
Typed GDScript, tabs. Do NOT modify scripts/ui/game.gd. game.tscn root stays
Node. Placeholders stay labelled.

# Done when
bash scripts/shot.sh 720 1280 /tmp/i.png --debug-inventory works, the other
flags render their panels, and scripts/run-tests.sh still passes.
