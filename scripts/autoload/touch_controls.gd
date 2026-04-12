extends CanvasLayer
## Virtual touch controls for mobile web play.
## Shows a virtual joystick (bottom-left), A/B action buttons (bottom-right),
## and a Bag button (top-right).  Console-style layout.
## Uses Godot's built-in GUI input system (gui_input signals).

const BUTTON_ALPHA := 0.45
const VIEWPORT_W := 1280
const VIEWPORT_H := 720

# Joystick geometry
const JOY_OUTER_RADIUS := 80.0   # 160px diameter outer ring
const JOY_KNOB_RADIUS := 30.0    # 60px diameter inner knob
const JOY_DEADZONE := 0.15       # Ignore tiny deflections

# A/B button sizes
const BTN_A_SIZE := 90
const BTN_B_SIZE := 80

## Public joystick direction vector — read by player.gd for movement.
var joystick_dir: Vector2 = Vector2.ZERO

var _backpack_toggle_frame: int = -1
var _joy_touch_index: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_knob: ColorRect = null
var _joy_panel: Control = null


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
	var root_control := Control.new()
	root_control.name = "RootControl"
	root_control.position = Vector2.ZERO
	root_control.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	_build_joystick(root_control)
	_build_ab_buttons(root_control)
	_build_backpack_button(root_control)


# ─── Virtual Joystick ───────────────────────────────────────────────

func _build_joystick(parent: Control) -> void:
	var outer_size := JOY_OUTER_RADIUS * 2.0
	var pos := Vector2(50.0, float(VIEWPORT_H) - outer_size - 50.0)

	# Container panel that captures touch input for the whole joystick area
	_joy_panel = Control.new()
	_joy_panel.name = "Joystick"
	_joy_panel.position = pos
	_joy_panel.size = Vector2(outer_size, outer_size)
	_joy_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_joy_panel)

	# Outer ring visual
	var outer_ring := _create_circle_panel(Vector2.ZERO, outer_size, Color(0.25, 0.25, 0.35, BUTTON_ALPHA))
	outer_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_panel.add_child(outer_ring)

	# Inner knob visual
	var knob_size := JOY_KNOB_RADIUS * 2.0
	var knob_offset := (outer_size - knob_size) * 0.5
	_joy_knob = ColorRect.new()
	_joy_knob.name = "Knob"
	_joy_knob.size = Vector2(knob_size, knob_size)
	_joy_knob.position = Vector2(knob_offset, knob_offset)
	_joy_knob.color = Color(0.7, 0.7, 0.8, BUTTON_ALPHA + 0.15)
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_panel.add_child(_joy_knob)

	_joy_center = Vector2(JOY_OUTER_RADIUS, JOY_OUTER_RADIUS)

	_joy_panel.gui_input.connect(_on_joystick_gui_input)


func _create_circle_panel(pos: Vector2, diameter: float, color: Color) -> ColorRect:
	## Helper — uses a ColorRect as the circle bg. True circles would need a
	## custom draw or TextureRect, but a rounded-corner rect at 50% radius
	## approximates well enough for a touch overlay.
	var rect := ColorRect.new()
	rect.position = pos
	rect.size = Vector2(diameter, diameter)
	rect.color = color
	return rect


func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_joy_touch_index = t.index
			_update_joystick(t.position)
		elif t.index == _joy_touch_index:
			_reset_joystick()
		_joy_panel.accept_event()

	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_touch_index:
			_update_joystick(d.position)
		_joy_panel.accept_event()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_joy_touch_index = -2  # sentinel for mouse
			_update_joystick(mb.position)
		else:
			if _joy_touch_index == -2:
				_reset_joystick()
		_joy_panel.accept_event()

	elif event is InputEventMouseMotion:
		if _joy_touch_index == -2:
			_update_joystick((event as InputEventMouseMotion).position)
			_joy_panel.accept_event()


func _update_joystick(local_pos: Vector2) -> void:
	var offset := local_pos - _joy_center
	var dist := offset.length()
	var max_dist := JOY_OUTER_RADIUS - JOY_KNOB_RADIUS
	if dist > max_dist:
		offset = offset.normalized() * max_dist
		dist = max_dist

	# Update knob visual position
	var knob_size := JOY_KNOB_RADIUS * 2.0
	_joy_knob.position = _joy_center + offset - Vector2(JOY_KNOB_RADIUS, JOY_KNOB_RADIUS)

	# Normalize to 0..1 range
	var normalized := offset / max_dist if max_dist > 0 else Vector2.ZERO
	if normalized.length() < JOY_DEADZONE:
		joystick_dir = Vector2.ZERO
	else:
		joystick_dir = normalized


func _reset_joystick() -> void:
	_joy_touch_index = -1
	joystick_dir = Vector2.ZERO
	# Snap knob back to center
	var knob_size := JOY_KNOB_RADIUS * 2.0
	var knob_offset := (JOY_OUTER_RADIUS * 2.0 - knob_size) * 0.5
	_joy_knob.position = Vector2(knob_offset, knob_offset)


# ─── A / B Buttons ──────────────────────────────────────────────────

func _build_ab_buttons(parent: Control) -> void:
	# A button — large, bottom-right
	var a_pos := Vector2(
		float(VIEWPORT_W) - BTN_A_SIZE - 40.0,
		float(VIEWPORT_H) - BTN_A_SIZE - 80.0
	)
	var btn_a := _create_action_button("A", a_pos, BTN_A_SIZE, "action_a")
	parent.add_child(btn_a)

	# B button — smaller, to the left of A
	var b_pos := Vector2(
		a_pos.x - BTN_B_SIZE - 20.0,
		a_pos.y + (BTN_A_SIZE - BTN_B_SIZE) * 0.5  # vertically centered with A
	)
	var btn_b := _create_action_button("B", b_pos, BTN_B_SIZE, "action_b")
	parent.add_child(btn_b)


func _create_action_button(text: String, pos: Vector2, btn_size: int, action_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = "Btn_" + action_name
	panel.position = pos
	panel.size = Vector2(btn_size, btn_size)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, BUTTON_ALPHA)
	style.corner_radius_top_left = btn_size / 2
	style.corner_radius_top_right = btn_size / 2
	style.corner_radius_bottom_left = btn_size / 2
	style.corner_radius_bottom_right = btn_size / 2
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
	label.size = Vector2(btn_size, btn_size)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	panel.set_meta("action_name", action_name)
	panel.gui_input.connect(_on_button_gui_input.bind(panel))
	return panel


# ─── Bag Button (unchanged) ─────────────────────────────────────────

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
	var is_release: bool = false
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		is_press = t.pressed
		is_release = not t.pressed
		panel.accept_event()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		is_press = mb.pressed
		is_release = not mb.pressed
		panel.accept_event()
	else:
		return
	if is_press:
		var current_frame: int = Engine.get_process_frames()
		if current_frame == _backpack_toggle_frame:
			return
		_backpack_toggle_frame = current_frame
		panel.modulate = Color(1.2, 1.2, 1.4, 1.0)
		var bp: Node = get_node_or_null("/root/BackpackPanel")
		if bp and bp.has_method("toggle"):
			bp.call("toggle")
	elif is_release:
		panel.modulate = Color(1, 1, 1, 1)


# ─── Shared button handler for A / B ────────────────────────────────

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
