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

## Step 2 — Waves as Data
- [x] Waves 1-15 encoded as pure data in `data/waves.gd`
- [x] Waves 1-3 play end-to-end (`tests/test_step2.tscn` -> `STEP2_TEST_PASS`)
- [x] Pre-wave preview shows `"No mutations"` on Wave 1
- [x] Wave bonus (`25 + 2 * wave`) is paid exactly once per wave number (verified no double-pay on replay)
- [x] Editing wave count in `data/waves.gd` changes spawned schedule with zero code edits

## Step 3 — Towers and Combat
- [x] Blaster alone holds Wave 1 with 0 leaks (`tests/test_step3.tscn` -> `STEP3_TEST_PASS w4_blaster_leaks=9 w4_mortar_leaks=3`)
- [x] Mortar visibly outperforms Blaster on bunched Wave 4; respects 60 px min range; splash evaluates positions at landing
- [x] Tower under construction or upgrade never fires (`scaffold + progress ring + seconds` visual)
- [x] Sell refunds exact `floor(50% of total_spent)` (`75->37`, `125->62`) and frees the pad
- [x] Kill earnings (`+money`, `+research`) appear as floating text and update economy totals

## Step 4 — Economy, Refineries and Research Tree
- [x] Refinery prices follow curve: `100, 135, 180, 245, 330` (`tests/test_step4.tscn` -> `STEP4_TEST_PASS no_ref_w5=596 ref_w5=736 w6_leaks=0`)
- [x] Buying Rapid Cycling raises fire rate on F1 debug overlay (`1.00x -> 1.05x`)
- [x] Currency separation enforced: Research cannot buy towers; Money cannot buy research
- [x] No-refinery (`596`) vs refinery-first (`736`) reach Wave 5 with visibly different money totals
- [x] First Balance Sanity Check (Waves 1-6, no powers): Waves 1-2 clean (0 leaks), Wave 6 held cleanly (`0` leaks with reasonable build)

## Step 5 — Surge (Isolated)
- [x] Ignoring surge bar fires surges at 45 s intervals with stacking penalties (`95%`, `90%`, `86%`)
- [x] Warning states fire at 15 s (amber) and 7 s (red pulse) before every surge
- [x] Test button resets surge timer and prevents surge
- [x] Surge pauses during `BUILD` phase and while Manipulator upgrades; resets cleanly on new mission (`tests/test_step5.tscn` -> `STEP5_TEST_PASS`)

## Step 6 — Time Powers, Mutation and Manipulator
- [x] All 3 powers start ready on Wave 1; cooldowns span ~1.5 waves (`Rewind 65s`, `Pause 55s`, `Haste 50s`)
- [x] Pause freezes alien movement while towers keep firing; Thaw-hardened x3 reduces frozen damage by 30% (floor 50%)
- [x] Haste 3x finishes a 7 s Mortar in ~2.33 s and adds Swift x1
- [x] Creator-confirmed Rewind restarts current enemy wave, keeps mid-wave towers/money/research/lost lives/surges, adds Armoured x1, locks nested Rewind, and starts 65 s cooldown after replay ends
- [x] Manipulator upgrade disables all 3 powers (`OFFLINE`), locks Refineries, and pauses Surge for exact build duration (`tests/test_step6.tscn` -> `STEP6_TEST_PASS`)
