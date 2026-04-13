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
var _touch_b_handled_frame: int = -1  # Frame guard: signal already toggled build menu
var _touch_y_handled_frame: int = -1  # Frame guard: signal already toggled backpack


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
	# Show placement hint
	if full_warning:
		full_warning.text = "Walk to position bot, tap A to place"
		full_warning.visible = true


func _hide_cancel_button() -> void:
	if cancel_placement_btn:
		cancel_placement_btn.visible = false
	if full_warning:
		full_warning.text = "BACKPACK FULL! Return to town!"
		full_warning.visible = false


func set_player(player: Player) -> void:
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, player.max_health, player.armor, player.max_armor)


func _on_touch_b() -> void:
	_touch_b_handled_frame = Engine.get_process_frames()
	# Close backpack if open — B always dismisses backpack first.
	# Inline the close logic to guarantee it executes (no intermediary calls).
	var bp = get_node_or_null("/root/BackpackPanel")
	if bp and bp._is_open:
		bp._is_open = false
		var bp_root = bp.get_node_or_null("Root")
		if bp_root:
			bp_root.visible = false
		get_tree().paused = false
		return
	if bot_placer and bot_placer.placing:
		return
	if build_panel.visible:
		_close_build_menu()
	else:
		_open_build_step1()


func _on_touch_y() -> void:
	_touch_y_handled_frame = Engine.get_process_frames()
	# Close build menu first if it's open (mutual exclusion)
	if build_panel.visible:
		_close_build_menu()
		return
	_toggle_backpack_direct()
	# If we just opened the backpack, also set the B guard so that _process
	# cannot accidentally open the build menu on the same frame.
	var bp = get_node_or_null("/root/BackpackPanel")
	if bp and bp._is_open:
		_touch_b_handled_frame = Engine.get_process_frames()


func _process(_delta: float) -> void:
	# --- B button: build menu toggle (keyboard fallback) ---
	if Input.is_action_just_pressed("action_b") or Input.is_action_just_pressed("build_menu"):
		# Skip if the touch signal already handled this press on the same frame.
		if _touch_b_handled_frame != Engine.get_process_frames():
			# Close backpack if open — B always dismisses backpack first
			var bp_b = get_node_or_null("/root/BackpackPanel")
			if bp_b and bp_b._is_open:
				_close_backpack_direct()
			elif bot_placer and bot_placer.placing:
				pass  # Don't toggle menu during placement
			elif build_panel.visible:
				_close_build_menu()
			else:
				_open_build_step1()

	# --- Y button: backpack toggle (keyboard fallback) ---
	if Input.is_action_just_pressed("action_y"):
		if _touch_y_handled_frame != Engine.get_process_frames():
			# Close build menu first if it's open
			if build_panel.visible:
				_close_build_menu()
			else:
				_toggle_backpack_direct()


func _toggle_backpack_direct() -> void:
	## Toggle BackpackPanel entirely from mining_hud, bypassing all bp methods.
	## BackpackPanel's @onready / _ready node refs are null, so we fetch every
	## child dynamically via get_node_or_null at press time.
	var bp = get_node_or_null("/root/BackpackPanel")
	if bp == null:
		return
	var root = bp.get_node_or_null("Root")
	if root == null:
		return
	# Mutual exclusion: don't open backpack while build menu is showing
	if not bp._is_open and build_panel.visible:
		return
	if bp._is_open:
		# CLOSE
		bp._is_open = false
		root.visible = false
		get_tree().paused = false
	else:
		# OPEN
		bp._is_open = true
		bp.visible = true
		bp.layer = 99
		root.visible = true
		get_tree().paused = true
		_refresh_backpack(bp)
		# Connect close button if not already connected.
		# Use a lambda with inline close logic to guarantee execution during pause.
		var close_btn = bp.get_node_or_null("Root/Panel/VBox/CloseButton")
		if close_btn:
			close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
			if not close_btn.pressed.is_connected(_close_backpack_direct):
				close_btn.pressed.connect(_close_backpack_direct)


func _close_backpack_direct() -> void:
	## Close BackpackPanel without calling any of its methods.
	var bp = get_node_or_null("/root/BackpackPanel")
	if bp == null or not bp._is_open:
		return
	bp._is_open = false
	var root = bp.get_node_or_null("Root")
	if root:
		root.visible = false
	get_tree().paused = false


