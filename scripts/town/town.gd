extends Node2D
## Town hub — walkable JRPG-style space with NPC interaction zones.
## NPCs: Market (sell/buy), Smith (gear), Lab (minerals/bots).

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var mine_entrance: Area2D = $MineEntrance
@onready var stats_label: Label = $CanvasLayer/HUD/StatsLabel
@onready var checkpoint_selector: OptionButton = $CanvasLayer/HUD/CheckpointSelector
@onready var mine_button: Button = $CanvasLayer/HUD/MineButton
@onready var sell_button: Button = $CanvasLayer/HUD/SellButton
@onready var sell_result: Label = $CanvasLayer/HUD/SellResult
@onready var hud_root: Control = $CanvasLayer/HUD

var mine_entrance_in_range: bool = false
var mine_panel_open: bool = false
var storage_shed_in_range: bool = false
var storage_panel_open: bool = false
var selected_checkpoint: int = 0
var _touch_b_handled_frame: int = -1
var town_gold_label: Label = null
var town_cp_label: Label = null

# Mine entrance panel (built programmatically in _build_mine_panel).
var mine_panel_layer: CanvasLayer = null
var mine_panel_dim: ColorRect = null
var mine_panel: PanelContainer = null
var mine_panel_options: VBoxContainer = null
var mine_panel_enter_button: Button = null
var mine_panel_option_buttons: Array[Button] = []

# Party selection at mine entrance.
var mine_panel_party_container: VBoxContainer = null
var mine_panel_party_summary: Label = null
var _party_selection: Dictionary = {}   # bot_id -> bool (selected)
var _party_cp_used: int = 0


func _ready() -> void:
	# Ensure game is not paused
	get_tree().paused = false
	# Allow _process to run while paused so B-button can close the mine panel.
	# Player is explicitly set to pausable so it stops during menus.
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.add_to_group("player")
	player.position = Vector2(640, 500)
	# Legacy HUD widgets are replaced by the mine entrance panel — hide and ignore them.
	mine_button.visible = false
	mine_button.process_mode = Node.PROCESS_MODE_DISABLED
	checkpoint_selector.visible = false
	checkpoint_selector.process_mode = Node.PROCESS_MODE_DISABLED
	sell_button.pressed.connect(_on_sell_ore)
	sell_result.visible = false
	mine_entrance.body_entered.connect(_on_mine_entrance_entered)
	mine_entrance.body_exited.connect(_on_mine_entrance_exited)
	_build_town_hud()
	_build_mine_panel()
	_build_storage_shed()
	_build_storage_panel()
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.checkpoint_reached.connect(_on_checkpoint_reached)
	Inventory.inventory_changed.connect(_refresh_persistent_hud)
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)
	_refresh_stats()


func _build_town_hud() -> void:
	## Persistent top-right HBox: battery count + gold — spec §6.
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "PersistentHUD"
	hbox.position = Vector2(1280.0 - 280.0, 16.0)
	hbox.size = Vector2(264.0, 32.0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hbox)
	town_cp_label = Label.new()
	town_cp_label.text = "CP 1"
	town_cp_label.add_theme_font_size_override("font_size", 24)
	town_cp_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	town_cp_label.add_theme_constant_override("outline_size", 2)
	town_cp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hbox.add_child(town_cp_label)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	hbox.add_child(spacer)
	var coin: ColorRect = ColorRect.new()
	coin.color = Color(1.0, 0.85, 0.2)
	coin.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(coin)
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	hbox.add_child(gap)
	town_gold_label = Label.new()
	town_gold_label.text = "0"
	town_gold_label.add_theme_font_size_override("font_size", 24)
	town_gold_label.add_theme_color_override("font_color", Color(1, 1, 1))
	town_gold_label.add_theme_constant_override("outline_size", 2)
	town_gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hbox.add_child(town_gold_label)
	_refresh_persistent_hud()


