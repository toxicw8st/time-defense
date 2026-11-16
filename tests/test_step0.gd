extends Node


func _ready() -> void:
	assert(Balance.VIEWPORT_WIDTH == 1280)
	assert(Balance.VIEWPORT_HEIGHT == 720)
	assert(Balance.PLAYER_STARTING_LIVES == 20)
	assert(Balance.STARTING_MONEY == 200)
	assert(Balance.TOWERS.has("blaster") and Balance.TOWERS.has("mortar"))
	assert(Balance.ENEMIES.has("runner") and Balance.ENEMIES.has("brute"))
	assert(Balance.RESEARCH_NODES.size() == 5)
	assert(Balance.TIME_POWERS.size() == 3)
	assert(Balance.MANIPULATOR_UPGRADES.size() == 4)
	assert(Balance.SURGE_BASE_WINDOW == 45.0)
	assert(Balance.ENEMY_BASE_MAX_HP == 500)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "main.tscn must load")
	var main_inst: Node = main_scene.instantiate()
	add_child(main_inst)

	var hud := main_inst.get_node("HUD")
	var debug_panel := hud.get_node("DebugPanel")
	var initial_vis: bool = debug_panel.visible
	var ev := InputEventKey.new()
	ev.keycode = KEY_F1
	ev.pressed = true
	hud._input(ev)
	assert(debug_panel.visible != initial_vis, "F1 must toggle debug panel")
	hud._input(ev)
	assert(debug_panel.visible == initial_vis, "Second F1 must restore debug panel")

	print("STEP0_TEST_PASS")
	get_tree().quit(0)
