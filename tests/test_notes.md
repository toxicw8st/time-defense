# Prototype Acceptance & Overhaul Self-Test Notes

## Overhaul Verification Suite (`tests/test_step8.tscn` -> `ALL_OVERHAUL_SELF_TESTS_PASSED`)
- [x] **(a) 2 towers alone do NOT clear 5 waves**: Verified (`CHECK_A_PASS two_towers_alone_lost_on_wave=5`; 2 starting towers clear Wave 1 with 0 leaks at ratio `1.02`, leak on Waves 2–4, and lose all 20 lives before Wave 5 completes).
- [x] **(b) 4th refinery is NOT affordable before Wave 5**: Verified (`CHECK_B_PASS max_refineries_before_wave_5=1`; exponential costs `$250, $450, $810, $1,460` require `$2,970` cumulative vs `~$745` max total economy in Waves 1–4).
- [x] **(c) Research is NOT buyable in-game & NOT maxable in 1 mission**: Verified (`CHECK_C_PASS in_game_research_blocked=true mission_cap=60 rank_costs=[100, 250, 600, 1400, 3200]`; `ResearchBox` removed from `RightPanel`, moved to `BetweenLevelsOverlay`, persists across `reset_mission()`, and capped at `60 R` per mission with `0.25x` replay diminishing return).
- [x] **(d) Enemy Base HUD & Multi-Wave Charge Cost**: Verified (`CHECK_D_PASS`; TopBar always displays `Enemy Base: 500 / 500 HP | Charge: 0% | Cost: $450 | Dmg: 167/shot | Charges needed: 3`, and `$450` cost takes multiple waves of income).
- [x] **(e) Wave Length (`180s + 10s/wave`), Speed Toggle (`1x/2x/3x` + Pause), and Tight Wave 10**: Verified (`CHECK_E_PASS w1_len=180s speed_toggle=1x_2x_3x_pause w10_no_power_survived=false w10_with_power_survived=true(lives=15)`).
- [x] **(f) `DPS needed` & Algorithmic Wave Table (Waves 1–10 + Wave 45 `s$393`)**: Verified (`CHECK_F_PASS dps_needed_w1_10=[27, 37, 46, 60, 104, 138, 121, 137, 179, 544] w10_ratio_no_farm=0.79 w10_ratio_farm=1.04 w45_s=393`).

## Regression Suite (`test_step0.tscn` through `test_step8.tscn`)
- [x] `tests/test_step0.tscn` -> `STEP0_TEST_PASS`
- [x] `tests/test_step1.tscn` -> `STEP1_TEST_PASS path_len=1891.1 leaks=20`
- [x] `tests/test_step2.tscn` -> `STEP2_TEST_PASS waves_1_to_3_money=510 w45_s=393`
- [x] `tests/test_step3.tscn` -> `STEP3_TEST_PASS w1_kills=20 damage_matrix=ok`
- [x] `tests/test_step4.tscn` -> `STEP4_TEST_PASS refinery_ramp=[250,450,810,1460,2625] meta_research=ok`
- [x] `tests/test_step5.tscn` -> `STEP5_TEST_PASS surges=[1, 2, 3] warnings=[1, 2, 1, 2, 1, 2, 2, 2]`
- [x] `tests/test_step6.tscn` -> `STEP6_TEST_PASS manip_lvl=2 arm=1 thaw=1 swift=1 hp_mult=1.38`
- [x] `tests/test_step7.tscn` -> `STEP7_TEST_PASS charges_fired=3 1_over_N=ok restart_clean=true`
- [x] `tests/test_step8.tscn` -> `ALL_OVERHAUL_SELF_TESTS_PASSED (a=ok b=ok c=ok d=ok e=ok f=ok)`

## Mobile + Desktop Verification
- [x] `tests/test_step8.tscn` (headless & windowed OpenGL 3.3 Compatibility): verified TopBar `Menu`, `Dbg`, and `Full` buttons fit cleanly inside `1280 px`, toggle Pause/Debug overlays without a keyboard, disabled-button tap via `InputEventScreenTouch` displays info in `HoverInfoPanel` without mouse hover, and `34 px` pad touch hitbox selects Pad P1 at `+24 px` offset (`ALL_TESTS_ZERO_ERRORS`).
