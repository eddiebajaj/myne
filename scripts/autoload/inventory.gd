extends Node
## Grid-based backpack, bot roster, batteries, artifacts, mineral storage.
## Ore is both profit and bot material — the core tension.

signal inventory_changed
signal backpack_full
signal bots_changed

# --- Grid Backpack ---
# Each cell holds 1 ore piece. Ore with different minerals = different slots.
# Slots: [{ore: OreData, mineral: MineralData or null, quantity: int}]
var grid_width: int = 4
var grid_height: int = 4
var carried_ore: Array[Dictionary] = []

# --- Batteries (purchased in town, consumed when building bots) ---
var batteries: int = 0

# --- Bots alive this run ---
var follower_bots: Array[Dictionary] = []  # [{data: BotData, health: float, ore_tier: int, mineral: MineralData}]
var checkpoint_bots: Array[Dictionary] = []

# --- Artifacts (run-only buffs, cleared on return/death) ---
var artifacts: Array[Dictionary] = []  # [{data: ArtifactData}] or [{id: String, ...}]

# --- Persistent storage ---
var mineral_storage: Array[MineralData] = []  # Lab-extracted minerals
var blueprints: Array[String] = []            # Unlocked bot variant IDs

# --- Town upgrades ---
var upgrade_levels: Dictionary = {
	"pickaxe_tier": 1,       # 1-4
	"armor_value": 0.0,      # Flat armor points
	"grid_rows": 0,          # Extra rows added to backpack
}


# === Grid Capacity ===

func get_max_capacity() -> int:
	return grid_width * (grid_height + upgrade_levels.get("grid_rows", 0))


func get_used_slots() -> int:
	var total := 0
	for slot in carried_ore:
		total += slot.quantity
	return total


func get_remaining_slots() -> int:
	# Check for Deep Pockets artifact
	var bonus := 0
	if has_artifact("deep_pockets"):
		bonus += grid_width  # One extra row
	return get_max_capacity() + bonus - get_used_slots()


func is_full() -> bool:
	return get_remaining_slots() <= 0


# === Ore Operations ===

func _get_slot_key(ore: OreData, mineral: MineralData) -> String:
	## Stacking key: ore id + mineral id (plain ore and mineral ore don't stack).
	if mineral:
		return ore.id + ":" + mineral.id
	return ore.id


func can_add_ore(ore: OreData, mineral: MineralData = null, quantity: int = 1) -> bool:
	return get_remaining_slots() >= quantity


func add_ore(ore: OreData, mineral: MineralData = null, quantity: int = 1) -> bool:
	if not can_add_ore(ore, mineral, quantity):
		return false
	var key := _get_slot_key(ore, mineral)
	for slot in carried_ore:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			slot.quantity += quantity
			_check_full()
			inventory_changed.emit()
			return true
	carried_ore.append({"ore": ore, "mineral": mineral, "quantity": quantity})
	_check_full()
	inventory_changed.emit()
	return true


func spend_ore_specific(ore_id: String, mineral_id: String, count: int) -> bool:
	## Spend exactly [count] pieces of a specific ore+mineral combo.
	## Used for bot building (no mixing allowed).
	var key := ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for slot in carried_ore:
		var slot_key := _get_slot_key(slot.ore, slot.mineral)
		if slot_key == key and slot.quantity >= count:
			slot.quantity -= count
			if slot.quantity <= 0:
				carried_ore.erase(slot)
			inventory_changed.emit()
			return true
	return false


func drop_one(ore_id: String, mineral_id: String) -> bool:
	## Drops exactly one piece from the matching stack. Returns true on success.
	## If the stack quantity hits 0 the slot is removed from carried_ore.
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for slot in carried_ore:
		var slot_key: String = _get_slot_key(slot.ore, slot.mineral)
		if slot_key == key and int(slot.quantity) >= 1:
			slot.quantity -= 1
			if int(slot.quantity) <= 0:
				carried_ore.erase(slot)
			inventory_changed.emit()
			return true
	return false


func get_stack_quantity(ore_id: String, mineral_id: String) -> int:
	## Returns the current quantity for a given ore+mineral stack, or 0 if no such stack.
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for slot in carried_ore:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			return int(slot.quantity)
	return 0


func sell_all() -> int:
	var total_gold := 0
	for slot in carried_ore:
		var base_value: int = slot.ore.value
		var mineral_bonus: int = slot.mineral.sell_bonus if slot.mineral else 0
		total_gold += (base_value + mineral_bonus) * slot.quantity
	carried_ore.clear()
	GameManager.add_gold(total_gold)
	inventory_changed.emit()
	return total_gold


func get_total_items() -> int:
	return get_used_slots()


