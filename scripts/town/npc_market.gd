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
@onready var menu_vbox: VBoxContainer = $CanvasLayer/MenuPanel/VBox
@onready var gold_label: Label = $CanvasLayer/MenuPanel/VBox/GoldLabel
@onready var inventory_label: Label = $CanvasLayer/MenuPanel/VBox/InventoryLabel
@onready var sell_button: Button = $CanvasLayer/MenuPanel/VBox/SellButton
@onready var buy_battery_button: Button = $CanvasLayer/MenuPanel/VBox/BuyBatteryButton
@onready var battery_label: Label = $CanvasLayer/MenuPanel/VBox/BatteryLabel
@onready var result_label: Label = $CanvasLayer/MenuPanel/VBox/ResultLabel
@onready var close_button: Button = $CanvasLayer/MenuPanel/VBox/CloseButton

var _breakdown_grid: GridContainer = null
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
	sell_button.pressed.connect(_on_sell)
	buy_battery_button.pressed.connect(_on_buy_battery)
	close_button.pressed.connect(_close_menu)
	# Replace single inventory_label with a breakdown container.
	inventory_label.visible = false
	_breakdown_container = VBoxContainer.new()
	_breakdown_container.name = "Breakdown"
	menu_vbox.add_child(_breakdown_container)
	menu_vbox.move_child(_breakdown_container, inventory_label.get_index() + 1)


func _process(_delta: float) -> void:
	if player_in_range and not menu_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	get_tree().paused = true
	_refresh_ui()
	menu_opened.emit()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	get_tree().paused = false
	menu_closed.emit()


func _on_sell() -> void:
	var earned: int = Inventory.sell_all()
	if earned > 0:
		result_label.text = "Sold for %d gold!" % earned
		_spawn_gold_popup(earned)
	else:
		result_label.text = "Nothing to sell."
	_refresh_ui()


func _spawn_gold_popup(amount: int) -> void:
	## Floating "+Ng" label that rises and fades over 0.6s.
	var popup: Label = Label.new()
	popup.text = "+%dg" % amount
	popup.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	popup.add_theme_font_size_override("font_size", 28)
	popup.z_index = 10
	# Add to the CanvasLayer (not the PanelContainer) so free positioning works.
	popup.position = menu_panel.position + Vector2(180, 220)
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: CanvasLayer = $CanvasLayer
	layer.add_child(popup)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 40.0, 0.6)
	tween.tween_property(popup, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(popup.queue_free)


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
	_refresh_breakdown()


func _refresh_breakdown() -> void:
	if _breakdown_container == null:
		return
	for child in _breakdown_container.get_children():
		child.queue_free()
	var header: Label = Label.new()
	header.text = "— SELL ORE —"
	_breakdown_container.add_child(header)
	var items: Array[Dictionary] = Inventory.get_ore_stacks()
	if items.is_empty():
		var empty: Label = Label.new()
		empty.text = "Backpack is empty."
		_breakdown_container.add_child(empty)
		sell_button.disabled = true
		sell_button.text = "Sell All"
		return
	sell_button.disabled = false
	var grid: GridContainer = GridContainer.new()
	grid.columns = 4
	_breakdown_container.add_child(grid)
	var total: int = 0
	for slot in items:
		var name_str: String = slot.ore.display_name
		if slot.mineral:
			name_str += " (" + slot.mineral.display_name + ")"
		var base_value: int = int(slot.ore.value)
		var bonus: int = int(slot.mineral.sell_bonus) if slot.mineral else 0
		var unit_price: int = base_value + bonus
		var qty: int = int(slot.quantity)
		var subtotal: int = unit_price * qty
		total += subtotal
		_add_grid_label(grid, name_str)
		_add_grid_label(grid, "x%d" % qty)
		_add_grid_label(grid, "@%dg" % unit_price)
		_add_grid_label(grid, "= %dg" % subtotal)
	var total_lbl: Label = Label.new()
	total_lbl.text = "TOTAL: %dg" % total
	total_lbl.add_theme_font_size_override("font_size", 18)
	total_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_breakdown_container.add_child(total_lbl)
	sell_button.text = "Sell All (%dg)" % total


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
