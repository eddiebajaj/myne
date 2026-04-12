class_name BotPlacer
extends Node2D
## Two-step bot building: pick bot type → pick ore stack → place.
## Costs: X ore of single type + 1 battery.
##
## Placement mode: ghost bot locks in front of player (based on facing direction).
## Player walks to desired position, then presses Mine/Space to confirm.
## This avoids tap-to-place conflicts with mobile touch controls.

signal bot_built(bot_data: BotData, ore_tier: int, mineral: MineralData)
signal build_cancelled
signal placement_started(bot_data: BotData)

const GHOST_OFFSET := 50.0  # Distance in front of player for ghost preview

var bot_defs: Array[BotData] = []
var selected_bot: BotData = null
var selected_ore_id: String = ""
var selected_mineral_id: String = ""
var placing: bool = false
var ghost: ColorRect = null
var emergency_battery_used_this_floor: bool = false
var _player: Player = null


func _ready() -> void:
	_create_bot_defs()
	GameManager.floor_changed.connect(func(_f): emergency_battery_used_this_floor = false)
	# Connect touch signals for reliable mobile input (signals fire synchronously,
	# no frame-timing issues with synthetic Input.action_press).
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)


func _on_touch_a() -> void:
	if _player:
		_player.show_pickup_popup("[A] placing=%s bot=%s" % [placing, selected_bot != null])
	if not placing or _player == null:
		return
	var target_pos: Vector2 = _player.global_position + _player.facing_dir * GHOST_OFFSET
	_confirm_placement(target_pos)


func _on_touch_b() -> void:
	if placing:
		_cancel_placement()


func _process(_delta: float) -> void:
	if not placing or ghost == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	if _player == null:
		return
	# Ghost follows in front of the player based on facing direction
	var target_pos: Vector2 = _player.global_position + _player.facing_dir * GHOST_OFFSET
	ghost.global_position = target_pos - ghost.size / 2
	# Keyboard/controller: confirm with Space/Enter, cancel with Esc/B key
	if Input.is_action_just_pressed("action_a") or Input.is_action_just_pressed("mine"):
		_confirm_placement(target_pos)
	if Input.is_action_just_pressed("action_b"):
		_cancel_placement()


func select_bot_and_ore(bot_data: BotData, ore_id: String, mineral_id: String) -> void:
	## Called by UI after player picks bot type + ore stack.
	selected_bot = bot_data
	selected_ore_id = ore_id
	selected_mineral_id = mineral_id
	placing = true
	_player = get_tree().get_first_node_in_group("player") as Player
	if _player:
		_player.set_meta("bot_placing", true)
	ghost = ColorRect.new()
	ghost.size = Vector2(24, 24)
	ghost.color = Color(bot_data.color, 0.5)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ghost)
	placement_started.emit(bot_data)


func _confirm_placement(world_pos: Vector2) -> void:
	if _player:
		var can_build = Inventory.can_build_bot(selected_bot, selected_ore_id, selected_mineral_id) if selected_bot else false
		_player.show_pickup_popup("CONFIRM bot=%s can_build=%s bat=%d" % [selected_bot != null, can_build, Inventory.batteries])
	if selected_bot == null:
		return
	# Check Emergency Battery artifact
	var use_free_battery := false
	if Inventory.has_artifact("emergency_battery") and not emergency_battery_used_this_floor:
		use_free_battery = true
	if not use_free_battery and not Inventory.can_build_bot(selected_bot, selected_ore_id, selected_mineral_id):
		_cancel_placement()
		return
	# Build
	var result: Dictionary
	if use_free_battery:
		# Spend ore but not battery
		if not Inventory.spend_ore_specific(selected_ore_id, selected_mineral_id, selected_bot.ore_count):
			_cancel_placement()
			return
		# Determine tier/mineral from ore
		result = {"ore_tier": 1, "mineral": null}
		for slot in Inventory.get_ore_stacks():
			var key: String = slot.ore.id
			if slot.mineral:
				key += ":" + slot.mineral.id
			if key == selected_ore_id + (":" + selected_mineral_id if selected_mineral_id != "" else ""):
				result.ore_tier = slot.ore.tier
				result.mineral = slot.mineral
				break
		emergency_battery_used_this_floor = true
	else:
		result = Inventory.build_bot(selected_bot, selected_ore_id, selected_mineral_id)
	if result.is_empty():
		_cancel_placement()
		return
	_spawn_bot(selected_bot, world_pos, result.ore_tier, result.mineral)
	bot_built.emit(selected_bot, result.ore_tier, result.mineral)
	_cleanup_ghost()


