extends Node
## Manages game state, floor progression, checkpoints, death, and scene transitions.

enum GameState { TOWN, MINING, TRANSITIONING }

signal state_changed(new_state: GameState)
signal floor_changed(floor_num: int)
signal checkpoint_reached(floor_num: int)
signal player_died

var current_state: GameState = GameState.TOWN
var current_floor: int = 1
var deepest_checkpoint: int = 0
var run_start_floor: int = 1
var gold: int = 0
var total_runs: int = 0

const CHECKPOINT_INTERVAL := 5
const MAX_FLOOR := 20


func _ready() -> void:
	state_changed.emit(current_state)


# === Tier System ===

func get_current_tier() -> int:
	## Floors 1-5=T1, 6-10=T2, 11-15=T3, 16-20=T4.
	return clampi(ceili(float(current_floor) / 5.0), 1, 4)


func is_checkpoint_floor(floor_num: int) -> bool:
	return floor_num > 0 and floor_num % CHECKPOINT_INTERVAL == 0


func get_unlocked_checkpoints() -> Array[int]:
	var checkpoints: Array[int] = [0]
	var f := CHECKPOINT_INTERVAL
	while f <= deepest_checkpoint:
		checkpoints.append(f)
		f += CHECKPOINT_INTERVAL
	return checkpoints


# === Run lifecycle ===

func start_run(from_checkpoint: int = 0) -> void:
	if current_state != GameState.TOWN:
		return
	current_state = GameState.TRANSITIONING
	total_runs += 1
	run_start_floor = from_checkpoint + 1 if from_checkpoint > 0 else 1
	current_floor = run_start_floor
	Inventory.begin_run()
	get_tree().change_scene_to_file("res://scenes/dungeon/mining_floor.tscn")
	current_state = GameState.MINING
	state_changed.emit(current_state)
	floor_changed.emit(current_floor)


func go_deeper() -> void:
	if current_state != GameState.MINING:
		return
	current_floor += 1
	if is_checkpoint_floor(current_floor):
		if current_floor > deepest_checkpoint:
			deepest_checkpoint = current_floor
		Inventory.save_checkpoint()
		checkpoint_reached.emit(current_floor)
	floor_changed.emit(current_floor)


func return_to_town() -> void:
	if current_state != GameState.MINING:
		return
	current_state = GameState.TRANSITIONING
	Inventory.end_run(false)
	get_tree().change_scene_to_file("res://scenes/town/town.tscn")
	current_state = GameState.TOWN
	state_changed.emit(current_state)


func die() -> void:
	if current_state != GameState.MINING:
		return
	current_state = GameState.TRANSITIONING
	player_died.emit()
	Inventory.end_run(true)
	get_tree().change_scene_to_file("res://scenes/town/town.tscn")
	current_state = GameState.TOWN
	state_changed.emit(current_state)


# === Gold ===

func add_gold(amount: int) -> void:
	gold += amount


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		return true
	return false


# === Floor generation helpers ===

func get_ore_density() -> float:
	return 1.0 + (current_floor - 1) * 0.05


func get_portal_chance() -> float:
	if current_floor < 3:
		return 0.0
	return clampf(0.3 + (current_floor - 3) * 0.05, 0.0, 0.8)


func get_cave_chance() -> float:
	if current_floor < 2:
		return 0.0
	return clampf(0.25 + (current_floor - 2) * 0.03, 0.0, 0.6)