func _build_mine_panel() -> void:
	## Mine entrance panel — opens when player presses interact near the entrance.
	## Mirrors NPC menu pattern (npc_smith.gd): CanvasLayer + PanelContainer, pauses game while open.
	mine_panel_layer = CanvasLayer.new()
	mine_panel_layer.name = "MinePanelLayer"
	mine_panel_layer.layer = 50
	mine_panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(mine_panel_layer)

	mine_panel_dim = ColorRect.new()
	mine_panel_dim.color = Color(0, 0, 0, 0.55)
	mine_panel_dim.anchor_right = 1.0
	mine_panel_dim.anchor_bottom = 1.0
	mine_panel_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	mine_panel_layer.add_child(mine_panel_dim)

	mine_panel = PanelContainer.new()
	mine_panel.anchor_left = 0.5
	mine_panel.anchor_top = 0.5
	mine_panel.anchor_right = 0.5
	mine_panel.anchor_bottom = 0.5
	mine_panel.custom_minimum_size = Vector2(440, 0)
	mine_panel_layer.add_child(mine_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	mine_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "MINE ENTRANCE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)

	var prompt: Label = Label.new()
	prompt.text = "Select starting floor:"
	vbox.add_child(prompt)

	mine_panel_options = VBoxContainer.new()
	mine_panel_options.add_theme_constant_override("separation", 4)
	vbox.add_child(mine_panel_options)

	var sep_party: HSeparator = HSeparator.new()
	vbox.add_child(sep_party)

	var party_header: Label = Label.new()
	party_header.text = "Select party (Crystal Power):"
	vbox.add_child(party_header)

	mine_panel_party_summary = Label.new()
	mine_panel_party_summary.text = "CP 0 / 1"
	vbox.add_child(mine_panel_party_summary)

	mine_panel_party_container = VBoxContainer.new()
	mine_panel_party_container.add_theme_constant_override("separation", 4)
	vbox.add_child(mine_panel_party_container)

	var sep2: HSeparator = HSeparator.new()
	vbox.add_child(sep2)

	mine_panel_enter_button = Button.new()
	mine_panel_enter_button.text = "Enter Mine"
	mine_panel_enter_button.add_theme_font_size_override("font_size", 22)
	mine_panel_enter_button.pressed.connect(_on_mine_panel_enter)
	vbox.add_child(mine_panel_enter_button)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_close_mine_panel)
	vbox.add_child(close_button)

	# Panel must keep running while the scene is paused.
	mine_panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	mine_panel.visible = false
	mine_panel_dim.visible = false

	# Reposition to center after it's had a layout pass.
	mine_panel.pivot_offset = mine_panel.size / 2.0
	mine_panel.offset_left = -240
	mine_panel.offset_top = -260
	mine_panel.offset_right = 240
	mine_panel.offset_bottom = 260


func _refresh_mine_panel_options() -> void:
	## Rebuild the checkpoint option buttons. Only called on open + checkpoint unlock.
	for btn in mine_panel_option_buttons:
		btn.queue_free()
	mine_panel_option_buttons.clear()
	var checkpoints: Array[int] = GameManager.get_unlocked_checkpoints()
	# Validate stored selection; default to 0 (B1F) if stale.
	if not checkpoints.has(selected_checkpoint):
		selected_checkpoint = 0
	for cp in checkpoints:
		var btn: Button = Button.new()
		if cp == 0:
			btn.text = "Start from B1F"
		else:
			btn.text = "Warp to B%dF" % cp
		btn.toggle_mode = true
		btn.button_pressed = (cp == selected_checkpoint)
		var cp_captured: int = cp
		btn.pressed.connect(func() -> void:
			selected_checkpoint = cp_captured
			_update_mine_panel_selection_visuals()
		)
		mine_panel_options.add_child(btn)
		mine_panel_option_buttons.append(btn)
	_update_mine_panel_selection_visuals()


func _update_mine_panel_selection_visuals() -> void:
	var checkpoints: Array[int] = GameManager.get_unlocked_checkpoints()
	for i in range(mine_panel_option_buttons.size()):
		var cp: int = checkpoints[i]
		mine_panel_option_buttons[i].button_pressed = (cp == selected_checkpoint)


