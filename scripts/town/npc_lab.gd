class_name NPCLab
extends Area2D
## Lab Researcher NPC — bot build hub (Sprint 5 rework).
##
## Menu layout:
##   - Main: Build Bot / Upgrade Bots / Upgrade Necklace / Upgrade Merge / Close
##   - Sub-menus rebuild into the same Services VBox; a "Back" button returns
##     to the main menu.

enum LabView { MAIN, BUILD_BOT, BOT_CRAFT, UPGRADE_BOTS, UPGRADE_NECKLACE, UPGRADE_MERGE }

# --- Bot build costs (Sprint 5 Round 2: uniform 10 ore, no gold) ---
const BOT_BUILD_ORE_COST := 10
const BOT_BUILD_GOLD_COST := 0

# Starter bots — always available (no blueprint required).
const STARTER_BOTS: Array[String] = ["miner", "striker", "backpack_bot"]

# Build stats per bot id. Keep in sync with mining_floor_controller._spawn_permanent_bot.
const BOT_BUILD_SPECS: Dictionary = {
	"miner":        {"display_name": "Miner",        "hp": 20.0, "damage": 0.0, "cp_cost": 1,
	                "desc": "Auto-mines ore. 20 HP, 0 DMG."},
	"striker":      {"display_name": "Striker",      "hp": 25.0, "damage": 8.0, "cp_cost": 1,
	                "desc": "Melee glass cannon. 25 HP, 8 DMG."},
	"backpack_bot": {"display_name": "Backpack Bot", "hp": 15.0, "damage": 0.0, "cp_cost": 1,
	                "desc": "+8 backpack slots. 15 HP, 0 DMG."},
	"scout":        {"display_name": "Scout",        "hp": 40.0, "damage": 5.0, "cp_cost": 1,
	                "desc": "Ranged combat support. 40 HP, 5 DMG."},
}

# --- Bot upgrade scaling ---
const BOT_UPGRADE_BASE_ORE := 15
const BOT_UPGRADE_BASE_GOLD := 150
const BOT_UPGRADE_COST_MULT := 1.5
const BOT_UPGRADE_MAX_LEVEL := 5
const HP_PER_LEVEL := 10.0
const DAMAGE_PER_LEVEL := 1.0

# --- Necklace (Crystal Power) scaling ---
const NECKLACE_BASE_ORE := 50
const NECKLACE_BASE_GOLD := 500
const NECKLACE_COST_MULT := 2.0
const NECKLACE_MAX_LEVEL := 4  # 0..4 → capacity 1..5

# --- Merge charges scaling ---
const MERGE_BASE_ORE := 50
const MERGE_BASE_GOLD := 500
const MERGE_COST_MULT := 2.0
const MERGE_MAX_LEVEL := 3     # 0..3 → max charges 1..4

var player_in_range: bool = false
var menu_open: bool = false
var _touch_b_handled_frame: int = -1
var _view: LabView = LabView.MAIN

# --- Bot crafting state (Sprint 7 recipe-grid UI) ---
# _craft_bot_id: which bot type is being crafted in BOT_CRAFT view.
# _build_slot: {ore_key (String) : {ore: OreData, mineral: MineralData, count: int}}
var _craft_bot_id: String = ""
var _build_slot: Dictionary = {}

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
@onready var menu_panel: PanelContainer = $CanvasLayer/MenuPanel
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var services_container: VBoxContainer = $CanvasLayer/MenuPanel/VBox/Services
@onready var storage_label: Label = $CanvasLayer/MenuPanel/VBox/StorageLabel
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.color = Color(0.3, 0.4, 0.8)
	label.text = "Lab [E]"
	label.visible = false
	menu_panel.visible = false
	var menu_layer: CanvasLayer = $CanvasLayer
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close_menu)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)


func _on_touch_a() -> void:
	if player_in_range and not menu_open:
		_open_menu()


