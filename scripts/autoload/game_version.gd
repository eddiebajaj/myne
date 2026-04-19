extends Node
## Global version label autoload.
##
## Holds the game version string and spawns a small grey label in the
## bottom-right corner of the screen that persists across all scenes.
##
## Build script (not a .tscn autoload) to avoid the web-export issue where
## autoload .tscn UI panels can fail to initialise — we build the CanvasLayer
## and Label at runtime in _ready() instead.

const VERSION := "v0.8.0a"

var _canvas_layer: CanvasLayer
var _label: Label


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "VersionLabelLayer"
	_canvas_layer.layer = 128  # above typical HUD/touch layers
	add_child(_canvas_layer)

	_label = Label.new()
	_label.name = "VersionLabel"
	_label.text = VERSION
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 0.8))

	# Anchor to bottom-right with ~8px padding.
	_label.anchor_left = 1.0
	_label.anchor_top = 1.0
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -120.0
	_label.offset_top = -22.0
	_label.offset_right = -8.0
	_label.offset_bottom = -4.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	_canvas_layer.add_child(_label)
