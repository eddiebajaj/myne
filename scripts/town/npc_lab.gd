class_name NPCLab
extends Area2D
## Lab Researcher NPC. Bot upgrades, mineral extract/infuse services.

const EXTRACT_COST := 5   # Gold to extract a mineral from ore
const INFUSE_COST := 8    # Gold to infuse a stored mineral onto plain ore

var player_in_range: bool = false
var menu_open: bool = false
var _a_was_pressed: bool = false
var _b_was_pressed: bool = false

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
	# Allow _process to run while paused so B-button can close the menu.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var a_pressed := Input.is_action_pressed("action_a")
	var a_just = a_pressed and not _a_was_pressed
	_a_was_pressed = a_pressed
	var b_pressed := Input.is_action_pressed("action_b")
	var b_just = b_pressed and not _b_was_pressed
	_b_was_pressed = b_pressed
	if menu_open and b_just:
		_close_menu()
		return
	if player_in_range and not menu_open and (Input.is_action_just_pressed("interact") or a_just):
		_open_menu()


func _open_menu() -> void:
	menu_open = true
	menu_panel.visible = true
	get_tree().paused = true
	_refresh_ui()
	# Focus first service button so keyboard/gamepad can activate it
	_focus_first_button()


func _close_menu() -> void:
	menu_open = false
	menu_panel.visible = false
	result_label.text = ""
	get_tree().paused = false


func _refresh_ui() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	# Mineral storage display
	if Inventory.mineral_storage.is_empty():
		storage_label.text = "Stored Minerals: none"
	else:
		var counts: Dictionary = {}
		for m in Inventory.mineral_storage:
			counts[m.display_name] = counts.get(m.display_name, 0) + 1
		var parts: Array[String] = []
		for name in counts:
			parts.append("%s x%d" % [name, counts[name]])
		storage_label.text = "Stored Minerals: " + ", ".join(parts)
	# Services
	for child in services_container.get_children():
		child.queue_free()
	# Section: Battery Crafting — spec §4.3 (no gold fee per Eddie)
	var header_batt: Label = Label.new()
	header_batt.text = "— BATTERY CRAFTING —"
	services_container.add_child(header_batt)
	var recipe_lbl: Label = Label.new()
	recipe_lbl.text = "Basic Battery\nRequires: 3 x T1 plain ore"
	services_container.add_child(recipe_lbl)
	var plain_t1: int = Inventory.count_plain_t1_ore()
	var have_lbl: Label = Label.new()
	have_lbl.text = "Have: %d T1 ore, %dg" % [plain_t1, GameManager.gold]
	services_container.add_child(have_lbl)
	var craft_btn: Button = Button.new()
	craft_btn.text = "Craft Battery"
	craft_btn.disabled = plain_t1 < 3
	craft_btn.pressed.connect(func():
		if Inventory.craft_battery():
			result_label.text = "Crafted 1 Basic Battery!"
			_refresh_ui()
		else:
			result_label.text = "Requires 3 plain T1 ore."
	)
	services_container.add_child(craft_btn)

	# Section: Extract (mineral ore → plain ore + stored mineral)
	var header_extract := Label.new()
	header_extract.text = "— EXTRACT (%d gold) —" % EXTRACT_COST
	services_container.add_child(header_extract)
	for slot in Inventory.get_ore_stacks():
		if slot.mineral == null:
			continue
		var btn := Button.new()
		btn.text = "Extract %s from %s (x%d)" % [slot.mineral.display_name, slot.ore.display_name, slot.quantity]
		btn.disabled = GameManager.gold < EXTRACT_COST
		var ore = slot.ore
		var mineral = slot.mineral
		btn.pressed.connect(func():
			if GameManager.spend_gold(EXTRACT_COST):
				# Remove 1 mineral ore, add 1 plain ore, store mineral
				Inventory.spend_ore_specific(ore.id, mineral.id, 1)
				Inventory.add_ore(ore, null, 1)
				Inventory.store_mineral(mineral)
				result_label.text = "Extracted %s!" % mineral.display_name
				_refresh_ui()
		)
		services_container.add_child(btn)
	# Section: Infuse (stored mineral + plain ore → mineral ore)
	var header_infuse := Label.new()
	header_infuse.text = "— INFUSE (%d gold) —" % INFUSE_COST
	services_container.add_child(header_infuse)
	# Show infuse options: each stored mineral × each plain ore stack
	var plain_stacks: Array[Dictionary] = []
	for slot in Inventory.get_ore_stacks():
		if slot.mineral == null:
			plain_stacks.append(slot)
	var shown_minerals: Dictionary = {}
	for stored_mineral in Inventory.mineral_storage:
		if shown_minerals.has(stored_mineral.id):
			continue
		shown_minerals[stored_mineral.id] = true
		for plain_slot in plain_stacks:
			var btn := Button.new()
			btn.text = "Infuse %s onto %s" % [stored_mineral.display_name, plain_slot.ore.display_name]
			btn.disabled = GameManager.gold < INFUSE_COST
			var ore = plain_slot.ore
			var min_copy := stored_mineral
			btn.pressed.connect(func():
				if GameManager.spend_gold(INFUSE_COST):
					var taken := Inventory.take_stored_mineral(min_copy.id)
					if taken:
						Inventory.spend_ore_specific(ore.id, "", 1)
						Inventory.add_ore(ore, taken, 1)
						result_label.text = "Infused %s onto %s!" % [taken.display_name, ore.display_name]
						_refresh_ui()
			)
			services_container.add_child(btn)
	# Note: battery crafting adds ~4 children baseline, extract/infuse add more.


func _focus_first_button() -> void:
	for child in services_container.get_children():
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
