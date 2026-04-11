extends Control
## In-mine HUD — floor, HP+armor, backpack, batteries, build menu, artifacts.

@onready var floor_label: Label = %FloorLabel
@onready var backpack_bar: ProgressBar = %BackpackBar
@onready var backpack_label: Label = %BackpackLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var health_label: Label = %HealthLabel
@onready var armor_label: Label = %ArmorLabel
@onready var battery_label: Label = %BatteryLabel
@onready var artifact_label: Label = %ArtifactLabel
@onready var full_warning: Label = %FullWarning
@onready var build_panel: PanelContainer = %BuildPanel
@onready var build_list: VBoxContainer = %BuildList

var bot_placer: BotPlacer = null
var build_step: int = 0  # 0=closed, 1=pick bot, 2=pick ore
var selected_bot: BotData = null
var cancel_placement_btn: Button = null


func _ready() -> void:
	Inventory.inventory_changed.connect(_update_backpack)
	Inventory.backpack_full.connect(_on_backpack_full)
	GameManager.floor_changed.connect(_on_floor_changed)
	build_panel.visible = false
	full_warning.visible = false
	_update_backpack()
	_update_extras()
	_on_floor_changed(GameManager.current_floor)


func set_bot_placer(placer: BotPlacer) -> void:
	bot_placer = placer
	placer.placement_started.connect(_on_placement_started)
	placer.bot_built.connect(func(_bd, _tier, _mineral): _hide_cancel_button())
	placer.build_cancelled.connect(_hide_cancel_button)
	_ensure_cancel_button()


func _ensure_cancel_button() -> void:
	## Sprint 2 bug 4: on mobile there is no right-click to cancel placement,
	## so we surface a visible Cancel button while the bot_placer is active.
	## The button lives on the HUD (not the touch overlay) so it also works
	## on desktop if the player prefers clicking over right-clicking.
	if cancel_placement_btn != null:
		return
	cancel_placement_btn = Button.new()
	cancel_placement_btn.text = "Cancel Placement"
	cancel_placement_btn.visible = false
	cancel_placement_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_placement_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	# Anchor to bottom-center, above touch action buttons (which sit ~bottom-right).
	cancel_placement_btn.anchor_left = 0.5
	cancel_placement_btn.anchor_right = 0.5
	cancel_placement_btn.anchor_top = 1.0
	cancel_placement_btn.anchor_bottom = 1.0
	cancel_placement_btn.offset_left = -90.0
	cancel_placement_btn.offset_right = 90.0
	cancel_placement_btn.offset_top = -80.0
	cancel_placement_btn.offset_bottom = -40.0
	cancel_placement_btn.pressed.connect(func():
		if bot_placer:
			bot_placer._cancel_placement()
	)
	add_child(cancel_placement_btn)


func _on_placement_started(_bot_data: BotData) -> void:
	if cancel_placement_btn:
		cancel_placement_btn.visible = true


func _hide_cancel_button() -> void:
	if cancel_placement_btn:
		cancel_placement_btn.visible = false


func set_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health, player.armor, player.max_armor)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_menu"):
		if build_panel.visible:
			_close_build_menu()
		else:
			_open_build_step1()
		get_viewport().set_input_as_handled()


func _open_build_step1() -> void:
	## Step 1: Pick bot type. Game pauses while menu is open.
	build_step = 1
	selected_bot = null
	build_panel.visible = true
	get_tree().paused = true
	_rebuild_bot_list()


func _open_build_step2(bot: BotData) -> void:
	## Step 2: Pick which ore stack to use.
	build_step = 2
	selected_bot = bot
	_rebuild_ore_list()


func _close_build_menu() -> void:
	build_panel.visible = false
	build_step = 0
	selected_bot = null
	get_tree().paused = false


func _rebuild_bot_list() -> void:
	for child in build_list.get_children():
		child.queue_free()
	if bot_placer == null:
		return
	var header := Label.new()
	header.text = "SELECT BOT TYPE"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_list.add_child(header)
	for bot_data in bot_placer.get_bot_defs():
		var type_label := "STATIC" if bot_data.category == BotData.BotCategory.STATIC else "FOLLOW"
		var btn := Button.new()
		btn.text = "%s [%s] — %d ore + 1 battery\n%s" % [bot_data.display_name, type_label, bot_data.ore_count, bot_data.description]
		btn.disabled = Inventory.batteries <= 0
		var bd := bot_data
		btn.pressed.connect(func(): _open_build_step2(bd))
		build_list.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_build_menu)
	build_list.add_child(cancel)


func _rebuild_ore_list() -> void:
	for child in build_list.get_children():
		child.queue_free()
	if selected_bot == null:
		return
	var header := Label.new()
	header.text = "SELECT ORE FOR %s (need %d)" % [selected_bot.display_name.to_upper(), selected_bot.ore_count]
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_list.add_child(header)
	for slot in Inventory.get_ore_stacks():
		var ore_name: String = slot.ore.display_name
		var mineral_id := ""
		if slot.mineral:
			ore_name += " (%s)" % slot.mineral.display_name
			mineral_id = slot.mineral.id
		var can_afford: bool = slot.quantity >= selected_bot.ore_count
		var tier_info: String = "T%d" % slot.ore.tier
		var btn := Button.new()
		btn.text = "%s %s x%d — Bot stats x%.1f" % [tier_info, ore_name, slot.quantity, BotData.get_tier_mult(slot.ore.tier)]
		if slot.mineral:
			btn.text += " + %s effect" % slot.mineral.display_name
		btn.disabled = not can_afford
		var oid: String = slot.ore.id
		var mid := mineral_id
		btn.pressed.connect(func():
			_close_build_menu()
			bot_placer.select_bot_and_ore(selected_bot, oid, mid)
		)
		build_list.add_child(btn)
	var back := Button.new()
	back.text = "← Back"
	back.pressed.connect(func(): _open_build_step1())
	build_list.add_child(back)


func _update_backpack() -> void:
	var used := Inventory.get_used_slots()
	var max_cap := Inventory.get_max_capacity()
	var bonus := Inventory.get_remaining_slots() + used - max_cap  # Artifact bonus
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
	battery_label.text = "Batteries: %d" % Inventory.batteries
	# Artifact display
	if Inventory.artifacts.is_empty():
		artifact_label.visible = false
	else:
		var names: Array[String] = []
		for a in Inventory.artifacts:
			names.append(a.get("id", "?").replace("_", " ").capitalize())
		artifact_label.text = "Artifacts: " + ", ".join(names)
		artifact_label.visible = true