func _open_mine_panel() -> void:
	if mine_panel_open:
		return
	mine_panel_open = true
	_refresh_mine_panel_options()
	_init_party_selection_default()
	_refresh_mine_panel_party()
	mine_panel.visible = true
	mine_panel_dim.visible = true
	get_tree().paused = true
	_wire_mine_panel_focus_wrap()
	# Focus first option button so keyboard/gamepad can activate it
	if mine_panel_option_buttons.size() > 0:
		mine_panel_option_buttons[0].grab_focus()
	elif mine_panel_enter_button:
		mine_panel_enter_button.grab_focus()


func _wire_mine_panel_focus_wrap() -> void:
	var focusables: Array = []
	for btn in mine_panel_option_buttons:
		focusables.append(btn)
	if mine_panel_party_container:
		for row in mine_panel_party_container.get_children():
			if row is HBoxContainer:
				for sub in row.get_children():
					if sub is CheckBox:
						focusables.append(sub)
	if mine_panel_enter_button:
		focusables.append(mine_panel_enter_button)
	# Close button is the last child of the root vbox; find it.
	var vbox: VBoxContainer = mine_panel.get_child(0) as VBoxContainer
	if vbox:
		for c in vbox.get_children():
			if c is Button and c != mine_panel_enter_button:
				focusables.append(c)
	FocusUtil.wire_vertical_wrap(focusables)


func _init_party_selection_default() -> void:
	## Auto-select all affordable bots within CP budget; unselected after budget fills.
	_party_selection.clear()
	var cp_used := 0
	for bot in Inventory.permanent_bots:
		var id: String = bot.get("id", "")
		var cost: int = int(bot.get("cp_cost", 1))
		var knocked_out: bool = bot.get("knocked_out", false)
		if not knocked_out and cp_used + cost <= Inventory.crystal_power_capacity:
			_party_selection[id] = true
			cp_used += cost
		else:
			_party_selection[id] = false
	_party_cp_used = cp_used


func _refresh_mine_panel_party() -> void:
	if mine_panel_party_container == null:
		return
	for child in mine_panel_party_container.get_children():
		child.queue_free()
	if Inventory.permanent_bots.is_empty():
		var empty: Label = Label.new()
		empty.text = "No bots yet — visit the Lab to build one."
		empty.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		mine_panel_party_container.add_child(empty)
	else:
		for bot in Inventory.permanent_bots:
			var id: String = bot.get("id", "")
			var dname: String = bot.get("display_name", "Bot")
			var cost: int = int(bot.get("cp_cost", 1))
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var cb: CheckBox = CheckBox.new()
			cb.text = "%s  (CP %d)" % [dname, cost]
			cb.button_pressed = bool(_party_selection.get(id, false))
			var id_captured: String = id
			var cost_captured: int = cost
			cb.toggled.connect(func(pressed: bool) -> void:
				_on_party_checkbox_toggled(id_captured, cost_captured, pressed)
			)
			row.add_child(cb)
			mine_panel_party_container.add_child(row)
	_update_party_summary_and_locks()
	if mine_panel_open:
		_wire_mine_panel_focus_wrap()


func _on_party_checkbox_toggled(id: String, cost: int, pressed: bool) -> void:
	if pressed:
		if _party_cp_used + cost > Inventory.crystal_power_capacity:
			# Reject: revert the checkbox on next refresh.
			_party_selection[id] = false
		else:
			_party_selection[id] = true
			_party_cp_used += cost
	else:
		if _party_selection.get(id, false):
			_party_cp_used = maxi(0, _party_cp_used - cost)
		_party_selection[id] = false
	_refresh_mine_panel_party()


