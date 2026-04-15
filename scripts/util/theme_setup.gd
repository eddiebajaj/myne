class_name ThemeSetup
extends RefCounted
## Applies a prominent focus outline to the default theme so every Button
## in the game gets a visible focus indicator without per-scene work.
## Call ThemeSetup.apply_focus_theme() once at startup (GameManager._ready).

static func apply_focus_theme() -> void:
	var theme := ThemeDB.get_default_theme()
	if theme == null:
		return
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)  # transparent fill — show button underneath
	focus_style.border_color = Color(1.0, 0.9, 0.2, 1.0)  # bright yellow
	focus_style.border_width_top = 3
	focus_style.border_width_bottom = 3
	focus_style.border_width_left = 3
	focus_style.border_width_right = 3
	focus_style.corner_radius_top_left = 4
	focus_style.corner_radius_top_right = 4
	focus_style.corner_radius_bottom_left = 4
	focus_style.corner_radius_bottom_right = 4
	focus_style.expand_margin_left = 2
	focus_style.expand_margin_right = 2
	focus_style.expand_margin_top = 2
	focus_style.expand_margin_bottom = 2
	theme.set_stylebox("focus", "Button", focus_style)
	theme.set_stylebox("focus", "CheckBox", focus_style)
