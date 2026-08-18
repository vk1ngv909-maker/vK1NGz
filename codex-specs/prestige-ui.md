# Goal
Prestige confirmation dialog + skills bar wiring, so Gate 3 has visual evidence.

# Files
- scenes/ui/prestige_dialog.tscn + scripts/ui/prestige_dialog.gd
- wire the 6 skill buttons in the existing HUD to SkillSystem

# prestige_dialog.gd
A Control panel (hidden by default) that takes a preview Dictionary from
scripts/progression/prestige.gd and shows THREE clearly separated columns/blocks:

  1. "WILL RESET"  — red-tinted list, one line per entry from preview["resets"]
  2. "WILL KEEP"   — green-tinted list, one line per entry from preview["keeps"]
  3. "YOU RECEIVE" — the reward number, large, with a Relic-currency label

Plus:
- A title "PRESTIGE" and a one-line explanation of why prestige is worth it.
- A "Confirm Prestige" button and a "Cancel" button, clearly distinguishable
  (confirm is the destructive-positive action; cancel must be obvious).
- When reward is 0 the confirm button MUST be disabled and a visible message
  explains why ("Reach a higher stage first"). Never present a dead button with
  no explanation.
- Method `show_preview(preview: Dictionary)` populates and shows it.
- Method `debug_open(max_stage: int)` for automated capture: builds a real
  preview via Prestige.preview() and shows the dialog.

# Skills bar
Wire the 6 existing skill buttons in the HUD:
- pressing one calls SkillSystem.activate(id, Time.get_unix_time_from_system()*1000)
- a button shows three visible states: READY, ACTIVE (with remaining seconds),
  COOLDOWN (with remaining seconds). Disabled look when not READY.
- state must be readable without colour alone — include the seconds text.

# Layout constraints
Portrait-safe: the dialog must fit inside 720x1280 with 16px margins and be
fully visible (no clipped text or buttons) at 720x1280, 1080x1920, 1080x2400.
Use containers, not fixed pixel offsets.

# Constraints
Typed GDScript, tabs. Placeholders stay labelled. Do NOT modify
scripts/ui/game.gd. game.tscn root stays Node. Add the arena hook
`debug_open_prestige(max_stage)` on combat_arena so capture can open it.

# Done when
bash scripts/shot.sh 720 1280 /tmp/p.png works and the game still runs, and
scripts/run-tests.sh passes.
