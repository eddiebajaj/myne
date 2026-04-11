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

var _is_open: bool = false
var _cell_size: int = CELL_SIZE_DESKTOP

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
	if event.is_action_pressed("toggle_backpack"):
		toggle()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	root_control.visible = true
	get_tree().paused = true
	_refresh()


func close() -> void:
	_is_open = false
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
		return cell
	var mineral: MineralData = cell_data.mineral
	if mineral != null:
		var pip: ColorRect = ColorRect.new()
		pip.color = mineral.color
		pip.size = Vector2(16, 16)
		pip.position = Vector2(_cell_size - 20, 4)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(pip)
	return cell


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
