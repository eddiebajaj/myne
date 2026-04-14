extends Control
## In-mine HUD — floor, HP+armor, backpack, merge charges, artifacts.

@onready var floor_label: Label = %FloorLabel
@onready var backpack_bar: ProgressBar = %BackpackBar
@onready var backpack_label: Label = %BackpackLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var armor_label: Label = %ArmorLabel
@onready var battery_label: Label = %BatteryLabel  # Repurposed: shows merge charges
@onready var artifact_label: Label = %ArtifactLabel
@onready var full_warning: Label = %FullWarning
@onready var build_panel: PanelContainer = %BuildPanel  # Legacy node, kept hidden
@onready var backpack_container: PanelContainer = %BackpackContainer
@onready var merge_panel: PanelContainer = %MergePanel

const MERGE_COOLDOWN_SECONDS := 30.0

var _touch_b_handled_frame: int = -1  # Frame guard for B-button double-fire

# ── Backpack state (fully owned by mining_hud, no autoload needed) ──
# ── Merge state ──
var _merge_active: bool = false
var _merge_type: String = ""
var _merge_timer: float = 0.0
var _merge_panel_open: bool = false
var _merge_list: VBoxContainer = null
var _merge_timer_bar: ProgressBar = null
var _merge_timer_label: Label = null
var _merge_timer_max: float = 15.0
var _merge_cooldown_timer: float = 0.0  # Seconds remaining before next merge allowed
var _player_ref: Player = null
var _touch_x_handled_frame: int = -1

var _backpack_open: bool = false
var _bp_grid: GridContainer = null
var _bp_capacity_label: Label = null
var _bp_gold_label: Label = null
var _bp_battery_label: Label = null  # Repurposed: merge charge readout inside backpack
var _bp_followers_header: Label = null
var _bp_followers_list: VBoxContainer = null

# Inspect popup state
var _inspect_popup: PanelContainer = null
var _inspect_dim: ColorRect = null
var _inspect_ore_id: String = ""
var _inspect_mineral_id: String = ""

const CELL_SIZE_DESKTOP: int = 64
const CELL_SIZE_MOBILE: int = 80
const GRID_COLS: int = 4
const INSPECT_BUTTON_MIN_H: int = 64


func _ready() -> void:
	Inventory.inventory_changed.connect(_update_backpack)
	Inventory.backpack_full.connect(_on_backpack_full)
	GameManager.floor_changed.connect(_on_floor_changed)
	build_panel.visible = false
	full_warning.visible = false
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_b_pressed.connect(_on_touch_b)
		touch.action_y_pressed.connect(_on_touch_y)
		touch.action_x_pressed.connect(_on_touch_x)
	_build_backpack_ui()
	_build_merge_panel_ui()
	_build_merge_timer_ui()
	_update_backpack()
	_update_extras()
	_on_floor_changed(GameManager.current_floor)
	# Restore merge state if persisted across floor transition
	if GameManager.merge_active:
		_restore_merge_from_gm()


# ── Player hookup ───────────────────────────────────────────────────

func set_player(player: Player) -> void:
	_player_ref = player
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health, player.armor, player.max_armor)


# ── Touch / keyboard input routing ──────────────────────────────────

func _on_touch_b() -> void:
	# Sprint 5: B is pure cancel. Closes any open panel, otherwise does nothing.
	_touch_b_handled_frame = Engine.get_process_frames()
	if _merge_panel_open:
		_close_merge_panel()
		return
	if _backpack_open:
		_close_backpack()
		return


func _on_touch_x() -> void:
	_touch_x_handled_frame = Engine.get_process_frames()
	if _merge_panel_open:
		_close_merge_panel()
		return
	if _merge_active:
		return  # Already merged, X does nothing
	if _backpack_open:
		return  # Other panels open
	if not Inventory.merge_unlocked:
		_show_merge_warning("Merge locked — reach B5F first")
		return
	_open_merge_panel()


func _on_touch_y() -> void:
	# Close merge panel if open (mutual exclusion)
	if _merge_panel_open:
		_close_merge_panel()
		return
	if _backpack_open:
		_close_backpack()
	else:
		_open_backpack()
		# Set B guard so _process can't re-trigger on same frame
		_touch_b_handled_frame = Engine.get_process_frames()


