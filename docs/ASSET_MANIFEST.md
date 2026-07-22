# Regnum Moravicum — Asset Manifest

> Status: `Planned → Generating → Review → Approved → Implemented`  
> Kanon: `docs/ART_PROMPT_CANON.md` · M6: `docs/M6_UI_ART_SCOPE.md` · Visual: `docs/VISUAL_DIRECTION.md`  
> Pipeline: Style Master → G2 masters → UI icons (M6) → map/battle markers → wire  
> **Sim:** M1–M5 complete (`SMOKE_PASS`). **Art blocker pre M6 shell:** G2 Review + icons Planned.

| id | layer | type | path | status | source_prompt | seed | notes |
|----|-------|------|------|--------|---------------|------|-------|
| regnum_visual_style_master | A | style_master | godot/assets/events/regnum_visual_style_master_v1.png | **Approved** | ART_PROMPT_CANON §9.1 / tools/art/prompts/style_master_v1.txt | 3914650080 | FAL fal-ai/flux-pro/v1.1; schválené userom |
| mojmir_ii_master_portrait | A | portrait | godot/assets/portraits/mojmir_ii_master_portrait_v1.png | **Approved** | §9.6 | 1632385312 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 768x1024; schválené userom |
| theodora_master_portrait | A | portrait | godot/assets/portraits/theodora_master_portrait_v1.png | **Approved** | §9.7 | 1227800731 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 768x1024; schválené userom |
| arpad_master_portrait | A | portrait | godot/assets/portraits/arpad_master_portrait_v1.png | **Approved** | §9.8 | 108386837 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 768x1024; schválené userom |
| nitra_master_hero | A | location | godot/assets/locations/nitra_master_hero_v1.png | **Approved** | §9.3 | 841884474 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1344x768; schválené userom |
| devin_master_fortress | A | location | godot/assets/locations/devin_master_fortress_v1.png | **Approved** | §9.4 | 1257575324 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1344x768; schválené userom |
| bratislava_master_river | A | location | godot/assets/locations/bratislava_master_river_v1.png | **Approved** | §9.5 / §9 river | 1582198874 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1344x768; schválené userom |
| moravian_court_interior | A | location | godot/assets/locations/moravian_court_interior_v1.png | **Approved** | §9.11 | 4144169081 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1344x768; schválené userom |
| mojmir_dynasty_emblem | A | emblem | godot/assets/icons/factions/mojmir_dynasty_emblem_v1.png | **Approved** | §9.9 | 4096415977 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1024x1024; schválené userom |
| battle_danube_composition | A | battle | godot/assets/events/battle_danube_composition_v1.png | **Approved** | §9.5 | 1349791227 | FAL fal-ai/flux-pro/v1.1 t2i (i2i rejected — style bleed); size 1344x768; schválené userom |

| ui_icon_set_v1 | C | icons | godot/assets/icons/ui/ | **Review** | Block C + M6 §4 | | G3 batch 12 icons generated; 64/256/1024 |
| icon_gold | C | ui_icon | godot/assets/icons/ui/icon_gold_64.png | **Review** | M6_UI_ART_SCOPE §4 | 3086081312 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_food | C | ui_icon | godot/assets/icons/ui/icon_food_64.png | **Review** | M6_UI_ART_SCOPE §4 | 664207953 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_wood | C | ui_icon | godot/assets/icons/ui/icon_wood_64.png | **Review** | M6_UI_ART_SCOPE §4 | 3532798983 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_stone | C | ui_icon | godot/assets/icons/ui/icon_stone_64.png | **Review** | M6_UI_ART_SCOPE §4 | 1528861453 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_iron | C | ui_icon | godot/assets/icons/ui/icon_iron_64.png | **Review** | M6_UI_ART_SCOPE §4 | 1786691906 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_prestige | C | ui_icon | godot/assets/icons/ui/icon_prestige_64.png | **Review** | M6_UI_ART_SCOPE §4 | 352713469 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_eagle | C | ui_icon | godot/assets/icons/ui/icon_eagle_64.png | **Review** | M6_UI_ART_SCOPE §4 | 3128970590 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_cross_latin | C | ui_icon | godot/assets/icons/ui/icon_cross_latin_64.png | **Review** | M6_UI_ART_SCOPE §4 | 267214866 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_cross_patriarchal | C | ui_icon | godot/assets/icons/ui/icon_cross_patriarchal_64.png | **Review** | M6_UI_ART_SCOPE §4 | 1176055786 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_sword | C | ui_icon | godot/assets/icons/ui/icon_sword_64.png | **Review** | M6_UI_ART_SCOPE §4 | 4036174036 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_shield | C | ui_icon | godot/assets/icons/ui/icon_shield_64.png | **Review** | M6_UI_ART_SCOPE §4 | 2002594877 | FAL flux-pro; also _256/_1024; schválenie userom |
| icon_scroll | C | ui_icon | godot/assets/icons/ui/icon_scroll_64.png | **Review** | M6_UI_ART_SCOPE §4 | 1857357039 | FAL flux-pro; also _256/_1024; schválenie userom |

## Theme / infra (nie AI)

| id | path | status |
|----|------|--------|
| regnum_colors | godot/assets/theme/colors.gd | Implemented |
| regnum_theme_factory | godot/assets/theme/regnum_theme_factory.gd | Implemented |
| fonts_cormorant_alegreya | godot/assets/fonts/ | Implemented |

## Changelog

| dátum | zmena |
|-------|--------|
| 2026-07-22 | Scaffold + theme infra |
| 2026-07-22 | Style Master v1 vygenerovaný (FAL flux-pro/v1.1, seed 3914650080) — status Review |
| 2026-07-22 | Style Master v1 **Approved** (seed 3914650080) — ref pre G2 batch |
| 2026-07-22 | G2 masters **re-generated** pure flux-pro t2i (i2i v1 discarded — MAE~6.6 style clone). Status Review. |
| 2026-07-22 | M6 scope zohľadnený: 12 UI icon rows Planned; odkaz M6_UI_ART_SCOPE; sim M1–M5 AS-IS |
| 2026-07-22 | G2 masters (9) **Approved** userom — ready G3 icons / M6 wire |
| 2026-07-22 | G3 UI icons MVP 12 vygenerované → Review (`godot/assets/icons/ui/`) |
