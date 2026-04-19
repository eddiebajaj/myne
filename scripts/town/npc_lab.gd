class_name NPCLab
extends Area2D
## Lab Researcher NPC — bot build hub.
##
## Sprint 8: tab-bar navigation. Five tabs (Build / Upgrade / Scrap / Merge /
## Necklace) are always visible at the top of the panel; the content area below
## swaps based on the active tab. BUILD_CRAFT is a sub-view within the Build
## tab (B returns to the Build bot list, not the Lab close).

enum LabView {
	BUILD,            # Build tab — list of bot types
	BUILD_CRAFT,      # Sub-view within Build: recipe grid for the chosen bot
	UPGRADE,          # Upgrade tab — list of owned bots
	UPGRADE_CRAFT,    # Sub-view within Upgrade: recipe grid for the chosen bot
	SCRAP,            # Scrap tab — list of owned bots
	SCRAP_CONFIRM,    # Sub-view within Scrap: confirm dialog with ore-return preview
	MERGE,            # Merge-charges tab
	NECKLACE,         # Necklace tab
}

# Crafting mode for the shared recipe-grid view.
enum CraftMode { BUILD, UPGRADE }

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

# --- Hard material requirements per bot type (Sprint 8) ---
# Each entry: array of {ore_id, mineral_id, count}.
# These count toward the point total — they are not extra.
const BOT_REQUIRED_MATERIALS: Dictionary = {
	"miner": [
		{"ore_id": "iron", "mineral_id": "", "count": 3},
	],
	"striker": [
		{"ore_id": "copper", "mineral_id": "", "count": 3},
	],
	"backpack_bot": [
		{"ore_id": "iron", "mineral_id": "", "count": 2},
		{"ore_id": "copper", "mineral_id": "", "count": 2},
	],
	"scout": [
		{"ore_id": "crystal", "mineral_id": "", "count": 2},
	],
}

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
var _view: LabView = LabView.BUILD

# --- Bot crafting state (Sprint 7 recipe-grid UI, Sprint 8 upgrades) ---
# _craft_mode: BUILD (new bot) or UPGRADE (existing bot).
# _craft_bot_id: which bot type is being crafted (BUILD) or upgraded (UPGRADE).
# _craft_upgrade_index: index into Inventory.permanent_bots for UPGRADE mode.
# _build_slot: {ore_key (String) : {ore: OreData, mineral: MineralData, count: int}}
var _craft_mode: CraftMode = CraftMode.BUILD
var _craft_bot_id: String = ""
var _craft_upgrade_index: int = -1
var _build_slot: Dictionary = {}

# Sprint 8 §A7: index into Inventory.permanent_bots for the bot currently on the
# SCRAP_CONFIRM sub-view. -1 when no scrap target is selected. Reset on menu
# open/close, cancel, successful confirm, and any tab change away from Scrap.
var _scrap_target_index: int = -1

# Shared TabBar (built in _ready, persists across panel open/close).
var _tab_bar: TabBarUI = null

# Map tab id (String) -> default LabView for that tab's main content.
const _TAB_DEFAULT_VIEW: Dictionary = {
	"build": LabView.BUILD,
	"upgrade": LabView.UPGRADE,
	"scrap": LabView.SCRAP,
	"merge": LabView.MERGE,
	"necklace": LabView.NECKLACE,
}

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
@onready var menu_panel: PanelContainer = $CanvasLayer/MenuPanel
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var services_container: VBoxContainer = $CanvasLayer/MenuPanel/VBox/Services
@onready var storage_label: Label = $CanvasLayer/MenuPanel/VBox/StorageLabel
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton
@onready var _panel_vbox: VBoxContainer = $CanvasLayer/MenuPanel/VBox


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
	_build_tab_bar()
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)


func _build_tab_bar() -> void:
	## Constructs the shared TabBar and inserts it above the Services VBox.
	_tab_bar = TabBarUI.new()
	_tab_bar.name = "TabBar"
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.add_tab("build", "Build")
	_tab_bar.add_tab("upgrade", "Upgrade")
	_tab_bar.add_tab("scrap", "Scrap")
	_tab_bar.add_tab("merge", "Merge")
	_tab_bar.add_tab("necklace", "Necklace")
	_tab_bar.tab_changed.connect(_on_tab_changed)
	# Insert directly above the Services VBox so it lives between StorageLabel
	# and the content area.
	_panel_vbox.add_child(_tab_bar)
	_panel_vbox.move_child(_tab_bar, services_container.get_index())


func _on_touch_a() -> void:
	if player_in_range and not menu_open:
		_open_menu()


func _on_touch_b() -> void:
	if menu_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		_handle_back()


