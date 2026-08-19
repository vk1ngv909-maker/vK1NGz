# Asset mapping — approved package to game content

Every id below is unchanged. Only the artwork and the display name change, so
saved runs, first-clear records and owned equipment keep resolving exactly as
before.

## Worlds

| Game id (unchanged) | New display name (EN / AR) | Package art | Status |
| --- | --- | --- | --- |
| `oasis_frontier` | Emerald Meadow / المرج الزمردي | `worlds/oasis_frontier.webp` | Rebuilt as 4 parallax layers |
| `moonlit_dunes` | Moonlit Wildwood / الغابة المقمرة | `worlds/moonlit_dunes.webp` | Name only; layers deferred |
| `ruins_of_the_sun_kingdom` | Obsidian Citadel / قلعة السبج | `worlds/ruins_of_the_sun_kingdom.webp` | Name only; layers deferred |

## Player and companion

| Game id | Package asset | Display name |
| --- | --- | --- |
| hero actor | `characters/main_hero` | — |
| falcon actor | `companions/falcon_companion` | — |

## Support heroes

| Game id (unchanged) | Package asset | New name (EN / AR) |
| --- | --- | --- |
| `dune_scout` | `characters/core_archer` | Meadow Archer / رامية المرج |
| `oasis_guard` | `characters/core_knight` | Grove Knight / فارس البستان |
| `sun_priestess` | `characters/sun_cleric` | Sun Cleric / كاهنة الشمس |
| `falconer` | `characters/spirit_tamer` | Spirit Tamer / مروّضة الأرواح |
| `scarab_knight` | `characters/royal_guardian` | Royal Guardian / الحارس الملكي |
| `mirage_weaver` | `characters/wind_dancer` | Wind Dancer / راقصة الريح |
| `djinn_binder` | `characters/rune_scholar` | Rune Scholar / عالم الرقيم |
| `star_vizier` | `characters/moon_bard` | Moon Bard / شاعر القمر |

## Regular enemies

| Game id (unchanged) | Package asset | New name (EN / AR) |
| --- | --- | --- |
| `dune_raider` | `monsters/leaf_fox` | Leaf Fox / ثعلب الأوراق |
| `oasis_scarab` | `monsters/pebble_crab` | Pebble Crab / سرطان الحصى |
| `thorn_lizard` | `monsters/sproutling` | Sproutling / البرعم |
| `mirage_stalker` | `monsters/acorn_brute` | Acorn Brute / غليظ البلوط |
| `night_howler` | `monsters/mushroom_guard` | Mushroom Guard / حارس الفطر |
| `dust_wraith` | `monsters/pollen_wisp` | Pollen Wisp / شهاب اللقاح |
| `moon_moth` | `monsters/frost_moth` | Frost Moth / عثّة الصقيع |
| `glass_serpent` | `monsters/shard_serpent` | Shard Serpent / أفعى الشظايا |
| `sunstone_sentinel` | `monsters/rune_guardian` | Rune Guardian / حارس الرقيم |
| `cursed_regalia` | `monsters/smoke_wisp` | Smoke Wisp / شهاب الدخان |
| `ember_djinn_construct` | `monsters/ember_imp` | Ember Imp / عفريت الجمر |
| `ossuary_warden` | `monsters/obsidian_beetle` | Obsidian Beetle / خنفساء السبج |

## Bosses — matched to each archetype's existing silhouette field

| Game id (unchanged) | Silhouette | Package asset | New name (EN / AR) |
| --- | --- | --- | --- |
| `sandstorm_colossus` | wide | `bosses/ancient_treant` | Ancient Treant / الشجرة العتيقة |
| `lunar_glasswing` | spindly | `bosses/crystal_cavern_wyrm` | Crystal Wyrm / تنين البلور |
| `ember_crown_construct` | tall | `bosses/clockwork_crown_king` | Clockwork Crown King / ملك التروس المتوّج |
| `vaultback_behemoth` | squat | `bosses/mushroom_monarch` | Mushroom Monarch / ملك الفطر |

## Equipment

Eight of the twenty items have honest art in the package. Every weapon-slot and
aura-slot item is covered; head, outfit and companion-charm items are not,
because the package contains weapon-type icons only.

| Game id (unchanged) | Slot | Package asset | New name (EN / AR) |
| --- | --- | --- | --- |
| `dune_knife` | weapon | `weapons/iron_short_sword` | Iron Short Sword / سيف حديدي قصير |
| `sunsteel_sabre` | weapon | `weapons/grove_blade` | Grove Blade / نصل البستان |
| `ifrit_fang` | weapon | `weapons/prism_sword` | Prism Sword / سيف المنشور |
| `blade_of_high_noon` | weapon | `weapons/ember_blade` | Ember Blade / نصل الجمر |
| `dust_wisp` | aura | `weapons/verdant_crystal_orb` | Verdant Orb / كرة الخضرة |
| `ember_halo` | aura | `weapons/star_wand` | Star Wand / عصا النجمة |
| `djinn_radiance` | aura | `weapons/amethyst_wand` | Amethyst Wand / عصا الجمشت |
| `solar_ascendance` | aura | `weapons/astral_spellbook` | Astral Spellbook / سفر النجوم |

The remaining twelve items were renamed to neutral fantasy names but still show
the text-only inventory card; they need art that the package does not contain.

## Rejected options

- **Head, outfit and charm icons taken from weapon art** — a hammer standing in
  for a hood misdescribes the item. A labelled text card is more honest.
- **`monsters/honey_slime` for `dune_raider`** — the raider is the fast enemy of
  world 1; `leaf_fox` carries that read, the slime does not.
- **`bosses/celestial_owl_guardian` for `lunar_glasswing`** — the name matches
  but the silhouette does not; the data says `spindly`, so the long coiled wyrm
  was used instead.
- **`bosses/magma_horn_beast` for `ember_crown_construct`** — thematically close
  but `low massive`, while the entry is `tall` and named for a crown.
- **Upscaling the 540x959 concept painting** — rejected by the brief and would
  not give the four depths a parallax needs.
