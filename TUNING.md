# TUNING.md

Record of balance changes (`old -> new`) using mandatory notation:
- `s$` = spawn cost (threat cost to spawn an enemy unit)
- `b$` = bounty (player `$` earned for killing an enemy unit)
- `$` = player money (starting `$200`, tower costs, refinery costs, base-attack cost)

## 1. Units (Fixed Base HP — No Wave-Number HP Scaling)
- `Runner` (`40 HP, +8%/wave, b$6`) -> Replaced by 5 fixed-HP unit types:
  - `Crawler`: `s$1`, `b$4`, `50 HP`, `1.0x` speed (`12.0 px/s`), `Standard`
  - `Rusher`: `s$2`, `b$6`, `50 HP`, `2.0x` speed (`24.0 px/s`), `Standard`
  - `Brute`: `s$8`, `b$20`, `600 HP` (was `220 HP + 12%/wave`), `0.9x` speed (`10.8 px/s`), `Armored`
  - `Blitzer` (new): `s$26`, `b$30`, `250 HP`, `3.0x` speed (`36.0 px/s`), `Reflective`
  - `Juggernaut` (new/boss): `s$40` (cut from `s$120`), `b$50`, `5,000 HP`, `1.15x` speed (`13.8 px/s`), `Armored + Reflective` (joins regular wave pool after Wave 10; Wave 10 spawns 4 Juggernauts)

## 2. 4×3 Damage Matrix, Towers (`~0.153 DPS/$`), Range `2x` & Target Modes
- `DAMAGE_MATRIX`:
  - `Normal`: `100%` vs `Standard`, `50%` vs `Armored`, `110%` vs `Reflective` (`55%` vs `Juggernaut`)
  - `Piercing`: `75%` vs `Standard`, `150%` vs `Armored`, `120%` vs `Reflective` (`180%` vs `Juggernaut`)
  - `Laser`: `150%` vs `Standard`, `85%` vs `Armored`, `10%` vs `Reflective` (`8.5%` vs `Juggernaut`)
  - `Time`: `100%` vs `Standard`, `120%` vs `Armored`, `150%` vs `Reflective` (HIGHEST multiplier only on `Armored + Reflective` `Juggernaut` = `150%`, NOT `180%`; per-tick effective Time Decay capped at `30%`)
- `Blaster Turret`: `$90`, `Piercing (180% vs Juggernaut)`, `11.5 dmg @ 1.2/s = 13.8 base DPS`, range `108 px`
- `Cluster Mortar`: `$110`, `Normal` splash (`70 px` AoE, `60 px` min range), `22.0 dmg @ 0.5/s = 11.0 single DPS`, range `135 px`, default target `First`
- `Laser Spire`: `$100`, `Laser`, `6.2 dmg @ 2.5/s = 15.5 base DPS` (`23.25 DPS` vs `Standard`; `10%` vs `Reflective`), range `112 px`
- `Chrono Slow Tower` (new): `$100`, `Time`, `1.0/s`, range `115 px`, `30%` slow for `2.0 s` (`Juggernaut: 15%`), `3` Decay ticks @ `1/sec` (`0%` base / `5%` Lv1 -> `14.3%` / `10%` Lv2 -> `27.1%` / `20%` Lv3 -> `48.8%` vs Standard; refreshes without stacking; executes `< 1 HP`)
- `Time Decay Rail Gun` (new): `$375`, `Time`, `0.20/s` (`1 shot / 5 s`), hitscan range `310 px` (`2.7x` Slow tower), `50%` slow for `4.0 s` (`Juggernaut: 25%`), same `0/5/10/20%` Decay DoT ladder (`$60/$95/$145` upgrade costs)
- **Range Upgrades (Total Bonus & Higher Cost Ramp)**: `+25%` Lv1 (`$75`), `+60%` Lv2 (`$160`), `+100%` / `2x` Lv3 (`$320`)
- **Per-Tower Target Selection**: `First` (default on all 5 towers), `Last`, `Strongest`, `Weakest`, `Fastest`, `Slowest` (`1ST / LST / STR / WK / FST / SLW`)

## 3. Time Powers & Mutations (`+5%` Lighter Stacks)
- `Rewind`: BUILD-phase only (once after clearing a wave; blocked before Wave 1). Replays previous cleared wave with NO new mutation; `+5%` `Armoured` (`hp_bonus_per_stack = 0.05`) applies afterward to next new wave; `65 s` cooldown.
- `Pause`: `6.0 s -> 8.0 s` base (`10.0 s` at Manipulator Lv 3); `+5%` `Thaw-hardened` eff. HP per use (`1.05 * 1.05 = x1.1025` combined w/ Rewind by W11).
- `Haste`: `+50%` tower attack speed to ALL towers AND `+50%` construction speed (`1.50x`) for `30.0 s` (`36.0 s` at Manipulator Lv 3; cannot speed Hive Destroyer charging); `+5%` `Swift` alien speed per use.
- `Surge`: `-5%` tower attack speed per surge, permanent for mission, hits at Wave 6 if unused in Waves 1–5.

## 4. Refineries (Exponential Cost Ramp & Longer-Wave Income Rate)
- `STARTING_REFINERIES`: `1 -> 0`
- `REFINERY_BASE_COST`: `$100 -> $250`
- `REFINERY_COST_GROWTH`: `1.35 -> 1.80` (`$250, $450, $810, $1,460, $2,625`; cumulative `$2,970` for 4 refineries — impossible before Wave 5)
- `REFINERY_RATE_PER_SEC`: `$1.60/s ($8/5s) -> $0.25/s ($1/4s)` so 3-minute+ waves (`180s + 10s/wave`) yield `$45–$67.50/wave` per refinery without breaking the economy
- `WAVE_CLEAR_BONUS_BASE`: `$25 + $2/wave -> $0` (all wave income comes from unit `b$` bounties + refinery income per Money Algorithm)

## 5. Rogue-Like Meta-Research (Between Levels Only)
- Removed in-game `ResearchBox` from `RightPanel`; moved to `BetweenLevelsOverlay` (`Levels / Lab`)
- `RESEARCH_RANK_COSTS`: `15–35 R (single-buy)` -> `[100, 250, 600, 1400, 3200] R` (5 ranks per node, persists across missions)
- `MAX_RESEARCH_PER_MISSION`: `unlimited -> 60 R` (1 mission alone cannot afford Rank 1 at `100 R`)
- `REWIND_RESEARCH_MULT`: `1.0 -> 0.25` (diminishing research on Rewind replays)

## 6. Enemy Base & Hive Destroyer (`1/N` Rule)
- `BASE_ATTACK_COST`: `$150 -> $450` per charge (requires multiple waves of savings / Rewind farming)
- `ENEMY_BASE_MAX_HP`: `500 HP` (`Level 1 = 1 shot @ 500 dmg`, `Level 2 = 2 shots @ 250 dmg`, `Level 3 = 3 shots @ 167 dmg`)