func _unhandled_input(event: InputEvent) -> void:
	# Consume toggle_backpack (Tab) here so the BackpackPanel autoload
	# (which has broken @onready refs in-mine) never receives it.
	if event.is_action_pressed("toggle_backpack"):
		if _backpack_open:
			_close_backpack()
		else:
			_open_backpack()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _merge_panel_open:
		_close_merge_panel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _backpack_open:
		_close_backpack()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# --- Merge timer ---
	if _merge_active:
		_merge_timer -= delta
		_update_merge_timer_display()
		if _merge_timer <= 0:
			_end_merge()
		# Persist to GameManager for floor transitions
		GameManager.merge_time_remaining = _merge_timer

	# --- Merge cooldown (runs even while paused is false; _process respects pause) ---
	if _merge_cooldown_timer > 0.0:
		_merge_cooldown_timer = maxf(0.0, _merge_cooldown_timer - delta)
		_update_extras()

	# --- X button: merge panel toggle (keyboard fallback) ---
	if Input.is_action_just_pressed("action_x"):
		if _touch_x_handled_frame != Engine.get_process_frames():
			if _merge_panel_open:
				_close_merge_panel()
			elif not _merge_active and not _backpack_open:
				if not Inventory.merge_unlocked:
					_show_merge_warning("Merge locked — reach B5F first")
				else:
					_open_merge_panel()

	# --- B button: pure cancel (keyboard fallback) ---
	if Input.is_action_just_pressed("action_b") or Input.is_action_just_pressed("build_menu"):
		if _touch_b_handled_frame != Engine.get_process_frames():
			if _merge_panel_open:
				_close_merge_panel()
			elif _backpack_open:
				_close_backpack()

	# --- Y button: backpack toggle (keyboard fallback) ---
	if Input.is_action_just_pressed("action_y"):
		if _merge_panel_open:
			_close_merge_panel()
		elif _backpack_open:
			_close_backpack()
		else:
			_open_backpack()


# ── Backpack panel (built in-scene, no autoload) ────────────────────

func _build_backpack_ui() -> void:
	backpack_container.process_mode = Node.PROCESS_MODE_ALWAYS
	backpack_container.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14, 0.96)
	style.border_color = Color(0.5, 0.5, 0.6, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	backpack_container.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backpack_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "BACKPACK"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_bp_capacity_label = Label.new()
	_bp_capacity_label.text = "0 / 0"
	header.add_child(_bp_capacity_label)

	# Body: grid + side panel
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	vbox.add_child(body)

	# Grid wrap
	var grid_wrap := PanelContainer.new()
	grid_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid_style := StyleBoxFlat.new()
	grid_style.bg_color = Color(0.08, 0.08, 0.1, 1.0)
	grid_style.content_margin_left = 6
	grid_style.content_margin_right = 6
	grid_style.content_margin_top = 6
	grid_style.content_margin_bottom = 6
	grid_wrap.add_theme_stylebox_override("panel", grid_style)
	body.add_child(grid_wrap)

	_bp_grid = GridContainer.new()
	_bp_grid.columns = GRID_COLS
	_bp_grid.add_theme_constant_override("h_separation", 4)
	_bp_grid.add_theme_constant_override("v_separation", 4)
	grid_wrap.add_child(_bp_grid)

	# Side panel
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(160, 0)
	side.add_theme_constant_override("separation", 6)
	body.add_child(side)

	_bp_gold_label = Label.new()
	_bp_gold_label.text = "Gold: 0"
	side.add_child(_bp_gold_label)

	_bp_battery_label = Label.new()
	_bp_battery_label.text = "Merge: 0/0"
	side.add_child(_bp_battery_label)

	_bp_followers_header = Label.new()
	_bp_followers_header.text = "FOLLOWERS"
	side.add_child(_bp_followers_header)

	_bp_followers_list = VBoxContainer.new()
	side.add_child(_bp_followers_list)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.pressed.connect(_close_backpack)
	vbox.add_child(close_btn)


func _open_backpack() -> void:
	if _backpack_open:
		return
	_close_merge_panel()
	_backpack_open = true
	backpack_container.visible = true
	get_tree().paused = true
	_refresh_bp()


func _close_backpack() -> void:
	if not _backpack_open:
		return
	_backpack_open = false
	_close_inspect_popup()
	backpack_container.visible = false
	get_tree().paused = false


func _refresh_bp() -> void:
	if not _backpack_open:
		return
	_refresh_bp_header()
	_refresh_bp_grid()
	_refresh_bp_side()


func _refresh_bp_header() -> void:
	var used: int = Inventory.get_used_slots()
	var cap: int = Inventory.get_max_capacity()
	_bp_capacity_label.text = "%d / %d" % [used, cap]


func _refresh_bp_grid() -> void:
	for child in _bp_grid.get_children():
		child.queue_free()
	var cap: int = Inventory.get_max_capacity()
	var cell_size: int = CELL_SIZE_MOBILE if _is_touch_device() else CELL_SIZE_DESKTOP
	var cells: Array[Dictionary] = []
	for slot in Inventory.get_ore_stacks():
		var qty: int = int(slot.quantity)
		for i in range(qty):
			cells.append({"ore": slot.ore, "mineral": slot.mineral})
	for i in range(cap):
		var cell_data: Dictionary = cells[i] if i < cells.size() else {}
		_bp_grid.add_child(_build_bp_cell(cell_data, cell_size))


func _build_bp_cell(cell_data: Dictionary, cell_size: int) -> Control:
	var cell: Panel = Panel.new()
	cell.custom_minimum_size = Vector2(cell_size, cell_size)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = Color(0.5, 0.5, 0.55, 1.0)
	if cell_data.is_empty():
		style.bg_color = Color(0.15, 0.15, 0.18, 1.0)
	else:
		var ore: OreData = cell_data.ore
		style.bg_color = ore.color
	cell.add_theme_stylebox_override("panel", style)
	if cell_data.is_empty():
		return cell
	var ore_data: OreData = cell_data.ore
	var mineral: MineralData = cell_data.mineral
	if mineral != null:
		var pip: ColorRect = ColorRect.new()
		pip.color = mineral.color
		pip.size = Vector2(16, 16)
		pip.position = Vector2(cell_size - 20, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pip)
	cell.set_meta("ore_id", ore_data.id)
	cell.set_meta("mineral_id", mineral.id if mineral != null else "")
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_on_bp_cell_input.bind(cell))
	return cell


