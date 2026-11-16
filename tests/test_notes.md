# Prototype Acceptance Test Notes

## Step 0 — Project Skeleton
- [x] Game launches to an empty 1280x720 scene (GL Compatibility, `canvas_items` / `expand`)
- [x] F1 toggles debug overlay (`tests/test_step0.tscn` -> `STEP0_TEST_PASS`)
- [x] All Implementation Guide pp. 4-5 values exist in `data/balance.gd`
- [x] First git commit made (`eec7782`)

## Step 1 — Map, Path and Alien Movement
- [x] S-path `Path2D` (`path_len=1891.1 px`), 14 non-overlapping build pads (>=37 px clear of path), Refinery Annex, Hive & Base markers (`tests/test_step1.tscn` -> `STEP1_TEST_PASS`)
- [x] 20 Runners spawn and all leak in order (IDs 1..20)
- [x] Lives go 20 -> 0 and Lose screen shows
- [x] No alien leaves the path; speed in px/s matches `50.0` balance value on F1 overlay
 (`Step 0: project skeleton + balance data + F1 debug overlay`)
