# Goal
Finish Gate 4: C20 salvage button states, settings that actually affect the
running game, and a first-time tutorial.

# Part 1 — C20: salvage button state must mirror inventory rules exactly
In scripts/ui/inventory_panel.gd, add a single source of truth:

  func salvage_ui_state(uid) -> Dictionary
    returns {"enabled": bool, "reason_key": String, "needs_confirm": bool}
    derived by ASKING Inventory, not by re-implementing the rules. Call
    inventory.salvage_refusal_preview(uid) (add it to inventory.gd: same logic
    as the refusal checks in salvage(), but PURE — it must not destroy anything).

  Rules surfaced to the UI:
   - equipped            -> disabled, reason "ui.inventory.cannot_equipped"
   - locked              -> disabled, reason "ui.inventory.cannot_locked"
   - equipped AND locked -> disabled, locked reason wins
   - common, eligible    -> enabled, no confirm
   - rare/epic/legendary -> enabled, needs_confirm
   - favorite            -> enabled, needs_confirm (extra warning line)

  The Salvage button's `disabled` property and an adjacent explanation Label
  must be driven ONLY by salvage_ui_state(). Show the reason text next to the
  disabled button so the player knows why.

Add tests/unit/test_salvage_ui_state.gd proving, for every combination of
(equipped, locked, favorite, rarity), that salvage_ui_state().enabled matches
whether inventory.salvage(uid, true, true) would have succeeded. The UI state
and the logic must never disagree.

# Part 2 — settings must affect the LIVE game
In scripts/ui/settings_panel.gd and a new autoload/settings.gd (autoload name
Settings):
 - Create real audio buses if missing: Master, Music, SFX, UI.
 - Volume sliders map 0..1 to AudioServer.set_bus_volume_db (use linear_to_db,
   and set_bus_mute(bus, true) at 0).
 - `reduced_flash` must reduce the combat flash: combat_arena's hit flash
   intensity multiplies by 0.25 when on, and the RECOIL and HP bar response
   must remain — never remove all feedback.
 - `damage_numbers` off hides pooled damage numbers.
 - `vibration` off must make any vibration call a no-op (route all vibration
   through Settings.vibrate() so there is one gate).
 - Settings live in permanent_state and survive prestige.
 - Loading clamps invalid values (NaN, out of range, wrong type) into range.
 - Changes apply immediately, no restart.

Add tests/unit/test_settings.gd asserting: bus volume actually changes in
AudioServer, mute really mutes, clamping works, values survive save/reload and
prestige, and vibration gating works.

# Part 3 — first-time tutorial
scripts/ui/tutorial.gd + scenes/ui/tutorial_overlay.tscn
Steps in order, each with a localization key:
  tap_enemy, upgrade_hero, support_dps, activate_skill, boss_intro,
  boss_retry, prestige_intro
Rules:
 - Highlight ONLY the current target (a cutout/outline around it); never cover
   the control the player must press.
 - Advance when the real action happens, not on a timer.
 - `prestige_intro` must NOT show until prestige is actually unlocked.
 - Skip button always available. Settings has a "Reset tutorial" action.
 - Completion and current step live in permanent_state, survive reload and
   prestige. Rapid tapping must not advance more than one step per action.
 - No rewards are granted by the tutorial (avoids duplication entirely).

Add tests/unit/test_tutorial.gd: step order, no double advance on rapid input,
skip, reset, persistence across reload, survives prestige, prestige step gated.

# Debug hooks for capture
--debug-salvage-equipped, --debug-salvage-locked, --debug-salvage-eligible,
--debug-salvage-rare, --debug-salvage-favorite,
--debug-flash-normal, --debug-flash-reduced,
--debug-tutorial N   (open tutorial at step N)

# Constraints
Typed GDScript, tabs. Do NOT modify scripts/ui/game.gd. game.tscn root stays
Node. All user-facing text via tr(). Add new keys to BOTH strings.en.csv and
strings.ar.csv (Arabic values may be prefixed "AR:" where not confidently
translated, so gaps are visible).

# Done when
scripts/run-tests.sh passes including the parse guard, and each debug flag
renders its state.
