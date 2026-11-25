extends Node
class_name EconomyManager

## Owns Refineries ($250 * 1.8^owned exponential ramp, $0.25/sec = +$1 per 4s tick)
## and Rogue-Like Meta-Research (spent ONLY on the Between-Levels / Level Picker screen, persists across missions).

signal refinery_built(total_owned: int)
signal refinery_ticked(total_income: int)
signal research_purchased(node_key: String)

var map_ref: GameMap = null
var refinery_job: ConstructionJob = null
var _tick_accum: float = 0.0


func setup(p_map: GameMap) -> void:
	map_ref = p_map
	if not GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.connect(_on_mission_reset)
	_reset_state()


func _exit_tree() -> void:
	if GameState.mission_reset.is_connected(_on_mission_reset):
		GameState.mission_reset.disconnect(_on_mission_reset)


func _on_mission_reset() -> void:
	_reset_state()


func _reset_state() -> void:
	refinery_job = null
	_tick_accum = 0.0


func _process(delta: float) -> void:
	step_economy(GameState.get_sim_delta(delta))


func step_economy(delta: float) -> void:
	if GameState.mission.is_over or not GameState.is_wave_active or delta <= 0.0:
		return

	# Refinery income tick every 4.0 s of active wave time ($1 per 4.0s = $0.25/sec per refinery)
	_tick_accum += delta
	while _tick_accum >= Balance.REFINERY_TICK_INTERVAL:
		_tick_accum -= Balance.REFINERY_TICK_INTERVAL
		var owned: int = GameState.mission.economy["refineries_owned"]
		if owned > 0:
			var income: int = owned * Balance.REFINERY_INCOME_PER_TICK
			GameState.add_money(income, true)
			refinery_ticked.emit(income)
			if map_ref != null:
				map_ref.show_refinery_tick_floaters(owned)

	# Active refinery construction job (accelerated by Haste)
	if refinery_job != null:
		var done: bool = refinery_job.advance(delta, GameState.get_construction_speed_multiplier())
		if done:
			refinery_job = null
			GameState.mission.economy["refineries_owned"] += 1
			var count: int = GameState.mission.economy["refineries_owned"]
			GameState.economy_changed.emit()
			refinery_built.emit(count)
			GameState.event_logged.emit("Refinery #%d online (+$%.2f/s)" % [count, Balance.REFINERY_RATE_PER_SEC])
			if map_ref != null:
				map_ref.queue_redraw()


## Exponential cost ramp: $250 * 1.8^(owned) rounded to nearest $5 -> $250, $450, $810, $1,460, $2,625
func get_next_refinery_cost() -> int:
	var owned: int = maxi(0, int(GameState.mission.economy["refineries_owned"]))
	var raw: float = Balance.REFINERY_BASE_COST * pow(Balance.REFINERY_COST_GROWTH, float(owned))
	var step: float = float(Balance.REFINERY_COST_ROUND_TO)
	return int(round(raw / step)) * Balance.REFINERY_COST_ROUND_TO


func can_build_refinery() -> bool:
	if GameState.mission.is_over or refinery_job != null:
		return false
	if GameState.is_base_locked():
		return false
	return GameState.mission.economy["money"] >= get_next_refinery_cost()


func start_build_refinery() -> bool:
	if not can_build_refinery():
		return false
	var cost: int = get_next_refinery_cost()
	if not GameState.spend_money(cost, true):
		return false
	refinery_job = ConstructionJob.new("refinery", Balance.REFINERY_BUILD_TIME)
	if AnalyticsManager != null:
		AnalyticsManager.record_refinery_started(cost, int(GameState.mission.economy["refineries_owned"]) + 1)
	if map_ref != null:
		map_ref.queue_redraw()
	return true


## Research cannot be bought mid-mission (during waves or after Wave 1 has started).
## It can ONLY be bought on the Between-Levels / Level Picker screen (`from_between_levels = true` or before Wave 1 starts).
func can_buy_research(node_key: String, from_between_levels: bool = false) -> bool:
	if not Balance.RESEARCH_NODES.has(node_key):
		return false
	if not from_between_levels:
		if GameState.is_wave_active or GameState.mission.wave_number > 1 or GameState.mission_elapsed_seconds > 0.0:
			return false
	var cost: int = GameState.get_next_research_cost(node_key)
	if cost < 0:
		return false
	return GameState.meta_research >= cost


func buy_research(node_key: String, from_between_levels: bool = false) -> bool:
	if not can_buy_research(node_key, from_between_levels):
		return false
	var cost: int = GameState.get_next_research_cost(node_key)
	if not GameState.spend_research(cost):
		return false
	var new_rank: int = GameState.get_research_rank(node_key) + 1
	GameState.meta_research_ranks[node_key] = new_rank
	GameState._sync_mission_research_mirror()
	GameState.save_meta_progress()
	GameState.economy_changed.emit()
	research_purchased.emit(node_key)
	if AnalyticsManager != null:
		AnalyticsManager.record_research_bought(node_key, new_rank, cost)
	GameState.event_logged.emit("Meta-Research %s Rank %d unlocked (%d R)" % [
		Balance.RESEARCH_NODES[node_key]["name"],
		new_rank,
		cost,
	])
	return true
