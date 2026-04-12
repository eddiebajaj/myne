extends CanvasLayer
## Backpack panel overlay. Opened with Tab (desktop) or a touch button.
## Pauses the game while open (same pattern as the build menu in mining_hud).
## Cell-per-piece rendering (Eddie's decision in spec §2 override).

const CELL_SIZE_DESKTOP: int = 64
const CELL_SIZE_MOBILE: int = 80
const GRID_COLS: int = 4
const PANEL_W: int = 900
const PANEL_H: int = 640
const VIEWPORT_W: int = 1280
const VIEWPORT_H: int = 720

const INSPECT_BUTTON_MIN_H: int = 64

var _is_open: bool = false
var _cell_size: int = CELL_SIZE_DESKTOP
var _inspect_popup: PanelContainer = null
var _inspect_dim: ColorRect = null
var _inspect_ore_id: String = ""
var _inspect_mineral_id: String = ""
@onready var root_control: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/VBox/HeaderRow/TitleLabel
@onready var capacity_label: Label = $Root/Panel/VBox/HeaderRow/CapacityLabel
@onready var grid_container: GridContainer = $Root/Panel/VBox/Body/GridWrap/Grid
@onready var gold_label: Label = $Root/Panel/VBox/Body/SidePanel/GoldLabel
@onready var battery_label: Label = $Root/Panel/VBox/Body/SidePanel/BatteryLabel
@onready var followers_label: Label = $Root/Panel/VBox/Body/SidePanel/FollowersHeader
@onready var followers_list: VBoxContainer = $Root/Panel/VBox/Body/SidePanel/FollowersList
@onready var close_button: Button = $Root/Panel/VBox/CloseButton


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control.visible = false
	close_button.pressed.connect(close)
	_cell_size = CELL_SIZE_MOBILE if _is_touch_device() else CELL_SIZE_DESKTOP
	grid_container.columns = GRID_COLS
	Inventory.inventory_changed.connect(_refresh)


func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	# Desktop Tab key toggle (toggle_backpack action). Touch Y is handled by
	# mining_hud via the TouchControls signal — no autoload timing issues.
	# NOTE: action_y is NOT checked here. parse_input_event injects a real
	# InputEventAction that reaches _unhandled_input, so if we also handled
	# action_y here it would double-toggle alongside mining_hud's signal handler.
	if event.is_action_pressed("toggle_backpack"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


var _toggle_frame: int = -1
var _open_frame: int = -1  # Frame when open() was called — block close() on same frame

func toggle() -> void:
	# Guard against double-toggle in the same frame
	var frame := Engine.get_process_frames()
	if _toggle_frame == frame:
		return
	_toggle_frame = frame
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_open_frame = Engine.get_process_frames()
	root_control.visible = true
	get_tree().paused = true
	_refresh()
	# NOTE: Do NOT call close_button.grab_focus() here.  On mobile-web the
	# active touch is still held when this runs; grabbing focus onto the
	# Close button causes Godot to route the subsequent touch-release into
	# the button, firing its "pressed" signal and immediately closing the
	# panel.  Desktop users can still click/tap Close normally.


func close() -> void:
	if not _is_open:
		return
	# Block close on the exact same frame as open — prevents open-then-close
	# from a single input event rippling through multiple handlers.
	if Engine.get_process_frames() == _open_frame:
		return
	_is_open = false
	_close_inspect_popup()
	root_control.visible = false
	get_tree().paused = false


func _refresh() -> void:
	if not _is_open:
		return
	_refresh_header()
	_refresh_grid()
	_refresh_side_panel()


func _refresh_header() -> void:
	var used: int = Inventory.get_used_slots()
	var cap: int = Inventory.get_max_capacity()
	title_label.text = "BACKPACK"
	capacity_label.text = "%d / %d" % [used, cap]


func _refresh_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	var cap: int = Inventory.get_max_capacity()
	# Expand cells row-major: flatten every stack into individual pieces (Eddie's call).
	var cells: Array[Dictionary] = []
	for slot in Inventory.get_ore_stacks():
		var qty: int = int(slot.quantity)
		for i in range(qty):
			cells.append({"ore": slot.ore, "mineral": slot.mineral})
	for i in range(cap):
		var cell_data: Dictionary = cells[i] if i < cells.size() else {}
		grid_container.add_child(_build_cell(cell_data))


func _build_cell(cell_data: Dictionary) -> Control:
	var cell: Panel = Panel.new()
	cell.custom_minimum_size = Vector2(_cell_size, _cell_size)
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
		# Empty cells are inert — no gui_input hookup.
		return cell
	var ore_data: OreData = cell_data.ore
	var mineral: MineralData = cell_data.mineral
	if mineral != null:
		var pip: ColorRect = ColorRect.new()
		pip.color = mineral.color
		pip.size = Vector2(16, 16)
		pip.position = Vector2(_cell_size - 20, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pip)
	# Resolve per-piece cell → source stack via (ore_id, mineral_id) metadata.
	# Inventory.drop_one() looks up the stack by this key.
	cell.set_meta("ore_id", ore_data.id)
	cell.set_meta("mineral_id", mineral.id if mineral != null else "")
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_on_cell_gui_input.bind(cell))
	return cell


func _on_cell_gui_input(event: InputEvent, cell: Control) -> void:
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
	accept_event()


func _open_inspect_popup(ore_id: String, mineral_id: String) -> void:
	_close_inspect_popup()
	_inspect_ore_id = ore_id
	_inspect_mineral_id = mineral_id
	# Dim click-catcher: tap-outside-to-dismiss.
	_inspect_dim = ColorRect.new()
	_inspect_dim.color = Color(0, 0, 0, 0.35)
	_inspect_dim.anchor_right = 1.0
	_inspect_dim.anchor_bottom = 1.0
	_inspect_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_inspect_dim.process_mode = Node.PROCESS_MODE_ALWAYS
	_inspect_dim.gui_input.connect(_on_dim_gui_input)
	root_control.add_child(_inspect_dim)
	# Popup panel, centered over backpack.
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
	root_control.add_child(_inspect_popup)
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
	# Re-center against the backpack panel once layout has resolved.
	await get_tree().process_frame
	if _inspect_popup == null:
		return
	var panel_rect: Rect2 = panel.get_global_rect()
	var popup_size: Vector2 = _inspect_popup.size
	if popup_size == Vector2.ZERO:
		popup_size = _inspect_popup.custom_minimum_size
	var origin: Vector2 = panel_rect.position + (panel_rect.size - popup_size) * 0.5
	_inspect_popup.position = origin


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
	# Refresh grid (Inventory.inventory_changed already fires via drop_one,
	# but _refresh is idempotent and keeps popup+grid coherent).
	_refresh_grid()
	_refresh_header()
	# If stack is now empty, close popup; otherwise repopulate so qty updates.
	var remaining: int = Inventory.get_stack_quantity(_inspect_ore_id, _inspect_mineral_id)
	if remaining <= 0:
		_close_inspect_popup()
	else:
		_populate_inspect_popup()


func _on_dim_gui_input(event: InputEvent) -> void:
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


func _refresh_side_panel() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	battery_label.text = "Batteries: %d" % Inventory.batteries
	for child in followers_list.get_children():
		child.queue_free()
	followers_label.text = "FOLLOWERS"
	if Inventory.follower_bots.is_empty():
		var empty: Label = Label.new()
		empty.text = "No followers"
		empty.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		followers_list.add_child(empty)
		return
	for bot_entry in Inventory.follower_bots:
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
		followers_list.add_child(row)