func _update_party_summary_and_locks() -> void:
	if mine_panel_party_summary:
		mine_panel_party_summary.text = "CP %d / %d" % [_party_cp_used, Inventory.crystal_power_capacity]
	# Disable checkboxes that would exceed the cap when toggled on.
	for child in mine_panel_party_container.get_children():
		if child is HBoxContainer:
			for sub in child.get_children():
				if sub is CheckBox:
					var cb: CheckBox = sub
					# Re-enable all, then disable those that would overflow.
					cb.disabled = false
		# Leave labels alone.
	# Second pass: determine which unchecked ones overflow.
	var idx: int = 0
	for bot in Inventory.permanent_bots:
		if idx >= mine_panel_party_container.get_child_count():
			break
		var row: Node = mine_panel_party_container.get_child(idx)
		idx += 1
		if not (row is HBoxContainer):
			continue
		var cb: CheckBox = row.get_child(0) as CheckBox
		if cb == null:
			continue
		var id: String = bot.get("id", "")
		var cost: int = int(bot.get("cp_cost", 1))
		var currently_selected: bool = bool(_party_selection.get(id, false))
		if not currently_selected and _party_cp_used + cost > Inventory.crystal_power_capacity:
			cb.disabled = true


func _close_mine_panel() -> void:
	if not mine_panel_open:
		return
	mine_panel_open = false
	mine_panel.visible = false
	mine_panel_dim.visible = false
	get_tree().paused = false


func _on_mine_panel_enter() -> void:
	var cp: int = selected_checkpoint
	# Commit party selection to Inventory.run_party before the run starts.
	Inventory.run_party.clear()
	for bot in Inventory.permanent_bots:
		var id: String = bot.get("id", "")
		if _party_selection.get(id, false):
			Inventory.run_party.append(bot.duplicate(true))
	# Unpause before scene change so the new scene starts clean.
	mine_panel_open = false
	mine_panel.visible = false
	mine_panel_dim.visible = false
	get_tree().paused = false
	GameManager.start_run(cp)


func _on_mine_entrance_entered(body: Node2D) -> void:
	if body is Player:
		mine_entrance_in_range = true


func _on_mine_entrance_exited(body: Node2D) -> void:
	if body is Player:
		mine_entrance_in_range = false
		if mine_panel_open:
			_close_mine_panel()


func _on_checkpoint_reached(_floor_num: int) -> void:
	if mine_panel_open:
		_refresh_mine_panel_options()


func _on_gold_changed(_new_gold: int) -> void:
	_refresh_persistent_hud()


func _refresh_persistent_hud() -> void:
	if town_gold_label:
		town_gold_label.text = "%d" % GameManager.gold
	if town_cp_label:
		town_cp_label.text = "CP %d" % Inventory.crystal_power_capacity


func _refresh_stats() -> void:
	## Cheap stats-only refresh — safe to call every frame.
	var ore_count: int = Inventory.get_used_slots()
	stats_label.text = "Gold: %d | Ore: %d | CP: %d | Runs: %d | Deepest: B%dF" % [
		GameManager.gold, ore_count, Inventory.crystal_power_capacity, GameManager.total_runs, GameManager.deepest_checkpoint]
	sell_button.visible = ore_count > 0
	sell_button.text = "Sell All Ore (%d pieces)" % ore_count


func _on_touch_a() -> void:
	if mine_panel_open or storage_panel_open:
		return
	if mine_entrance_in_range:
		_open_mine_panel()
	elif storage_shed_in_range:
		_open_storage_panel()


func _on_touch_b() -> void:
	if mine_panel_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		_close_mine_panel()
	elif storage_panel_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		_close_storage_panel()


func _process(_delta: float) -> void:
	# Refresh stats periodically (after NPC interactions)
	if Engine.get_physics_frames() % 30 == 0:
		_refresh_stats()
	# B closes any panel (keyboard fallback)
	if Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame != Engine.get_process_frames():
			if mine_panel_open:
				_close_mine_panel()
				return
			if storage_panel_open:
				_close_storage_panel()
				return
	# Mine entrance interaction (keyboard fallback)
	if mine_entrance_in_range and not mine_panel_open and not storage_panel_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_mine_panel()
		return
	# Storage shed interaction (keyboard fallback)
	if storage_shed_in_range and not storage_panel_open and not mine_panel_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_storage_panel()


func _on_sell_ore() -> void:
	var earned: int = Inventory.sell_all()
	if earned > 0:
		sell_result.text = "Sold for %d gold!" % earned
		sell_result.visible = true
		var tween: Tween = create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(sell_result, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func() -> void:
			sell_result.visible = false
			sell_result.modulate.a = 1.0
		)
	_refresh_stats()