func _process(_delta: float) -> void:
	if menu_open and Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame == Engine.get_process_frames():
			return
		_handle_back()
		return
	if player_in_range and not menu_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_menu()


func _handle_back() -> void:
	## B button: if in a sub-view within a tab, return to the tab's main view.
	## Otherwise close the panel. The tab bar's main views do NOT get a "Back"
	## button — the tab bar IS the nav.
	match _view:
		LabView.BUILD_CRAFT:
			_show_view(LabView.BUILD)
		LabView.UPGRADE_CRAFT:
			_show_view(LabView.UPGRADE)
		LabView.SCRAP_CONFIRM:
			_show_view(LabView.SCRAP)
		_:
			_close_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	get_tree().paused = true
	# Defensive state reset — scrap target shouldn't survive a menu re-open.
	_scrap_target_index = -1
	# Default to Build tab on every open. Clear any leftover lock first so
	# set_active() isn't short-circuited by a stale lock from a prior session.
	# If the bar was already on "build", set_active is a no-op and won't fire
	# tab_changed — _show_view below rebuilds content defensively either way.
	_tab_bar.set_locked(false)
	_tab_bar.set_active("build")
	_show_view(LabView.BUILD)
	# Focus the active tab button first (per Sprint 8 spec: down moves into content).
	_tab_bar.focus_active()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	get_tree().paused = false
	_scrap_target_index = -1
	# Defensive: clear the sub-view lock so a re-open from any state starts
	# with a live tab bar (_show_view(BUILD) will also set this, but belt-and-
	# suspenders costs nothing).
	if _tab_bar != null:
		_tab_bar.set_locked(false)


func _on_tab_changed(_index: int, id: String) -> void:
	var target: int = _TAB_DEFAULT_VIEW.get(id, LabView.BUILD)
	_show_view(target)
	# Keep focus on the tab bar after a cycle so left/right keeps working.
	_tab_bar.focus_active()


# ── View dispatch ───────────────────────────────────────────────────

func _show_view(view: LabView, restore_focus_index: int = -1) -> void:
	_view = view
	_refresh_common()
	for child in services_container.get_children():
		child.queue_free()
	# Lock the tab bar while a sub-view is active so left/right can't steal the
	# player's interaction. Sub-views: BUILD_CRAFT, UPGRADE_CRAFT, SCRAP_CONFIRM.
	var is_sub_view: bool = view == LabView.BUILD_CRAFT or view == LabView.UPGRADE_CRAFT or view == LabView.SCRAP_CONFIRM
	if _tab_bar != null:
		_tab_bar.set_locked(is_sub_view)
	# Reset scrap target whenever we leave the confirm sub-view. The SCRAP list
	# view also clears it (cancelled confirms, tab changes, etc.) so a stale
	# target can't linger. _on_scrap_row_pressed sets the target right before
	# calling _show_view(SCRAP_CONFIRM), which is the only path that needs it
	# preserved.
	if view != LabView.SCRAP_CONFIRM:
		_scrap_target_index = -1
	match view:
		LabView.BUILD: _build_build_bot_view()
		LabView.BUILD_CRAFT: _build_bot_craft_view()
		LabView.UPGRADE: _build_upgrade_list_view()
		LabView.UPGRADE_CRAFT: _build_bot_craft_view()
		LabView.SCRAP: _build_scrap_list_view()
		LabView.SCRAP_CONFIRM: _build_scrap_confirm_view()
		LabView.MERGE: _build_upgrade_merge_view()
		LabView.NECKLACE: _build_upgrade_necklace_view()
	_wire_focus_wrap()
	_wire_tab_bar_to_content()
	if restore_focus_index >= 0:
		_focus_button_at_index(restore_focus_index)


func _wire_tab_bar_to_content() -> void:
	## Let ui_down on tab buttons move focus into the first focusable control
	## in the content area, and ui_up on the first content control return to
	## the active tab (Sprint 8 spec §A6).
	if _tab_bar == null:
		return
	var focusables: Array = FocusUtil.collect_focusables(services_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion() and not c.disabled)
	var first: Control = focusables[0] if not focusables.is_empty() else close_button
	_tab_bar.wire_content_below(first)
	# Bind first-content-control's top neighbor to active tab so ui_up returns.
	var active_tab: Button = _tab_bar.get_active_button()
	if first != null and active_tab != null and not first.is_queued_for_deletion() and not active_tab.is_queued_for_deletion():
		first.focus_neighbor_top = first.get_path_to(active_tab)
		first.focus_previous = first.get_path_to(active_tab)


func _wire_focus_wrap() -> void:
	var focusables: Array = FocusUtil.collect_focusables(services_container)
	# Filter out nodes queued for deletion (old view children not yet freed).
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
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


