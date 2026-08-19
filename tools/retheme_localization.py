#!/usr/bin/env python3
"""Rewrite display names for the neutral cartoon fantasy theme.

Only the text a player reads changes. Every id stays exactly as it is, so saved
runs, first-clear records and owned equipment keep resolving.
"""
from __future__ import annotations

import csv
from pathlib import Path

# key -> (english, arabic)
NAMES: dict[str, tuple[str, str]] = {
    "world.oasis_frontier.name": ("Emerald Meadow", "المرج الزمردي"),
    "world.oasis_frontier.desc": ("Cross bright grassland ruins where blue crystals grow.",
                                  "اعبر أطلال المروج المضيئة حيث تنمو البلورات الزرقاء."),
    "world.moonlit_dunes.name": ("Moonlit Wildwood", "الغابة المقمرة"),
    "world.moonlit_dunes.desc": ("Walk a glowing forest under an endless moon.",
                                 "امشِ في غابة متوهجة تحت قمر لا يغيب."),
    "world.ruins_of_the_sun_kingdom.name": ("Obsidian Citadel", "قلعة السبج"),
    "world.ruins_of_the_sun_kingdom.desc": ("Climb a volcanic fortress lit by molten veins.",
                                            "اصعد قلعة بركانية تضيئها عروق منصهرة."),

    "enemy.dune_raider.name": ("Leaf Fox", "ثعلب الأوراق"),
    "enemy.dune_raider.desc": ("A quick woodland runner that darts between the stones.",
                               "عدّاء سريع من الغابة يتنقل بين الحجارة."),
    "enemy.oasis_scarab.name": ("Pebble Crab", "سرطان الحصى"),
    "enemy.oasis_scarab.desc": ("A rock-shelled crab that guards the meadow pools.",
                                "سرطان بصدفة صخرية يحرس برك المرج."),
    "enemy.thorn_lizard.name": ("Sproutling", "البرعم"),
    "enemy.thorn_lizard.desc": ("A small plant creature with a stubborn leaf crown.",
                                "مخلوق نباتي صغير بتاج من الأوراق العنيدة."),
    "enemy.mirage_stalker.name": ("Acorn Brute", "غليظ البلوط"),
    "enemy.mirage_stalker.desc": ("A broad-fisted brute armoured in acorn shell.",
                                  "غليظ عريض القبضة مدرّع بقشر البلوط."),
    "enemy.night_howler.name": ("Mushroom Guard", "حارس الفطر"),
    "enemy.night_howler.desc": ("A capped fighter that never lowers its shield.",
                                "مقاتل بقبعة فطر لا يخفض درعه أبداً."),
    "enemy.dust_wraith.name": ("Pollen Wisp", "شهاب اللقاح"),
    "enemy.dust_wraith.desc": ("A drifting light that scatters glowing pollen.",
                               "ضوء سابح ينثر لقاحاً متوهجاً."),
    "enemy.moon_moth.name": ("Frost Moth", "عثّة الصقيع"),
    "enemy.moon_moth.desc": ("A pale flier whose wings leave a cold shimmer.",
                             "طائرة شاحبة تترك أجنحتها بريقاً بارداً."),
    "enemy.glass_serpent.name": ("Shard Serpent", "أفعى الشظايا"),
    "enemy.glass_serpent.desc": ("A coiled serpent grown over with sharp crystal.",
                                 "أفعى ملتفة تغطيها بلورات حادة."),
    "enemy.sunstone_sentinel.name": ("Rune Guardian", "حارس الرقيم"),
    "enemy.sunstone_sentinel.desc": ("A tall construct sealed with steady runes.",
                                     "بنية عالية مختومة برقوم ثابتة."),
    "enemy.cursed_regalia.name": ("Smoke Wisp", "شهاب الدخان"),
    "enemy.cursed_regalia.desc": ("A restless coil of smoke with burning eyes.",
                                  "لفافة دخان قلقة بعينين متقدتين."),
    "enemy.ember_djinn_construct.name": ("Ember Imp", "عفريت الجمر"),
    "enemy.ember_djinn_construct.desc": ("A small fire spirit that never stops moving.",
                                         "روح نار صغيرة لا تهدأ."),
    "enemy.ossuary_warden.name": ("Obsidian Beetle", "خنفساء السبج"),
    "enemy.ossuary_warden.desc": ("A low beetle plated in dark volcanic glass.",
                                  "خنفساء منخفضة مدرّعة بزجاج بركاني داكن."),

    "boss.sandstorm_colossus.name": ("Ancient Treant", "الشجرة العتيقة"),
    "boss.sandstorm_colossus.desc": ("A wide forest guardian that slams with branch arms.",
                                     "حارس غابة عريض يضرب بأذرع من الأغصان."),
    "boss.lunar_glasswing.name": ("Crystal Wyrm", "تنين البلور"),
    "boss.lunar_glasswing.desc": ("A long coiled wyrm that sweeps the ground with crystal.",
                                  "تنين طويل ملتف يكنس الأرض بالبلور."),
    "boss.ember_crown_construct.name": ("Clockwork Crown King", "ملك التروس المتوّج"),
    "boss.ember_crown_construct.desc": ("A tall crowned machine with a cannon for a hand.",
                                        "آلة عالية متوّجة يدها مدفع."),
    "boss.vaultback_behemoth.name": ("Mushroom Monarch", "ملك الفطر"),
    "boss.vaultback_behemoth.desc": ("A squat crowned monarch that punches with both fists.",
                                     "ملك قصير متوّج يلكم بقبضتيه."),

    "hero.dune_scout": ("Meadow Archer", "رامية المرج"),
    "hero.dune_scout.desc": ("A keen-eyed archer whose signals strengthen every ally.",
                             "رامية حادة النظر تقوّي إشاراتها كل الرفاق."),
    "hero.oasis_guard": ("Grove Knight", "فارس البستان"),
    "hero.oasis_guard.desc": ("A steadfast blade who turns close combat into stronger taps.",
                              "نصل ثابت يحوّل القتال القريب إلى نقرات أقوى."),
    "hero.sun_priestess": ("Sun Cleric", "كاهنة الشمس"),
    "hero.sun_priestess.desc": ("A radiant guide who improves gold and lasting skill power.",
                                "مرشدة مشعّة ترفع الذهب وقوة المهارات."),
    "hero.falconer": ("Spirit Tamer", "مروّضة الأرواح"),
    "hero.falconer.desc": ("A precision hunter who raises the company critical chance.",
                           "صيّادة دقيقة ترفع فرصة الضربة الحاسمة للجميع."),
    "hero.scarab_knight": ("Royal Guardian", "الحارس الملكي"),
    "hero.scarab_knight.desc": ("A heavy striker who reinforces direct attacks.",
                                "ضارب ثقيل يعزّز الهجمات المباشرة."),
    "hero.mirage_weaver": ("Wind Dancer", "راقصة الريح"),
    "hero.mirage_weaver.desc": ("A spellcaster whose spinning blades amplify the whole roster.",
                                "ساحرة نصالها الدوّارة تضاعف قوة الفريق كله."),
    "hero.djinn_binder": ("Rune Scholar", "عالم الرقيم"),
    "hero.djinn_binder.desc": ("A master of magic who empowers allies and shortens recovery.",
                               "أستاذ سحر يقوّي الرفاق ويقصّر الانتظار."),
    "hero.star_vizier": ("Moon Bard", "شاعر القمر"),
    "hero.star_vizier.desc": ("A celestial adviser who bends skill time and fortune.",
                              "مستشار سماوي يطوّع وقت المهارات والحظ."),

    "equipment.dune_knife.name": ("Iron Short Sword", "سيف حديدي قصير"),
    "equipment.dune_knife.desc": ("A plain blade every traveller starts with.",
                                  "نصل بسيط يبدأ به كل مسافر."),
    "equipment.sunsteel_sabre.name": ("Grove Blade", "نصل البستان"),
    "equipment.sunsteel_sabre.desc": ("A sword grown around living wood.",
                                      "سيف نما حول خشب حيّ."),
    "equipment.ifrit_fang.name": ("Prism Sword", "سيف المنشور"),
    "equipment.ifrit_fang.desc": ("A crystal edge that splits the light.",
                                  "حدّ بلوري يشقّ الضوء."),
    "equipment.blade_of_high_noon.name": ("Ember Blade", "نصل الجمر"),
    "equipment.blade_of_high_noon.desc": ("A legendary blade wrapped in steady flame.",
                                          "نصل أسطوري يلتف حوله لهب ثابت."),
    "equipment.wanderer_wrap.name": ("Traveller's Hood", "قلنسوة الرحّالة"),
    "equipment.wanderer_wrap.desc": ("A light hood for long roads.",
                                     "قلنسوة خفيفة للطرق الطويلة."),
    "equipment.scarab_circlet.name": ("Leaf Circlet", "إكليل الأوراق"),
    "equipment.scarab_circlet.desc": ("A circlet woven from evergreen leaves.",
                                      "إكليل منسوج من أوراق دائمة الخضرة."),
    "equipment.oracle_veil.name": ("Seer's Veil", "خمار العرّافة"),
    "equipment.oracle_veil.desc": ("A veil that shimmers around hidden paths.",
                                   "خمار يتلألأ حول الدروب الخفية."),
    "equipment.crown_of_stars.name": ("Crown of Stars", "تاج النجوم"),
    "equipment.crown_of_stars.desc": ("A crown set with a midnight constellation.",
                                      "تاج مرصّع بكوكبة منتصف الليل."),
    "equipment.traveler_robes.name": ("Traveller's Cloak", "عباءة الرحّالة"),
    "equipment.traveler_robes.desc": ("Practical cloth for a long walk.",
                                      "قماش عملي لمسير طويل."),
    "equipment.caravan_guard_mail.name": ("Guard's Mail", "درع الحارس"),
    "equipment.caravan_guard_mail.desc": ("Mail worn by steadfast gate guards.",
                                          "درع يلبسه حرّاس البوابة الثابتون."),
    "equipment.stormweave_mantle.name": ("Stormweave Mantle", "عباءة العاصفة"),
    "equipment.stormweave_mantle.desc": ("A mantle woven with caught lightning.",
                                         "عباءة منسوجة ببرق محبوس."),
    "equipment.sultans_regalia.name": ("Royal Regalia", "الحلّة الملكية"),
    "equipment.sultans_regalia.desc": ("Regalia worthy of an ancient court.",
                                       "حلّة تليق ببلاط قديم."),
    "equipment.dust_wisp.name": ("Verdant Orb", "كرة الخضرة"),
    "equipment.dust_wisp.desc": ("A small orb humming with green light.",
                                 "كرة صغيرة تهمس بضوء أخضر."),
    "equipment.ember_halo.name": ("Star Wand", "عصا النجمة"),
    "equipment.ember_halo.desc": ("A wand that trails warm sparks.",
                                  "عصا تخلّف شرراً دافئاً."),
    "equipment.djinn_radiance.name": ("Amethyst Wand", "عصا الجمشت"),
    "equipment.djinn_radiance.desc": ("A wand cut from a single violet stone.",
                                      "عصا منحوتة من حجر بنفسجي واحد."),
    "equipment.solar_ascendance.name": ("Astral Spellbook", "سفر النجوم"),
    "equipment.solar_ascendance.desc": ("A legendary book that keeps its own light.",
                                        "كتاب أسطوري يحمل ضوءه معه."),
    "equipment.beetle_token.name": ("Beetle Token", "رمز الخنفساء"),
    "equipment.beetle_token.desc": ("A humble token polished by travel.",
                                    "رمز متواضع صقله السفر."),
    "equipment.falcon_bell.name": ("Falcon Bell", "جرس الصقر"),
    "equipment.falcon_bell.desc": ("A silver bell your falcon answers to.",
                                   "جرس فضي يستجيب له صقرك."),
    "equipment.moon_fox_talisman.name": ("Moon Fox Talisman", "تعويذة ثعلب القمر"),
    "equipment.moon_fox_talisman.desc": ("A moonlit charm for a clever companion.",
                                         "تعويذة مقمرة لرفيق ذكي."),
    "equipment.phoenix_signet.name": ("Phoenix Signet", "خاتم العنقاء"),
    "equipment.phoenix_signet.desc": ("A legendary signet of return and renewal.",
                                      "خاتم أسطوري للعودة والتجدد."),
}


def rewrite(path: Path, column: int) -> int:
    rows = list(csv.reader(path.open(encoding="utf-8")))
    changed = 0
    for row in rows:
        if not row or row[0] not in NAMES:
            continue
        value = NAMES[row[0]][column]
        if row[1] != value:
            row[1] = value
            changed += 1
    with path.open("w", encoding="utf-8", newline="") as handle:
        csv.writer(handle, lineterminator="\n").writerows(rows)
    return changed


def main() -> None:
    english = rewrite(Path("localization/strings.en.csv"), 0)
    arabic = rewrite(Path("localization/strings.ar.csv"), 1)
    print(f"renamed {english} english and {arabic} arabic entries across {len(NAMES)} keys")


if __name__ == "__main__":
    main()
