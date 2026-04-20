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
		mine_panel_option_buttons[0].call_deferred("grab_focus")
	elif mine_panel_enter_button:
		mine_panel_enter_button.call_deferred("grab_focus")


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
			var suffix: String = Inventory.format_mineral_suffix(
				bot.get("mineral_profile", {}),
				bot.get("void_resolved", []),
			)
			var labeled: String = dname if suffix.is_empty() else "%s %s" % [dname, suffix]
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var cb: CheckBox = CheckBox.new()
			cb.text = "%s  (CP %d)" % [labeled, cost]
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
#
# Sprint 8 §B3: tabbed Deposit / Withdraw layout.
# - Deposit tab: rows are backpack ore stacks; press A to deposit 1 piece.
#   A "Deposit All" button lives at the bottom of this tab.
# - Withdraw tab: rows are storage ore stacks; press A to withdraw 1 piece.
# Tab swap is driven by TabBarUI.tab_changed; the content VBox is cleared and
# rebuilt per tab. Focus-index preservation mirrors the Sprint 7 pattern in
# npc_lab.gd — on deposit/withdraw press we save the focused button's index
# within the current tab's focusable list and restore it after the rebuild so
# continuous clicks keep focus on the same row (or nearest if the row is gone).

var storage_shed_area: Area2D = null
var storage_panel_layer: CanvasLayer = null
var storage_panel_dim: ColorRect = null
var storage_panel: PanelContainer = null
var storage_tab_bar: TabBarUI = null
var storage_header_label: Label = null         # "Backpack: N/M" or "Storage: N/48"
var storage_content_list: VBoxContainer = null # rebuilt per tab (rows + optional Deposit All)
var storage_result_label: Label = null
var storage_close_btn: Button = null
var _storage_active_tab: String = "deposit"


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
	storage_panel.custom_minimum_size = Vector2(520, 0)
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

	# Tab bar (Sprint 8 shared component).
	storage_tab_bar = TabBarUI.new()
	storage_tab_bar.name = "StorageTabBar"
	storage_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	storage_tab_bar.add_tab("deposit", "Deposit")
	storage_tab_bar.add_tab("withdraw", "Withdraw")
	storage_tab_bar.tab_changed.connect(_on_storage_tab_changed)
	vbox.add_child(storage_tab_bar)

	# Header ("Backpack: N/M" or "Storage: N/48"). Rebuilt per refresh.
	storage_header_label = Label.new()
	storage_header_label.text = ""
	storage_header_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(storage_header_label)

	# Content VBox — cleared and rebuilt on tab change / deposit / withdraw.
	storage_content_list = VBoxContainer.new()
	storage_content_list.add_theme_constant_override("separation", 2)
	storage_content_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(storage_content_list)

	vbox.add_child(HSeparator.new())

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
	storage_panel.offset_left = -260
	storage_panel.offset_top = -260
	storage_panel.offset_right = 260
	storage_panel.offset_bottom = 260


func _open_storage_panel() -> void:
	if storage_panel_open:
		return
	storage_panel_open = true
	storage_panel.visible = true
	storage_panel_dim.visible = true
	get_tree().paused = true
	# Default tab = Deposit. If the bar was already on "deposit" from a prior
	# session, set_active is a no-op and won't fire tab_changed — call
	# _refresh_storage_panel defensively either way.
	_storage_active_tab = "deposit"
	storage_tab_bar.set_active("deposit")
	_refresh_storage_panel()
	# Focus the active tab so L/R cycling works immediately.
	storage_tab_bar.focus_active()


func _close_storage_panel() -> void:
	if not storage_panel_open:
		return
	storage_panel_open = false
	storage_panel.visible = false
	storage_panel_dim.visible = false
	storage_result_label.text = ""
	get_tree().paused = false


func _on_storage_tab_changed(_index: int, id: String) -> void:
	_storage_active_tab = id
	_refresh_storage_panel()
	# Keep focus on the tab bar after a cycle so L/R keeps working.
	storage_tab_bar.focus_active()


func _refresh_storage_panel(restore_focus_index: int = -1) -> void:
	## Rebuild header + rows for the active tab. When restore_focus_index >= 0,
	## re-focus the row at that index (clamped) after rebuild — matches the
	## Sprint 7 focus-preservation pattern so continuous deposit/withdraw clicks
	## stay on the same row (or nearest if the row vanished).
	for c in storage_content_list.get_children():
		c.queue_free()

	if _storage_active_tab == "deposit":
		_build_deposit_tab()
	else:
		_build_withdraw_tab()

	_wire_storage_focus_wrap()
	# Re-point the tab bar's ui_down neighbor at the first content control.
	var content_focusables: Array = _collect_storage_focusables()
	var first: Control = null
	if not content_focusables.is_empty():
		first = content_focusables[0]
	if storage_tab_bar:
		storage_tab_bar.wire_content_below(first if first != null else storage_close_btn)
		# ui_up from the first row returns to the active tab.
		var active_tab_btn: Button = storage_tab_bar.get_active_button()
		if first != null and active_tab_btn != null and not first.is_queued_for_deletion() and not active_tab_btn.is_queued_for_deletion():
			first.focus_neighbor_top = first.get_path_to(active_tab_btn)
			first.focus_previous = first.get_path_to(active_tab_btn)

	if restore_focus_index >= 0:
		_focus_storage_button_at_index(restore_focus_index)