func _refresh_backpack(bp: Node) -> void:
	## Replicate BackpackPanel's _refresh logic using dynamic node lookups.
	if not bp._is_open:
		return
	_refresh_backpack_header(bp)
	_refresh_backpack_grid(bp)
	_refresh_backpack_side_panel(bp)


func _refresh_backpack_header(bp: Node) -> void:
	var title_lbl = bp.get_node_or_null("Root/Panel/VBox/HeaderRow/TitleLabel")
	var cap_lbl = bp.get_node_or_null("Root/Panel/VBox/HeaderRow/CapacityLabel")
	var used: int = Inventory.get_used_slots()
	var cap: int = Inventory.get_max_capacity()
	if title_lbl:
		title_lbl.text = "BACKPACK"
	if cap_lbl:
		cap_lbl.text = "%d / %d" % [used, cap]


func _refresh_backpack_grid(bp: Node) -> void:
	var grid = bp.get_node_or_null("Root/Panel/VBox/Body/GridWrap/Grid")
	if grid == null:
		return
	for child in grid.get_children():
		child.queue_free()
	var cap: int = Inventory.get_max_capacity()
	var cell_size: int = 80 if _bp_is_touch_device() else 64
	# Flatten stacks into individual cells
	var cells: Array[Dictionary] = []
	for slot in Inventory.get_ore_stacks():
		var qty: int = int(slot.quantity)
		for i in range(qty):
			cells.append({"ore": slot.ore, "mineral": slot.mineral})
	for i in range(cap):
		var cell_data: Dictionary = cells[i] if i < cells.size() else {}
		grid.add_child(_build_bp_cell(cell_data, cell_size))


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
	# Cell tap uses BackpackPanel's inspect popup — call it directly on bp
	cell.gui_input.connect(func(event: InputEvent):
		var is_click: bool = event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
		var is_tap: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
		if is_click or is_tap:
			var bp_ref = get_node_or_null("/root/BackpackPanel")
			if bp_ref:
				bp_ref._open_inspect_popup(
					String(cell.get_meta("ore_id", "")),
					String(cell.get_meta("mineral_id", ""))
				)
	)
	return cell


func _refresh_backpack_side_panel(bp: Node) -> void:
	var gold_lbl = bp.get_node_or_null("Root/Panel/VBox/Body/SidePanel/GoldLabel")
	var batt_lbl = bp.get_node_or_null("Root/Panel/VBox/Body/SidePanel/BatteryLabel")
	var followers_hdr = bp.get_node_or_null("Root/Panel/VBox/Body/SidePanel/FollowersHeader")
	var followers_lst = bp.get_node_or_null("Root/Panel/VBox/Body/SidePanel/FollowersList")
	if gold_lbl:
		gold_lbl.text = "Gold: %d" % GameManager.gold
	if batt_lbl:
		batt_lbl.text = "Batteries: %d" % Inventory.batteries
	if followers_lst:
		for child in followers_lst.get_children():
			child.queue_free()
	if followers_hdr:
		followers_hdr.text = "FOLLOWERS"
	if followers_lst == null:
		return
	if Inventory.follower_bots.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "No followers"
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		followers_lst.add_child(empty_lbl)
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
		followers_lst.add_child(row)


func _bp_is_touch_device() -> bool:
	if OS.has_feature("web"):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


func _open_build_step1() -> void:
	## Step 1: Pick bot type. Game pauses while menu is open.
	# Close backpack first if it's open
	_close_backpack_direct()
	build_step = 1
	selected_bot = null
	build_panel.visible = true
	get_tree().paused = true
	_rebuild_bot_list()
	_focus_first_build_button()


func _open_build_step2(bot: BotData) -> void:
	## Step 2: Pick which ore stack to use.
	build_step = 2
	selected_bot = bot
	_rebuild_ore_list()
	_focus_first_build_button()


func _close_build_menu() -> void:
	build_panel.visible = false
	build_step = 0
	selected_bot = null
	get_tree().paused = false


func _focus_first_build_button() -> void:
	for child in build_list.get_children():
		if child is Button:
			child.grab_focus()
			return


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
		var bot := selected_bot  # Capture by value before _close_build_menu nulls it
		btn.pressed.connect(func():
			_close_build_menu()
			bot_placer.select_bot_and_ore(bot, oid, mid)
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
