# TUNING.md

Record every change from the starter values on Implementation Guide pp. 4-5 as `old -> new` plus the playtest observation or creator rule that caused it.

## Pre-Run Test Overrides & Creator Adjustments
- `BASE_ATTACK_DAMAGE_PER_SHOT`: `500 (level-1 1/N)` -> `167 (level-3 override, 3 shots to win)` — Required by Implementation Guide p. 5 for the 15-wave prototype playtest.
- `PAUSE_COOLDOWN`: `30.0 s` -> `55.0 s` — Creator direction: cooldown should span ~1.5 waves so powers cannot be spammed every wave.
- `HASTE_COOLDOWN`: `25.0 s` -> `50.0 s` — Creator direction: cooldown should span ~1.5 waves so powers cannot be spammed every wave.
- `REWIND_COOLDOWN`: `60.0 s` -> `65.0 s` — Creator direction: ~1.5 waves cooldown after replay ends, preventing back-to-back wave rewinds.