func _on_touch_b() -> void:
	if menu_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		# Back out of sub-menu first, else close entirely.
		if _view == LabView.BOT_CRAFT:
			_show_view(LabView.BUILD_BOT)
		elif _view != LabView.MAIN:
			_show_view(LabView.MAIN)
		else:
			_close_menu()


func _process(_delta: float) -> void:
	if menu_open and Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame == Engine.get_process_frames():
			return
		if _view == LabView.BOT_CRAFT:
			_show_view(LabView.BUILD_BOT)
		elif _view != LabView.MAIN:
			_show_view(LabView.MAIN)
		else:
			_close_menu()
		return
	if player_in_range and not menu_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	get_tree().paused = true
	_show_view(LabView.MAIN)


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	get_tree().paused = false


# ── View dispatch ───────────────────────────────────────────────────

func _show_view(view: LabView) -> void:
	_view = view
	_refresh_common()
	for child in services_container.get_children():
		child.queue_free()
	match view:
		LabView.MAIN: _build_main_view()
		LabView.BUILD_BOT: _build_build_bot_view()
		LabView.BOT_CRAFT: _build_bot_craft_view()
		LabView.UPGRADE_BOTS: _build_upgrade_bots_view()
		LabView.UPGRADE_NECKLACE: _build_upgrade_necklace_view()
		LabView.UPGRADE_MERGE: _build_upgrade_merge_view()
	_wire_focus_wrap()
	_focus_first_button()


func _wire_focus_wrap() -> void:
	var focusables: Array = FocusUtil.collect_focusables(services_container)
	focusables.append(close_button)
	FocusUtil.wire_vertical_wrap(focusables)


func _refresh_common() -> void:
	gold_label.text = "Gold: %d   |   CP capacity: %d   |   Merge max: %d" % [
		GameManager.gold, Inventory.crystal_power_capacity, Inventory.merge_charges_max,
	]
	if Inventory.mineral_storage.is_empty():
		storage_label.text = "Stored Minerals: none"
	else:
		var counts: Dictionary = {}
		for m in Inventory.mineral_storage:
			counts[m.display_name] = counts.get(m.display_name, 0) + 1
		var parts: Array[String] = []
		for nm in counts:
			parts.append("%s x%d" % [nm, counts[nm]])
		storage_label.text = "Stored Minerals: " + ", ".join(parts)


func _focus_first_button() -> void:
	for child in services_container.get_children():
		if child is Button and not child.disabled:
			child.call_deferred("grab_focus")
			return
	close_button.call_deferred("grab_focus")


# ── Main view ───────────────────────────────────────────────────────

func _build_main_view() -> void:
	_add_header("— LAB —")

	var build_btn: Button = Button.new()
	build_btn.text = "Build Bot"
	build_btn.pressed.connect(func(): _show_view(LabView.BUILD_BOT))
	services_container.add_child(build_btn)

	# Sprint 6: Upgrade Bots view parked pending Sprint 8 rework.
	# Keep button visible-but-disabled so players see the feature exists.
	# LabView.UPGRADE_BOTS enum + _build_upgrade_bots_view() retained for reference.
	var upgrade_bots_btn: Button = Button.new()
	upgrade_bots_btn.text = "Upgrade Bots (Coming Soon)"
	upgrade_bots_btn.disabled = true
	upgrade_bots_btn.pressed.connect(func(): _show_view(LabView.UPGRADE_BOTS))
	services_container.add_child(upgrade_bots_btn)

	var necklace_btn: Button = Button.new()
	necklace_btn.text = "Upgrade Necklace (Crystal Power)"
	necklace_btn.pressed.connect(func(): _show_view(LabView.UPGRADE_NECKLACE))
	services_container.add_child(necklace_btn)

	var merge_btn: Button = Button.new()
	merge_btn.text = "Upgrade Merge Charges"
	merge_btn.pressed.connect(func(): _show_view(LabView.UPGRADE_MERGE))
	services_container.add_child(merge_btn)


# ── Build Bot view (list of bot types) ──────────────────────────────

