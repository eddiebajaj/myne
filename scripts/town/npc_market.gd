class_name NPCMarket
extends Area2D
## Market NPC. Two-column sell UI: pick ores from backpack + storage, stage
## them in a sell slot, then confirm the sale.

signal menu_opened
signal menu_closed

const BATTERY_PRICE := 8  # Gold per battery (legacy, unused)

var player_in_range: bool = false
var menu_open: bool = false
var _touch_b_handled_frame: int = -1

# Sell-slot local state: {ore_key: {ore: OreData, mineral: MineralData, count: int}}
var _sell_slot: Dictionary = {}

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
@onready var menu_panel: PanelContainer = $CanvasLayer/MenuPanel
@onready var menu_vbox: VBoxContainer = $CanvasLayer/MenuPanel/VBox
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var inventory_label: Label = $CanvasLayer/MenuPanel/VBox/InventoryLabel
@onready var sell_button: Button = $CanvasLayer/MenuPanel/VBox/SellButton
@onready var buy_battery_button: Button = $CanvasLayer/MenuPanel/VBox/BuyBatteryButton
@onready var battery_label: Label = $CanvasLayer/MenuPanel/VBox/BatteryLabel
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton

var _breakdown_container: VBoxContainer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.color = Color(0.2, 0.7, 0.3)
	label.text = "Market [E]"
	label.visible = false
	menu_panel.visible = false
	var menu_layer: CanvasLayer = $CanvasLayer
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	# Hide legacy scene nodes — we build the new UI programmatically.
	sell_button.visible = false
	sell_button.disabled = true
	buy_battery_button.visible = false
	buy_battery_button.disabled = true
	battery_label.visible = false
	inventory_label.visible = false
	close_button.pressed.connect(_close_menu)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)
	# Programmatic container for the two-column sell UI.
	_breakdown_container = VBoxContainer.new()
	_breakdown_container.name = "Breakdown"
	menu_vbox.add_child(_breakdown_container)
	menu_vbox.move_child(_breakdown_container, inventory_label.get_index() + 1)


func _on_touch_a() -> void:
	if player_in_range and not menu_open:
		_open_menu()


func _on_touch_b() -> void:
	if menu_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		_close_menu()


func _process(_delta: float) -> void:
	if menu_open and Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame == Engine.get_process_frames():
			return
		_close_menu()
		return
	if player_in_range and not menu_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	get_tree().paused = true
	_sell_slot.clear()
	_refresh_ui()
	menu_opened.emit()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	_sell_slot.clear()
	get_tree().paused = false
	menu_closed.emit()


# ---------------------------------------------------------------------------
#  Sell actions
# ---------------------------------------------------------------------------

func _on_sell_selected(restore_focus_index: int = -1) -> void:
	if _sell_slot.is_empty():
		result_label.text = "Nothing selected."
		return
	var total_gold: int = 0
	for key in _sell_slot.keys():
		var entry: Dictionary = _sell_slot[key]
		var ore: OreData = entry.ore
		var mineral: MineralData = entry.mineral
		var count: int = int(entry.count)
		var unit_price: int = _unit_price(ore, mineral)
		total_gold += unit_price * count
		var mineral_id: String = mineral.id if mineral else ""
		Inventory.spend_ore_combined(ore.id, mineral_id, count)
	GameManager.add_gold(total_gold)
	_sell_slot.clear()
	if total_gold > 0:
		result_label.text = "Sold for %d gold!" % total_gold
		_spawn_gold_popup(total_gold)
	else:
		result_label.text = "Nothing to sell."
	_refresh_ui(restore_focus_index)


func _on_sell_all() -> void:
	## Fill the sell slot with every available ore, then immediately sell.
	var focus_idx: int = _get_focused_button_index()
	_sell_slot.clear()
	var stacks: Array = _collect_inventory_stacks()
	for stack in stacks:
		var key: String = _ore_key(stack.ore, stack.mineral)
		_sell_slot[key] = {"ore": stack.ore, "mineral": stack.mineral, "count": int(stack.quantity)}
	_on_sell_selected(focus_idx)