# (Scout unlock popup removed in Sprint 5 — Scout is now a Lab purchase.)


# ── Storage Shed ────────────────────────────────────────────────────

var storage_shed_area: Area2D = null
var storage_panel_layer: CanvasLayer = null
var storage_panel_dim: ColorRect = null
var storage_panel: PanelContainer = null
var storage_backpack_list: VBoxContainer = null
var storage_storage_list: VBoxContainer = null
var storage_storage_header: Label = null
var storage_result_label: Label = null
var storage_deposit_btn: Button = null
var storage_close_btn: Button = null


func _build_storage_shed() -> void:
	## Build a Storage Shed interactable — Area2D with visual + proximity trigger.
	## Placed to the right of the mine entrance in the town scene.
	storage_shed_area = Area2D.new()
	storage_shed_area.name = "StorageShed"
	storage_shed_area.position = Vector2(900, 380)
	storage_shed_area.collision_layer = 0
	storage_shed_area.collision_mask = 1
	var rect := ColorRect.new()
	rect.name = "Sprite"
	rect.size = Vector2(48, 48)
	rect.position = Vector2(-24, -24)
	rect.color = Color(0.55, 0.38, 0.22)  # warm brown
	storage_shed_area.add_child(rect)
	var shape := CollisionShape2D.new()
	var cs := RectangleShape2D.new()
	cs.size = Vector2(56, 56)
	shape.shape = cs
	storage_shed_area.add_child(shape)
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.text = "Storage [E]"
	lbl.position = Vector2(-40, 28)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 2)
	storage_shed_area.add_child(lbl)
	add_child(storage_shed_area)
	storage_shed_area.body_entered.connect(_on_storage_shed_entered)
	storage_shed_area.body_exited.connect(_on_storage_shed_exited)


func _on_storage_shed_entered(body: Node2D) -> void:
	if body is Player:
		storage_shed_in_range = true


func _on_storage_shed_exited(body: Node2D) -> void:
	if body is Player:
		storage_shed_in_range = false
		if storage_panel_open:
			_close_storage_panel()


