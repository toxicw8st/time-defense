extends Node

## Headless Step 7 acceptance verification (v3.0 Chrono-Citadel Ascension "Sun God" + Wave 40 Milestone -> Endless Freeplay):
## - Stage 1 ($1,500): Point-Defense Pulse Cannons fire & restore +3 Lives
## - Stage 2 ($6,500 + Opt-In Tower Sacrifices): Absorbs ONLY chosen towers, grafts Super-Weapons, grants +15% Global Speed & Global Camo Reveal (Energy)
## - Stage 3 ($18,000): ★ True Chrono-Singularity ("Time God") — +30% Global Speed, Hyper-Apex Grafts, 10s Singularity Pulse (<15% Boss Execute!)
## - Clearing Wave 40 awards Sector Milestone Victory & unlocks Endless Freeplay + persists Best Wave; Restart cleans mission while keeping Meta-Research

func _ready() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var ba: BaseAttackManager = inst.get_node("BaseAttackManager")
	var hud: CanvasLayer = inst.get_node("HUD")

	# 1) Starting $200 cannot afford Stage 1 ($1,500)
	assert(not ba.can_ascend_citadel())

	# 2) Stage 1: Fortified Citadel ($1,500) restores +3 lives & fires Point-Defense Cannons!
	GameState.mission.lives = 14
	GameState.mission.economy["money"] = 30000
	assert(ba.ascend_citadel())
	assert(GameState.mission.citadel_stage == 1 and GameState.mission.lives == 17, "Stage 1 must heal +3 lives (14 -> 17)")
	GameState.is_wave_active = true
	var near_e: EnemyUnit = map.spawn_enemy("brute", 5)
	near_e.distance_along_path = maxf(0.0, map.get_path_length() - 90.0)
	near_e._sync_transform_to_path()
	var hp_b1: float = near_e.hp
	ba.step_base_attack(0.6)
	assert(near_e.hp < hp_b1 and GameState.mission.citadel_total_damage > 0.0, "Stage 1 Point-Defense Cannons must damage enemies near Citadel")
	map.clear_all_enemies()

	# 3) Stage 2: Chrono-Dreadnought ($6,500) + Opt-In Sun-God Tower Sacrifices (keeps unchosen towers safe!)
	var t_keep: TowerUnit = map.build_tower_on_pad(0, "blaster")
	t_keep.current_job = null; t_keep.is_built = true
	var t_sac_laser: TowerUnit = map.build_tower_on_pad(1, "laser")
	t_sac_laser.current_job = null; t_sac_laser.is_built = true; t_sac_laser.total_spent = 1350
	var t_sac_kin: TowerUnit = map.build_tower_on_pad(2, "annihilator")
	t_sac_kin.current_job = null; t_sac_kin.is_built = true; t_sac_kin.total_spent = 1400
	var prev_sac: Dictionary = ba.preview_sacrifice_unlocks([t_sac_laser, t_sac_kin], false)
	assert(bool(prev_sac["unlocked"]["energy"]) and bool(prev_sac["unlocked"]["kinetic"]) and not bool(prev_sac["unlocked"]["explosive"]))
	assert(ba.ascend_citadel([t_sac_laser, t_sac_kin], false))
	assert(GameState.mission.citadel_stage == 2)
	assert(is_instance_valid(t_keep) and map.get_all_towers().has(t_keep), "Unchosen towers MUST NOT be sacrificed!")
	assert(not map.get_all_towers().has(t_sac_laser) and not map.get_all_towers().has(t_sac_kin), "Chosen sacrifice towers must be absorbed!")
	assert(int(GameState.mission.citadel_sacrifices["energy"]) == 1 and int(GameState.mission.citadel_sacrifices["kinetic"]) == 1)
	assert(GameState.has_global_camo_reveal() and t_keep.can_detect_cloaked(), "Energy sacrifice must grant GLOBAL Camo Reveal to all towers!")
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.15), "Stage 2 Citadel must grant +15%% global tower attack speed!")

	# 4) Stage 3: ★ True Chrono-Singularity ("Time God", $18,000) — +30% Global Speed, Hyper-Apex Grafts, <15% Boss Execute Pulse!
	assert(ba.ascend_citadel([], false))
	assert(GameState.mission.citadel_stage == 3 and GameState.mission.lives == 20)
	assert(int(GameState.mission.citadel_sacrifices["energy"]) == 2 and int(GameState.mission.citadel_sacrifices["kinetic"]) == 2, "Stage 3 must promote grafted weapons to Hyper-Apex (Lv2)")
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 1.30), "Stage 3 Citadel must grant +30%% global tower attack speed!")
	var low_boss: EnemyUnit = map.spawn_enemy("juggernaut", 30)
	low_boss.hp = low_boss.max_hp * 0.12 # <15% HP execute threshold!
	ba.pulse_cooldown = 0.05
	ba.step_base_attack(0.1)
	assert(low_boss.is_dead_or_leaked, "Stage 3 Singularity Pulse must EXECUTE bosses below 15%% HP!")
	map.clear_all_enemies()

	# 5) Clearing Wave 40 awards Sector Milestone Victory & unlocks Endless Freeplay + persists Best Wave!
	GameState.mission.wave_number = WavesData.MISSION_TARGET_WAVE
	wm._complete_current_wave()
	assert(GameState.mission.is_over and GameState.mission.outcome == "won", "Clearing Wave 40 must award Sector Milestone Victory!")
	assert(GameState.get_level_best_wave(GameState.selected_map_level) >= 40)
	assert(hud.end_overlay.visible and hud.end_endless_button.visible)
	GameState.continue_into_endless()
	assert(not GameState.mission.is_over and GameState.is_endless_mode and GameState.mission.wave_number == 41)

	# 6) Restart resets mission cleanly while preserving persistent meta_research & Best Wave!
	GameState.add_research(40, false)
	var expected_res: int = GameState.meta_research
	hud._on_restart_pressed()
	var m := GameState.mission
	assert(not m.is_over and m.wave_number == 1 and m.lives == 20 and m.citadel_stage == 0)
	assert(GameState.meta_research == expected_res and GameState.get_level_best_wave(1) >= 40)

	GameState.reset_meta_progression()
	print("STEP7_TEST_PASS citadel_s1_s2_s3=ok sacrifices=ok milestone_w40_endless=ok restart_clean=true")
	get_tree().quit(0)