func _on_bp_cell_input(event: InputEvent, cell: Control) -> void:
	var is_click: bool = event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var is_tap: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if not (is_click or is_tap):
		return
	var ore_id: String = String(cell.get_meta("ore_id", ""))
	var mineral_id: String = String(cell.get_meta("mineral_id", ""))
	if ore_id == "":
		return
	_open_inspect_popup(ore_id, mineral_id)


func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


# ── Inspect popup (ore detail + drop) ───────────────────────────────

func _open_inspect_popup(ore_id: String, mineral_id: String) -> void:
	_close_inspect_popup()
	_inspect_ore_id = ore_id
	_inspect_mineral_id = mineral_id

	# Dim overlay — tap outside to dismiss
	_inspect_dim = ColorRect.new()
	_inspect_dim.color = Color(0, 0, 0, 0.35)
	_inspect_dim.anchor_right = 1.0
	_inspect_dim.anchor_bottom = 1.0
	_inspect_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_inspect_dim.gui_input.connect(_on_inspect_dim_input)
	backpack_container.add_child(_inspect_dim)

	# Popup panel
	_inspect_popup = PanelContainer.new()
	_inspect_popup.process_mode = Node.PROCESS_MODE_ALWAYS
	_inspect_popup.custom_minimum_size = Vector2(360, 260)
	_inspect_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = Color(0.12, 0.12, 0.16, 0.98)
	popup_style.border_color = Color(0.7, 0.7, 0.8, 1.0)
	popup_style.border_width_top = 2
	popup_style.border_width_bottom = 2
	popup_style.border_width_left = 2
	popup_style.border_width_right = 2
	popup_style.content_margin_left = 16
	popup_style.content_margin_right = 16
	popup_style.content_margin_top = 14
	popup_style.content_margin_bottom = 14
	_inspect_popup.add_theme_stylebox_override("panel", popup_style)
	backpack_container.add_child(_inspect_popup)

	_populate_inspect_popup()
	_center_inspect_popup()


