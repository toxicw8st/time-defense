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

## 2. 3×3 Damage Matrix & Towers (`~0.153 DPS/$`)
- `DAMAGE_MATRIX`:
  - `Normal`: `100%` vs `Standard`, `50%` vs `Armored`, `110%` vs `Reflective`
  - `Piercing`: `75%` vs `Standard`, `150%` vs `Armored`, `120%` vs `Reflective` (`180%` vs `Armored + Reflective`)
  - `Laser`: `150%` vs `Standard`, `85%` vs `Armored`, `10%` vs `Reflective`
- `Blaster Turret`: `$75 -> $90`, `Piercing`, `11.5 dmg @ 1.2/s = 13.8 base DPS`, range `108 px`
- `Cluster Mortar`: `$110`, `Normal` splash (`70 px` AoE, `60 px` min range), `22.0 dmg @ 0.5/s = 11.0 single DPS`, range `135 px`
- `Laser Spire` (new): `$100`, `Laser`, `6.2 dmg @ 2.5/s = 15.5 base DPS` (`23.25 DPS` vs `Standard`), range `112 px`

## 3. Refineries (Exponential Cost Ramp & Longer-Wave Income Rate)
- `STARTING_REFINERIES`: `1 -> 0`
- `REFINERY_BASE_COST`: `$100 -> $250`
- `REFINERY_COST_GROWTH`: `1.35 -> 1.80` (`$250, $450, $810, $1,460, $2,625`; cumulative `$2,970` for 4 refineries — impossible before Wave 5)
- `REFINERY_RATE_PER_SEC`: `$1.60/s ($8/5s) -> $0.25/s ($1/4s)` so 3-minute+ waves (`180s + 10s/wave`) yield `$45–$67.50/wave` per refinery without breaking the economy
- `WAVE_CLEAR_BONUS_BASE`: `$25 + $2/wave -> $0` (all wave income comes from unit `b$` bounties + refinery income per Money Algorithm)

## 4. Rogue-Like Meta-Research (Between Levels Only)
- Removed in-game `ResearchBox` from `RightPanel`; moved to `BetweenLevelsOverlay` (`Levels / Lab`)
- `RESEARCH_RANK_COSTS`: `15–35 R (single-buy)` -> `[100, 250, 600, 1400, 3200] R` (5 ranks per node, persists across missions)
- `MAX_RESEARCH_PER_MISSION`: `unlimited -> 60 R` (1 mission alone cannot afford Rank 1 at `100 R`)
- `REWIND_RESEARCH_MULT`: `1.0 -> 0.25` (diminishing research on Rewind replays)

## 5. Enemy Base & Hive Destroyer (`1/N` Rule)
- `BASE_ATTACK_COST`: `$150 -> $450` per charge (requires multiple waves of savings / Rewind farming)
- `ENEMY_BASE_MAX_HP`: `500 HP` (`Level 1 = 1 shot @ 500 dmg`, `Level 2 = 2 shots @ 250 dmg`, `Level 3 = 3 shots @ 167 dmg`)
