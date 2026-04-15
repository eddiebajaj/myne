extends Node
## Grid-based backpack, bot roster, artifacts, mineral storage.
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

# --- Bots alive this run (legacy disposable system, retained for artifact/save plumbing) ---
var follower_bots: Array[Dictionary] = []  # [{data: BotData, health: float, ore_tier: int, mineral: MineralData}]
var checkpoint_bots: Array[Dictionary] = []

# --- Artifacts (run-only buffs, cleared on return/death) ---
var artifacts: Array[Dictionary] = []  # [{data: ArtifactData}] or [{id: String, ...}]

# --- Permanent bots (persist across runs, never lost) ---
var permanent_bots: Array[Dictionary] = []
# Sprint 7: multi-instance + mineral_profile.
# [{id: "scout", instance_number: 1, display_name: "Scout #1",
#   max_health: 40.0, health: 40.0, damage: 5.0, cp_cost: 1,
#   hp_upgrade_level: 0, damage_upgrade_level: 0, knocked_out: false,
#   mineral_profile: {fire,ice,earth,thunder,venom,wind,void all int},
#   void_resolved: [String, ...]}]

# === Sprint 7 crafting constants ===
const ORE_POINTS_BY_TIER := {
	1: 1,
	2: 3,
	3: 9,
	4: 27,
}
const BOT_BUILD_THRESHOLD := 10
const MINERAL_KEYS := ["fire", "ice", "earth", "thunder", "venom", "wind", "void"]
const VOID_REAL_TYPES := ["fire", "ice", "earth", "thunder", "venom", "wind"]


static func empty_mineral_profile() -> Dictionary:
	return {"fire": 0, "ice": 0, "earth": 0, "thunder": 0, "venom": 0, "wind": 0, "void": 0}


static func format_mineral_suffix(profile: Dictionary, void_resolved: Array = []) -> String:
	## Spec §A10: compact display suffix for a bot, e.g. "(Fire+3, Earth+1)".
	## Void is shown as "Void+N" where N = void_resolved.size() (resolved count).
	## Returns "" if everything is zero/empty.
	if profile == null or profile.is_empty():
		return ""
	var parts: Array[String] = []
	for key in VOID_REAL_TYPES:
		var v: int = int(profile.get(key, 0))
		if v > 0:
			parts.append("%s+%d" % [key.capitalize(), v])
	var void_n: int = void_resolved.size() if void_resolved != null else 0
	if void_n > 0:
		parts.append("Void+%d" % void_n)
	if parts.is_empty():
		return ""
	return "(" + ", ".join(parts) + ")"

var run_party: Array[Dictionary] = []
# Subset of permanent_bots selected for this run (set by town mine entrance UI; fallback auto-populate)

# --- Crystal Power (permanent, upgraded at Lab) ---
var crystal_power_capacity: int = 1

# --- Merge charges (reset each run, max upgraded at Lab) ---
var merge_charges_max: int = 1
var merge_charges: int = 1

# --- Lab upgrade levels (used to compute scaling costs) ---
var necklace_upgrade_level: int = 0  # 0 = starter (cap 1). Max 4 (cap 5).
var merge_upgrade_level: int = 0     # 0 = starter (max 1). Max 3 (max 4).

# --- Persistent storage ---
var mineral_storage: Array[MineralData] = []  # Lab-extracted minerals
var blueprints: Array[String] = []            # Unlocked bot variant IDs

# --- Ore storage shed (persistent across runs) ---
const STORAGE_CAPACITY: int = 48
var storage: Array[Dictionary] = []  # Same format as carried_ore: [{ore, mineral, quantity}]

# --- Merge gating (unlocks on first B5F reach) ---
var merge_unlocked: bool = false

# --- Town upgrades ---
var upgrade_levels: Dictionary = {
	"pickaxe_tier": 1,       # 1-4
	"armor_value": 0.0,      # Flat armor points
	"grid_rows": 0,          # Extra rows added to backpack
}


