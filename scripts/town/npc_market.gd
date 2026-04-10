class_name NPCMarket
extends Area2D
## Market NPC. Sell ore for gold, buy batteries.

signal menu_opened
signal menu_closed

const BATTERY_PRICE := 8  # Gold per battery

var player_in_range: bool = false
var menu_open: bool = false

@onready var sprite: ColorRect = $Sprite
@onready var label: Label = $Label
@onready var menu_panel: PanelContainer = $CanvasLayer/MenuPanel
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var inventory_label: Label = $CanvasLayer/MenuPanel/VBox/InventoryLabel
@onready var sell_button: Button = $CanvasLayer/MenuPanel/VBox/SellButton
@onready var buy_battery_button: Button = $CanvasLayer/MenuPanel/VBox/BuyBatteryButton
@onready var battery_label: Label = $CanvasLayer/MenuPanel/VBox/BatteryLabel
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	sprite.color = Color(0.2, 0.7, 0.3)
	label.text = "Market [E]"
	label.visible = false
	menu_panel.visible = false
	sell_button.pressed.connect(_on_sell)
	buy_battery_button.pressed.connect(_on_buy_battery)
	close_button.pressed.connect(_close_menu)


func _process(_delta: float) -> void:
	if player_in_range and not menu_open and Input.is_action_just_pressed("interact"):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	_refresh_ui()
	menu_opened.emit()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	menu_closed.emit()


func _on_sell() -> void:
	var earned := Inventory.sell_all()
	if earned > 0:
		result_label.text = "Sold for %d gold!" % earned
	else:
		result_label.text = "Nothing to sell."
	_refresh_ui()


func _on_buy_battery() -> void:
	if GameManager.spend_gold(BATTERY_PRICE):
		Inventory.add_batteries(1)
		result_label.text = "Bought 1 battery!"
	else:
		result_label.text = "Not enough gold!"
	_refresh_ui()


func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	battery_label.text = "Batteries: %d" % Inventory.batteries
	buy_battery_button.text = "Buy Battery (%d gold)" % BATTERY_PRICE
	buy_battery_button.disabled = GameManager.gold < BATTERY_PRICE
	# Inventory summary
	var items := Inventory.get_ore_stacks()
	if items.is_empty():
		inventory_label.text = "Backpack: empty"
	else:
		var parts: Array[String] = []
		for slot in items:
			var name_str: String = slot.ore.display_name
			if slot.mineral:
				name_str += " (%s)" % slot.mineral.display_name
			parts.append("%s x%d" % [name_str, slot.quantity])
		inventory_label.text = "Backpack: " + ", ".join(parts)


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
