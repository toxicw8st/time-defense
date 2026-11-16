extends Node
class_name EconomyManager

## Owns Refineries (build job + 5 s income ticks) and the 5-node Research Tree.

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
	step_economy(delta)


func step_economy(delta: float) -> void:
	if GameState.mission.is_over or not GameState.is_wave_active:
		return

	# Refinery income tick every 5.0 s of mission time
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
			GameState.event_logged.emit("Refinery #%d online (+%d/5s)" % [count, Balance.REFINERY_INCOME_PER_TICK])
			if map_ref != null:
				map_ref.queue_redraw()


func get_next_refinery_cost() -> int:
	var owned: int = GameState.mission.economy["refineries_owned"]
	var raw: float = Balance.REFINERY_BASE_COST * pow(Balance.REFINERY_COST_GROWTH, float(max(0, owned - 1)))
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
	if not GameState.spend_money(cost):
		return false
	refinery_job = ConstructionJob.new("refinery", Balance.REFINERY_BUILD_TIME)
	if map_ref != null:
		map_ref.queue_redraw()
	return true


func can_buy_research(node_key: String) -> bool:
	if GameState.mission.is_over:
		return false
	if not Balance.RESEARCH_NODES.has(node_key):
		return false
	if GameState.mission.owned_research.get(node_key, false):
		return false
	var cost: int = int(Balance.RESEARCH_NODES[node_key]["cost"])
	return GameState.mission.economy["research"] >= cost


func buy_research(node_key: String) -> bool:
	if not can_buy_research(node_key):
		return false
	var cost: int = int(Balance.RESEARCH_NODES[node_key]["cost"])
	if not GameState.spend_research(cost):
		return false
	GameState.mission.owned_research[node_key] = true
	GameState.economy_changed.emit()
	research_purchased.emit(node_key)
	GameState.event_logged.emit("Research unlocked: %s" % Balance.RESEARCH_NODES[node_key]["name"])
	return true
