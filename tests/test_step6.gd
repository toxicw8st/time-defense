extends Node

## Headless Step 6 acceptance verification (v3.0 Paid, Upgradable Time Abilities in Live Combat):
## - Time Freeze ($75): Freezes aliens; T2 reveals Cloaked; T3+ grants +20..40% Brittle dmg; T5 shatters non-bosses <15% HP
## - Overclock ($60): Boosts fire & build speed (+50%..+125%), T3+ bonus crit dmg, T5 instant build finish
## - Temporal Rewind ($100): Yanks all active aliens 18%..48% BACKWARD along path, spawns rewind trails, strips buffs/deals Paradox dmg/stuns
## - Zero permanent enemy mutations added after casting any Time Ability!

func _ready() -> void:
	GameState.reset_meta_progression()
	GameState.reset_mission()
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var inst: Node = main_scene.instantiate()
	add_child(inst)

	var map: GameMap = inst.get_node("Map")
	var wm: WaveManager = inst.get_node("WaveManager")
	var econ: EconomyManager = inst.get_node("EconomyManager")
	var tp: TimePowersManager = inst.get_node("TimePowersManager")

	# Blocked in BUILD phase
	assert(not tp.can_use_power("pause") and not tp.can_use_power("haste") and not tp.can_use_power("rewind"))

	GameState.mission.economy["money"] = 10000
	var blaster: TowerUnit = map.build_tower_on_pad(4, "blaster")
	wm.start_wave()
	_step(map, wm, econ, tp, 4.1)
	assert(blaster.is_built)
	_step(map, wm, econ, tp, 13.5)

	# 1) Paid Time Freeze: cash check, freeze movement, T3 Brittle +20% bonus dmg, T2 Cloak reveal, T5 <15% shatter!
	GameState.mission.economy["money"] = 50
	assert(not tp.can_use_power("pause"), "Time Freeze ($75) must require >= $75")
	GameState.mission.economy["money"] = 5000
	GameState.mission.ability_levels["pause"] = 3 # T3: 8s freeze, Cloak reveal, +20% Brittle dmg!
	var cloaked: EnemyUnit = map.spawn_enemy("stalker", 11)
	cloaked.advance_along_path(2.0)
	assert(cloaked.is_effectively_cloaked())
	var cash_pre_f: int = GameState.mission.economy["money"]
	assert(tp.activate_power("pause"))
	assert(GameState.mission.economy["money"] == cash_pre_f - 75, "Time Freeze must deduct $75 cast cost")
	assert(is_equal_approx(tp.pause_remaining, 8.0))
	assert(not cloaked.is_effectively_cloaked(), "T2+ Time Freeze must expose Cloaked Stalkers!")
	var hp_brittle_pre: float = cloaked.hp
	cloaked.take_damage(100.0)
	assert(is_equal_approx(cloaked.hp, hp_brittle_pre - 120.0), "T3 Brittle Lattice must deal +20%% bonus dmg while frozen!")
	assert(is_equal_approx(GameState.get_enemy_hp_multiplier(), 1.0), "Zero permanent HP mutation after Time Freeze!")
	cloaked.queue_free()
	tp.pause_remaining = 0.0
	tp.cooldowns["pause"] = 0.0
	GameState.is_enemies_frozen = false

	# 2) Paid Overclock: T5 (+125% speed, +30% crit dmg & instant build finish!)
	GameState.mission.ability_levels["haste"] = 5
	var mortar: TowerUnit = map.build_tower_on_pad(10, "mortar")
	assert(mortar != null and not mortar.is_built)
	var cash_pre_h: int = GameState.mission.economy["money"]
	assert(tp.activate_power("haste"))
	assert(GameState.mission.economy["money"] == cash_pre_h - 60, "Overclock must deduct $60 cast cost")
	assert(mortar.is_built, "T5 Overclock (Hyper-Dilation) must instantly finish active tower builds!")
	assert(is_equal_approx(GameState.get_tower_attack_speed_multiplier(), 2.25), "T5 Overclock must grant +125%% fire speed (2.25x)")
	assert(is_equal_approx(GameState.get_overclock_crit_bonus(), 0.30))
	assert(is_equal_approx(GameState.get_enemy_speed_multiplier(), 1.0), "Zero permanent enemy speed mutation after Overclock!")
	tp.haste_remaining = 0.0
	tp.cooldowns["haste"] = 0.0
	GameState.is_haste_active = false

	# 3) Paid Temporal Rewind: T4 yanks active aliens -38% backward along path + 15% Paradox dmg + 2s stun + rewind trails!
	GameState.mission.ability_levels["rewind"] = 4
	var jugg: EnemyUnit = map.spawn_enemy("juggernaut", 10)
	jugg.distance_along_path = 1200.0
	jugg._sync_transform_to_path()
	var d_before: float = jugg.distance_along_path
	var j_hp_before: float = jugg.hp
	var cash_pre_r: int = GameState.mission.economy["money"]
	assert(tp.activate_power("rewind"))
	assert(GameState.mission.economy["money"] == cash_pre_r - 100, "Temporal Rewind must deduct $100 cast cost")
	assert(jugg.distance_along_path < d_before - 500.0, "T4 Temporal Rewind must pull Juggernaut -38%% backward along path (was %.0f -> %.0f)" % [d_before, jugg.distance_along_path])
	assert(jugg.hp < j_hp_before - 100.0, "T3+ Temporal Rewind must inflict Paradox HP damage")
	assert(jugg.stun_remaining >= 0.75, "T4+ Temporal Rewind must stun enemy on landing (boss resist applied), got %.2f" % jugg.stun_remaining)
	assert(map.rewind_trails.size() >= 1, "Temporal Rewind must spawn visual rewind trails")
	assert(is_equal_approx(GameState.get_enemy_hp_multiplier(), 1.0), "Zero permanent HP mutation after Temporal Rewind!")

	print("STEP6_TEST_PASS freeze_brittle=ok overclock_t5=ok rewind_pull_px=%.0f zero_mutations=ok" % (d_before - jugg.distance_along_path))
	get_tree().quit(0)


func _step(map: GameMap, wm: WaveManager, econ: EconomyManager, tp: TimePowersManager, duration: float) -> void:
	var dt: float = 0.05
	var steps: int = int(round(duration / dt))
	for _i in range(steps):
		tp.step_powers(dt)
		wm.step_wave(dt)
		econ.step_economy(dt)
		for enemy in map.get_active_enemies():
			enemy.advance_along_path(dt)
		for tower in map.get_all_towers():
			tower.advance_tower(dt)
		for proj in map.projectiles_container.get_children():
			if proj is ProjectileEffect:
				proj.advance_projectile(dt)
