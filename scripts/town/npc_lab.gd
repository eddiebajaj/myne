class_name NPCLab
extends Area2D
## Lab Researcher NPC — bot build hub (Sprint 5 rework).
##
## Menu layout:
##   - Main: Build Bot / Upgrade Bots / Upgrade Necklace / Upgrade Merge / Close
##   - Sub-menus rebuild into the same Services VBox; a "Back" button returns
##     to the main menu.

enum LabView { MAIN, BUILD_BOT, UPGRADE_BOTS, UPGRADE_NECKLACE, UPGRADE_MERGE }

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
		if _view != LabView.MAIN:
			_show_view(LabView.MAIN)
		else:
			_close_menu()


func _process(_delta: float) -> void:
	if menu_open and Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame == Engine.get_process_frames():
			return
		if _view != LabView.MAIN:
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
		LabView.UPGRADE_BOTS: _build_upgrade_bots_view()
		LabView.UPGRADE_NECKLACE: _build_upgrade_necklace_view()
		LabView.UPGRADE_MERGE: _build_upgrade_merge_view()
	_focus_first_button()


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
			child.grab_focus()
			return
	close_button.grab_focus()


# ── Main view ───────────────────────────────────────────────────────

func _build_main_view() -> void:
	_add_header("— LAB —")

	var build_btn: Button = Button.new()
	build_btn.text = "Build Bot"
	build_btn.pressed.connect(func(): _show_view(LabView.BUILD_BOT))
	services_container.add_child(build_btn)

	var upgrade_bots_btn: Button = Button.new()
	upgrade_bots_btn.text = "Upgrade Bots"
	upgrade_bots_btn.disabled = Inventory.permanent_bots.is_empty()
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


# ── Build Bot view ──────────────────────────────────────────────────

func _build_build_bot_view() -> void:
	_add_header("— BUILD BOT —")

	var plain_t1: int = Inventory.count_plain_t1_ore_combined()
	var have_lbl: Label = Label.new()
	have_lbl.text = "Have: %d plain T1 ore (backpack+storage), %dg" % [plain_t1, GameManager.gold]
	services_container.add_child(have_lbl)

	# Build list of available bot ids: starters + any blueprints.
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
		var desc: String = spec.get("desc", "")
		var info: Label = Label.new()
		if Inventory.has_permanent_bot(id):
			info.text = "%s — Owned  (%s)" % [dname, desc]
			info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
			services_container.add_child(info)
		else:
			info.text = "%s — cost: %d plain T1 ore  (%s)" % [dname, BOT_BUILD_ORE_COST, desc]
			services_container.add_child(info)
			var buy_btn: Button = Button.new()
			buy_btn.text = "Build %s" % dname
			buy_btn.disabled = plain_t1 < BOT_BUILD_ORE_COST
			var id_cap: String = id
			buy_btn.pressed.connect(func(): _on_build_bot(id_cap))
			services_container.add_child(buy_btn)

	_add_back_button()


func _on_build_bot(id: String) -> void:
	if Inventory.has_permanent_bot(id):
		return
	var spec: Dictionary = BOT_BUILD_SPECS.get(id, {})
	if spec.is_empty():
		result_label.text = "Unknown bot."
		return
	# Gate: starters always buildable; non-starters require blueprint.
	if not (id in STARTER_BOTS) and not (id in Inventory.blueprints):
		result_label.text = "Blueprint required."
		return
	if Inventory.count_plain_t1_ore_combined() < BOT_BUILD_ORE_COST:
		result_label.text = "Not enough plain T1 ore."
		return
	if not Inventory.spend_plain_t1_ore_from_any(BOT_BUILD_ORE_COST):
		result_label.text = "Could not spend ore."
		return
	var dname: String = spec.get("display_name", id.capitalize())
	var hp: float = float(spec.get("hp", 40.0))
	var dmg: float = float(spec.get("damage", 5.0))
	var cp_cost: int = int(spec.get("cp_cost", 1))
	Inventory.unlock_permanent_bot(id, dname, hp, dmg, cp_cost)
	result_label.text = "Built %s!" % dname
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
