extends Node
## Manages game state, floor progression, checkpoints, death, and scene transitions.

enum GameState { TOWN, MINING, TRANSITIONING }

signal state_changed(new_state: GameState)
signal floor_changed(floor_num: int)
signal checkpoint_reached(floor_num: int)
signal player_died
signal gold_changed(new_gold: int)

var current_state: GameState = GameState.TOWN
var current_floor: int = 1
var deepest_checkpoint: int = 0
var run_start_floor: int = 1
var gold: int = 0
var total_runs: int = 0

# --- Run-persistent player vitals ---
# These survive scene reloads (e.g. descending stairs rebuilds mining_floor.tscn).
# Player._ready() reads from these; take_damage() writes back.
const DEFAULT_MAX_HEALTH := 12.0
var run_health: float = DEFAULT_MAX_HEALTH
var run_max_health: float = DEFAULT_MAX_HEALTH
var run_armor: float = 0.0
var run_max_armor: float = 0.0

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
	# Checkpoint warp restarts AT the checkpoint floor (B5, B10, ...), not the one after.
	run_start_floor = from_checkpoint if from_checkpoint > 0 else 1
	current_floor = run_start_floor
	Inventory.begin_run()
	_reset_run_vitals()
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
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
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


# === Run vitals ===

func _reset_run_vitals() -> void:
	## Called at the start of every run. Pulls max_armor from the Smith upgrade.
	run_max_health = DEFAULT_MAX_HEALTH
	run_health = run_max_health
	var upgraded_armor: float = float(Inventory.upgrade_levels.get("armor_value", 0.0))
	run_max_armor = upgraded_armor
	run_armor = run_max_armor


func set_run_max_armor(value: float) -> void:
	## Used by cave equipment loot that bumps the armor cap mid-run.
	run_max_armor = maxf(run_max_armor, value)
	run_armor = run_max_armor
