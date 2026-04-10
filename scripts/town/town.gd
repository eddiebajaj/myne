extends Node2D
## Town hub — walkable JRPG-style space with NPC interaction zones.
## NPCs: Market (sell/buy), Smith (gear), Lab (minerals/bots).

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var mine_entrance: Area2D = $MineEntrance
@onready var stats_label: Label = $CanvasLayer/HUD/StatsLabel
@onready var checkpoint_selector: OptionButton = $CanvasLayer/HUD/CheckpointSelector
@onready var mine_button: Button = $CanvasLayer/HUD/MineButton
@onready var sell_button: Button = $CanvasLayer/HUD/SellButton
@onready var sell_result: Label = $CanvasLayer/HUD/SellResult

var mine_entrance_in_range: bool = false


func _ready() -> void:
	# Ensure game is not paused
	get_tree().paused = false
	player.add_to_group("player")
	player.position = Vector2(640, 500)
	mine_button.pressed.connect(_on_start_mining)
	sell_button.pressed.connect(_on_sell_ore)
	mine_entrance.body_entered.connect(func(body):
		if body is Player:
			mine_entrance_in_range = true
			mine_button.visible = true
			checkpoint_selector.visible = true
	)
	mine_entrance.body_exited.connect(func(body):
		if body is Player:
			mine_entrance_in_range = false
			mine_button.visible = false
			checkpoint_selector.visible = false
	)
	mine_button.visible = false
	checkpoint_selector.visible = false
	sell_result.visible = false
	_refresh_ui()


func _refresh_ui() -> void:
	var ore_count := Inventory.get_used_slots()
	stats_label.text = "Gold: %d | Ore: %d | Batteries: %d | Runs: %d | Deepest: B%dF" % [
		GameManager.gold, ore_count, Inventory.batteries, GameManager.total_runs, GameManager.deepest_checkpoint]
	checkpoint_selector.clear()
	checkpoint_selector.add_item("Start from B1F", 0)
	for cp in GameManager.get_unlocked_checkpoints():
		if cp > 0:
			checkpoint_selector.add_item("Warp to B%dF" % (cp + 1), cp)
	# Show sell button if player has ore
	sell_button.visible = ore_count > 0
	sell_button.text = "Sell All Ore (%d pieces)" % ore_count


func _process(_delta: float) -> void:
	# Refresh stats periodically (after NPC interactions)
	if Engine.get_physics_frames() % 30 == 0:
		_refresh_ui()


func _on_start_mining() -> void:
	var selected := checkpoint_selector.get_selected_id()
	GameManager.start_run(selected)


func _on_sell_ore() -> void:
	var earned := Inventory.sell_all()
	if earned > 0:
		sell_result.text = "Sold for %d gold!" % earned
		sell_result.visible = true
		var tween := create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(sell_result, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			sell_result.visible = false
			sell_result.modulate.a = 1.0
		)
	_refresh_ui()
