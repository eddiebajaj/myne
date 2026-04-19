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
# Sprint 7/8: multi-instance + mineral_profile + upgrade_level.
# [{id: "scout", instance_number: 1, display_name: "Scout #1",
#   base_max_health: 40.0, base_damage: 5.0,
#   max_health: 40.0, health: 40.0, damage: 5.0, cp_cost: 1,
#   upgrade_level: 0, knocked_out: false,
#   mineral_profile: {fire,ice,earth,thunder,venom,wind,void all int},
#   void_resolved: [String, ...]}]
# base_max_health / base_damage are the immutable per-bot-type starting stats
# set at build time. max_health / damage are the CURRENTLY-SCALED mirror values
# kept in sync by mining_floor_controller._spawn_permanent_bot for HUD/merge
# respawn. Stat scaling MUST read from base_* fields, never from the mutable
# mirror, to avoid compounding every floor entry.
# Legacy fields hp_upgrade_level / damage_upgrade_level (Sprint 5) are no longer
# written; ensure_bot_migration collapses them into upgrade_level on load.

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

# === Sprint 8 bot upgrade constants ===
# Index i holds the plain T1-equivalent ore-points cost to go from level i to i+1.
# Max upgrade level is 5 (index 4 is level 4 -> 5).
const UPGRADE_THRESHOLDS := [10, 15, 25, 40, 60]
const MAX_UPGRADE_LEVEL := 5


static func get_upgrade_threshold(current_level: int) -> int:
	## Returns the cost to go from [current_level] to [current_level + 1].
	## Returns -1 if current_level is invalid or already at max.
	if current_level < 0 or current_level >= UPGRADE_THRESHOLDS.size():
		return -1
	return UPGRADE_THRESHOLDS[current_level]


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
		"base_max_health": max_hp,
		"base_damage": damage,
		"max_health": max_hp,
		"health": max_hp,
		"damage": damage,
		"cp_cost": cp_cost,
		"upgrade_level": 0,
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
	if not entry.has("upgrade_level"):
		entry["upgrade_level"] = 0
	# Sprint 8: snapshot base stats if caller didn't provide them. These are the
	# immutable per-bot-type starting values used by all stat scaling.
	if not entry.has("base_max_health"):
		entry["base_max_health"] = float(entry.get("max_health", 40.0))
	if not entry.has("base_damage"):
		entry["base_damage"] = float(entry.get("damage", 0.0))
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
	## Backfills Sprint 7/8 fields on legacy permanent_bot entries (in-place).
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
	# Sprint 8: collapse legacy per-stat upgrade fields into a unified upgrade_level.
	# Rough approximation: most-upgraded stat wins.
	if not entry.has("upgrade_level"):
		var legacy_hp: int = int(entry.get("hp_upgrade_level", 0))
		var legacy_dmg: int = int(entry.get("damage_upgrade_level", 0))
		entry["upgrade_level"] = max(legacy_hp, legacy_dmg)
	# Sprint 8 (stat compounding fix): backfill immutable base stats from the
	# current mirror value. Legacy entries may have already-scaled max_health /
	# damage — treating those as base loses accumulated scaling drift, but
	# that's the safest assumption for saves written before this field existed.
	if not entry.has("base_max_health"):
		entry["base_max_health"] = float(entry.get("max_health", 40.0))
	if not entry.has("base_damage"):
		entry["base_damage"] = float(entry.get("damage", 0.0))
	var name_str: String = String(entry.get("display_name", ""))
	if name_str == "" or name_str.find("#") == -1:
		var base_name := type_display_name
		if base_name == "":
			base_name = name_str if name_str != "" else String(entry.get("id", "Bot")).capitalize()
		entry["display_name"] = "%s #%d" % [base_name, int(entry.get("instance_number", 1))]


func upgrade_permanent_bot(entry: Dictionary, added_minerals: Dictionary, added_void_resolved: Array) -> void:
	## Sprint 8: applies one upgrade tier to [entry] in-place.
	## - Increments upgrade_level by 1.
	## - Merges [added_minerals] into the bot's mineral_profile (per-key sum).
	## - Appends [added_void_resolved] entries to the bot's void_resolved list.
	## - Emits bots_changed.
	## NOTE: ore spending is the caller's responsibility (mirror add_permanent_bot).
	if entry == null:
		return
	entry["upgrade_level"] = int(entry.get("upgrade_level", 0)) + 1
	var profile: Dictionary = entry.get("mineral_profile", empty_mineral_profile())
	if added_minerals != null:
		for key in added_minerals.keys():
			var add_n: int = int(added_minerals[key])
			if add_n == 0:
				continue
			profile[key] = int(profile.get(key, 0)) + add_n
	entry["mineral_profile"] = profile
	var void_list: Array = entry.get("void_resolved", [])
	if added_void_resolved != null:
		for v in added_void_resolved:
			void_list.append(v)
	entry["void_resolved"] = void_list
	bots_changed.emit()


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


func deposit_one_to_storage(ore_id: String, mineral_id: String) -> bool:
	## Moves 1 piece from backpack to storage if storage has space. Symmetric
	## with withdraw_one_from_storage — per-row "A to deposit 1" UI (Sprint 8 B3).
	if get_storage_remaining() <= 0:
		return false
	var key: String = ore_id
	if mineral_id != "":
		key = ore_id + ":" + mineral_id
	for i in range(carried_ore.size()):
		var slot: Dictionary = carried_ore[i]
		if _get_slot_key(slot.ore, slot.mineral) == key and int(slot.quantity) >= 1:
			var added: int = _storage_add(slot.ore, slot.mineral, 1)
			if added <= 0:
				return false
			slot.quantity -= 1
			if int(slot.quantity) <= 0:
				carried_ore.remove_at(i)
			inventory_changed.emit()
			return true
	return false


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