func _build_deposit_tab() -> void:
	## Deposit tab: backpack ores as "A to deposit 1" rows + "Deposit All".
	var used: int = Inventory.get_used_slots()
	var cap: int = Inventory.get_max_capacity()
	storage_header_label.text = "Backpack: %d/%d" % [used, cap]

	var bp_stacks: Array[Dictionary] = Inventory.get_ore_stacks()
	if bp_stacks.is_empty():
		var e := Label.new()
		e.text = "Backpack is empty."
		e.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
		storage_content_list.add_child(e)
	else:
		var storage_full: bool = Inventory.get_storage_remaining() <= 0
		for slot in bp_stacks:
			var btn := Button.new()
			var stack_name: String = _storage_stack_name(slot)
			btn.text = "%s x%d" % [stack_name, int(slot.quantity)]
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.disabled = storage_full
			var ore_id: String = slot.ore.id
			var mineral_id: String = slot.mineral.id if slot.mineral else ""
			btn.pressed.connect(func(): _on_storage_deposit_one(ore_id, mineral_id))
			storage_content_list.add_child(btn)

		# Separator + Deposit All at the bottom of the tab.
		storage_content_list.add_child(HSeparator.new())
		var all_btn := Button.new()
		all_btn.text = "Deposit All"
		all_btn.disabled = storage_full
		all_btn.pressed.connect(_on_storage_deposit_all)
		storage_content_list.add_child(all_btn)


func _build_withdraw_tab() -> void:
	## Withdraw tab: storage ores as "A to withdraw 1" rows.
	storage_header_label.text = "Storage: %d/%d" % [Inventory.get_storage_used(), Inventory.STORAGE_CAPACITY]

	var st_stacks: Array[Dictionary] = Inventory.get_storage_stacks()
	if st_stacks.is_empty():
		var e := Label.new()
		e.text = "Storage is empty."
		e.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))
		storage_content_list.add_child(e)
		return

	var backpack_full: bool = Inventory.get_remaining_slots() <= 0
	for slot in st_stacks:
		var btn := Button.new()
		var stack_name: String = _storage_stack_name(slot)
		btn.text = "%s x%d" % [stack_name, int(slot.quantity)]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.disabled = backpack_full
		var ore_id: String = slot.ore.id
		var mineral_id: String = slot.mineral.id if slot.mineral else ""
		btn.pressed.connect(func(): _on_storage_withdraw_one(ore_id, mineral_id))
		storage_content_list.add_child(btn)


func _wire_storage_focus_wrap() -> void:
	var focusables: Array = _collect_storage_focusables()
	if storage_close_btn:
		focusables.append(storage_close_btn)
	FocusUtil.wire_vertical_wrap(focusables)


func _collect_storage_focusables() -> Array:
	## All focusable buttons inside the tab's content area (excludes tab bar
	## and close button — those are wired separately).
	var focusables: Array = FocusUtil.collect_focusables(storage_content_list)
	focusables = focusables.filter(func(c): return not c.is_queued_for_deletion())
	return focusables


func _get_focused_storage_button_index() -> int:
	## Find the currently focused control's index within the content list
	## (ignoring the tab bar and close button). Returns -1 if focus is not in
	## content, so the caller can choose a fallback (e.g. close button).
	var focused := storage_content_list.get_viewport().gui_get_focus_owner()
	if focused == null:
		return -1
	var focusables: Array = _collect_storage_focusables()
	return focusables.find(focused)


func _focus_storage_button_at_index(idx: int) -> void:
	# Defer focus restoration to the next frame so any queue_free'd old focus
	# owner is fully gone and Godot's internal focus state has settled. See the
	# matching comment in npc_lab.gd — plain call_deferred races with the
	# previous focus owner's tree_exiting (which clears focus) and occasionally
	# loses, leaving the player with no focused button.
	await get_tree().process_frame
	var focusables: Array = _collect_storage_focusables()
	if focusables.is_empty():
		# No rows left (backpack emptied after deposit-all, etc.) — bounce to
		# the active tab so L/R still feels responsive.
		if storage_tab_bar:
			storage_tab_bar.focus_active()
		elif storage_close_btn:
			storage_close_btn.grab_focus()
		return
	idx = clampi(idx, 0, focusables.size() - 1)
	var ctrl: Control = focusables[idx]
	if ctrl is Button and ctrl.disabled:
		# Prefer a non-disabled button if one exists nearby.
		for alt in focusables:
			if alt is Button and not alt.disabled:
				alt.grab_focus()
				return
	ctrl.grab_focus()


func _storage_stack_name(slot: Dictionary) -> String:
	var base: String = slot.ore.display_name
	if slot.mineral:
		return "%s (%s)" % [base, slot.mineral.display_name]
	return base


func _on_storage_deposit_one(ore_id: String, mineral_id: String) -> void:
	var focus_idx: int = _get_focused_storage_button_index()
	if Inventory.deposit_one_to_storage(ore_id, mineral_id):
		storage_result_label.text = "Deposited 1."
	else:
		storage_result_label.text = "Storage full or item missing."
	_refresh_storage_panel(focus_idx)


func _on_storage_deposit_all() -> void:
	var moved: int = Inventory.deposit_all_to_storage()
	if moved > 0:
		storage_result_label.text = "Deposited %d pieces." % moved
	else:
		storage_result_label.text = "Nothing to deposit (or storage full)."
	# After Deposit All the backpack is (usually) empty, so there are no rows
	# to restore to — let the tab bar or close button take focus.
	_refresh_storage_panel()
	if storage_tab_bar:
		storage_tab_bar.focus_active()


func _on_storage_withdraw_one(ore_id: String, mineral_id: String) -> void:
	var focus_idx: int = _get_focused_storage_button_index()
	if Inventory.withdraw_one_from_storage(ore_id, mineral_id):
		storage_result_label.text = "Withdrew 1."
	else:
		storage_result_label.text = "Backpack full or item missing."
	_refresh_storage_panel(focus_idx)
