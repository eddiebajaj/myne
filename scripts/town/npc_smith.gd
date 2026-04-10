class_name NPCSmith
extends Area2D
## Smith NPC. Pickaxe upgrades, armor purchase/repair, backpack expansion.

var player_in_range: bool = false
var menu_open: bool = false

# Pickaxe upgrade costs per tier (tier 1→2, 2→3, 3→4)
const PICKAXE_COSTS: Array[int] = [0, 25, 60, 150]
# Armor tier values and costs
const ARMOR_TIERS: Array[Dictionary] = [
	{"name": "Leather Armor", "armor": 10.0, "cost": 20},
	{"name": "Chain Armor", "armor": 20.0, "cost": 50},
	{"name": "Plate Armor", "armor": 35.0, "cost": 100},
	{"name": "Crystal Armor", "armor": 50.0, "cost": 200},
]
const ARMOR_REPAIR_COST_PER_POINT := 1
const BACKPACK_ROW_COST := 30

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
	close_button.pressed.connect(_close_menu)


func _process(_delta: float) -> void:
	if player_in_range and not menu_open and Input.is_action_just_pressed("interact"):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	_refresh_ui()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""


func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	for child in upgrades_container.get_children():
		child.queue_free()
	# Pickaxe upgrade
	var pick_tier: int = Inventory.upgrade_levels.get("pickaxe_tier", 1)
	if pick_tier < 4:
		var cost: int = PICKAXE_COSTS[pick_tier]
		var btn := Button.new()
		btn.text = "Pickaxe T%d → T%d (%d gold)" % [pick_tier, pick_tier + 1, cost]
		btn.disabled = GameManager.gold < cost
		btn.pressed.connect(func():
			if GameManager.spend_gold(cost):
				Inventory.apply_upgrade("pickaxe_tier", pick_tier + 1)
				result_label.text = "Pickaxe upgraded to T%d!" % (pick_tier + 1)
				_refresh_ui()
		)
		upgrades_container.add_child(btn)
	else:
		var lbl := Label.new()
		lbl.text = "Pickaxe: MAX TIER"
		upgrades_container.add_child(lbl)
	# Armor purchase
	var current_armor: float = Inventory.upgrade_levels.get("armor_value", 0.0)
	for tier_data in ARMOR_TIERS:
		if tier_data.armor > current_armor:
			var btn := Button.new()
			btn.text = "%s (Armor %d) — %d gold" % [tier_data.name, int(tier_data.armor), tier_data.cost]
			btn.disabled = GameManager.gold < tier_data.cost
			var td := tier_data
			btn.pressed.connect(func():
				if GameManager.spend_gold(td.cost):
					Inventory.apply_upgrade("armor_value", td.armor)
					result_label.text = "Bought %s!" % td.name
					_refresh_ui()
			)
			upgrades_container.add_child(btn)
			break  # Only show next tier
	# Armor repair (placeholder — in actual game, armor degrades during runs)
	# Backpack expansion
	var extra_rows: int = Inventory.upgrade_levels.get("grid_rows", 0)
	if extra_rows < 4:
		var cost := BACKPACK_ROW_COST * (extra_rows + 1)
		var btn := Button.new()
		btn.text = "Backpack +1 Row (%d gold) — Current: %dx%d" % [cost, Inventory.grid_width, Inventory.grid_height + extra_rows]
		btn.disabled = GameManager.gold < cost
		btn.pressed.connect(func():
			if GameManager.spend_gold(cost):
				Inventory.apply_upgrade("grid_rows", extra_rows + 1)
				result_label.text = "Backpack expanded!"
				_refresh_ui()
		)
		upgrades_container.add_child(btn)


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