func count_plain_t1_ore() -> int:
	## Counts total pieces of plain (mineral == null) T1 ore across all stacks.
	var total: int = 0
	for slot in carried_ore:
		if slot.mineral == null and slot.ore.tier == 1:
			total += int(slot.quantity)
	return total


func craft_battery() -> bool:
	## Consumes 3 plain T1 ore (mixable across types) and adds 1 battery.
	## Prefers spending from smallest stacks first to consolidate inventory.
	## Returns false if player lacks 3 plain T1 ore.
	if count_plain_t1_ore() < 3:
		return false
	# Build list of plain T1 slots, sorted smallest-first
	var plain_slots: Array[Dictionary] = []
	for slot in carried_ore:
		if slot.mineral == null and slot.ore.tier == 1:
			plain_slots.append(slot)
	plain_slots.sort_custom(func(a, b): return int(a.quantity) < int(b.quantity))
	var remaining: int = 3
	for slot in plain_slots:
		if remaining <= 0:
			break
		var take: int = mini(int(slot.quantity), remaining)
		slot.quantity -= take
		remaining -= take
	# Remove any emptied slots
	var i: int = carried_ore.size() - 1
	while i >= 0:
		if int(carried_ore[i].quantity) <= 0:
			carried_ore.remove_at(i)
		i -= 1
	batteries += 1
	inventory_changed.emit()
	return true


func get_ore_stacks() -> Array[Dictionary]:
	## Returns all ore stacks for UI display.
	return carried_ore


# === Batteries ===

func add_batteries(count: int) -> void:
	batteries += count


func use_battery() -> bool:
	if batteries <= 0:
		return false
	# Check Emergency Battery artifact
	if has_artifact("emergency_battery"):
		# First bot per floor is free — handled by caller checking artifact
		pass
	batteries -= 1
	return true


# === Bots ===

func can_build_bot(bot: BotData, ore_id: String, mineral_id: String) -> bool:
	## Check if player has enough of the specific ore type + a battery.
	var key := ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for slot in carried_ore:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			if slot.quantity >= bot.ore_count:
				return batteries > 0
	return false


func build_bot(bot: BotData, ore_id: String, mineral_id: String) -> Dictionary:
	## Build a bot. Returns {ore_tier, mineral} for the spawned bot, or empty dict on failure.
	if not can_build_bot(bot, ore_id, mineral_id):
		return {}
	# Find the ore slot to determine tier and mineral
	var key := ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	var ore_tier := 1
	var mineral_mod: MineralData = null
	for slot in carried_ore:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			ore_tier = slot.ore.tier
			mineral_mod = slot.mineral
			break
	if not spend_ore_specific(ore_id, mineral_id, bot.ore_count):
		return {}
	if not use_battery():
		return {}  # Shouldn't happen if can_build_bot passed
	if bot.category == BotData.BotCategory.FOLLOWER:
		follower_bots.append({"data": bot, "health": bot.health, "ore_tier": ore_tier, "mineral": mineral_mod})
		bots_changed.emit()
	return {"ore_tier": ore_tier, "mineral": mineral_mod}


func save_checkpoint() -> void:
	checkpoint_bots = follower_bots.duplicate(true)


# === Artifacts ===

func add_artifact(artifact_id: String, data: Dictionary = {}) -> void:
	data["id"] = artifact_id
	artifacts.append(data)


func has_artifact(artifact_id: String) -> bool:
	for a in artifacts:
		if a.get("id", "") == artifact_id:
			return true
	return false


# === Mineral Storage (Lab) ===

func store_mineral(mineral: MineralData) -> void:
	mineral_storage.append(mineral)


func take_stored_mineral(mineral_id: String) -> MineralData:
	for i in range(mineral_storage.size()):
		if mineral_storage[i].id == mineral_id:
			return mineral_storage.pop_at(i)
	return null


# === Run Lifecycle ===

func begin_run() -> void:
	carried_ore.clear()
	follower_bots.clear()
	checkpoint_bots.clear()
	artifacts.clear()
	# Start each run with 3 batteries for testing
	batteries = 3
	inventory_changed.emit()
	bots_changed.emit()


func end_run(died: bool) -> void:
	if died:
		carried_ore.clear()
		follower_bots = checkpoint_bots.duplicate(true)
	# Artifacts always lost on return
	artifacts.clear()
	# Follower bots lost on return
	follower_bots.clear()
	checkpoint_bots.clear()
	inventory_changed.emit()
	bots_changed.emit()


# === Upgrades ===

func apply_upgrade(upgrade_id: String, value) -> void:
	upgrade_levels[upgrade_id] = value
	inventory_changed.emit()


func _check_full() -> void:
	if is_full():
		backpack_full.emit()
