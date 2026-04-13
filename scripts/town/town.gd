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
var selected_checkpoint: int = 0
var _touch_b_handled_frame: int = -1
var town_gold_label: Label = null
var town_battery_label: Label = null

# Mine entrance panel (built programmatically in _build_mine_panel).
var mine_panel_layer: CanvasLayer = null
var mine_panel_dim: ColorRect = null
var mine_panel: PanelContainer = null
var mine_panel_options: VBoxContainer = null
var mine_panel_enter_button: Button = null
var mine_panel_option_buttons: Array[Button] = []


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
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.checkpoint_reached.connect(_on_checkpoint_reached)
	Inventory.inventory_changed.connect(_refresh_persistent_hud)
	var touch := get_node_or_null("/root/TouchControls")
	if touch:
		touch.action_a_pressed.connect(_on_touch_a)
		touch.action_b_pressed.connect(_on_touch_b)
	_refresh_stats()
	# Show Scout unlock notification if just unlocked
	if GameManager._scout_just_unlocked and not GameManager.scout_unlocked_notified:
		GameManager._scout_just_unlocked = false
		GameManager.scout_unlocked_notified = true
		_show_scout_unlock_popup()


func _build_town_hud() -> void:
	## Persistent top-right HBox: battery count + gold — spec §6.
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.name = "PersistentHUD"
	hbox.position = Vector2(1280.0 - 280.0, 16.0)
	hbox.size = Vector2(264.0, 32.0)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(hbox)
	town_battery_label = Label.new()
	town_battery_label.text = "Bat x 0"
	town_battery_label.add_theme_font_size_override("font_size", 24)
	town_battery_label.add_theme_color_override("font_color", Color(1, 1, 1))
	town_battery_label.add_theme_constant_override("outline_size", 2)
	town_battery_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	hbox.add_child(town_battery_label)
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
	mine_panel.offset_left = -220
	mine_panel.offset_top = -200
	mine_panel.offset_right = 220
	mine_panel.offset_bottom = 200


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
	mine_panel.visible = true
	mine_panel_dim.visible = true
	get_tree().paused = true
	# Focus first option button so keyboard/gamepad can activate it
	if mine_panel_option_buttons.size() > 0:
		mine_panel_option_buttons[0].grab_focus()
	elif mine_panel_enter_button:
		mine_panel_enter_button.grab_focus()


func _close_mine_panel() -> void:
	if not mine_panel_open:
		return
	mine_panel_open = false
	mine_panel.visible = false
	mine_panel_dim.visible = false
	get_tree().paused = false


func _on_mine_panel_enter() -> void:
	var cp: int = selected_checkpoint
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
	if town_battery_label:
		town_battery_label.text = "Bat x %d" % Inventory.batteries


func _refresh_stats() -> void:
	## Cheap stats-only refresh — safe to call every frame.
	var ore_count: int = Inventory.get_used_slots()
	stats_label.text = "Gold: %d | Ore: %d | Batteries: %d | Runs: %d | Deepest: B%dF" % [
		GameManager.gold, ore_count, Inventory.batteries, GameManager.total_runs, GameManager.deepest_checkpoint]
	sell_button.visible = ore_count > 0
	sell_button.text = "Sell All Ore (%d pieces)" % ore_count


func _on_touch_a() -> void:
	if mine_entrance_in_range and not mine_panel_open:
		_open_mine_panel()


func _on_touch_b() -> void:
	if mine_panel_open:
		_touch_b_handled_frame = Engine.get_process_frames()
		_close_mine_panel()


func _process(_delta: float) -> void:
	# Refresh stats periodically (after NPC interactions)
	if Engine.get_physics_frames() % 30 == 0:
		_refresh_stats()
	# B closes mine panel (keyboard fallback)
	if mine_panel_open and Input.is_action_just_pressed("action_b"):
		if _touch_b_handled_frame == Engine.get_process_frames():
			return
		_close_mine_panel()
		return
	# Mine entrance interaction (keyboard fallback)
	if mine_entrance_in_range and not mine_panel_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("action_a")):
		_open_mine_panel()


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


func _show_scout_unlock_popup() -> void:
	## Display a temporary notification that the Scout companion has been unlocked.
	var popup_layer := CanvasLayer.new()
	popup_layer.layer = 60
	add_child(popup_layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.3
	panel.anchor_bottom = 0.3
	panel.offset_left = -220
	panel.offset_right = 220
	panel.offset_top = -80
	panel.offset_bottom = 80
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	style.border_color = Color(0.3, 0.9, 1.0)
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_width_left = 3
	style.border_width_right = 3
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	popup_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Crystal Companion Found!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = "Scout joins your party."
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(desc_label)

	# Fade out after 3 seconds
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(panel, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func() -> void:
		popup_layer.queue_free()
	)
