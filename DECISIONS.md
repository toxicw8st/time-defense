# DECISIONS.md

Log of unspecified design choices and creator overrides made during prototype implementation.

## Step 0 + Pre-Step 1 Creator Rulings
- **Workspace folder name**: Kept existing repo directory `time-defense` (`project.godot` name `TimeDefense`), using `res://` relative paths everywhere.
- **Renderer & viewport**: Switched `project.godot` to `GL Compatibility` and explicit `1280x720` (`canvas_items` / `expand`) per Implementation Guide p. 3.
- **Balance data format**: Used `res://data/balance.gd` (`class_name Balance`) for typed constant access across all scripts.
- **#1 Research stacking**: Multiplicative with tower upgrades and surge (`base * (1 + upgrade_bonus) * (1 + research_bonus) * surge_penalty`), matching Guide p. 6 formula and creator confirmation.
- **#2 Base lock during Manipulator upgrade**: Manipulator upgrade and Hive Destroyer charging share the single Base slot — starting a Manipulator upgrade blocks new Hive Destroyer charges and new Refinery builds until finished; if a Hive Destroyer charge is active, starting a Manipulator upgrade is blocked until the charge finishes.
- **#3 Rewind behavior (Creator Override of Guide pp. 5-6)**: Rewind affects only the enemy wave (clears active enemies/projectiles, restarts the current wave deterministically without re-paying the wave-clear bonus, and adds `+1 Armoured`). All player-side state — towers (including mid-wave builds/upgrades), refineries, constructions in progress, money, research, research tree, manipulator level, and player lives (lost lives remain lost) — stays as it currently is.
- **#4 Brute HP scaling**: Brutes scale from their Wave 8 debut (`220 * 1.12^(wave - 8)`), reaching ~486 HP by Wave 15 instead of debuting at 486 HP.
- **#5 Cooldowns, Surge timing & Wave 15 end**:
  - Time power cooldowns raised to ~1.5 waves (`Pause 55 s`, `Haste 50 s`, `Rewind 65 s` post-replay; Rewind is also locked during an active replay so nested rewinds cannot happen).
  - Surge window targets ~1.5 waves of pressure so ignoring time powers through Wave 2 triggers a Surge by the start of Wave 3 (verified during Step 5/balance pass).
  - If Wave 15 clears with lives > 0 and enemy base HP > 0, end the run in a `"Stalled"` debrief screen per Guide p. 11.