func _populate_inspect_popup() -> void:
	if _inspect_popup == null:
		return
	for child in _inspect_popup.get_children():
		child.queue_free()
	var slot: Dictionary = _find_stack(_inspect_ore_id, _inspect_mineral_id)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_inspect_popup.add_child(vbox)
	if slot.is_empty():
		var gone_label: Label = Label.new()
		gone_label.text = "(stack empty)"
		vbox.add_child(gone_label)
		var close_only: Button = Button.new()
		close_only.text = "Close"
		close_only.custom_minimum_size = Vector2(0, INSPECT_BUTTON_MIN_H)
		close_only.pressed.connect(_close_inspect_popup)
		vbox.add_child(close_only)
		return
	var ore: OreData = slot.ore
	var mineral: MineralData = slot.mineral
	var qty: int = int(slot.quantity)
	var title: Label = Label.new()
	title.text = ore.display_name + " Ore"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
	var tier_label: Label = Label.new()
	tier_label.text = "Tier %d    x%d" % [ore.tier, qty]
	vbox.add_child(tier_label)
	if mineral != null:
		var mineral_label: Label = Label.new()
		mineral_label.text = "%s — %s" % [mineral.display_name, mineral.bot_effect_description]
		mineral_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mineral_label.custom_minimum_size = Vector2(320, 0)
		vbox.add_child(mineral_label)
	var base_value: int = ore.value
	var mineral_bonus: int = mineral.sell_bonus if mineral != null else 0
	var sell_text: String
	if mineral_bonus > 0:
		sell_text = "Sell: %d gold  (%d base + %d mineral)" % [base_value + mineral_bonus, base_value, mineral_bonus]
	else:
		sell_text = "Sell: %d gold" % base_value
	var sell_label: Label = Label.new()
	sell_label.text = sell_text
	vbox.add_child(sell_label)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)
	var drop_button: Button = Button.new()
	drop_button.text = "Drop 1"
	drop_button.custom_minimum_size = Vector2(140, INSPECT_BUTTON_MIN_H)
	drop_button.pressed.connect(_on_drop_pressed)
	button_row.add_child(drop_button)
	var close_button_inner: Button = Button.new()
	close_button_inner.text = "Close"
	close_button_inner.custom_minimum_size = Vector2(140, INSPECT_BUTTON_MIN_H)
	close_button_inner.pressed.connect(_close_inspect_popup)
	button_row.add_child(close_button_inner)


func _center_inspect_popup() -> void:
	if _inspect_popup == null:
		return
	await get_tree().process_frame
	if _inspect_popup == null:
		return
	var container_rect: Rect2 = backpack_container.get_global_rect()
	var popup_size: Vector2 = _inspect_popup.size
	if popup_size == Vector2.ZERO:
		popup_size = _inspect_popup.custom_minimum_size
	var origin: Vector2 = container_rect.position + (container_rect.size - popup_size) * 0.5
	_inspect_popup.global_position = origin


func _find_stack(ore_id: String, mineral_id: String) -> Dictionary:
	for slot in Inventory.get_ore_stacks():
		var this_ore: OreData = slot.ore
		var this_mineral: MineralData = slot.mineral
		var this_mineral_id: String = this_mineral.id if this_mineral != null else ""
		if this_ore.id == ore_id and this_mineral_id == mineral_id:
			return slot
	return {}


func _on_drop_pressed() -> void:
	if _inspect_ore_id == "":
		return
	var ok: bool = Inventory.drop_one(_inspect_ore_id, _inspect_mineral_id)
	if not ok:
		_close_inspect_popup()
		return
	_refresh_bp_grid()
	_refresh_bp_header()
	var remaining: int = Inventory.get_stack_quantity(_inspect_ore_id, _inspect_mineral_id)
	if remaining <= 0:
		_close_inspect_popup()
	else:
		_populate_inspect_popup()


func _on_inspect_dim_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton \
		and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	var is_tap: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	if is_click or is_tap:
		_close_inspect_popup()


func _close_inspect_popup() -> void:
	if _inspect_popup != null:
		_inspect_popup.queue_free()
		_inspect_popup = null
	if _inspect_dim != null:
		_inspect_dim.queue_free()
		_inspect_dim = null
	_inspect_ore_id = ""
	_inspect_mineral_id = ""


