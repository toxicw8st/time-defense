# DECISIONS.md

Log of unspecified design choices, creator overrides, and algorithmic difficulty overhaul decisions.

## Notation Standard (Used Across Code, Comments & Docs)
- `s$` = spawn cost (threat cost to spawn an enemy unit)
- `b$` = bounty (player `$` earned for killing an enemy unit)
- `$` = player money (starting `$200`, tower costs, refinery costs, base-attack cost)
- `s$` and `b$` are strictly separate numbers for the same unit and are never equated.

## Step 0 + Pre-Step 1 Creator Rulings (Locked)
- **Workspace & Viewport**: `time-defense` (`GL Compatibility`, `1280x720`, `canvas_items` / `expand`).
- **#1 Research stacking**: Multiplicative with tower upgrades and surge (`base * (1 + upgrade_bonus) * (1 + research_bonus) * surge_penalty`).
- **#2 Base lock during Manipulator upgrade**: Manipulator upgrade and Hive Destroyer charging share the single Base slot — starting a Manipulator upgrade blocks new Hive Destroyer charges and new Refinery builds until finished; if a Hive Destroyer charge is active, starting a Manipulator upgrade is blocked until the charge finishes.
- **#3 Rewind behavior**: Rewind affects only the enemy wave (clears active enemies/projectiles, restarts the current wave deterministically, and adds `+1 Armoured`). All player-side state — towers (including mid-wave builds/upgrades), refineries, constructions in progress, `$`, persistent `meta_research`, manipulator level, and player lives (lost lives remain lost) — stays as it currently is.
- **BUILD Phase Universal Pause**: Between waves (`BUILD` phase), all progression timers — Refineries, construction timers, Hive Destroyer charge timer, time-ability cooldowns, Surge countdown, and Mission Clock — pause.
- **Hive Destroyer Charge Pauses Time Abilities & Surge**: While Hive Destroyer is charging, all 3 time abilities (`Rewind`, `Pause`, `Haste`) are locked (`PAUSED (HIVE)`), active Pause/Haste effects and power cooldowns pause, and the Surge countdown pauses.

## Algorithmic Difficulty, Economy & Meta-Progression Overhaul
1. **Added `Laser Spire` (`$100`, `Laser` damage) Alongside `Blaster Turret` (`$90`, `Piercing`) and `Cluster Mortar` (`$110`, `Normal`)**:
   - **Why**: The prompt requires the 3×3 Damage Matrix (`Normal`, `Piercing`, `Laser` vs `Standard`, `Armored`, `Reflective`), and the original prototype only had 2 towers (`Blaster` and `Mortar`). Adding `Laser Spire` (`$100`, `6.2 dmg @ 2.5/s = 15.5 base DPS`, `150%` vs `Standard`, `85%` vs `Armored`, `10%` vs `Reflective`) gives the player all 3 damage types without adding any forbidden mechanics.
2. **Physical Speed & Single-Lane Range Calibration (`BASE_UNIT_SPEED_PX = 12.0 px/s`, Tower Ranges `108–135 px`)**:
   - **Why**: On the `1,891.1 px` S-path, `12.0 px/s` gives a `157.6 s` traversal time (`+ ~23 s` spawn stream = `~180 s` / `3 minutes` on Wave 1, growing `+10 s` per wave). Calibrating tower ranges to `108–135 px` ensures a tower placed at `y = 157` or `y = 322` covers a single lane (`~140 px` chord = `~11.7 s` crossing + `~25 s` stream = `~37.0 s` effective engagement window on Wave 1) rather than hitting two parallel lanes simultaneously. This makes the live 2D physics match `DPS needed = (mutated_hp * avg_speed) / (wave_length * 0.30 * difficulty_k)` directly so 2 starting towers hold Wave 1 (`ratio 1.02`) and fail before Wave 5.
3. **5-Wave Surge Deadline (`SURGE_WAVE_SPAN = 5`)**:
   - **Why**: With 3-minute waves, the Surge deadline is the beginning of Wave 6 if no time power is used during Waves 1–5, and resets to `+5` full waves (`current_wave + 6` start) whenever any time ability is used.
4. **Rogue-Like Persistent Meta-Research & Between-Levels Lab**:
   - **Why**: Removed `ResearchBox` from the in-game `RightPanel` shop completely and moved research spending to `BetweenLevelsOverlay` (`Levels / Lab`), with persistent `GameState.meta_research`, multi-rank costs `[100, 250, 600, 1400, 3200]`, a `60 R` per-mission cap (`< 100 R` Rank 1 cost), and `0.25x` diminishing returns on Rewind replays.

## Mobile + Desktop Cross-Platform & Web CI/CD Decisions
- **Viewport Stretch Mode (`aspect="keep"`) + Landscape Hint**: Switched stretch aspect from `"expand"` to `"keep"` with `window/handheld/orientation=0` and `pointing/emulate_mouse_from_touch=true` in `project.godot` so fixed `1280x720` HUD/map regions center cleanly across both desktop windows and widescreen phone landscape browsers. Added a CSS-only portrait hint banner (`Rotate phone to landscape for best view`) via `export_presets.cfg`.
- **Touch Ergonomics Without Keyboard or Mouse Hover**: Added on-screen `Menu`, `Dbg`, and `Full` buttons in `TopBar` (replacing keyboard-only `Esc` / `F1`), expanded `_find_pad_at` touch hit radius to `34 px` (closest pad when >=105 px apart), and wired `gui_input` tap-to-inspect on both enabled and disabled buttons so mobile players can tap any button to read its description in `HoverInfoPanel`.
- **Single-Threaded Web Export + Auto-Deploy via GitHub Actions -> GitHub Pages**: Configured `variant/thread_support=false` (`progressive_web_app/enabled=false` to prevent stale service-worker caching between test pushes) in `export_presets.cfg` and `.github/workflows/deploy.yml` so GitHub Pages serves the game to both iOS Safari and Android Chrome on every `git push`.
