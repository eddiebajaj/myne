extends CanvasLayer
## Virtual touch controls for mobile web play.
## Shows a D-pad (bottom-left) and action buttons (bottom-right).
## Uses Godot's built-in GUI input system (gui_input signals) instead of
## manual hit-testing.  This matches how checkpoints and mine entrance
## buttons already work on mobile.

const BUTTON_SIZE := 80
const BUTTON_ALPHA := 0.45
const VIEWPORT_W := 1280
const VIEWPORT_H := 720


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_touch_device():
		visible = false
		return
	_build_ui()


func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


func _build_ui() -> void:
	# CanvasLayer is NOT a Control, so we add a full-viewport Control as the
	# single child.  All buttons go inside it.
	var root_control := Control.new()
	root_control.name = "RootControl"
	root_control.position = Vector2.ZERO
	root_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_build_dpad(root_control)
	_build_action_buttons(root_control)
	_build_backpack_button(root_control)


# === Backpack toggle button (top-right, 72x72, mobile only) ===
func _build_backpack_button(parent: Control) -> void:
	var size: int = 72
	var pos: Vector2 = Vector2(float(VIEWPORT_W) - size - 16.0, 16.0)
	var panel: Panel = Panel.new()
	panel.name = "Btn_toggle_backpack"
	panel.position = pos
	panel.size = Vector2(size, size)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, BUTTON_ALPHA)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.8, 0.8, 0.9, BUTTON_ALPHA)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "Bag"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(size, size)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.set_meta("action_name", "toggle_backpack")
	panel.gui_input.connect(_on_backpack_btn_input.bind(panel))
	parent.add_child(panel)


func _on_backpack_btn_input(event: InputEvent, panel: Panel) -> void:
	var is_press: bool = false
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		is_press = t.pressed
		panel.accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		is_press = mb.pressed
		panel.accept_event()
	else:
		return
	if is_press:
		panel.modulate = Color(1.2, 1.2, 1.4, 1.0)
		var bp: Node = get_node_or_null("/root/BackpackPanel")
		if bp and bp.has_method("toggle"):
			bp.call("toggle")
	else:
		panel.modulate = Color(1, 1, 1, 1)


# === D-Pad ===

func _build_dpad(parent: Control) -> void:
	var base_x := 30.0
	var base_y := float(VIEWPORT_H) - 280.0

	var dpad_defs := {
		"move_up":    Vector2(base_x + BUTTON_SIZE, base_y),
		"move_left":  Vector2(base_x, base_y + BUTTON_SIZE),
		"move_right": Vector2(base_x + BUTTON_SIZE * 2, base_y + BUTTON_SIZE),
		"move_down":  Vector2(base_x + BUTTON_SIZE, base_y + BUTTON_SIZE * 2),
	}
	var labels := {
		"move_up": "^",
		"move_left": "<",
		"move_right": ">",
		"move_down": "v",
	}

	for action_name in dpad_defs:
		var pos: Vector2 = dpad_defs[action_name]
		var btn := _create_touch_button(labels[action_name], pos, action_name, true)
		parent.add_child(btn)


# === Action Buttons ===

func _build_action_buttons(parent: Control) -> void:
	var base_x := float(VIEWPORT_W) - 130.0
	var base_y := float(VIEWPORT_H) - 280.0

	var action_defs := [
		{"name": "mine",       "label": "Mine", "offset": Vector2(0, -BUTTON_SIZE - 10)},
		{"name": "interact",   "label": "Act",  "offset": Vector2(-BUTTON_SIZE - 10, 0)},
		{"name": "build_menu", "label": "Bld",  "offset": Vector2(0, 0)},
	]

	for def in action_defs:
		var pos := Vector2(base_x + def.offset.x, base_y + def.offset.y)
		var btn := _create_touch_button(def.label, pos, def.name, false)
		parent.add_child(btn)


# === Button Factory ===

func _create_touch_button(text: String, pos: Vector2, action_name: String, is_dpad: bool) -> Panel:
	var panel := Panel.new()
	panel.name = "Btn_" + action_name
	panel.position = pos
	panel.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)

	# MOUSE_FILTER_STOP: let Godot's GUI system handle input on this panel.
	# This is the key change -- no more manual hit-testing.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, BUTTON_ALPHA)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.8, 0.8, 0.9, BUTTON_ALPHA)
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	label.add_theme_font_size_override("font_size", 28 if is_dpad else 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	# Store action name as metadata for the signal handler
	panel.set_meta("action_name", action_name)

	# Connect the gui_input signal -- Godot delivers touch/mouse events here
	# with coordinates already resolved, no manual transforms needed.
	panel.gui_input.connect(_on_button_gui_input.bind(panel))

	return panel


func _on_button_gui_input(event: InputEvent, panel: Panel) -> void:
	var action_name: String = panel.get_meta("action_name")

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press_action(action_name, panel)
		else:
			_release_action(action_name, panel)
		panel.accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_action(action_name, panel)
			else:
				_release_action(action_name, panel)
			panel.accept_event()


func _press_action(action_name: String, panel: Panel) -> void:
	panel.modulate = Color(1.2, 1.2, 1.4, 1.0)
	Input.action_press(action_name)


func _release_action(action_name: String, panel: Panel) -> void:
	panel.modulate = Color(1, 1, 1, 1)
	Input.action_release(action_name)