func _build_build_bot_view() -> void:
	_add_header("— BUILD BOT —")

	var hint: Label = Label.new()
	hint.text = "Multi-instance allowed — build as many as you have ore for."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	services_container.add_child(hint)

	# All bot ids: starters + any blueprints. Greyed-out owned logic removed.
	var available: Array[String] = []
	for id in STARTER_BOTS:
		available.append(id)
	if "scout" in Inventory.blueprints and not ("scout" in available):
		available.append("scout")

	for id in available:
		var spec: Dictionary = BOT_BUILD_SPECS.get(id, {})
		if spec.is_empty():
			continue
		var dname: String = spec.get("display_name", id.capitalize())
		var hp: float = float(spec.get("hp", 40.0))
		var dmg: float = float(spec.get("damage", 0.0))
		var cp_cost: int = int(spec.get("cp_cost", 1))
		var owned: int = Inventory.count_permanent_bots_of_type(id)
		var row_btn: Button = Button.new()
		var owned_suffix: String = ("   [owned: %d]" % owned) if owned > 0 else ""
		row_btn.text = "%s — %d HP / %d DMG / CP %d%s" % [dname, int(hp), int(dmg), cp_cost, owned_suffix]
		var id_cap: String = id
		row_btn.pressed.connect(func(): _open_bot_craft(id_cap))
		services_container.add_child(row_btn)

	_add_back_button()


func _open_bot_craft(id: String) -> void:
	_craft_bot_id = id
	_build_slot.clear()
	_show_view(LabView.BOT_CRAFT)


# ── Bot Craft view (recipe grid) ────────────────────────────────────

