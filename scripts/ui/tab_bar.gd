class_name TabBarUI
extends HBoxContainer
## Shared horizontal tab bar for tabbed panels (Sprint 8).
##
## Usage:
##   var bar := TabBarUI.new()
##   bar.add_tab("build", "Build")
##   bar.add_tab("upgrade", "Upgrade")
##   bar.tab_changed.connect(func(idx, id): _on_tab_changed(id))
##   bar.set_active("build")
##
## Navigation:
##   - ui_left / ui_right cycle active tab (wrap-around) when a tab button has focus
##   - ui_down moves focus into the content area — call wire_content_below(first_ctrl)
##     after you (re)build the content so the neighbor is correct
##   - ui_up from first content row returns focus to the active tab (caller's job)
##
## Visual:
##   - Active tab is tinted brighter (and thicker/bold label) via theme overrides
##   - Inactive tabs use the default button style
##
## The tab bar does NOT manage its own content — the parent panel is responsible
## for swapping the content container when `tab_changed` fires.

signal tab_changed(index: int, id: String)

const _ACTIVE_COLOR := Color(1.0, 0.95, 0.55)      # warm yellow tint on active label
const _INACTIVE_COLOR := Color(0.75, 0.75, 0.80)   # dim on inactive

var _tab_ids: Array[String] = []
var _tab_buttons: Array[Button] = []
var _tab_labels: Array[String] = []
var _active_index: int = -1
var _content_first_control: Control = null
# When locked, left/right cycling and tab-press activation are ignored and the
# bar dims to communicate inertness. Set by the host panel while a sub-view is
# visible so the tab bar can't steal focus or switch tabs mid-interaction.
var _locked: bool = false


func _init() -> void:
	add_theme_constant_override("separation", 4)


func add_tab(id: String, label: String) -> void:
	var btn: Button = Button.new()
	btn.text = label
	btn.focus_mode = Control.FOCUS_ALL
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Capture id so pressing the tab activates it.
	var id_cap: String = id
	btn.pressed.connect(func(): set_active(id_cap))
	# Allow left/right to cycle via gui_input so we don't depend on Godot's
	# neighbor wiring (which can be finicky when buttons are rebuilt).
	btn.gui_input.connect(_on_tab_button_gui_input.bind(id_cap))
	add_child(btn)
	_tab_ids.append(id)
	_tab_buttons.append(btn)
	_tab_labels.append(label)
	_apply_visual_state()
	_rewire_neighbors()
	if _active_index < 0:
		_active_index = 0
		_apply_visual_state()


func set_active(id: String) -> void:
	if _locked:
		return
	var idx: int = _tab_ids.find(id)
	if idx < 0:
		return
	set_active_index(idx)


func set_active_index(i: int) -> void:
	if _locked:
		return
	if i < 0 or i >= _tab_ids.size():
		return
	if i == _active_index:
		return
	_active_index = i
	_apply_visual_state()
	tab_changed.emit(_active_index, _tab_ids[_active_index])


func set_locked(locked: bool) -> void:
	## When locked: left/right input and tab-button presses are ignored, and the
	## bar is dimmed so the player can see switching is disabled. Used by the
	## host panel while a sub-view (e.g. BUILD_CRAFT) is open.
	if _locked == locked:
		return
	_locked = locked
	modulate.a = 0.5 if locked else 1.0


func is_locked() -> bool:
	return _locked


func get_active_id() -> String:
	if _active_index < 0 or _active_index >= _tab_ids.size():
		return ""
	return _tab_ids[_active_index]


func get_active_index() -> int:
	return _active_index


func get_active_button() -> Button:
	if _active_index < 0 or _active_index >= _tab_buttons.size():
		return null
	return _tab_buttons[_active_index]


func focus_active() -> void:
	var btn: Button = get_active_button()
	if btn == null or btn.is_queued_for_deletion():
		return
	btn.call_deferred("grab_focus")


## Wire `focus_neighbor_bottom` on every tab button so ui_down from the tab bar
## moves into the content area. Pass the first focusable Control below — if null
## the neighbor is cleared (Godot falls back to native traversal).
func wire_content_below(first_content_control: Control) -> void:
	_content_first_control = first_content_control
	for btn in _tab_buttons:
		if btn == null or btn.is_queued_for_deletion():
			continue
		if first_content_control != null and not first_content_control.is_queued_for_deletion():
			btn.focus_neighbor_bottom = btn.get_path_to(first_content_control)
			btn.focus_next = btn.get_path_to(first_content_control)
		else:
			btn.focus_neighbor_bottom = NodePath("")
			btn.focus_next = NodePath("")


# ── Internal ────────────────────────────────────────────────────────

func _on_tab_button_gui_input(event: InputEvent, _id: String) -> void:
	# is_action_pressed() is edge-triggered, so we don't need to filter releases.
	if _locked:
		# Still swallow the input so it doesn't fall through to other handlers,
		# but do not cycle. Prevents tab switches while a sub-view is open.
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_left"):
		_cycle(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_cycle(1)
		get_viewport().set_input_as_handled()


func _cycle(delta: int) -> void:
	var n: int = _tab_ids.size()
	if n == 0:
		return
	var next_idx: int = (_active_index + delta + n) % n
	set_active_index(next_idx)
	# Follow focus so the player keeps navigating the tab bar.
	var btn: Button = _tab_buttons[next_idx]
	if btn and not btn.is_queued_for_deletion():
		btn.call_deferred("grab_focus")


func _apply_visual_state() -> void:
	for i in range(_tab_buttons.size()):
		var btn: Button = _tab_buttons[i]
		if btn == null or btn.is_queued_for_deletion():
			continue
		var is_active: bool = (i == _active_index)
		var base_label: String = _tab_labels[i] if i < _tab_labels.size() else btn.text
		# Prefix a visible marker on active so the state is obvious regardless of theme.
		btn.text = ("> %s <" % base_label) if is_active else ("  %s  " % base_label)
		btn.add_theme_color_override("font_color", _ACTIVE_COLOR if is_active else _INACTIVE_COLOR)
		btn.add_theme_color_override("font_focus_color", _ACTIVE_COLOR if is_active else _INACTIVE_COLOR)


func _rewire_neighbors() -> void:
	# Wire left/right as a ring. Godot will call focus_neighbor_left/right before
	# it falls back to native hit-testing. We still have gui_input as a belt-and-
	# suspenders for edge cases (e.g. single-tab setup, buttons rebuilt).
	var n: int = _tab_buttons.size()
	for i in range(n):
		var btn: Button = _tab_buttons[i]
		if btn == null or btn.is_queued_for_deletion():
			continue
		var prev_btn: Button = _tab_buttons[(i - 1 + n) % n]
		var next_btn: Button = _tab_buttons[(i + 1) % n]
		btn.focus_neighbor_left = btn.get_path_to(prev_btn)
		btn.focus_neighbor_right = btn.get_path_to(next_btn)
		btn.focus_previous = btn.get_path_to(prev_btn)