func _add_one_to_slot(ore: OreData, mineral: MineralData) -> void:
	var key: String = _ore_key(ore, mineral)
	var mineral_id: String = mineral.id if mineral else ""
	var available: int = Inventory.count_ore_combined(ore.id, mineral_id)
	var already: int = int(_sell_slot[key].count) if _sell_slot.has(key) else 0
	if already >= available:
		return
	var focus_idx: int = _get_focused_button_index()
	if _sell_slot.has(key):
		_sell_slot[key].count = already + 1
	else:
		_sell_slot[key] = {"ore": ore, "mineral": mineral, "count": 1}
	_refresh_ui(focus_idx)


func _remove_one_from_slot(ore: OreData, mineral: MineralData) -> void:
	var key: String = _ore_key(ore, mineral)
	if not _sell_slot.has(key):
		return
	var focus_idx: int = _get_focused_button_index()
	_sell_slot[key].count = int(_sell_slot[key].count) - 1
	if int(_sell_slot[key].count) <= 0:
		_sell_slot.erase(key)
	_refresh_ui(focus_idx)


# ---------------------------------------------------------------------------
#  UI rebuild
# ---------------------------------------------------------------------------

func _refresh_ui(restore_focus_index: int = -1) -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	_refresh_breakdown(restore_focus_index)


func _refresh_breakdown(restore_focus_index: int = -1) -> void:
	if _breakdown_container == null:
		return
	for child in _breakdown_container.get_children():
		child.queue_free()

	var header: Label = Label.new()
	header.text = "— SELL ORE —"
	header.add_theme_font_size_override("font_size", 18)
	_breakdown_container.add_child(header)

	var stacks: Array = _collect_inventory_stacks()

	# --- Two-column layout ---
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_breakdown_container.add_child(columns)

	# LEFT: Available ores
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var left_hdr: Label = Label.new()
	left_hdr.text = "Available (A = add 1)"
	left.add_child(left_hdr)

	if stacks.is_empty():
		var empty: Label = Label.new()
		empty.text = "  (no ore)"
		left.add_child(empty)
	for stack in stacks:
		var ore: OreData = stack.ore
		var mineral: MineralData = stack.mineral
		var key: String = _ore_key(ore, mineral)
		var total_qty: int = int(stack.quantity)
		var staged: int = int(_sell_slot[key].count) if _sell_slot.has(key) else 0
		var remaining: int = total_qty - staged
		var unit: int = _unit_price(ore, mineral)
		var row_btn: Button = Button.new()
		row_btn.text = "%s  x%d  @%dg" % [_ore_label(ore, mineral), remaining, unit]
		row_btn.disabled = remaining <= 0
		var ore_cap: OreData = ore
		var min_cap: MineralData = mineral
		row_btn.pressed.connect(func(): _add_one_to_slot(ore_cap, min_cap))
		left.add_child(row_btn)

	# RIGHT: Sell slot
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var right_hdr: Label = Label.new()
	right_hdr.text = "Sell Slot (A = remove 1)"
	right.add_child(right_hdr)

	if _sell_slot.is_empty():
		var empty2: Label = Label.new()
		empty2.text = "  (empty)"
		right.add_child(empty2)
	else:
		for key in _sell_slot.keys():
			var entry: Dictionary = _sell_slot[key]
			var ore: OreData = entry.ore
			var mineral: MineralData = entry.mineral
			var count: int = int(entry.count)
			var unit: int = _unit_price(ore, mineral)
			var slot_btn: Button = Button.new()
			slot_btn.text = "%s  x%d  = %dg" % [_ore_label(ore, mineral), count, unit * count]
			var ore_cap: OreData = ore
			var min_cap: MineralData = mineral
			slot_btn.pressed.connect(func(): _remove_one_from_slot(ore_cap, min_cap))
			right.add_child(slot_btn)

	# --- Running total ---
	var running_total: int = _sell_slot_total_gold()
	var total_lbl: Label = Label.new()
	total_lbl.text = "Gold: +%dg" % running_total
	total_lbl.add_theme_font_size_override("font_size", 18)
	total_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_breakdown_container.add_child(total_lbl)

	# --- Bottom buttons ---
	var btn_row: HBoxContainer = HBoxContainer.new()
	_breakdown_container.add_child(btn_row)

	var sell_all_btn: Button = Button.new()
	sell_all_btn.text = "Sell All"
	sell_all_btn.disabled = stacks.is_empty()
	sell_all_btn.pressed.connect(_on_sell_all)
	btn_row.add_child(sell_all_btn)

	var sell_sel_btn: Button = Button.new()
	sell_sel_btn.text = "Sell Selected"
	sell_sel_btn.disabled = _sell_slot.is_empty()
	sell_sel_btn.pressed.connect(_on_sell_selected)
	btn_row.add_child(sell_sel_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_menu)
	btn_row.add_child(cancel_btn)

	# --- Focus wiring ---
	_wire_focus(restore_focus_index)


