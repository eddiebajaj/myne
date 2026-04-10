extends Node2D
## Town hub — walkable JRPG-style space with NPC interaction zones.
## NPCs: Market (sell/buy), Smith (gear), Lab (minerals/bots).

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var mine_entrance: Area2D = $MineEntrance
@onready var stats_label: Label = $CanvasLayer/HUD/StatsLabel
@onready var checkpoint_selector: OptionButton = $CanvasLayer/HUD/CheckpointSelector
@onready var mine_button: Button = $CanvasLayer/HUD/MineButton

var mine_entrance_in_range: bool = false


func _ready() -> void:
	player.add_to_group("player")
	player.position = Vector2(400, 500)
	mine_button.pressed.connect(_on_start_mining)
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
	_refresh_ui()


func _refresh_ui() -> void:
	stats_label.text = "Gold: %d | Batteries: %d | Runs: %d | Deepest: B%dF" % [
		GameManager.gold, Inventory.batteries, GameManager.total_runs, GameManager.deepest_checkpoint]
	checkpoint_selector.clear()
	checkpoint_selector.add_item("Start from B1F", 0)
	for cp in GameManager.get_unlocked_checkpoints():
		if cp > 0:
			checkpoint_selector.add_item("Warp to B%dF" % (cp + 1), cp)


func _process(_delta: float) -> void:
	# Refresh stats periodically (after NPC interactions)
	if Engine.get_physics_frames() % 30 == 0:
		_refresh_ui()


func _on_start_mining() -> void:
	var selected := checkpoint_selector.get_selected_id()
	GameManager.start_run(selected)
