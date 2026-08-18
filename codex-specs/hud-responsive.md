# Goal
Fix confirmed layout clipping in the portrait HUD. Verified by rendered
screenshots at 720x1280: content is cut off at both screen edges.

# Confirmed defects (from real captures, not assumptions)
At 720x1280:
1. HERO placeholder is clipped off the LEFT edge.
2. ENEMY placeholder is clipped off the RIGHT edge.
3. Enemy HP bar is clipped off the RIGHT edge.
4. "TAP DAMAGE — PLACEHOLDER" label clipped on the left ("AP DAMAGE").
5. "HERO DPS — PLACEHOLDER" label clipped on the right.
6. SKILL 1 and SKILL 6 buttons clipped at both edges.
7. Bottom nav TabBar does not span the width; touch targets are small.

Root cause: fixed pixel sizes/offsets tuned for a 1080-wide viewport.

# Required fix
Make the whole HUD resolution-independent so it is correct at 720x1280,
1080x1920 and 1080x2400 with NO clipping.

- Combat actors (hero, falcon, enemy) must be positioned and sized as a
  PROPORTION of the combat area rect, not fixed pixels. Use anchors or compute
  from the combat area size on resize.
- Actors must be SMALL: hero and enemy each no more than 22% of combat-area
  width and 28% of its height. The brief requires them small so combat feedback
  and UI have room. Falcon ~60% of hero size, placed above-left of the hero,
  never centre screen.
- Hero must remain LEFT of the enemy at every resolution.
- Enemy HP bar must sit above the enemy and stay fully inside the combat area.
- Upgrade rows: labels must use autowrap or clip_text with shrinking, inside
  HBoxContainer children with size_flags_horizontal = SIZE_EXPAND_FILL, and
  the row must have left/right margins of at least 16 px.
- Skill row: 6 buttons in an HBoxContainer, each SIZE_EXPAND_FILL, with a
  minimum touch height of 88 px, separation 8, and outer margins 16.
- Bottom nav must span the FULL width, each tab SIZE_EXPAND_FILL, minimum
  height 96 px.
- Keep SAFE_TOP = 48 and add SAFE_BOTTOM = 24 margin.
- Keep zones at roughly 15% / 55% / 30% via size_flags_stretch_ratio.

# Constraints
- Typed GDScript, tabs. No external assets. Keep placeholders clearly labelled.
- Do not change scripts/ui/game.gd (it holds the screenshot capture logic).
- game.tscn root node type must stay Node.

# Done when
These three commands each save a PNG and the layout has no clipped element:
  bash scripts/shot.sh 720 1280 /tmp/a.png
  bash scripts/shot.sh 1080 1920 /tmp/b.png
  bash scripts/shot.sh 1080 2400 /tmp/c.png