func _wire_focus(restore_focus_index: int = -1) -> void:
	var focusables: Array = FocusUtil.collect_focusables(_breakdown_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	focusables.append(close_button)
	FocusUtil.wire_vertical_wrap(focusables)
	if restore_focus_index >= 0:
		_focus_button_at_index(restore_focus_index)
	else:
		_grab_first_focus()


func _get_focused_button_index() -> int:
	var focused := _breakdown_container.get_viewport().gui_get_focus_owner()
	if focused == null:
		return -1
	var focusables: Array = FocusUtil.collect_focusables(_breakdown_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	focusables.append(close_button)
	return focusables.find(focused)


func _focus_button_at_index(idx: int) -> void:
	# Defer focus restoration to the next frame so any queue_free'd old focus
	# owner is fully gone and Godot's internal focus state has settled. See the
	# matching comment in npc_lab.gd — plain call_deferred races with the
	# previous focus owner's tree_exiting (which clears focus) and occasionally
	# loses, leaving the player with no focused button.
	await get_tree().process_frame
	var focusables: Array = FocusUtil.collect_focusables(_breakdown_container)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	focusables.append(close_button)
	if focusables.is_empty():
		close_button.grab_focus()
		return
	idx = clampi(idx, 0, focusables.size() - 1)
	focusables[idx].grab_focus()


func _grab_first_focus() -> void:
	var focusables: Array = FocusUtil.collect_focusables(_breakdown_container)
	for ctrl in focusables:
		if ctrl.is_queued_for_deletion():
			continue
		if ctrl is Button and not ctrl.disabled:
			ctrl.call_deferred("grab_focus")
			return
	close_button.call_deferred("grab_focus")


# ---------------------------------------------------------------------------
#  Gold popup (unchanged)
# ---------------------------------------------------------------------------

func _spawn_gold_popup(amount: int) -> void:
	var popup: Label = Label.new()
	popup.text = "+%dg" % amount
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	popup.add_theme_font_size_override("font_size", 28)
	popup.z_index = 10
	popup.position = menu_panel.position + Vector2(180, 220)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: CanvasLayer = $CanvasLayer
	layer.add_child(popup)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 40.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)


# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------

func _ore_key(ore: OreData, mineral: MineralData) -> String:
	if mineral:
		return ore.id + ":" + mineral.id
	return ore.id


func _ore_label(ore: OreData, mineral: MineralData) -> String:
	var base: String = ore.display_name if ore.display_name != "" else ore.id
	if mineral:
		return "%s (%s)" % [base, mineral.display_name]
	return base


func _unit_price(ore: OreData, mineral: MineralData) -> int:
	var base_value: int = int(ore.value)
	var bonus: int = int(mineral.sell_bonus) if mineral else 0
	return base_value + bonus


func _sell_slot_total_gold() -> int:
	var total: int = 0
	for key in _sell_slot.keys():
		var entry: Dictionary = _sell_slot[key]
		total += _unit_price(entry.ore, entry.mineral) * int(entry.count)
	return total


func _collect_inventory_stacks() -> Array:
	## Merged list of {ore, mineral, quantity} combining backpack + storage.
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


func _add_grid_label(grid: GridContainer, text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	grid.add_child(lbl)


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