func _build_storage_panel() -> void:
	storage_panel_layer = CanvasLayer.new()
	storage_panel_layer.name = "StoragePanelLayer"
	storage_panel_layer.layer = 50
	storage_panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(storage_panel_layer)

	storage_panel_dim = ColorRect.new()
	storage_panel_dim.color = Color(0, 0, 0, 0.55)
	storage_panel_dim.anchor_right = 1.0
	storage_panel_dim.anchor_bottom = 1.0
	storage_panel_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	storage_panel_layer.add_child(storage_panel_dim)

	storage_panel = PanelContainer.new()
	storage_panel.anchor_left = 0.5
	storage_panel.anchor_top = 0.5
	storage_panel.anchor_right = 0.5
	storage_panel.anchor_bottom = 0.5
	storage_panel.custom_minimum_size = Vector2(640, 0)
	storage_panel_layer.add_child(storage_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	storage_panel.add_child(vbox)

	var title := Label.new()
	title.text = "STORAGE SHED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# Two-column split
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	vbox.add_child(cols)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var lh := Label.new()
	lh.text = "Backpack"
	lh.add_theme_font_size_override("font_size", 18)
	left.add_child(lh)
	storage_backpack_list = VBoxContainer.new()
	storage_backpack_list.add_theme_constant_override("separation", 2)
	left.add_child(storage_backpack_list)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	storage_storage_header = Label.new()
	storage_storage_header.text = "Storage (0/48)"
	storage_storage_header.add_theme_font_size_override("font_size", 18)
	right.add_child(storage_storage_header)
	storage_storage_list = VBoxContainer.new()
	storage_storage_list.add_theme_constant_override("separation", 2)
	right.add_child(storage_storage_list)

	vbox.add_child(HSeparator.new())

	storage_deposit_btn = Button.new()
	storage_deposit_btn.text = "Deposit All"
	storage_deposit_btn.pressed.connect(_on_storage_deposit_all)
	vbox.add_child(storage_deposit_btn)

	storage_result_label = Label.new()
	storage_result_label.text = ""
	storage_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(storage_result_label)

	storage_close_btn = Button.new()
	storage_close_btn.text = "Close"
	storage_close_btn.pressed.connect(_close_storage_panel)
	vbox.add_child(storage_close_btn)

	storage_panel.visible = false
	storage_panel_dim.visible = false
	storage_panel.offset_left = -320
	storage_panel.offset_top = -240
	storage_panel.offset_right = 320
	storage_panel.offset_bottom = 240


func _open_storage_panel() -> void:
	if storage_panel_open:
		return
	storage_panel_open = true
	storage_panel.visible = true
	storage_panel_dim.visible = true
	get_tree().paused = true
	_refresh_storage_panel()
	if storage_deposit_btn and not storage_deposit_btn.disabled:
		storage_deposit_btn.grab_focus()
	elif storage_close_btn:
		storage_close_btn.grab_focus()


func _close_storage_panel() -> void:
	if not storage_panel_open:
		return
	storage_panel_open = false
	storage_panel.visible = false
	storage_panel_dim.visible = false
	storage_result_label.text = ""
	get_tree().paused = false


func _refresh_storage_panel() -> void:
	# Backpack column
	for c in storage_backpack_list.get_children():
		c.queue_free()
	var bp_stacks: Array[Dictionary] = Inventory.get_ore_stacks()
	if bp_stacks.is_empty():
		var e := Label.new()
		e.text = "(empty)"
		storage_backpack_list.add_child(e)
	else:
		for slot in bp_stacks:
			var lbl := Label.new()
			var stack_name: String = _storage_stack_name(slot)
			lbl.text = "%s x%d" % [stack_name, int(slot.quantity)]
			storage_backpack_list.add_child(lbl)

	# Storage column
	for c in storage_storage_list.get_children():
		c.queue_free()
	storage_storage_header.text = "Storage (%d/%d)" % [Inventory.get_storage_used(), Inventory.STORAGE_CAPACITY]
	var st_stacks: Array[Dictionary] = Inventory.get_storage_stacks()
	if st_stacks.is_empty():
		var e2 := Label.new()
		e2.text = "(empty)"
		storage_storage_list.add_child(e2)
	else:
		for slot in st_stacks:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var lbl := Label.new()
			var stack_name: String = _storage_stack_name(slot)
			lbl.text = "%s x%d" % [stack_name, int(slot.quantity)]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(lbl)
			var btn := Button.new()
			btn.text = "Withdraw 1"
			btn.disabled = Inventory.get_remaining_slots() <= 0
			var ore_id: String = slot.ore.id
			var mineral_id: String = slot.mineral.id if slot.mineral else ""
			btn.pressed.connect(func(): _on_storage_withdraw_one(ore_id, mineral_id))
			row.add_child(btn)
			storage_storage_list.add_child(row)
	_wire_storage_focus_wrap()


func _wire_storage_focus_wrap() -> void:
	var focusables: Array = FocusUtil.collect_focusables(storage_storage_list)
	if storage_deposit_btn:
		focusables.append(storage_deposit_btn)
	if storage_close_btn:
		focusables.append(storage_close_btn)
	FocusUtil.wire_vertical_wrap(focusables)


func _storage_stack_name(slot: Dictionary) -> String:
	var base: String = slot.ore.display_name
	if slot.mineral:
		return "%s (%s)" % [base, slot.mineral.display_name]
	return base


func _on_storage_deposit_all() -> void:
	var moved: int = Inventory.deposit_all_to_storage()
	if moved > 0:
		storage_result_label.text = "Deposited %d pieces." % moved
	else:
		storage_result_label.text = "Nothing to deposit (or storage full)."
	_refresh_storage_panel()


func _on_storage_withdraw_one(ore_id: String, mineral_id: String) -> void:
	if Inventory.withdraw_one_from_storage(ore_id, mineral_id):
		storage_result_label.text = "Withdrew 1."
	else:
		storage_result_label.text = "Backpack full or item missing."
	_refresh_storage_panel()