func _refresh_bp_side() -> void:
	_bp_gold_label.text = "Gold: %d" % GameManager.gold
	_bp_battery_label.text = "Merge: %d/%d" % [Inventory.merge_charges, Inventory.merge_charges_max]
	for child in _bp_followers_list.get_children():
		child.queue_free()
	_bp_followers_header.text = "FOLLOWERS"
	var has_any := false
	# Show permanent bots (from run_party)
	for entry in Inventory.run_party:
		has_any = true
		var row: HBoxContainer = HBoxContainer.new()
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		pip.color = Color(0.3, 0.9, 1.0)  # cyan for permanent bots
		row.add_child(pip)
		var name_label: Label = Label.new()
		var dname: String = entry.get("display_name", "Companion")
		if entry.get("knocked_out", false):
			name_label.text = "  %s (KO)" % dname
			name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		else:
			name_label.text = "  %s" % dname
		row.add_child(name_label)
		_bp_followers_list.add_child(row)
	# Show disposable follower bots
	for bot_entry in Inventory.follower_bots:
		has_any = true
		var row: HBoxContainer = HBoxContainer.new()
		var pip: ColorRect = ColorRect.new()
		pip.custom_minimum_size = Vector2(12, 12)
		var tier: int = int(bot_entry.get("ore_tier", 1))
		var tier_colors: Array = [
			Color(0.8, 0.8, 0.8),
			Color(0.4, 0.8, 1.0),
			Color(1.0, 0.8, 0.3),
			Color(1.0, 0.4, 0.9),
		]
		pip.color = tier_colors[clampi(tier - 1, 0, 3)]
		row.add_child(pip)
		var name_label: Label = Label.new()
		var bot_data: BotData = bot_entry.get("data") as BotData
		name_label.text = "  " + (bot_data.display_name if bot_data else "Bot")
		row.add_child(name_label)
		_bp_followers_list.add_child(row)
	if not has_any:
		var empty: Label = Label.new()
		empty.text = "No followers"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_bp_followers_list.add_child(empty)


# ── Build menu removed in Sprint 5 (bots are built at the Lab in town) ──


# ── Merge panel ─────────────────────────────────────────────────────

func _build_merge_panel_ui() -> void:
	merge_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	merge_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.16, 0.96)
	style.border_color = Color(0.3, 0.9, 1.0, 1.0)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	merge_panel.add_theme_stylebox_override("panel", style)

	_merge_list = VBoxContainer.new()
	_merge_list.add_theme_constant_override("separation", 6)
	merge_panel.add_child(_merge_list)


func _build_merge_timer_ui() -> void:
	## Merge timer bar — thin bar below the HP bar area, hidden by default.
	_merge_timer_bar = ProgressBar.new()
	_merge_timer_bar.name = "MergeTimerBar"
	_merge_timer_bar.layout_mode = 1
	_merge_timer_bar.anchors_preset = 0
	_merge_timer_bar.offset_left = 10
	_merge_timer_bar.offset_top = 70
	_merge_timer_bar.offset_right = 180
	_merge_timer_bar.offset_bottom = 82
	_merge_timer_bar.show_percentage = false
	_merge_timer_bar.visible = false
	# Cyan color via stylebox
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.9, 1.0, 0.9)
	_merge_timer_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	_merge_timer_bar.add_theme_stylebox_override("background", bg_style)
	add_child(_merge_timer_bar)

	_merge_timer_label = Label.new()
	_merge_timer_label.name = "MergeTimerLabel"
	_merge_timer_label.layout_mode = 1
	_merge_timer_label.anchors_preset = 0
	_merge_timer_label.offset_left = 10
	_merge_timer_label.offset_top = 70
	_merge_timer_label.offset_right = 180
	_merge_timer_label.offset_bottom = 82
	_merge_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merge_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_merge_timer_label.add_theme_font_size_override("font_size", 10)
	_merge_timer_label.visible = false
	_merge_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_merge_timer_label)


