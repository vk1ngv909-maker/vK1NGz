# Asset Manifest

Every asset must be original, licensed, or a clearly labelled placeholder.
No Tap Titans (or any third-party) art, audio, icon, or data is used.

## Source

The project owner supplied an approved visual package,
`CLAUDE_READY_CARTOON_ASSET_BIBLE/`, stored in the repository exactly as
delivered. Its declared style is an original, culturally neutral 2D fantasy
cartoon, and its manifest marks every file
`concept_reference_only_requires_clean_sprite_redraw_or_final_cutout`.

Nothing from that folder is loaded by the game. Production sprites are built
from it by `tools/clean_assets.py` into `assets/sprites/`, and world layers by
`tools/build_world_layers.py` into `assets/worlds/`. The folder carries a
`.gdignore` so Godot never imports the concept crops.

## Production assets: 57 sprites + 12 world layers

| Item | Count | Source | Built by | Status |
| --- | --- | --- | --- | --- |
| Main hero, falcon companion | 2 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Support hero portraits (retained, no longer displayed) | 8 | approved package | `clean_assets.py` | CONCEPT_SOURCED, UNUSED |
| Regular enemies | 12 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Boss archetypes | 4 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Equipment icons, weapon and aura slots | 8 | approved package | `clean_assets.py` + `make_equipment_icons.py` | CONCEPT_SOURCED |
| Equipment icons, head / outfit / companion_charm slots | 12 | drawn from scratch for this project | `make_equipment_icons.py` | ORIGINAL |
| Gold coin and six skill icons | 7 | drawn from scratch for this project | `make_ui_icons.py` | ORIGINAL |
| Rear-view main hero, idle and attack poses | 2 | delivered production art (`CLAUDE_HERO_ASSETS_SELF_EXTRACTING`, SHA-256 verified on extraction) | delivered as final, not generated | DELIVERED_FINAL |
| Sword slash arc, staff magic bolt | 2 | drawn from scratch for this project | `make_slash_arc.py`, `make_magic_bolt.py` | ORIGINAL |
| Parallax layers for three worlds (sky, distant, arena, foreground each) | 12 | approved package | `build_world_layers.py` | CONCEPT_SOURCED |

`CONCEPT_SOURCED` means: cleaned from an approved concept reference, in use as
production art, and not yet redrawn as bespoke final art. `DELIVERED_FINAL`
means supplied by the project owner as finished art and used byte-for-byte: the
two hero PNGs are 2048x2048 RGBA, recorded with their SHA-256 in
`resources/hero_sprite_metrics.json`, and imported losslessly. They are the one
category `tests/unit/test_sprite_background.gd` skips, because they never went
through `clean_assets.py` and so cannot carry the concept sheet's background;
the exclusion is named in that test and each entry must exist. `ORIGINAL` means drawn
for this project by a checked-in, reproducible script under `tools/`. All twenty equipment icons are 256x256 lossless WebP with a
transparent background, a 12% safe margin, and a rarity frame plus a badge of
one to four pips so rarity survives without relying on colour.
`tests/unit/test_sprite_background.gd` fails the build if any sprite still
carries the reference sheet's background, and the content validator refuses a
`CONCEPT_SOURCED` entry whose sprite file is missing.

## Remaining placeholders

| Item | Count | Why it is still a placeholder |
| --- | --- | --- |
| Music and SFX | all | `placeholder://` references only, no audio files |
| Hero and enemy animation frames | all | Single static sprite per subject; motion is tweened (lunge, slash arc, recoil) rather than frame-animated |

Placeholder count: **2 categories, 0 placeholder image files** — the remaining
placeholders are drawn in-engine or are data-only references.

No placeholder above may be presented as production art, and no placeholder
text reaches the player: the localization files contain no `PLACEHOLDER`
strings in either language.