func _build_bot_craft_view() -> void:
	var spec: Dictionary = BOT_BUILD_SPECS.get(_craft_bot_id, {})
	var dname: String = spec.get("display_name", _craft_bot_id.capitalize())
	_add_header("— CRAFT: %s —" % dname.to_upper())

	# Header: base stats
	var stats_lbl: Label = Label.new()
	stats_lbl.text = "Base: %d HP  |  %d DMG  |  CP %d" % [
		int(float(spec.get("hp", 40.0))),
		int(float(spec.get("damage", 0.0))),
		int(spec.get("cp_cost", 1)),
	]
	services_container.add_child(stats_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = spec.get("desc", "")
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	services_container.add_child(desc_lbl)

	# Two columns
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	services_container.add_child(columns)

	# LEFT: Inventory
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var left_hdr: Label = Label.new()
	left_hdr.text = "Inventory (A = add 1)"
	left.add_child(left_hdr)

	var inv_stacks: Array = _collect_inventory_stacks()
	if inv_stacks.is_empty():
		var empty: Label = Label.new()
		empty.text = "  (no ore)"
		left.add_child(empty)
	for stack in inv_stacks:
		var inv_ore: OreData = stack.ore
		var inv_mineral: MineralData = stack.mineral
		var inv_key: String = _ore_key(inv_ore, inv_mineral)
		var available_count: int = int(stack.quantity) - _build_slot_count_for(inv_key)
		var pts_inv: int = _points_for_tier(int(inv_ore.tier))
		var row_btn: Button = Button.new()
		row_btn.text = "%s  x%d  (+%d pts each)" % [_ore_label(inv_ore, inv_mineral), available_count, pts_inv]
		row_btn.disabled = available_count <= 0
		var ore_cap: OreData = inv_ore
		var min_cap: MineralData = inv_mineral
		row_btn.pressed.connect(func(): _craft_add_one(ore_cap, min_cap))
		left.add_child(row_btn)

	# RIGHT: Build Slot
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var right_hdr: Label = Label.new()
	right_hdr.text = "Build Slot (A = remove 1)"
	right.add_child(right_hdr)

	if _build_slot.is_empty():
		var empty2: Label = Label.new()
		empty2.text = "  (empty)"
		right.add_child(empty2)
	for slot_key in _build_slot.keys():
		var entry: Dictionary = _build_slot[slot_key]
		var slot_ore: OreData = entry.ore
		var slot_mineral: MineralData = entry.mineral
		var slot_count: int = int(entry.count)
		var pts_slot: int = _points_for_tier(int(slot_ore.tier))
		var rm_btn: Button = Button.new()
		rm_btn.text = "%s  x%d  (%d pts)" % [_ore_label(slot_ore, slot_mineral), slot_count, pts_slot * slot_count]
		var key_cap: String = slot_key
		rm_btn.pressed.connect(func(): _craft_remove_one(key_cap))
		right.add_child(rm_btn)

	# Totals + bonus preview
	var total_pts: int = _build_slot_total_points()
	var total_lbl: Label = Label.new()
	total_lbl.text = "Points: %d / %d" % [total_pts, Inventory.BOT_BUILD_THRESHOLD]
	if total_pts >= Inventory.BOT_BUILD_THRESHOLD:
		total_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	services_container.add_child(total_lbl)

	var bonus_lbl: Label = Label.new()
	bonus_lbl.text = "Bonuses: " + _bonus_preview_text()
	services_container.add_child(bonus_lbl)

	# Action buttons
	var auto_btn: Button = Button.new()
	auto_btn.text = "Auto-assign"
	auto_btn.pressed.connect(_craft_auto_assign)
	services_container.add_child(auto_btn)

	var build_btn: Button = Button.new()
	build_btn.text = "Build %s" % dname
	build_btn.disabled = total_pts < Inventory.BOT_BUILD_THRESHOLD
	build_btn.pressed.connect(_craft_build)
	services_container.add_child(build_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "← Cancel"
	cancel_btn.pressed.connect(_on_craft_cancel)
	services_container.add_child(cancel_btn)


func _on_craft_cancel() -> void:
	_build_slot.clear()
	_show_view(LabView.BUILD_BOT)


# ── Craft helpers ────────────────────────────────────────────────────

func _ore_key(ore: OreData, mineral: MineralData) -> String:
	if mineral:
		return ore.id + ":" + mineral.id
	return ore.id


func _ore_label(ore: OreData, mineral: MineralData) -> String:
	var base: String = ore.display_name if ore.display_name != "" else ore.id
	if mineral:
		return "%s (%s)" % [base, mineral.display_name]
	return base


func _points_for_tier(tier: int) -> int:
	return int(Inventory.ORE_POINTS_BY_TIER.get(tier, 1))


func _collect_inventory_stacks() -> Array:
	## Returns merged list of {ore, mineral, quantity} combining backpack + storage.
	var merged: Dictionary = {}
	var sources: Array = [Inventory.carried_ore, Inventory.storage]
	for src in sources:
		for slot in src:
			var key: String = _ore_key(slot.ore, slot.mineral)
			if merged.has(key):
				merged[key].quantity = int(merged[key].quantity) + int(slot.quantity)
			else:
				merged[key] = {"ore": slot.ore, "mineral": slot.mineral, "quantity": int(slot.quantity)}
	var out: Array = []
	for k in merged.keys():
		out.append(merged[k])
	return out


func _build_slot_count_for(ore_key: String) -> int:
	if _build_slot.has(ore_key):
		return int(_build_slot[ore_key].count)
	return 0


func _build_slot_total_points() -> int:
	var total: int = 0
	for k in _build_slot.keys():
		var entry: Dictionary = _build_slot[k]
		total += _points_for_tier(int(entry.ore.tier)) * int(entry.count)
	return total


func _craft_add_one(ore: OreData, mineral: MineralData) -> void:
	var key: String = _ore_key(ore, mineral)
	var available: int = Inventory.count_ore_combined(ore.id, mineral.id if mineral else "")
	if _build_slot_count_for(key) >= available:
		return
	if _build_slot.has(key):
		_build_slot[key].count = int(_build_slot[key].count) + 1
	else:
		_build_slot[key] = {"ore": ore, "mineral": mineral, "count": 1}
	_show_view(LabView.BOT_CRAFT)


func _craft_remove_one(ore_key: String) -> void:
	if not _build_slot.has(ore_key):
		return
	_build_slot[ore_key].count = int(_build_slot[ore_key].count) - 1
	if int(_build_slot[ore_key].count) <= 0:
		_build_slot.erase(ore_key)
	_show_view(LabView.BOT_CRAFT)


func _compute_raw_mineral_profile() -> Dictionary:
	## Spec §A5/§A6: sums raw mineral COUNTS per type across the build slot.
	## Void counted under "void" key; resolution to real types happens at build time.
	## Used by both the preview and the actual build so they can't disagree.
	var profile: Dictionary = Inventory.empty_mineral_profile()
	for k in _build_slot.keys():
		var entry: Dictionary = _build_slot[k]
		var mineral: MineralData = entry.mineral
		if mineral == null:
			continue
		var count: int = int(entry.count)
		var mid: String = mineral.id
		if profile.has(mid):
			profile[mid] = int(profile[mid]) + count
	return profile


func _bonus_preview_text() -> String:
	var profile: Dictionary = _compute_raw_mineral_profile()
	var parts: Array[String] = []
	for key in Inventory.VOID_REAL_TYPES:
		var v: int = int(profile.get(key, 0))
		if v > 0:
			parts.append("%s +%d" % [key.capitalize(), v])
	var void_v: int = int(profile.get("void", 0))
	if void_v > 0:
		parts.append("Void +%d (random)" % void_v)
	if parts.is_empty():
		return "none"
	return ", ".join(parts)


func _craft_auto_assign() -> void:
	## Greedy fill (spec §A7): cheapest first, plain before mineral within a tier.
	_build_slot.clear()
	var stacks: Array = _collect_inventory_stacks()
	# Sort: tier ascending, then plain (mineral == null) before mineral.
	stacks.sort_custom(func(a, b):
		var ta: int = int(a.ore.tier)
		var tb: int = int(b.ore.tier)
		if ta != tb:
			return ta < tb
		var a_plain: bool = a.mineral == null
		var b_plain: bool = b.mineral == null
		if a_plain != b_plain:
			return a_plain  # plain first
		return false
	)
	var running: int = 0
	for stack in stacks:
		if running >= Inventory.BOT_BUILD_THRESHOLD:
			break
		var ore: OreData = stack.ore
		var mineral: MineralData = stack.mineral
		var qty: int = int(stack.quantity)
		var pts: int = _points_for_tier(int(ore.tier))
		var key: String = _ore_key(ore, mineral)
		while qty > 0 and running < Inventory.BOT_BUILD_THRESHOLD:
			if _build_slot.has(key):
				_build_slot[key].count = int(_build_slot[key].count) + 1
			else:
				_build_slot[key] = {"ore": ore, "mineral": mineral, "count": 1}
			qty -= 1
			running += pts
	_show_view(LabView.BOT_CRAFT)


func _craft_build() -> void:
	## Spec §A6: validate, spend ores, compute mineral_profile + void_resolved, append bot.
	var total_pts: int = _build_slot_total_points()
	if total_pts < Inventory.BOT_BUILD_THRESHOLD:
		return  # Defensive: button should be disabled.

	# 1. Spend ores. Snapshot entries first so we can abort cleanly on failure.
	var spend_list: Array = []
	for k in _build_slot.keys():
		var entry: Dictionary = _build_slot[k]
		spend_list.append({
			"ore_id": entry.ore.id,
			"mineral_id": entry.mineral.id if entry.mineral else "",
			"count": int(entry.count),
		})
	for spend in spend_list:
		var ok: bool = Inventory.spend_ore_combined(spend.ore_id, spend.mineral_id, spend.count)
		if not ok:
			push_error("npc_lab: spend_ore_combined failed for %s (mineral=%s) x%d — build aborted" % [
				spend.ore_id, spend.mineral_id, spend.count,
			])
			result_label.text = "Build failed: ore shortfall."
			return

	# 2. Compute raw-count mineral_profile (shared with preview) + resolve void rolls.
	var mineral_profile: Dictionary = _compute_raw_mineral_profile()
	var void_resolved: Array = []
	var void_count: int = int(mineral_profile.get("void", 0))
	for i in void_count:
		var rolled: String = Inventory.VOID_REAL_TYPES[randi() % Inventory.VOID_REAL_TYPES.size()]
		void_resolved.append(rolled)

	# 3. Build the new bot entry.
	var spec: Dictionary = BOT_BUILD_SPECS.get(_craft_bot_id, {})
	var base_name: String = spec.get("display_name", _craft_bot_id.capitalize())
	var max_hp: float = float(spec.get("hp", 40.0))
	var dmg: float = float(spec.get("damage", 0.0))
	var cp_cost: int = int(spec.get("cp_cost", 1))
	var instance_number_preview: int = Inventory.count_permanent_bots_of_type(_craft_bot_id) + 1
	var entry_out: Dictionary = {
		"id": _craft_bot_id,
		"display_name": "%s #%d" % [base_name, instance_number_preview],
		"max_health": max_hp,
		"health": max_hp,
		"damage": dmg,
		"cp_cost": cp_cost,
		"knocked_out": false,
		"hp_upgrade_level": 0,
		"damage_upgrade_level": 0,
		"mineral_profile": mineral_profile,
		"void_resolved": void_resolved,
	}

	# 4. Append (fills instance_number, emits bots_changed).
	Inventory.add_permanent_bot(entry_out)

	# 5. Return to Build Bot list.
	result_label.text = "Built %s!" % entry_out["display_name"]
	_build_slot.clear()
	_show_view(LabView.BUILD_BOT)


# ── Upgrade Bots view ───────────────────────────────────────────────

func _build_upgrade_bots_view() -> void:
	_add_header("— UPGRADE BOTS —")
	if Inventory.permanent_bots.is_empty():
		var empty: Label = Label.new()
		empty.text = "No bots yet — build one first."
		services_container.add_child(empty)
		_add_back_button()
		return

	var plain_t1: int = Inventory.count_plain_t1_ore_combined()
	var have_lbl: Label = Label.new()
	have_lbl.text = "Have: %d plain T1 ore, %dg" % [plain_t1, GameManager.gold]
	services_container.add_child(have_lbl)

	for bot in Inventory.permanent_bots:
		var id: String = bot.get("id", "")
		var dname: String = bot.get("display_name", "Bot")
		var hp_lvl: int = int(bot.get("hp_upgrade_level", 0))
		var dmg_lvl: int = int(bot.get("damage_upgrade_level", 0))
		var current_hp: float = float(bot.get("max_health", 40.0))
		var current_dmg: float = float(bot.get("damage", 5.0))

		var section: Label = Label.new()
		section.text = "%s — HP %d (lvl %d/%d)  |  DMG %d (lvl %d/%d)" % [
			dname, int(current_hp), hp_lvl, BOT_UPGRADE_MAX_LEVEL,
			int(current_dmg), dmg_lvl, BOT_UPGRADE_MAX_LEVEL,
		]
		services_container.add_child(section)

		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		services_container.add_child(row)

		# HP upgrade button
		var hp_btn: Button = Button.new()
		if hp_lvl >= BOT_UPGRADE_MAX_LEVEL:
			hp_btn.text = "HP: MAX"
			hp_btn.disabled = true
		else:
			var cost: Dictionary = _bot_upgrade_cost(hp_lvl)
			hp_btn.text = "+%d HP  (%d ore + %dg)" % [int(HP_PER_LEVEL), cost.ore, cost.gold]
			hp_btn.disabled = plain_t1 < cost.ore or GameManager.gold < cost.gold
			var id_cap: String = id
			hp_btn.pressed.connect(func(): _on_upgrade_bot_hp(id_cap))
		row.add_child(hp_btn)

		# Damage upgrade button
		var dmg_btn: Button = Button.new()
		if dmg_lvl >= BOT_UPGRADE_MAX_LEVEL:
			dmg_btn.text = "DMG: MAX"
			dmg_btn.disabled = true
		else:
			var cost2: Dictionary = _bot_upgrade_cost(dmg_lvl)
			dmg_btn.text = "+%d DMG  (%d ore + %dg)" % [int(DAMAGE_PER_LEVEL), cost2.ore, cost2.gold]
			dmg_btn.disabled = plain_t1 < cost2.ore or GameManager.gold < cost2.gold
			var id_cap2: String = id
			dmg_btn.pressed.connect(func(): _on_upgrade_bot_damage(id_cap2))
		row.add_child(dmg_btn)

	_add_back_button()


func _bot_upgrade_cost(level: int) -> Dictionary:
	var mult: float = pow(BOT_UPGRADE_COST_MULT, level)
	return {
		"ore": int(round(BOT_UPGRADE_BASE_ORE * mult)),
		"gold": int(round(BOT_UPGRADE_BASE_GOLD * mult)),
	}


func _on_upgrade_bot_hp(id: String) -> void:
	var bot: Dictionary = Inventory.get_permanent_bot(id)
	if bot.is_empty():
		return
	var lvl: int = int(bot.get("hp_upgrade_level", 0))
	if lvl >= BOT_UPGRADE_MAX_LEVEL:
		return
	var cost: Dictionary = _bot_upgrade_cost(lvl)
	if not _pay(cost.ore, cost.gold):
		return
	bot["hp_upgrade_level"] = lvl + 1
	bot["max_health"] = float(bot.get("max_health", 40.0)) + HP_PER_LEVEL
	bot["health"] = bot["max_health"]
	result_label.text = "%s HP upgraded to %d!" % [bot.get("display_name", "Bot"), int(bot["max_health"])]
	Inventory.bots_changed.emit()
	_show_view(LabView.UPGRADE_BOTS)


func _on_upgrade_bot_damage(id: String) -> void:
	var bot: Dictionary = Inventory.get_permanent_bot(id)
	if bot.is_empty():
		return
	var lvl: int = int(bot.get("damage_upgrade_level", 0))
	if lvl >= BOT_UPGRADE_MAX_LEVEL:
		return
	var cost: Dictionary = _bot_upgrade_cost(lvl)
	if not _pay(cost.ore, cost.gold):
		return
	bot["damage_upgrade_level"] = lvl + 1
	bot["damage"] = float(bot.get("damage", 5.0)) + DAMAGE_PER_LEVEL
	result_label.text = "%s damage upgraded to %d!" % [bot.get("display_name", "Bot"), int(bot["damage"])]
	Inventory.bots_changed.emit()
	_show_view(LabView.UPGRADE_BOTS)


# ── Upgrade Necklace view ───────────────────────────────────────────

func _build_upgrade_necklace_view() -> void:
	_add_header("— UPGRADE NECKLACE —")
	var current: int = Inventory.crystal_power_capacity
	var lvl: int = Inventory.necklace_upgrade_level
	var info: Label = Label.new()
	info.text = "Crystal Power: %d (level %d/%d)" % [current, lvl, NECKLACE_MAX_LEVEL]
	services_container.add_child(info)

	var plain_t1: int = Inventory.count_plain_t1_ore_combined()
	var have_lbl: Label = Label.new()
	have_lbl.text = "Have: %d plain T1 ore, %dg" % [plain_t1, GameManager.gold]
	services_container.add_child(have_lbl)

	if lvl >= NECKLACE_MAX_LEVEL:
		var maxed: Label = Label.new()
		maxed.text = "Maximum capacity reached."
		services_container.add_child(maxed)
	else:
		var cost: Dictionary = _necklace_cost(lvl)
		var btn: Button = Button.new()
		btn.text = "Upgrade to CP %d  (%d ore + %dg)" % [current + 1, cost.ore, cost.gold]
		btn.disabled = plain_t1 < cost.ore or GameManager.gold < cost.gold
		btn.pressed.connect(_on_upgrade_necklace)
		services_container.add_child(btn)
	_add_back_button()


func _necklace_cost(level: int) -> Dictionary:
	var mult: float = pow(NECKLACE_COST_MULT, level)
	return {
		"ore": int(round(NECKLACE_BASE_ORE * mult)),
		"gold": int(round(NECKLACE_BASE_GOLD * mult)),
	}


func _on_upgrade_necklace() -> void:
	var lvl: int = Inventory.necklace_upgrade_level
	if lvl >= NECKLACE_MAX_LEVEL:
		return
	var cost: Dictionary = _necklace_cost(lvl)
	if not _pay(cost.ore, cost.gold):
		return
	Inventory.necklace_upgrade_level = lvl + 1
	Inventory.crystal_power_capacity += 1
	result_label.text = "Crystal Power +1 (now %d)!" % Inventory.crystal_power_capacity
	Inventory.inventory_changed.emit()
	_show_view(LabView.UPGRADE_NECKLACE)


# ── Upgrade Merge Charges view ──────────────────────────────────────

func _build_upgrade_merge_view() -> void:
	_add_header("— UPGRADE MERGE CHARGES —")
	var current: int = Inventory.merge_charges_max
	var lvl: int = Inventory.merge_upgrade_level
	var info: Label = Label.new()
	info.text = "Merge charges per run: %d (level %d/%d)" % [current, lvl, MERGE_MAX_LEVEL]
	services_container.add_child(info)

	var plain_t1: int = Inventory.count_plain_t1_ore_combined()
	var have_lbl: Label = Label.new()
	have_lbl.text = "Have: %d plain T1 ore, %dg" % [plain_t1, GameManager.gold]
	services_container.add_child(have_lbl)

	if lvl >= MERGE_MAX_LEVEL:
		var maxed: Label = Label.new()
		maxed.text = "Maximum merge charges reached."
		services_container.add_child(maxed)
	else:
		var cost: Dictionary = _merge_cost(lvl)
		var btn: Button = Button.new()
		btn.text = "Upgrade to %d charges  (%d ore + %dg)" % [current + 1, cost.ore, cost.gold]
		btn.disabled = plain_t1 < cost.ore or GameManager.gold < cost.gold
		btn.pressed.connect(_on_upgrade_merge)
		services_container.add_child(btn)
	_add_back_button()


func _merge_cost(level: int) -> Dictionary:
	var mult: float = pow(MERGE_COST_MULT, level)
	return {
		"ore": int(round(MERGE_BASE_ORE * mult)),
		"gold": int(round(MERGE_BASE_GOLD * mult)),
	}


func _on_upgrade_merge() -> void:
	var lvl: int = Inventory.merge_upgrade_level
	if lvl >= MERGE_MAX_LEVEL:
		return
	var cost: Dictionary = _merge_cost(lvl)
	if not _pay(cost.ore, cost.gold):
		return
	Inventory.merge_upgrade_level = lvl + 1
	Inventory.merge_charges_max += 1
	# Also bump current charges (convenience in town — they're not in a run).
	Inventory.merge_charges = Inventory.merge_charges_max
	result_label.text = "Merge charges max now %d!" % Inventory.merge_charges_max
	Inventory.inventory_changed.emit()
	_show_view(LabView.UPGRADE_MERGE)


# ── Helpers ─────────────────────────────────────────────────────────

func _pay(ore_amount: int, gold_amount: int) -> bool:
	if Inventory.count_plain_t1_ore_combined() < ore_amount:
		result_label.text = "Not enough plain T1 ore."
		return false
	if GameManager.gold < gold_amount:
		result_label.text = "Not enough gold."
		return false
	if not Inventory.spend_plain_t1_ore_from_any(ore_amount):
		result_label.text = "Failed to spend ore."
		return false
	if not GameManager.spend_gold(gold_amount):
		result_label.text = "Failed to spend gold."
		return false
	return true


func _add_header(text: String) -> void:
	var header: Label = Label.new()
	header.text = text
	services_container.add_child(header)


func _add_back_button() -> void:
	var back: Button = Button.new()
	back.text = "← Back"
	back.pressed.connect(func(): _show_view(LabView.MAIN))
	services_container.add_child(back)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		label.visible = false
		if menu_open:
			_close_menu()