# === Grid Capacity ===

func get_max_capacity() -> int:
	var base: int = grid_width * (grid_height + upgrade_levels.get("grid_rows", 0))
	# Backpack Bot passive: +8 slots while in run_party and alive
	for entry in run_party:
		if entry.get("id", "") == "backpack_bot" and not entry.get("knocked_out", false):
			base += 8
			break
	return base


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
	## Drops exactly one piece from the matching stack.
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


func spend_plain_t1_ore(amount: int) -> bool:
	## Consumes [amount] plain T1 ore across stacks (smallest-first). Returns false if insufficient.
	if count_plain_t1_ore() < amount:
		return false
	var plain_slots: Array[Dictionary] = []
	for slot in carried_ore:
		if slot.mineral == null and slot.ore.tier == 1:
			plain_slots.append(slot)
	plain_slots.sort_custom(func(a, b): return int(a.quantity) < int(b.quantity))
	var remaining: int = amount
	for slot in plain_slots:
		if remaining <= 0:
			break
		var take: int = mini(int(slot.quantity), remaining)
		slot.quantity -= take
		remaining -= take
	var i: int = carried_ore.size() - 1
	while i >= 0:
		if int(carried_ore[i].quantity) <= 0:
			carried_ore.remove_at(i)
		i -= 1
	inventory_changed.emit()
	return true


func get_ore_stacks() -> Array[Dictionary]:
	## Returns all ore stacks for UI display.
	return carried_ore


# === Merge charges ===

func use_merge_charge() -> bool:
	if merge_charges <= 0:
		return false
	merge_charges -= 1
	inventory_changed.emit()
	return true


# === Bots (legacy disposable build stub — retained so old code compiles) ===

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


# === Permanent Bots ===

func unlock_permanent_bot(id: String, display_name: String, max_hp: float, damage: float = 5.0, cp_cost: int = 1) -> void:
	## Sprint 7: multi-instance allowed. No "already owned" gate. Auto-numbers display name.
	var instance_number := count_permanent_bots_of_type(id) + 1
	var final_name := "%s #%d" % [display_name, instance_number]
	permanent_bots.append({
		"id": id,
		"instance_number": instance_number,
		"display_name": final_name,
		"max_health": max_hp,
		"health": max_hp,
		"damage": damage,
		"cp_cost": cp_cost,
		"hp_upgrade_level": 0,
		"damage_upgrade_level": 0,
		"knocked_out": false,
		"mineral_profile": empty_mineral_profile(),
		"void_resolved": [],
	})
	bots_changed.emit()


func add_permanent_bot(entry: Dictionary) -> void:
	## Sprint 7: append a fully-formed bot entry (used by Lab crafting).
	## Caller is responsible for id/stats; this fills in instance_number and emits.
	var id: String = entry.get("id", "bot")
	var instance_number := count_permanent_bots_of_type(id) + 1
	entry["instance_number"] = instance_number
	if not entry.has("mineral_profile"):
		entry["mineral_profile"] = empty_mineral_profile()
	if not entry.has("void_resolved"):
		entry["void_resolved"] = []
	if not entry.has("knocked_out"):
		entry["knocked_out"] = false
	if not entry.has("hp_upgrade_level"):
		entry["hp_upgrade_level"] = 0
	if not entry.has("damage_upgrade_level"):
		entry["damage_upgrade_level"] = 0
	permanent_bots.append(entry)
	bots_changed.emit()


func has_permanent_bot(id: String) -> bool:
	## Sprint 7: kept for legacy callers but no longer gates building.
	for bot in permanent_bots:
		if bot.get("id", "") == id:
			return true
	return false


func count_permanent_bots_of_type(id: String) -> int:
	var n := 0
	for bot in permanent_bots:
		if bot.get("id", "") == id:
			n += 1
	return n


