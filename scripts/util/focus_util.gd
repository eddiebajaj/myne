class_name FocusUtil
extends RefCounted
## Helpers for wiring Control focus neighbors (wrap-around navigation).

## Wires a vertical list of focusable Controls so up/down wraps around.
## Accepts any Control (Button, CheckBox, etc.). Disabled entries are INCLUDED
## in the focus cycle — Godot's Button accepts focus when disabled but ignores
## ui_accept/click presses, so focus can land on them (so the player sees they
## exist) but pressing A does nothing. This is the desired behavior for menus
## where some options are greyed out (can't afford, already owned, etc.).
static func wire_vertical_wrap(controls: Array) -> void:
	var usable: Array = []
	for c in controls:
		if c == null or not (c is Control):
			continue
		usable.append(c)
	var n := usable.size()
	if n == 0:
		return
	for i in range(n):
		var ctrl: Control = usable[i]
		var prev_ctrl: Control = usable[(i - 1 + n) % n]
		var next_ctrl: Control = usable[(i + 1) % n]
		ctrl.focus_neighbor_top = ctrl.get_path_to(prev_ctrl)
		ctrl.focus_neighbor_bottom = ctrl.get_path_to(next_ctrl)
		ctrl.focus_previous = ctrl.get_path_to(prev_ctrl)
		ctrl.focus_next = ctrl.get_path_to(next_ctrl)


## Walks a container tree and collects all Button/CheckBox descendants in
## tree order. Useful when a panel builds rows of HBoxContainers containing
## labels + buttons and you want a flat list for wrap wiring.
static func collect_focusables(root: Node) -> Array:
	var out: Array = []
	_collect_focusables_recursive(root, out)
	return out


static func _collect_focusables_recursive(node: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Button or child is CheckBox:
			out.append(child)
		_collect_focusables_recursive(child, out)
