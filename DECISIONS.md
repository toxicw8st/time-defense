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
- **Viewport Stretch Mode (`aspect="keep"`) + Landscape Hint**: Switched stretch aspect from `"expand"` to `"keep"` with `window/handheld/orientation=0` and `pointing/emulate_mouse_from_touch=true` in `project.godot` so fixed `1280x720` HUD/map regions center cleanly across desktop and phone landscape browsers.
- **Touch Ergonomics Without Keyboard or Mouse Hover**: Added on-screen `Menu`, `Dbg`, `Full`, and `DL / App` buttons in `TopBar` (replacing keyboard-only `Esc` / `F1`), expanded `_find_pad_at` touch hit radius to `34 px`, and wired `gui_input` tap-to-inspect on both enabled and disabled buttons.
- **Single-Threaded Web PWA + Real Download Modal (`TimeDefense-Web.zip` + `TimeDefense.apk`)**: Enabled Godot `4.7.2` PWA export (`progressive_web_app/enabled=true`, `index.manifest.json`, `index.service.worker.js`, `144/180/512` PNG icons) with single-threaded Wasm (`variant/thread_support=false`) for Android Chrome + iOS Safari compatibility, plus a TopBar `DL / App` modal (`#ttd-dl-modal`) exposing one-tap PWA install AND direct downloads for `downloads/TimeDefense-Web.zip` and debug-signed `downloads/TimeDefense.apk` built on every CI push.