func get_permanent_bot(id: String) -> Dictionary:
	## Returns the FIRST instance of [id]. Use sparingly post-Sprint 7 since multiple may exist.
	for bot in permanent_bots:
		if bot.get("id", "") == id:
			return bot
	return {}


func ensure_bot_migration(entry: Dictionary, type_display_name: String = "") -> void:
	## Backfills Sprint 7 fields on legacy permanent_bot entries (in-place).
	if not entry.has("mineral_profile"):
		entry["mineral_profile"] = empty_mineral_profile()
	else:
		var prof: Dictionary = entry["mineral_profile"]
		for k in MINERAL_KEYS:
			if not prof.has(k):
				prof[k] = 0
	if not entry.has("void_resolved"):
		entry["void_resolved"] = []
	if not entry.has("instance_number"):
		entry["instance_number"] = 1
	var name_str: String = String(entry.get("display_name", ""))
	if name_str == "" or name_str.find("#") == -1:
		var base_name := type_display_name
		if base_name == "":
			base_name = name_str if name_str != "" else String(entry.get("id", "Bot")).capitalize()
		entry["display_name"] = "%s #%d" % [base_name, int(entry.get("instance_number", 1))]


func knock_out_bot(id: String) -> void:
	for entry in run_party:
		if entry.get("id", "") == id:
			entry["knocked_out"] = true
			entry["health"] = 0.0
			break


func restore_permanent_bots() -> void:
	## Called on return to town. Resets HP and knocked_out for all permanent bots.
	for bot in permanent_bots:
		bot["health"] = bot.get("max_health", 40.0)
		bot["knocked_out"] = false


func _populate_run_party() -> void:
	## Fallback: auto-populate from permanent_bots within CP budget. Only used
	## if the town UI didn't set run_party explicitly before begin_run().
	run_party.clear()
	var cp_used := 0
	for bot in permanent_bots:
		if bot.get("knocked_out", false):
			continue
		var cost: int = int(bot.get("cp_cost", 1))
		if cp_used + cost > crystal_power_capacity:
			continue
		run_party.append(bot.duplicate(true))
		cp_used += cost


# === Run Lifecycle ===

func begin_run() -> void:
	carried_ore.clear()
	follower_bots.clear()
	checkpoint_bots.clear()
	artifacts.clear()
	# Reset merge charges for the new run
	merge_charges = merge_charges_max
	# If town UI didn't set run_party, fall back to auto-populate
	if run_party.is_empty():
		_populate_run_party()
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
	# Permanent bots restored on return to town
	run_party.clear()
	restore_permanent_bots()
	inventory_changed.emit()
	bots_changed.emit()


# === Upgrades ===

func apply_upgrade(upgrade_id: String, value) -> void:
	upgrade_levels[upgrade_id] = value
	inventory_changed.emit()


func _check_full() -> void:
	if is_full():
		backpack_full.emit()


# === Storage Shed ===

func get_storage_used() -> int:
	var total: int = 0
	for slot in storage:
		total += int(slot.get("quantity", 0))
	return total


func get_storage_remaining() -> int:
	return STORAGE_CAPACITY - get_storage_used()


func _storage_add(ore: OreData, mineral: MineralData, quantity: int) -> int:
	## Adds up to [quantity] pieces to storage, respecting capacity. Returns count added.
	var can_add: int = mini(quantity, get_storage_remaining())
	if can_add <= 0:
		return 0
	var key: String = _get_slot_key(ore, mineral)
	for slot in storage:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			slot.quantity += can_add
			return can_add
	storage.append({"ore": ore, "mineral": mineral, "quantity": can_add})
	return can_add