func _populate_merge_list() -> void:
	for child in _merge_list.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "MERGE WITH SCOUT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_merge_list.add_child(title)

	var sep1 := Control.new()
	sep1.custom_minimum_size = Vector2(0, 4)
	_merge_list.add_child(sep1)

	var cooldown_active: bool = _merge_cooldown_timer > 0.0
	var no_charges: bool = Inventory.merge_charges <= 0
	var charges_line: String = "Charges: %d/%d" % [Inventory.merge_charges, Inventory.merge_charges_max]
	if cooldown_active:
		charges_line += "    Cooldown: %.0fs" % _merge_cooldown_timer
	var info_lbl := Label.new()
	info_lbl.text = charges_line
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_merge_list.add_child(info_lbl)

	# Upper Body button
	var upper_btn := Button.new()
	upper_btn.text = "Upper Body — Crystal Shots\nRapid-fire, +8 damage, 180px range\nDuration: %.0fs | Cost: 1 charge" % _get_merge_duration()
	upper_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	upper_btn.custom_minimum_size = Vector2(0, 70)
	upper_btn.disabled = cooldown_active or no_charges
	upper_btn.pressed.connect(func(): _execute_merge("upper"))
	_merge_list.add_child(upper_btn)

	# Lower Body button
	var lower_btn := Button.new()
	lower_btn.text = "Lower Body — Crystal Dash\n350 speed, +5 armor, doubled dodge\nDuration: %.0fs | Cost: 1 charge" % _get_merge_duration()
	lower_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lower_btn.custom_minimum_size = Vector2(0, 70)
	lower_btn.disabled = cooldown_active or no_charges
	lower_btn.pressed.connect(func(): _execute_merge("lower"))
	_merge_list.add_child(lower_btn)

	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(0, 4)
	_merge_list.add_child(sep2)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_close_merge_panel)
	_merge_list.add_child(cancel_btn)


func _open_merge_panel() -> void:
	if _merge_panel_open or _merge_active:
		return
	_close_backpack()
	_merge_panel_open = true
	merge_panel.visible = true
	get_tree().paused = true
	_populate_merge_list()


func _close_merge_panel() -> void:
	if not _merge_panel_open:
		return
	_merge_panel_open = false
	merge_panel.visible = false
	get_tree().paused = false


func _get_merge_duration() -> float:
	# TODO: battery tier selection when multiple tiers exist
	return 15.0


func _execute_merge(type: String) -> void:
	_close_merge_panel()

	# Check: Scout alive + merge charges available + cooldown clear
	var scout_alive := false
	for entry in Inventory.run_party:
		if entry.get("id", "") == "scout" and not entry.get("knocked_out", false):
			scout_alive = true
			break

	if not scout_alive:
		_show_merge_warning("Scout is knocked out!")
		return
	if _merge_cooldown_timer > 0.0:
		_show_merge_warning("Merge on cooldown (%.0fs)" % _merge_cooldown_timer)
		return
	if Inventory.merge_charges <= 0:
		_show_merge_warning("No merge charges!")
		return

	# Consume 1 merge charge
	if not Inventory.use_merge_charge():
		_show_merge_warning("No merge charges!")
		return
	_update_extras()

	# Find and remove Scout from the floor
	var floor_root := get_tree().current_scene
	if floor_root:
		for bot in get_tree().get_nodes_in_group("permanent_bots"):
			if bot is PermanentBot and bot.bot_id == "scout":
				bot.queue_free()
				break

	# Apply merge stats to player
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.apply_merge(type)

	# Start merge timer
	_merge_type = type
	_merge_timer_max = _get_merge_duration()
	_merge_timer = _merge_timer_max
	_merge_active = true

	# Show timer bar
	_merge_timer_bar.visible = true
	_merge_timer_bar.max_value = _merge_timer_max
	_merge_timer_bar.value = _merge_timer
	_merge_timer_label.visible = true

	# Persist to GameManager
	GameManager.merge_active = true
	GameManager.merge_type = type
	GameManager.merge_time_remaining = _merge_timer


func _end_merge() -> void:
	_merge_active = false
	_merge_timer = 0.0

	# Revert player stats
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.revert_merge()

	# Respawn Scout near player
	_respawn_scout_after_merge()

	# Hide timer bar
	_merge_timer_bar.visible = false
	_merge_timer_label.visible = false

	# Clear GameManager state
	GameManager.merge_active = false
	GameManager.merge_type = ""
	GameManager.merge_time_remaining = 0.0

	_merge_type = ""

	# Start cooldown before next merge is allowed
	_merge_cooldown_timer = MERGE_COOLDOWN_SECONDS
	_update_extras()