func _get_focused_button_index() -> int:
	var focused := services_container.get_viewport().gui_get_focus_owner()
	if focused == null:
		return -1
	var focusables := FocusUtil.collect_focusables(services_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	focusables.append(close_button)
	return focusables.find(focused)


func _focus_button_at_index(idx: int) -> void:
	var focusables := FocusUtil.collect_focusables(services_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	focusables.append(close_button)
	if focusables.is_empty():
		close_button.call_deferred("grab_focus")
		return
	idx = clampi(idx, 0, focusables.size() - 1)
	focusables[idx].call_deferred("grab_focus")


func _focus_first_button() -> void:
	# Use FocusUtil to find buttons in nested sub-containers (e.g. BOT_CRAFT
	# two-column layout).  Skip nodes queued for deletion — _show_view
	# queue_free()s old children before building new ones in the same frame.
	var focusables := FocusUtil.collect_focusables(services_container)
	for ctrl in focusables:
		if ctrl.is_queued_for_deletion():
			continue
		if not ctrl.disabled:
			ctrl.call_deferred("grab_focus")
			return
	close_button.call_deferred("grab_focus")


# ── Upgrade / Scrap list views (step 2 — scaffolding for step 4/5) ──
#
# Both views list owned bots as focusable rows using the same compact format
# ("Scout #1 — Lv 0 (Fire+3, Earth+1)"). Pressing a row currently shows a
# placeholder notice in result_label; step 4 will wire Upgrade into the recipe
# grid and step 5 will wire Scrap into its confirmation flow.

func _build_upgrade_list_view() -> void:
	_add_header("— UPGRADE BOT —")
	if Inventory.permanent_bots.is_empty():
		var empty: Label = Label.new()
		empty.text = "No bots yet — build one first."
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		services_container.add_child(empty)
		return
	var hint: Label = Label.new()
	hint.text = "Select a bot to upgrade."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	services_container.add_child(hint)
	for i in Inventory.permanent_bots.size():
		var bot: Dictionary = Inventory.permanent_bots[i]
		var lvl: int = int(bot.get("upgrade_level", 0))
		var row_btn: Button = Button.new()
		var at_max: bool = lvl >= Inventory.MAX_UPGRADE_LEVEL
		if at_max:
			row_btn.text = _format_bot_row(bot) + "   [MAX]"
			row_btn.disabled = true
		else:
			row_btn.text = _format_bot_row(bot)
			var idx_cap: int = i
			row_btn.pressed.connect(func(): _open_upgrade_craft(idx_cap))
		services_container.add_child(row_btn)


func _open_upgrade_craft(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= Inventory.permanent_bots.size():
		return
	var bot: Dictionary = Inventory.permanent_bots[entry_index]
	if int(bot.get("upgrade_level", 0)) >= Inventory.MAX_UPGRADE_LEVEL:
		result_label.text = "Bot is already at max level."
		return
	_craft_mode = CraftMode.UPGRADE
	_craft_upgrade_index = entry_index
	_craft_bot_id = String(bot.get("id", ""))
	_build_slot.clear()
	_show_view(LabView.UPGRADE_CRAFT)
	_focus_first_button()


func _build_scrap_list_view() -> void:
	_add_header("— SCRAP BOT —")
	if Inventory.permanent_bots.is_empty():
		var empty: Label = Label.new()
		empty.text = "No bots yet — nothing to scrap."
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		services_container.add_child(empty)
		return
	var hint: Label = Label.new()
	hint.text = "Select a bot to scrap."
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	services_container.add_child(hint)
	for i in Inventory.permanent_bots.size():
		var bot: Dictionary = Inventory.permanent_bots[i]
		var row_btn: Button = Button.new()
		row_btn.text = _format_bot_row(bot)
		var idx_cap: int = i
		row_btn.pressed.connect(func(): _on_scrap_row_pressed(idx_cap))
		services_container.add_child(row_btn)


func _format_bot_row(bot: Dictionary) -> String:
	## "Scout #1 — Lv 0 (Fire+3, Earth+1)" — matches crafting-list format spec.
	var dname: String = String(bot.get("display_name", "Bot"))
	# upgrade_level lands in step 3's data-model migration; fall back to 0 so
	# the scaffolding still renders sensibly today.
	var lvl: int = int(bot.get("upgrade_level", 0))
	var profile: Dictionary = bot.get("mineral_profile", Inventory.empty_mineral_profile())
	var void_resolved: Array = bot.get("void_resolved", [])
	var suffix: String = Inventory.format_mineral_suffix(profile, void_resolved)
	if suffix == "":
		return "%s — Lv %d" % [dname, lvl]
	return "%s — Lv %d %s" % [dname, lvl, suffix]


func _on_scrap_row_pressed(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= Inventory.permanent_bots.size():
		return
	_scrap_target_index = entry_index
	_show_view(LabView.SCRAP_CONFIRM)


# ── Scrap confirm view (Sprint 8 §A7) ───────────────────────────────

func _build_scrap_confirm_view() -> void:
	_add_header("— SCRAP BOT —")
	if _scrap_target_index < 0 or _scrap_target_index >= Inventory.permanent_bots.size():
		# Shouldn't happen under normal flow — the row press validates bounds
		# before transitioning here. Recover by returning to the list so the
		# player isn't stranded.
		var miss: Label = Label.new()
		miss.text = "Bot not found. Returning to list…"
		services_container.add_child(miss)
		_add_cancel_button_scrap()
		return
	var bot: Dictionary = Inventory.permanent_bots[_scrap_target_index]
	var dname: String = String(bot.get("display_name", "Bot"))
	var lvl: int = int(bot.get("upgrade_level", 0))
	var profile: Dictionary = bot.get("mineral_profile", Inventory.empty_mineral_profile())
	var void_resolved: Array = bot.get("void_resolved", [])
	var suffix: String = Inventory.format_mineral_suffix(profile, void_resolved)

	# Bot name + identity line
	var name_lbl: Label = Label.new()
	if suffix == "":
		name_lbl.text = "%s (Lv %d)" % [dname, lvl]
	else:
		name_lbl.text = "%s (Lv %d, %s)" % [dname, lvl, _strip_parens(suffix)]
	services_container.add_child(name_lbl)

	# Ore return preview — pure compute, shown exactly as the confirm will give.
	var refund: Array = ScrapUtil.compute_refund(bot, BOT_REQUIRED_MATERIALS.get(_craft_bot_id_for_bot(bot), []))
	var return_lbl: Label = Label.new()
	return_lbl.text = "Returns: " + _format_refund_text(refund)
	return_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	services_container.add_child(return_lbl)

	# Mineral loss note — only if any mineral or resolved void is on the bot.
	if _profile_has_any(profile) or not void_resolved.is_empty():
		var loss_lbl: Label = Label.new()
		loss_lbl.text = "Minerals lost: " + _strip_parens(suffix if suffix != "" else "(none)")
		loss_lbl.add_theme_color_override("font_color", Color(0.95, 0.7, 0.4))
		services_container.add_child(loss_lbl)

	# Confirm + Cancel buttons
	var confirm_btn: Button = Button.new()
	confirm_btn.text = "Confirm Scrap"
	confirm_btn.pressed.connect(_on_scrap_confirm)
	services_container.add_child(confirm_btn)

	_add_cancel_button_scrap()


func _add_cancel_button_scrap() -> void:
	## Separate from _add_cancel_button (which is bound to _on_craft_cancel) so
	## the scrap flow can route B/Cancel back to the scrap list, not the build
	## or upgrade list.
	var cancel_btn: Button = Button.new()
	cancel_btn.text = "← Cancel"
	cancel_btn.pressed.connect(_on_scrap_cancel)
	services_container.add_child(cancel_btn)


func _on_scrap_cancel() -> void:
	_show_view(LabView.SCRAP)
	_focus_first_button()


func _on_scrap_confirm() -> void:
	## Executes the scrap: compute refund, try to deposit ores, remove bot.
	## Aborts with a message if storage + backpack can't fit the full refund.
	if _scrap_target_index < 0 or _scrap_target_index >= Inventory.permanent_bots.size():
		result_label.text = "Scrap failed: bot not found."
		_show_view(LabView.SCRAP)
		return
	var bot: Dictionary = Inventory.permanent_bots[_scrap_target_index]
	var bot_id: String = _craft_bot_id_for_bot(bot)
	var dname: String = String(bot.get("display_name", "Bot"))
	var refund: Array = ScrapUtil.compute_refund(bot, BOT_REQUIRED_MATERIALS.get(bot_id, []))

	# Capacity pre-check: total refund pieces must fit in storage + backpack.
	# _storage_add caps at storage capacity; add_ore caps at backpack capacity.
	var total_refund: int = 0
	for row in refund:
		total_refund += int(row.count)
	var total_space: int = Inventory.get_storage_remaining() + Inventory.get_remaining_slots()
	if total_refund > total_space:
		result_label.text = "Clear space in storage first — %d pieces wouldn't fit." % (total_refund - total_space)
		return

	# Deposit each refund row (storage first, backpack overflow).  If any row
	# only partially fits we abort after restoring — but the pre-check above
	# should prevent that path in practice.
	var deposited: Array = []  # [{ore_id, mineral_id, count}] for reporting/rollback
	for row in refund:
		var want: int = int(row.count)
		var placed: int = Inventory.try_deposit_ore_combined(
			String(row.ore_id), String(row.mineral_id), want,
		)
		deposited.append({"ore_id": row.ore_id, "mineral_id": row.mineral_id, "count": placed})
		if placed < want:
			# Shouldn't happen thanks to the pre-check, but guard anyway.
			result_label.text = "Scrap failed: couldn't deposit all refund pieces."
			return

	# Remove bot (also drops it from run_party + emits bots_changed).
	Inventory.remove_permanent_bot(_scrap_target_index)
	_scrap_target_index = -1

	result_label.text = "Scrapped %s. Got %s." % [dname, _format_refund_text(deposited)]
	_show_view(LabView.SCRAP)
	_focus_first_button()


func _craft_bot_id_for_bot(bot: Dictionary) -> String:
	## Prefer the bot's canonical id for recipe lookup (BOT_REQUIRED_MATERIALS).
	return String(bot.get("id", ""))


func _format_refund_text(refund: Array) -> String:
	## Array of {ore_id, mineral_id, count} -> "5 Crystal, 2 Iron".
	if refund.is_empty():
		return "nothing"
	var parts: Array[String] = []
	for row in refund:
		var n: int = int(row.count)
		if n <= 0:
			continue
		var name: String = ScrapUtil.display_name_for_ore_id(String(row.ore_id))
		parts.append("%d %s" % [n, name])
	if parts.is_empty():
		return "nothing"
	return ", ".join(parts)


func _profile_has_any(profile: Dictionary) -> bool:
	for k in profile.keys():
		if int(profile[k]) > 0:
			return true
	return false


func _strip_parens(suffix: String) -> String:
	## "(Fire+3, Earth+1)" -> "Fire+3, Earth+1". Returns input if no parens.
	if suffix.begins_with("(") and suffix.ends_with(")"):
		return suffix.substr(1, suffix.length() - 2)
	return suffix


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


func _open_bot_craft(id: String) -> void:
	_craft_mode = CraftMode.BUILD
	_craft_bot_id = id
	_craft_upgrade_index = -1
	_build_slot.clear()
	_show_view(LabView.BUILD_CRAFT)
	_focus_first_button()


# ── Bot Craft view (recipe grid) ────────────────────────────────────

func _build_bot_craft_view() -> void:
	var spec: Dictionary = BOT_BUILD_SPECS.get(_craft_bot_id, {})
	var type_dname: String = spec.get("display_name", _craft_bot_id.capitalize())

	# Header varies by mode:
	#   BUILD:   "— CRAFT: SCOUT —"  + "Base: X HP | Y DMG | CP Z"
	#   UPGRADE: "— UPGRADE: SCOUT #1 —" + "Lv N -> N+1" + current/after stats
	if _craft_mode == CraftMode.UPGRADE:
		var bot: Dictionary = _get_upgrade_entry()
		if bot.is_empty():
			_add_header("— UPGRADE —")
			var miss: Label = Label.new()
			miss.text = "Bot not found. Cancel to return."
			services_container.add_child(miss)
			_add_cancel_button()
			return
		var instance_name: String = String(bot.get("display_name", type_dname))
		var cur_lvl: int = int(bot.get("upgrade_level", 0))
		var nxt_lvl: int = cur_lvl + 1
		_add_header("— UPGRADE: %s —" % instance_name.to_upper())

		var lvl_lbl: Label = Label.new()
		lvl_lbl.text = "%s — Lv %d → Lv %d" % [instance_name, cur_lvl, nxt_lvl]
		services_container.add_child(lvl_lbl)

		var cur_stats: Dictionary = _compute_bot_stats(bot, cur_lvl)
		var nxt_stats: Dictionary = _compute_bot_stats(bot, nxt_lvl)
		var stats_lbl: Label = Label.new()
		stats_lbl.text = "Current: %d HP, %d DMG, AS x%.2f" % [
			int(round(cur_stats.max_health)), int(round(cur_stats.damage)), float(cur_stats.atk_speed_mult),
		]
		services_container.add_child(stats_lbl)
		var after_lbl: Label = Label.new()
		after_lbl.text = "After:   %d HP, %d DMG, AS x%.2f" % [
			int(round(nxt_stats.max_health)), int(round(nxt_stats.damage)), float(nxt_stats.atk_speed_mult),
		]
		after_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
		services_container.add_child(after_lbl)

		# Mineral profile preview (current + pending delta)
		var cur_profile: Dictionary = bot.get("mineral_profile", Inventory.empty_mineral_profile())
		var cur_void: Array = bot.get("void_resolved", [])
		var cur_suffix: String = Inventory.format_mineral_suffix(cur_profile, cur_void)
		if cur_suffix == "":
			cur_suffix = "(none)"
		var delta_profile: Dictionary = _compute_raw_mineral_profile()
		var merged_profile: Dictionary = _merge_profiles(cur_profile, delta_profile)
		# For the "after" suffix: include void_resolved count projected from current + pending void
		var pending_void: int = int(delta_profile.get("void", 0))
		var merged_void: Array = cur_void.duplicate()
		for i in pending_void:
			merged_void.append("?")  # placeholder — real roll happens at confirm
		var merged_suffix: String = Inventory.format_mineral_suffix(merged_profile, merged_void)
		if merged_suffix == "":
			merged_suffix = "(none)"
		var prof_lbl: Label = Label.new()
		prof_lbl.text = "Mineral profile: %s  →  %s" % [cur_suffix, merged_suffix]
		services_container.add_child(prof_lbl)
	else:
		_add_header("— CRAFT: %s —" % type_dname.to_upper())
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
	var threshold: int = _current_points_threshold()
	var total_lbl: Label = Label.new()
	total_lbl.text = "Points: %d / %d" % [total_pts, threshold]
	if total_pts >= threshold:
		total_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
	services_container.add_child(total_lbl)

	# Required materials display
	var reqs: Array = _current_required_materials()
	var reqs_met: bool = true
	if not reqs.is_empty():
		for req in reqs:
			var have: int = _count_ore_id_in_build_slot(req.ore_id, req.mineral_id)
			var needed: int = int(req.count)
			var mat_name: String = _get_required_materials_display_name(req.ore_id, req.mineral_id)
			var req_lbl: Label = Label.new()
			req_lbl.text = "Requires: %dx %s (%d/%d)" % [needed, mat_name, have, needed]
			if have >= needed:
				req_lbl.add_theme_color_override("font_color", Color(0.6, 0.95, 0.6))
			else:
				req_lbl.add_theme_color_override("font_color", Color(0.95, 0.4, 0.4))
				reqs_met = false
			services_container.add_child(req_lbl)

	var bonus_lbl: Label = Label.new()
	bonus_lbl.text = "Bonuses: " + _bonus_preview_text()
	services_container.add_child(bonus_lbl)

	# Action buttons
	var auto_btn: Button = Button.new()
	auto_btn.text = "Auto-assign"
	auto_btn.pressed.connect(_craft_auto_assign)
	services_container.add_child(auto_btn)

	var action_btn: Button = Button.new()
	action_btn.text = "Upgrade" if _craft_mode == CraftMode.UPGRADE else "Build %s" % type_dname
	action_btn.disabled = total_pts < threshold or not reqs_met
	action_btn.pressed.connect(_craft_build)
	services_container.add_child(action_btn)

	_add_cancel_button()


func _add_cancel_button() -> void:
	var cancel_btn: Button = Button.new()
	cancel_btn.text = "← Cancel"
	cancel_btn.pressed.connect(_on_craft_cancel)
	services_container.add_child(cancel_btn)


func _on_craft_cancel() -> void:
	_build_slot.clear()
	var back_view: LabView = LabView.UPGRADE if _craft_mode == CraftMode.UPGRADE else LabView.BUILD
	_show_view(back_view)
	_focus_first_button()


func _current_craft_view() -> LabView:
	return LabView.UPGRADE_CRAFT if _craft_mode == CraftMode.UPGRADE else LabView.BUILD_CRAFT


func _current_points_threshold() -> int:
	if _craft_mode == CraftMode.UPGRADE:
		var bot: Dictionary = _get_upgrade_entry()
		if bot.is_empty():
			return Inventory.BOT_BUILD_THRESHOLD
		var lvl: int = int(bot.get("upgrade_level", 0))
		var t: int = Inventory.get_upgrade_threshold(lvl)
		return t if t > 0 else Inventory.BOT_BUILD_THRESHOLD
	return Inventory.BOT_BUILD_THRESHOLD


func _current_required_materials() -> Array:
	## For BUILD: the full BOT_REQUIRED_MATERIALS entry (original counts).
	## For UPGRADE (spec §A4): 1x of each required material type.
	var base: Array = BOT_REQUIRED_MATERIALS.get(_craft_bot_id, [])
	if _craft_mode == CraftMode.BUILD:
		return base
	var scaled: Array = []
	for req in base:
		scaled.append({"ore_id": req.ore_id, "mineral_id": req.mineral_id, "count": 1})
	return scaled


func _get_upgrade_entry() -> Dictionary:
	if _craft_upgrade_index < 0 or _craft_upgrade_index >= Inventory.permanent_bots.size():
		return {}
	return Inventory.permanent_bots[_craft_upgrade_index]


func _compute_bot_stats(bot: Dictionary, upgrade_level: int) -> Dictionary:
	## Mirrors mining_floor_controller._spawn_permanent_bot stat scaling (spec §A3).
	##   max_health: base + base*0.20*lvl
	##   damage:     base + base*0.15*lvl
	##   atk_speed_mult: pow(1.05, lvl)
	## NOTE: mineral bonuses are NOT applied here — this preview shows stat-scaling
	## only, so the "before/after" delta represents the upgrade-level bump.
	## Read base_* fields (immutable) with fallback to the mirror fields for
	## legacy entries that haven't been migrated yet.
	var base_hp: float = float(bot.get("base_max_health", bot.get("max_health", 40.0)))
	var base_dmg: float = float(bot.get("base_damage", bot.get("damage", 0.0)))
	return {
		"max_health": base_hp + base_hp * 0.20 * float(upgrade_level),
		"damage":     base_dmg + base_dmg * 0.15 * float(upgrade_level),
		"atk_speed_mult": pow(1.05, float(upgrade_level)),
	}


func _merge_profiles(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = Inventory.empty_mineral_profile()
	for k in out.keys():
		out[k] = int(a.get(k, 0)) + int(b.get(k, 0))
	return out


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


func _count_ore_id_in_build_slot(ore_id: String, mineral_id: String) -> int:
	## Count how many of a specific ore_id (with optional mineral_id) are in the build slot.
	## mineral_id "" matches only plain ore (no mineral).
	var total: int = 0
	for k in _build_slot.keys():
		var entry: Dictionary = _build_slot[k]
		var entry_mineral_id: String = entry.mineral.id if entry.mineral else ""
		if entry.ore.id == ore_id and entry_mineral_id == mineral_id:
			total += int(entry.count)
	return total


func _check_required_materials() -> bool:
	## Returns true if all required materials (mode-scaled) are present in _build_slot.
	var reqs: Array = _current_required_materials()
	for req in reqs:
		var have: int = _count_ore_id_in_build_slot(req.ore_id, req.mineral_id)
		if have < int(req.count):
			return false
	return true


func _get_required_materials_display_name(ore_id: String, mineral_id: String) -> String:
	## Human-readable name for a required material.
	# Map known ore_ids to display names.
	var names: Dictionary = {
		"iron": "Iron", "copper": "Copper", "crystal": "Crystal",
		"silver": "Silver", "gold_ore": "Gold", "obsidian": "Obsidian",
		"diamond": "Diamond", "mythril": "Mythril",
	}
	var base: String = names.get(ore_id, ore_id.capitalize())
	if mineral_id != "":
		return "%s (%s)" % [base, mineral_id.capitalize()]
	return base


func _craft_add_one(ore: OreData, mineral: MineralData) -> void:
	var key: String = _ore_key(ore, mineral)
	var available: int = Inventory.count_ore_combined(ore.id, mineral.id if mineral else "")
	if _build_slot_count_for(key) >= available:
		return
	var focus_idx: int = _get_focused_button_index()
	if _build_slot.has(key):
		_build_slot[key].count = int(_build_slot[key].count) + 1
	else:
		_build_slot[key] = {"ore": ore, "mineral": mineral, "count": 1}
	_show_view(_current_craft_view(), focus_idx)


func _craft_remove_one(ore_key: String) -> void:
	if not _build_slot.has(ore_key):
		return
	var focus_idx: int = _get_focused_button_index()
	_build_slot[ore_key].count = int(_build_slot[ore_key].count) - 1
	if int(_build_slot[ore_key].count) <= 0:
		_build_slot.erase(ore_key)
	_show_view(_current_craft_view(), focus_idx)


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
	## Greedy fill: required materials first, then cheapest to reach threshold.
	_build_slot.clear()
	var stacks: Array = _collect_inventory_stacks()

	# Phase 1: Fill required materials first.
	var reqs: Array = _current_required_materials()
	# Track how many of each stack we've consumed (by key) so greedy phase skips them.
	var consumed: Dictionary = {}  # ore_key -> int
	for req in reqs:
		var needed: int = int(req.count)
		var target_ore_id: String = req.ore_id
		var target_mineral_id: String = req.mineral_id
		# Find matching stacks (prefer plain ore matching the requirement).
		for stack in stacks:
			if needed <= 0:
				break
			var ore: OreData = stack.ore
			var mineral: MineralData = stack.mineral
			var stack_mineral_id: String = mineral.id if mineral else ""
			if ore.id != target_ore_id or stack_mineral_id != target_mineral_id:
				continue
			var key: String = _ore_key(ore, mineral)
			var already_used: int = consumed.get(key, 0)
			var avail: int = int(stack.quantity) - already_used
			var take: int = mini(avail, needed)
			if take <= 0:
				continue
			if _build_slot.has(key):
				_build_slot[key].count = int(_build_slot[key].count) + take
			else:
				_build_slot[key] = {"ore": ore, "mineral": mineral, "count": take}
			consumed[key] = already_used + take
			needed -= take

	# Phase 2: Greedy fill remaining points (cheapest first, plain before mineral).
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
	var threshold: int = _current_points_threshold()
	var running: int = _build_slot_total_points()
	for stack in stacks:
		if running >= threshold:
			break
		var ore: OreData = stack.ore
		var mineral: MineralData = stack.mineral
		var qty: int = int(stack.quantity) - consumed.get(_ore_key(ore, mineral), 0)
		var pts: int = _points_for_tier(int(ore.tier))
		var key: String = _ore_key(ore, mineral)
		while qty > 0 and running < threshold:
			if _build_slot.has(key):
				_build_slot[key].count = int(_build_slot[key].count) + 1
			else:
				_build_slot[key] = {"ore": ore, "mineral": mineral, "count": 1}
			qty -= 1
			running += pts
	var focus_idx: int = _get_focused_button_index()
	_show_view(_current_craft_view(), focus_idx)


func _craft_build() -> void:
	## Spec §A6/§A4: validate, spend ores, then either append a new bot (BUILD)
	## or apply an upgrade tier to the selected bot (UPGRADE).
	var total_pts: int = _build_slot_total_points()
	var threshold: int = _current_points_threshold()
	if total_pts < threshold:
		return  # Defensive: button should be disabled.

	if not _check_required_materials():
		push_error("npc_lab: _craft_build called without required materials for %s — aborted" % _craft_bot_id)
		result_label.text = "Failed: missing required materials."
		return

	# UPGRADE mode: snapshot the bot ref & validate max-level before spending.
	var upgrade_bot: Dictionary = {}
	if _craft_mode == CraftMode.UPGRADE:
		upgrade_bot = _get_upgrade_entry()
		if upgrade_bot.is_empty():
			result_label.text = "Upgrade failed: bot not found."
			return
		if int(upgrade_bot.get("upgrade_level", 0)) >= Inventory.MAX_UPGRADE_LEVEL:
			result_label.text = "Already at max level."
			return

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
			push_error("npc_lab: spend_ore_combined failed for %s (mineral=%s) x%d — aborted" % [
				spend.ore_id, spend.mineral_id, spend.count,
			])
			result_label.text = "Failed: ore shortfall."
			return

	# 2. Compute raw-count mineral_profile (shared with preview) + resolve void rolls.
	var mineral_profile: Dictionary = _compute_raw_mineral_profile()
	var void_resolved: Array = []
	var void_count: int = int(mineral_profile.get("void", 0))
	for i in void_count:
		var rolled: String = Inventory.VOID_REAL_TYPES[randi() % Inventory.VOID_REAL_TYPES.size()]
		void_resolved.append(rolled)

	if _craft_mode == CraftMode.UPGRADE:
		# 3a. Apply upgrade delta.
		Inventory.upgrade_permanent_bot(upgrade_bot, mineral_profile, void_resolved)
		var new_lvl: int = int(upgrade_bot.get("upgrade_level", 0))
		result_label.text = "Upgraded %s to Lv %d!" % [String(upgrade_bot.get("display_name", "bot")), new_lvl]
		_build_slot.clear()
		_show_view(LabView.UPGRADE)
		_focus_first_button()
		return

	# 3b. BUILD: assemble a new entry.
	var spec: Dictionary = BOT_BUILD_SPECS.get(_craft_bot_id, {})
	var base_name: String = spec.get("display_name", _craft_bot_id.capitalize())
	var max_hp: float = float(spec.get("hp", 40.0))
	var dmg: float = float(spec.get("damage", 0.0))
	var cp_cost: int = int(spec.get("cp_cost", 1))
	var instance_number_preview: int = Inventory.count_permanent_bots_of_type(_craft_bot_id) + 1
	var entry_out: Dictionary = {
		"id": _craft_bot_id,
		"display_name": "%s #%d" % [base_name, instance_number_preview],
		"base_max_health": max_hp,
		"base_damage": dmg,
		"max_health": max_hp,
		"health": max_hp,
		"damage": dmg,
		"cp_cost": cp_cost,
		"knocked_out": false,
		"upgrade_level": 0,
		"mineral_profile": mineral_profile,
		"void_resolved": void_resolved,
	}

	# 4. Append (fills instance_number, emits bots_changed).
	Inventory.add_permanent_bot(entry_out)

	# 5. Return to Build Bot list.
	result_label.text = "Built %s!" % entry_out["display_name"]
	_build_slot.clear()
	_show_view(LabView.BUILD)
	_focus_first_button()


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
	_show_view(LabView.NECKLACE)


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
	_show_view(LabView.MERGE)


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
