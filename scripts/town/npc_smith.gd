class_name NPCSmith
extends Area2D
## Smith NPC. Pickaxe upgrades, armor purchase/repair, backpack expansion.

var player_in_range: bool = false
var menu_open: bool = false
var _touch_b_handled_frame: int = -1

# Pickaxe upgrade costs per tier (tier 1→2, 2→3, 3→4) — spec §3.1
const PICKAXE_COSTS: Array[int] = [0, 40, 120, 320]
# Armor tier values and costs — spec §3.2
const ARMOR_TIERS: Array[Dictionary] = [
	{"name": "Leather Armor", "armor": 10.0, "cost": 30},
	{"name": "Chain Armor", "armor": 20.0, "cost": 90},
	{"name": "Plate Armor", "armor": 35.0, "cost": 220},
	{"name": "Crystal Armor", "armor": 55.0, "cost": 500},
]
# Backpack row costs (row 5, 6, 7, 8) — spec §3.3
const BACKPACK_ROW_COSTS: Array[int] = [60, 150, 320, 600]
const MAX_EXTRA_ROWS: int = 4

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
@onready var menu_panel: PanelContainer = $CanvasLayer/MenuPanel
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var upgrades_container: VBoxContainer = $CanvasLayer/MenuPanel/VBox/Upgrades
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.color = Color(0.8, 0.5, 0.2)
	label.text = "Smith [E]"
	label.visible = false
	menu_panel.visible = false
	# Menu must keep processing while the game is paused so buttons respond.
	var menu_layer: CanvasLayer = $CanvasLayer
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close_menu)
	# Allow _process to run while paused so B-button can close the menu.
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
	_refresh_ui()
	# Focus first upgrade button so keyboard/gamepad can activate it
	_focus_first_button()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	get_tree().paused = false


func _refresh_ui() -> void:
	gold_label.text = "Gold: %dg" % GameManager.gold
	for child in upgrades_container.get_children():
		child.queue_free()

	# — PICKAXE —
	_add_header("— PICKAXE —")
	var pick_tier: int = int(Inventory.upgrade_levels.get("pickaxe_tier", 1))
	if pick_tier < 4:
		var cost: int = PICKAXE_COSTS[pick_tier]
		var desc: String = "Pickaxe T%d → T%d    %dg" % [pick_tier, pick_tier + 1, cost]
		_add_buy_row(desc, cost, func():
			if GameManager.spend_gold(cost):
				Inventory.apply_upgrade("pickaxe_tier", pick_tier + 1)
				result_label.text = "Pickaxe upgraded to T%d!" % (pick_tier + 1)
				_refresh_ui()
		)
	else:
		_add_max_row("Pickaxe: MAX")

	# — ARMOR —
	_add_header("— ARMOR —")
	var current_armor: float = float(Inventory.upgrade_levels.get("armor_value", 0.0))
	var next_armor: Dictionary = {}
	for tier_data in ARMOR_TIERS:
		if float(tier_data.armor) > current_armor:
			next_armor = tier_data
			break
	if next_armor.is_empty():
		_add_max_row("Armor: MAX")
	else:
		var td: Dictionary = next_armor
		var desc: String = "%s (Armor %d)    %dg" % [td.name, int(td.armor), int(td.cost)]
		var cost_i: int = int(td.cost)
		_add_buy_row(desc, cost_i, func():
			if GameManager.spend_gold(cost_i):
				Inventory.apply_upgrade("armor_value", float(td.armor))
				result_label.text = "Bought %s!" % td.name
				_refresh_ui()
		)

	# — BACKPACK —
	_add_header("— BACKPACK —")
	var extra_rows: int = int(Inventory.upgrade_levels.get("grid_rows", 0))
	var current_rows: int = Inventory.grid_height + extra_rows
	if extra_rows < MAX_EXTRA_ROWS:
		var cost: int = BACKPACK_ROW_COSTS[extra_rows]
		var desc: String = "%dx%d → %dx%d    %dg" % [
			Inventory.grid_width, current_rows, Inventory.grid_width, current_rows + 1, cost]
		_add_buy_row(desc, cost, func():
			if GameManager.spend_gold(cost):
				Inventory.apply_upgrade("grid_rows", extra_rows + 1)
				result_label.text = "Backpack expanded!"
				_refresh_ui()
		)
		var current_lbl: Label = Label.new()
		current_lbl.text = "Current: %d slots" % (Inventory.grid_width * current_rows)
		upgrades_container.add_child(current_lbl)
	else:
		_add_max_row("Backpack: MAX (%d slots)" % (Inventory.grid_width * current_rows))


func _add_header(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	upgrades_container.add_child(lbl)


func _add_max_row(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text + "  [MAX]"
	upgrades_container.add_child(lbl)


func _add_buy_row(desc: String, cost: int, on_buy: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = desc
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var btn: Button = Button.new()
	btn.text = "Buy"
	btn.disabled = GameManager.gold < cost
	btn.pressed.connect(on_buy)
	row.add_child(btn)
	upgrades_container.add_child(row)


func _focus_first_button() -> void:
	for child in upgrades_container.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is Button:
					sub.grab_focus()
					return
		if child is Button:
			child.grab_focus()
			return
	close_button.grab_focus()


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
