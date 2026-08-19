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

## Production assets: 46 sprites + 4 world layers

| Item | Count | Source | Built by | Status |
| --- | --- | --- | --- | --- |
| Main hero, falcon companion | 2 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Support hero portraits | 8 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Regular enemies | 12 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Boss archetypes | 4 | approved package | `clean_assets.py` | CONCEPT_SOURCED |
| Equipment icons, weapon and aura slots | 8 | approved package | `clean_assets.py` + `make_equipment_icons.py` | CONCEPT_SOURCED |
| Equipment icons, head / outfit / companion_charm slots | 12 | drawn from scratch for this project | `make_equipment_icons.py` | ORIGINAL |
| Emerald Meadow parallax layers (sky, distant, arena, foreground) | 4 | approved package | `build_world_layers.py` | CONCEPT_SOURCED |

`CONCEPT_SOURCED` means: cleaned from an approved concept reference, in use as
production art, and not yet redrawn as bespoke final art. `ORIGINAL` means drawn
for this project by `tools/make_equipment_icons.py`, which is checked in and
reproducible. All twenty equipment icons are 256x256 lossless WebP with a
transparent background, a 12% safe margin, and a rarity frame plus a badge of
one to four pips so rarity survives without relying on colour.
`tests/unit/test_sprite_background.gd` fails the build if any sprite still
carries the reference sheet's background, and the content validator refuses a
`CONCEPT_SOURCED` entry whose sprite file is missing.

## Remaining placeholders

| Item | Count | Why it is still a placeholder |
| --- | --- | --- |
| Moonlit Wildwood and Obsidian Citadel backgrounds | 2 worlds | Layer rebuild deferred until the first world is approved; they render their flat palette colour |
| Gold icon | 1 | Drawn as a plain swatch |
| Skill icons | 6 | Drawn as text buttons |
| Music and SFX | all | `placeholder://` references only, no audio files |
| Hero and enemy animation frames | all | Single static sprite per subject; the package's animation plans are not built |

Placeholder count: **5 categories, 0 placeholder image files** — the remaining
placeholders are drawn in-engine or are data-only references.

No placeholder above may be presented as production art.