func _synthesize_ore_for_id(ore_id: String) -> OreData:
	## Builds a minimal OreData resource for [ore_id]. Used when we need to
	## deposit ore pieces in town (e.g. Scrap refunds in Sprint 8 §A7) and
	## don't have a live OreData reference from the floor generator. Stacking
	## keys go by `ore.id`, so a fresh OreData with the correct id/tier/value
	## merges into existing stacks seamlessly.
	## Keep the tier / color / value fields in sync with floor_generator._create_ore_types.
	var ore := OreData.new()
	ore.id = ore_id
	match ore_id:
		"iron":     _set_ore_fields(ore, "Iron",     Color(0.7, 0.7, 0.75),  1, false, 2)
		"copper":   _set_ore_fields(ore, "Copper",   Color(0.8, 0.5, 0.2),   1, true,  3)
		"crystal":  _set_ore_fields(ore, "Crystal",  Color(0.6, 0.8, 0.9),   2, false, 6)
		"silver":   _set_ore_fields(ore, "Silver",   Color(0.85, 0.85, 0.9), 2, true,  8)
		"gold_ore": _set_ore_fields(ore, "Gold",     Color(1.0, 0.84, 0.0),  3, false, 15)
		"obsidian": _set_ore_fields(ore, "Obsidian", Color(0.15, 0.1, 0.2),  3, true,  20)
		"diamond":  _set_ore_fields(ore, "Diamond",  Color(0.6, 0.9, 1.0),   4, false, 35)
		"mythril":  _set_ore_fields(ore, "Mythril",  Color(0.5, 0.7, 1.0),   4, true,  50)
		_:          _set_ore_fields(ore, ore_id.capitalize(), Color.GRAY, 1, false, 1)
	return ore


func _set_ore_fields(ore: OreData, dname: String, color: Color, tier: int, specialist: bool, value: int) -> void:
	ore.display_name = dname
	ore.color = color
	ore.tier = tier
	ore.specialist = specialist
	ore.value = value


func _find_existing_ore_data(ore_id: String) -> OreData:
	## Returns a live OreData reference matching [ore_id] from any existing
	## stack in storage or carried_ore. Prefer this over _synthesize_ore_for_id
	## so we reuse the floor generator's canonical resource when available.
	for slot in storage:
		if slot.ore != null and slot.ore.id == ore_id:
			return slot.ore
	for slot in carried_ore:
		if slot.ore != null and slot.ore.id == ore_id:
			return slot.ore
	return null


func try_deposit_ore_combined(ore_id: String, mineral_id: String, count: int) -> int:
	## Deposits up to [count] pieces of [ore_id] (+ optional [mineral_id]) into
	## storage first, overflowing into the carried_ore backpack. Returns the
	## number of pieces actually placed (0..count). Does nothing if count <= 0.
	## Emits inventory_changed iff any pieces were placed.
	##
	## NOTE: mineral_id is currently only wired for ""; Scrap refunds don't
	## return mineral-ore pieces. The plumbing matches the backpack/storage
	## stack-key format so a future caller passing a real mineral works without
	## rework.
	if count <= 0:
		return 0
	var ore: OreData = _find_existing_ore_data(ore_id)
	if ore == null:
		ore = _synthesize_ore_for_id(ore_id)
	# mineral_id "" is the plain-ore case — the only path Scrap needs.
	var mineral: MineralData = null
	if mineral_id != "":
		# Look up an existing mineral ref from inventory so future callers can
		# return mineral-enhanced ore without code changes here.
		for slot in storage:
			if slot.mineral != null and slot.mineral.id == mineral_id:
				mineral = slot.mineral
				break
		if mineral == null:
			for slot in carried_ore:
				if slot.mineral != null and slot.mineral.id == mineral_id:
					mineral = slot.mineral
					break
		# If still null we silently drop the mineral affinity — Scrap doesn't
		# exercise this branch in Sprint 8.
	var placed: int = 0
	# Storage first (spec §A7).
	var to_storage: int = _storage_add(ore, mineral, count)
	placed += to_storage
	var remaining: int = count - to_storage
	# Overflow to backpack (respects capacity).
	if remaining > 0:
		var bp_space: int = get_remaining_slots()
		var to_bp: int = mini(remaining, bp_space)
		if to_bp > 0:
			# add_ore already emits inventory_changed; we still emit once below
			# if storage placed anything, so this may double-emit in rare cases.
			# Acceptable — inventory_changed is a broadcast, not a command.
			add_ore(ore, mineral, to_bp)
			placed += to_bp
	if placed > 0:
		inventory_changed.emit()
	return placed


func remove_permanent_bot(index: int) -> Dictionary:
	## Removes the bot at [index] from permanent_bots. Returns the removed
	## entry (empty dict if index is out of range). Also removes any matching
	## bot from run_party (match by id + instance_number). Emits bots_changed
	## iff a removal actually happened.
	if index < 0 or index >= permanent_bots.size():
		return {}
	var removed: Dictionary = permanent_bots[index]
	permanent_bots.remove_at(index)
	# Remove matching entries from run_party by id + instance_number.
	var rid: String = String(removed.get("id", ""))
	var rinst: int = int(removed.get("instance_number", -1))
	var i: int = run_party.size() - 1
	while i >= 0:
		var rp: Dictionary = run_party[i]
		if String(rp.get("id", "")) == rid and int(rp.get("instance_number", -1)) == rinst:
			run_party.remove_at(i)
		i -= 1
	bots_changed.emit()
	return removed


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
