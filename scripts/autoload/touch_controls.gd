extends CanvasLayer
## Virtual touch controls for mobile web play.
## Shows a virtual joystick (bottom-left) and A/B/Y action buttons
## (bottom-right, console diamond layout).  Y toggles the backpack.
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

## Signals emitted on A/B tap. Consumers connect to these for reliable
## touch input — Input.is_action_just_pressed doesn't work with synthetic
## Input.action_press() calls due to frame timing (press+release both
## fire in the same input phase, so is_action_pressed is already false
## by the time _process runs).
signal action_a_pressed
signal action_b_pressed
signal action_y_pressed
signal action_x_pressed
var _action_press_frame: Dictionary = {}  # action_name -> last frame pressed (debounce)

## Joystick → UI nav state (only used when get_tree().paused == true)
const JOY_UI_ACTIVATE := 0.5
const JOY_UI_RELEASE := 0.3
const JOY_UI_REPEAT_DELAY := 0.4     # initial hold duration before auto-repeat kicks in
const JOY_UI_REPEAT_INTERVAL := 0.1  # time between auto-repeat fires while held
var _joy_ui_axis_state: Vector2i = Vector2i.ZERO  # Current "pressed" state per axis (-1/0/+1)
var _joy_ui_held_time: Vector2 = Vector2.ZERO    # seconds axis held past activation
var _joy_ui_next_repeat: Vector2 = Vector2.ZERO  # next held_time threshold to fire on
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
	_build_action_buttons(root_control)


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


# ─── A / B / Y Buttons ──────────────────────────────────────────────

func _build_action_buttons(parent: Control) -> void:
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

	# Y button — above A (console diamond: Y top, B left, A right, X bottom)
	var y_pos := Vector2(
		a_pos.x + (BTN_A_SIZE - BTN_B_SIZE) * 0.5,  # horizontally centered with A
		a_pos.y - BTN_B_SIZE - 15.0
	)
	var btn_y := _create_action_button("Y", y_pos, BTN_B_SIZE, "action_y")
	parent.add_child(btn_y)

	# X button — below A (console diamond: Y top, B left, A right, X bottom)
	var x_pos := Vector2(
		a_pos.x + (BTN_A_SIZE - BTN_B_SIZE) * 0.5,  # horizontally centered with A
		a_pos.y + BTN_A_SIZE + 15.0
	)
	var btn_x := _create_action_button("X", x_pos, BTN_B_SIZE, "action_x")
	parent.add_child(btn_x)


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


# ─── Shared button handler for A / B / Y ────────────────────────────

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
	# Debounce: emulate_mouse_from_touch causes duplicate presses per tap
	var frame := Engine.get_process_frames()
	if _action_press_frame.get(action_name, -1) == frame:
		return
	_action_press_frame[action_name] = frame
	panel.modulate = Color(1.2, 1.2, 1.4, 1.0)
	# Inject a real InputEventAction so is_action_just_pressed and
	# _unhandled_input work correctly (unlike Input.action_press which
	# only sets internal state).
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)
	# Also inject the matching built-in UI action so Control nodes with
	# focus (Buttons etc.) respond to A/B automatically.
	var ui_action := _ui_action_for(action_name)
	if ui_action != "":
		var ui_ev := InputEventAction.new()
		ui_ev.action = ui_action
		ui_ev.pressed = true
		ui_ev.strength = 1.0
		Input.parse_input_event(ui_ev)
	# Emit signal for reliable detection — consumers connect to these
	if action_name == "action_a":
		action_a_pressed.emit()
	elif action_name == "action_b":
		action_b_pressed.emit()
	elif action_name == "action_y":
		action_y_pressed.emit()
	elif action_name == "action_x":
		action_x_pressed.emit()


func _release_action(action_name: String, panel: Panel) -> void:
	panel.modulate = Color(1, 1, 1, 1)
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = false
	Input.parse_input_event(ev)
	var ui_action := _ui_action_for(action_name)
	if ui_action != "":
		var ui_ev := InputEventAction.new()
		ui_ev.action = ui_action
		ui_ev.pressed = false
		Input.parse_input_event(ui_ev)


func _ui_action_for(action_name: String) -> String:
	match action_name:
		"action_a": return "ui_accept"
		"action_b": return "ui_cancel"
	return ""


# ─── Joystick → UI directional nav (Sprint 6 Pillar A) ───────────────

func _process(delta: float) -> void:
	if get_tree().paused:
		_process_ui_joystick(delta)
	else:
		# Outside UI mode, clear state so first deflection next time fires fresh.
		if _joy_ui_axis_state != Vector2i.ZERO:
			_joy_ui_axis_state = Vector2i.ZERO
			_joy_ui_held_time = Vector2.ZERO
			_joy_ui_next_repeat = Vector2.ZERO


func _process_ui_joystick(delta: float) -> void:
	# --- X axis ---
	var dir_x := 0
	if joystick_dir.x > JOY_UI_ACTIVATE:
		dir_x = 1
	elif joystick_dir.x < -JOY_UI_ACTIVATE:
		dir_x = -1

	if dir_x != 0:
		if _joy_ui_axis_state.x != dir_x:
			# New direction — fire immediately, start hold timer.
			_fire_ui_direction("ui_right" if dir_x > 0 else "ui_left")
			_joy_ui_axis_state.x = dir_x
			_joy_ui_held_time.x = 0.0
			_joy_ui_next_repeat.x = JOY_UI_REPEAT_DELAY
		else:
			# Same direction held — accumulate and fire on repeat schedule.
			_joy_ui_held_time.x += delta
			if _joy_ui_held_time.x >= _joy_ui_next_repeat.x:
				_fire_ui_direction("ui_right" if dir_x > 0 else "ui_left")
				_joy_ui_next_repeat.x += JOY_UI_REPEAT_INTERVAL
	elif absf(joystick_dir.x) < JOY_UI_RELEASE:
		_joy_ui_axis_state.x = 0
		_joy_ui_held_time.x = 0.0
		_joy_ui_next_repeat.x = 0.0

	# --- Y axis ---
	var dir_y := 0
	if joystick_dir.y > JOY_UI_ACTIVATE:
		dir_y = 1
	elif joystick_dir.y < -JOY_UI_ACTIVATE:
		dir_y = -1

	if dir_y != 0:
		if _joy_ui_axis_state.y != dir_y:
			_fire_ui_direction("ui_down" if dir_y > 0 else "ui_up")
			_joy_ui_axis_state.y = dir_y
			_joy_ui_held_time.y = 0.0
			_joy_ui_next_repeat.y = JOY_UI_REPEAT_DELAY
		else:
			_joy_ui_held_time.y += delta
			if _joy_ui_held_time.y >= _joy_ui_next_repeat.y:
				_fire_ui_direction("ui_down" if dir_y > 0 else "ui_up")
				_joy_ui_next_repeat.y += JOY_UI_REPEAT_INTERVAL
	elif absf(joystick_dir.y) < JOY_UI_RELEASE:
		_joy_ui_axis_state.y = 0
		_joy_ui_held_time.y = 0.0
		_joy_ui_next_repeat.y = 0.0


func _fire_ui_direction(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
