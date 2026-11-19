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
- **#3 Rewind behavior (BUILD-phase Replay)**: Rewind is triggered during `BUILD` phase between waves (once per build phase after clearing a wave, blocked before Wave 1 to prevent Wave 1 pre-farming). It replays the previously cleared wave deterministically with NO new mutation on the replayed wave, awards `b$` again (`0.25x` diminishing Research), adds `+1 Armoured` (`+5%` HP) applied AFTER the replay to the next NEW wave, and preserves all player state (towers, upgrades, refineries, builds in progress, `$`, persistent `meta_research`, manipulator level, and lost lives).
- **BUILD Phase Universal Pause**: Between waves (`BUILD` phase), all progression timers — Refineries, construction timers, Hive Destroyer charge timer, time-ability cooldowns, Surge countdown, and Mission Clock — pause.
- **Hive Destroyer Charge Pauses Time Abilities & Surge**: While Hive Destroyer is charging, all 3 time abilities (`Rewind`, `Pause`, `Haste`) are locked (`PAUSED (HIVE)`), active Pause/Haste effects and power cooldowns pause, and the Surge countdown pauses. Haste explicitly cannot speed base-attack charging.

## Algorithmic Difficulty, Economy & Meta-Progression Overhaul
1. **5 Towers Across All 4 Damage Types (`Piercing`, `Normal`, `Laser`, `Time`)**:
   - **Why**: Added `Laser Spire` (`$100`, `Laser` damage) for the 3×3 matrix, then added `Chrono Slow Tower` (`$100`, `115 px`, `30%/15%` slow + `Time` Decay DoT) and `Time Decay Rail Gun` (`$375`, `310 px` = `2.7x` range, `1 shot/5s`, `50%/25%` slow + `Time` Decay DoT) so slow/control and percentage DoT give Juggernaut-wave tactical options alongside `Blaster Turret` (`Piercing`, `180%` vs Juggernaut). Kept `Blaster` Piercing identity prominent on HUD & cards.
2. **Time Damage Row + Juggernaut HIGHEST-Only Rule + 30%/tick Cap**:
   - **Why**: `Time` Decay bypasses Normal/Piercing/Laser armor calculations and uses its own row (`100% Standard`, `120% Armored`, `150% Reflective`). On dual-tag `Armored + Reflective` (`Juggernaut`), `Balance.get_damage_multiplier("Time", ...)` takes the HIGHEST tag multiplier (`150%`, NOT `1.2 × 1.5 = 180%`), and `apply_time_decay_tick()` caps effective per-tick % HP damage at `30%`. Refreshes duration without stacking; executes when remaining HP drops `< 1.0`.
3. **Per-Tower Target Selection (`First` Default for All Towers)**:
   - **Why**: Every built tower starts on `First` (`1ST`) — including `Cluster Mortar` (re-targeted to `First` splash center instead of AoE cluster heuristics) — and cycles cleanly across `First / Last / Strongest / Weakest / Fastest / Slowest` via the right-panel `TargetModeButton` with short tag badges on the tower sprite.
4. **Physical Speed & Single-Lane Range Calibration (`BASE_UNIT_SPEED_PX = 12.0 px/s`, Tower Ranges `108–135 px` + `2x` Range Upgrades)**:
   - **Why**: On the `1,891.1 px` S-path, `12.0 px/s` gives a `~180 s` Wave 1 length (`+10 s/wave`). Base tower ranges (`108–135 px`) cover one lane initially, while upgraded range (`+25% / +60% / +100%` total at `$75 / $160 / $320`) unlocks cross-lane coverage at a higher `$` investment.
5. **5-Wave Surge Deadline (`SURGE_WAVE_SPAN = 5`) & Lighter `+5%` Mutations**:
   - **Why**: With 3-minute waves, the Surge deadline is the beginning of Wave 6 if no time power is used during Waves 1–5 (`-5%` permanent tower attack speed). Mutations were tuned down to `+5%` per use (`Armoured` `+5%` HP, `Thaw-hardened` `+5%` HP = `x1.1025` combined, `Swift` `+5%` alien speed) while Haste was redefined to `+50%` tower attack speed + `+50%` build speed for `30 s` and Pause extended `+2 s` (`8 s` base, `10 s` at Manipulator Lv 3).
6. **Rogue-Like Persistent Meta-Research & Between-Levels Lab**:
   - **Why**: Removed `ResearchBox` from the in-game `RightPanel` shop completely and moved research spending to `BetweenLevelsOverlay` (`Levels / Lab`), with persistent `GameState.meta_research`, multi-rank costs `[100, 250, 600, 1400, 3200]`, a `60 R` per-mission cap (`< 100 R` Rank 1 cost), and `0.25x` diminishing returns on Rewind replays.

## Mobile + Desktop Cross-Platform, PWA & Download Distribution Decisions
- **Pixel 11 Pro `20:9` Full-Bleed Responsive Layout (`aspect="expand"`, `SCREEN_SENSOR_LANDSCAPE`)**: Enabled `window/stretch/aspect="expand"` and `window/handheld/orientation=4` in `project.godot`, plus `HUD.apply_responsive_layout(vp_size)` in `scripts/hud.gd` and extended arena margins in `scripts/map.gd`. Preserves fixed `1280×720` (`RightPanel` `340×480`) on desktop `16:9`, eliminates black pillarbox bars on Pixel 11 Pro `20:9` widescreen (`~1603×720`, centering the map with extended grid/corridor margins and cutout-safe bar padding), and stacks all panels full-width in `9:20` portrait fallback (`1280×2844`) with a tappable landscape/fullscreen pill.
- **Touch Ergonomics Without Keyboard or Mouse Hover**: Added on-screen `Menu`, `Dbg`, `Full`, and `DL / App` buttons in `TopBar` (with `Full` calling `ttdToggleLandscapeFullscreen()` on Web), expanded `_find_pad_at` touch hit radius to `34 px`, and wired `gui_input` tap-to-inspect on both enabled and disabled buttons.
- **Fullscreen PWA + Auto-Updating Service Worker + Download Modal (`TimeDefense-Web.zip` + `TimeDefense.apk`)**: Configured `progressive_web_app/display=0` (`fullscreen`) and `orientation=1` (`landscape`) with SHA-stamped `CACHE_VERSION`, `skipWaiting()`/`clients.claim()`, and `controllerchange` auto-reload so installed Pixel 11 Pro PWAs pick up updates automatically.