func _cancel_placement() -> void:
	_cleanup_ghost()
	build_cancelled.emit()


func _cleanup_ghost() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	placing = false
	selected_bot = null
	selected_ore_id = ""
	selected_mineral_id = ""
	if _player:
		_player.set_meta("bot_placing", false)


func _spawn_bot(bot_data: BotData, pos: Vector2, tier: int, mineral_mod: MineralData) -> void:
	var bot_scene := _build_bot_scene(bot_data)
	var bot: CharacterBody2D = bot_scene.instantiate()
	bot.global_position = pos
	bot.setup_with_tier(bot_data, tier, mineral_mod)
	bot.add_to_group("bots")
	get_parent().add_child(bot)


func _build_bot_scene(bot_data: BotData) -> PackedScene:
	var scene := PackedScene.new()
	var script_path: String
	match bot_data.id:
		"turret": script_path = "res://scripts/bots/turret.gd"
		"mining_rig": script_path = "res://scripts/bots/mining_rig.gd"
		"combat_drone": script_path = "res://scripts/bots/combat_drone.gd"
		"mining_drone": script_path = "res://scripts/bots/mining_drone.gd"
		_: script_path = "res://scripts/bots/bot_base.gd"
	var root := CharacterBody2D.new()
	root.name = bot_data.display_name.replace(" ", "")
	root.set_script(load(script_path))
	root.collision_layer = 8
	root.collision_mask = 20
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(20, 20)
	rect.position = Vector2(-10, -10)
	rect.color = bot_data.color
	root.add_child(rect); rect.owner = root
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	col.shape = shape
	root.add_child(col); col.owner = root
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	bar.size = Vector2(20, 4)
	bar.position = Vector2(-10, -16)
	bar.show_percentage = false
	root.add_child(bar); bar.owner = root
	scene.pack(root)
	return scene


func get_bot_defs() -> Array[BotData]:
	return bot_defs


func _create_bot_defs() -> void:
	# Values from 13_balance_t1.md section 9
	bot_defs.append(_make_bot("turret", "Turret", "Static, shoots enemies", Color(0.9, 0.7, 0.2),
		BotData.BotCategory.STATIC, BotData.BotRole.DEFENSE, 3, 30.0, 6.0, 150.0, 1.0, 0.0))
	bot_defs.append(_make_bot("mining_rig", "Mining Rig", "Static, auto-mines ore", Color(0.9, 0.6, 0.1),
		BotData.BotCategory.STATIC, BotData.BotRole.MINING, 4, 20.0, 0.0, 80.0, 1.0, 0.0))
	bot_defs.append(_make_bot("combat_drone", "Combat Drone", "Follows you, fights", Color(0.8, 0.2, 0.2),
		BotData.BotCategory.FOLLOWER, BotData.BotRole.DEFENSE, 8, 50.0, 8.0, 120.0, 1.0, 100.0))
	bot_defs.append(_make_bot("mining_drone", "Mining Drone", "Follows you, mines", Color(0.2, 0.8, 0.5),
		BotData.BotCategory.FOLLOWER, BotData.BotRole.MINING, 6, 35.0, 3.0, 100.0, 0.5, 90.0))


func _make_bot(id: String, dname: String, desc: String, color: Color, cat: BotData.BotCategory, role: BotData.BotRole,
		ore_count: int, hp: float, dmg: float, range_: float, aspd: float, mspd: float) -> BotData:
	var b := BotData.new()
	b.id = id; b.display_name = dname; b.description = desc; b.color = color
	b.category = cat; b.role = role; b.ore_count = ore_count
	b.base_health = hp; b.base_damage = dmg; b.base_range = range_
	b.base_attack_speed = aspd; b.move_speed = mspd
	return b
