extends CanvasLayer
## Virtual touch controls for mobile web play.
## Shows a D-pad (bottom-left) and action buttons (bottom-right).
## Injects the same input actions as keyboard so the rest of the game is unaware.

const BUTTON_SIZE := 80
const DPAD_MARGIN := 20
const ACTION_MARGIN := 20
const BUTTON_ALPHA := 0.45
const VIEWPORT_W := 1280
const VIEWPORT_H := 720

var _dpad_buttons: Dictionary = {}  # action_name -> Panel
var _action_buttons: Dictionary = {}
var _active_touches: Dictionary = {}  # touch_index -> Panel


func _ready() -> void:
	layer = 100  # On top of everything
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _is_touch_device():
		visible = false
		set_process_input(false)
		return
	_build_ui()
	set_process_input(true)


func _is_touch_device() -> bool:
	if OS.has_feature("web"):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	return false


func _build_ui() -> void:
	# CanvasLayer is NOT a Control, so child Controls have no parent rect to
	# anchor against.  We must set the size explicitly on every Control we add.
	_build_dpad()
	_build_action_buttons()


# === D-Pad ===

func _build_dpad() -> void:
	# D-pad layout: 3x3 grid, only the cross cells are used
	# Absolute positions: bottom-left of viewport
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
		add_child(btn)
		_dpad_buttons[action_name] = btn


# === Action Buttons ===

func _build_action_buttons() -> void:
	# Absolute positions: bottom-right of viewport
	var base_x := float(VIEWPORT_W) - 130.0
	var base_y := float(VIEWPORT_H) - 280.0

	var action_defs := [
		{"name": "mine", "label": "M", "offset": Vector2(0, -BUTTON_SIZE - 10)},
		{"name": "interact", "label": "E", "offset": Vector2(-BUTTON_SIZE - 10, 0)},
		{"name": "build_menu", "label": "B", "offset": Vector2(0, 0)},
	]

	for def in action_defs:
		var pos := Vector2(base_x + def.offset.x, base_y + def.offset.y)
		var btn := _create_touch_button(def.label, pos, def.name, false)
		add_child(btn)
		_action_buttons[def.name] = btn


# === Button Factory ===

func _create_touch_button(text: String, pos: Vector2, action_name: String, is_dpad: bool) -> Panel:
	var panel := Panel.new()
	panel.name = "Btn_" + action_name
	# Set position and size explicitly (no anchors — parent is CanvasLayer).
	panel.position = pos
	panel.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	# MOUSE_FILTER_IGNORE — we do our own hit-testing in _input().
	# Setting STOP can swallow events before _input() sees them on some builds.
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	label.add_theme_font_size_override("font_size", 28 if is_dpad else 24)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	panel.set_meta("action_name", action_name)
	panel.set_meta("is_dpad", is_dpad)
	panel.set_meta("is_pressed", false)

	return panel


func _get_all_buttons() -> Array:
	var buttons: Array = []
	for btn in _dpad_buttons.values():
		buttons.append(btn)
	for btn in _action_buttons.values():
		buttons.append(btn)
	return buttons


func _find_button_at(pos: Vector2) -> Panel:
	# pos is in viewport coordinates.  With canvas_items stretch mode the
	# viewport is scaled; we need to convert to the game's logical coordinates.
	# get_final_transform() maps from viewport pixels → canvas coordinates.
	var xform := get_viewport().get_final_transform()
	var logical_pos := xform * pos
	for btn in _get_all_buttons():
		var rect := Rect2(btn.position, btn.size)
		if rect.has_point(logical_pos):
			return btn
	return null


func _press_action(action_name: String, panel: Panel) -> void:
	if panel.get_meta("is_pressed"):
		return
	panel.set_meta("is_pressed", true)
	panel.modulate = Color(1.2, 1.2, 1.4, 1.0)
	Input.action_press(action_name)


func _release_action(action_name: String, panel: Panel) -> void:
	if not panel.get_meta("is_pressed"):
		return
	panel.set_meta("is_pressed", false)
	panel.modulate = Color(1, 1, 1, 1)
	Input.action_release(action_name)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var panel := _find_button_at(touch.position)
			if panel:
				var action_name: String = panel.get_meta("action_name")
				_press_action(action_name, panel)
				_active_touches[touch.index] = panel
				get_viewport().set_input_as_handled()
		else:
			if touch.index in _active_touches:
				var panel: Panel = _active_touches[touch.index]
				var action_name: String = panel.get_meta("action_name")
				_release_action(action_name, panel)
				_active_touches.erase(touch.index)
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index in _active_touches:
			var old_panel: Panel = _active_touches[drag.index]
			var new_panel := _find_button_at(drag.position)
			if new_panel != old_panel:
				# Finger dragged off the original button — release it.
				var action_name: String = old_panel.get_meta("action_name")
				_release_action(action_name, old_panel)
				_active_touches.erase(drag.index)
				# If dragged onto another button, press it.
				if new_panel:
					var new_action: String = new_panel.get_meta("action_name")
					_press_action(new_action, new_panel)
					_active_touches[drag.index] = new_panel

	elif event is InputEventMouseButton:
		# Also handle mouse clicks for desktop testing.
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var panel := _find_button_at(mb.position)
				if panel:
					var action_name: String = panel.get_meta("action_name")
					_press_action(action_name, panel)
					_active_touches[-1] = panel  # use -1 as mouse index
					get_viewport().set_input_as_handled()
			else:
				if -1 in _active_touches:
					var panel: Panel = _active_touches[-1]
					var action_name: String = panel.get_meta("action_name")
					_release_action(action_name, panel)
					_active_touches.erase(-1)
					get_viewport().set_input_as_handled()