func _respawn_scout_after_merge() -> void:
	## Respawn the Scout near the player after merge expires.
	var floor_controller = get_tree().current_scene
	if floor_controller == null or not floor_controller.has_method("_spawn_permanent_bot"):
		# Fallback: can't respawn if no floor controller
		return
	# Find scout in run_party
	for entry in Inventory.run_party:
		if entry.get("id", "") == "scout":
			entry["knocked_out"] = false  # Ensure not knocked out
			var spawn_pos := Vector2.ZERO
			if _player_ref and is_instance_valid(_player_ref):
				spawn_pos = _player_ref.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			floor_controller._spawn_permanent_bot(entry, spawn_pos)
			break


func _update_merge_timer_display() -> void:
	if not _merge_active:
		return
	_merge_timer_bar.value = maxf(_merge_timer, 0.0)
	_merge_timer_label.text = "MERGE: %.1fs" % maxf(_merge_timer, 0.0)
	# Flash when < 3s remaining
	if _merge_timer < 3.0:
		var flash := fmod(Time.get_ticks_msec() / 1000.0, 0.4)
		_merge_timer_bar.modulate.a = 0.5 if flash < 0.2 else 1.0
		_merge_timer_label.modulate.a = _merge_timer_bar.modulate.a
	else:
		_merge_timer_bar.modulate.a = 1.0
		_merge_timer_label.modulate.a = 1.0


func _show_merge_warning(text: String) -> void:
	if full_warning:
		full_warning.text = text
		full_warning.visible = true
		var tween := create_tween()
		tween.tween_property(full_warning, "modulate:a", 1.0, 0.0)
		tween.tween_interval(1.5)
		tween.tween_property(full_warning, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			full_warning.visible = false
			full_warning.modulate.a = 1.0
		)


func _restore_merge_from_gm() -> void:
	## Called on floor load if GameManager says merge was active.
	## Reapply merge to the new player node and resume the timer.
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.apply_merge(GameManager.merge_type)
	_merge_type = GameManager.merge_type
	_merge_timer_max = _get_merge_duration()
	_merge_timer = GameManager.merge_time_remaining
	_merge_active = true
	_merge_timer_bar.visible = true
	_merge_timer_bar.max_value = _merge_timer_max
	_merge_timer_bar.value = _merge_timer
	_merge_timer_label.visible = true


# ── HUD updates ─────────────────────────────────────────────────────

func _update_backpack() -> void:
	var used := Inventory.get_used_slots()
	var max_cap := Inventory.get_max_capacity()
	var bonus := Inventory.get_remaining_slots() + used - max_cap
	backpack_bar.max_value = max_cap + bonus
	backpack_bar.value = used
	backpack_label.text = "Backpack: %d/%d" % [used, max_cap + bonus]
	_update_extras()


func _on_backpack_full() -> void:
	full_warning.visible = true
	var tween := create_tween().set_loops(4)
	tween.tween_property(full_warning, "modulate:a", 0.3, 0.3)
	tween.tween_property(full_warning, "modulate:a", 1.0, 0.3)


func _on_floor_changed(floor_num: int) -> void:
	floor_label.text = "B%dF (T%d)" % [floor_num, GameManager.get_current_tier()]
	full_warning.visible = false
	if GameManager.is_checkpoint_floor(floor_num):
		floor_label.text += " ★ CHECKPOINT"
	# Merge unlock popup — shown once, after B5F reach.
	if GameManager.merge_just_unlocked:
		GameManager.merge_just_unlocked = false
		_show_merge_warning("Merge Unlocked! Press X to transform.")


func _on_health_changed(hp: float, max_hp: float, armor: float, max_armor: float) -> void:
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_label.text = "HP: %d/%d" % [int(hp), int(max_hp)]
	if max_armor > 0:
		armor_label.text = "Armor: %d/%d" % [int(armor), int(max_armor)]
		armor_label.visible = true
	else:
		armor_label.visible = false


func _update_extras() -> void:
	var merge_txt := "Merge: %d/%d" % [Inventory.merge_charges, Inventory.merge_charges_max]
	if _merge_cooldown_timer > 0.0:
		merge_txt += "  (ready in %.0fs)" % _merge_cooldown_timer
	battery_label.text = merge_txt
	if Inventory.artifacts.is_empty():
		artifact_label.visible = false
	else:
		var names: Array[String] = []
		for a in Inventory.artifacts:
			names.append(a.get("id", "?").replace("_", " ").capitalize())
		artifact_label.text = "Artifacts: " + ", ".join(names)
		artifact_label.visible = true