func deposit_all_to_storage() -> int:
	## Moves everything from backpack to storage (within capacity).
	## Returns number of pieces moved.
	var moved: int = 0
	var i: int = 0
	while i < carried_ore.size():
		var slot: Dictionary = carried_ore[i]
		var qty: int = int(slot.quantity)
		var added: int = _storage_add(slot.ore, slot.mineral, qty)
		moved += added
		slot.quantity -= added
		if int(slot.quantity) <= 0:
			carried_ore.remove_at(i)
		else:
			i += 1
		if get_storage_remaining() <= 0:
			break
	if moved > 0:
		inventory_changed.emit()
	return moved


func withdraw_one_from_storage(ore_id: String, mineral_id: String) -> bool:
	## Moves 1 piece from storage to backpack if backpack has space.
	if get_remaining_slots() <= 0:
		return false
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for i in range(storage.size()):
		var slot: Dictionary = storage[i]
		if _get_slot_key(slot.ore, slot.mineral) == key and int(slot.quantity) >= 1:
			if not add_ore(slot.ore, slot.mineral, 1):
				return false
			slot.quantity -= 1
			if int(slot.quantity) <= 0:
				storage.remove_at(i)
			inventory_changed.emit()
			return true
	return false


func get_storage_stacks() -> Array[Dictionary]:
	return storage


func count_ore_combined(ore_id: String, mineral_id: String) -> int:
	## Total count of a specific ore+mineral across storage + backpack.
	var total: int = 0
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for slot in storage:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			total += int(slot.quantity)
	for slot in carried_ore:
		if _get_slot_key(slot.ore, slot.mineral) == key:
			total += int(slot.quantity)
	return total


func spend_ore_combined(ore_id: String, mineral_id: String, amount: int) -> bool:
	## Spend [amount] of a specific ore+mineral, storage first then backpack.
	if count_ore_combined(ore_id, mineral_id) < amount:
		return false
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	var remaining: int = amount
	# Storage first.
	var i: int = 0
	while i < storage.size() and remaining > 0:
		var slot: Dictionary = storage[i]
		if _get_slot_key(slot.ore, slot.mineral) == key:
			var take: int = mini(int(slot.quantity), remaining)
			slot.quantity -= take
			remaining -= take
			if int(slot.quantity) <= 0:
				storage.remove_at(i)
				continue
		i += 1
	# Then backpack.
	i = 0
	while i < carried_ore.size() and remaining > 0:
		var slot: Dictionary = carried_ore[i]
		if _get_slot_key(slot.ore, slot.mineral) == key:
			var take: int = mini(int(slot.quantity), remaining)
			slot.quantity -= take
			remaining -= take
			if int(slot.quantity) <= 0:
				carried_ore.remove_at(i)
				continue
		i += 1
	inventory_changed.emit()
	return remaining == 0


func count_plain_t1_ore_combined() -> int:
	## Backpack + storage total of plain T1 ore.
	var total: int = count_plain_t1_ore()
	for slot in storage:
		if slot.mineral == null and slot.ore.tier == 1:
			total += int(slot.quantity)
	return total


func spend_plain_t1_ore_from_any(amount: int) -> bool:
	## Spends plain T1 ore from storage first, then backpack.
	if count_plain_t1_ore_combined() < amount:
		return false
	var remaining: int = amount
	# Spend from storage first (smallest stacks first, for consistency).
	var storage_plain: Array[Dictionary] = []
	for slot in storage:
		if slot.mineral == null and slot.ore.tier == 1:
			storage_plain.append(slot)
	storage_plain.sort_custom(func(a, b): return int(a.quantity) < int(b.quantity))
	for slot in storage_plain:
		if remaining <= 0:
			break
		var take: int = mini(int(slot.quantity), remaining)
		slot.quantity -= take
		remaining -= take
	var i: int = storage.size() - 1
	while i >= 0:
		if int(storage[i].quantity) <= 0:
			storage.remove_at(i)
		i -= 1
	# Then backpack for any leftover.
	if remaining > 0:
		if not spend_plain_t1_ore(remaining):
			return false
	inventory_changed.emit()
	return true
