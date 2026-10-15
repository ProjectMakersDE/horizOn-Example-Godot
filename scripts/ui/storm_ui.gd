class_name StormUI
extends RefCounted

const NAVY := Color("121113")
const PANEL := Color("1C1C1C")
const ORANGE := Color("E78A53")
const SAND := Color("f3e7cc")
const MUTED := Color("a6bdc8")
const TEAL := Color("5F8787")

static func theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 18
	result.set_color("font_color", "Label", SAND)
	result.set_color("font_color", "Button", SAND)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.3))
	result.set_color("font_color", "LineEdit", SAND)
	result.set_color("font_color", "TextEdit", SAND)
	for kind in ["Button", "OptionButton", "CheckButton"]:
		result.set_stylebox("normal", kind, box(PANEL.lightened(0.1)))
		result.set_stylebox("hover", kind, box(PANEL.lightened(0.2), ORANGE))
		result.set_stylebox("pressed", kind, box(ORANGE.darkened(0.35)))
		result.set_stylebox("disabled", kind, box(PANEL.darkened(0.1)))
		result.set_stylebox("focus", kind, box(Color.TRANSPARENT, TEAL))
	for kind in ["LineEdit", "TextEdit"]:
		result.set_stylebox("normal", kind, box(NAVY.lightened(0.05)))
		result.set_stylebox("focus", kind, box(NAVY, TEAL))
	result.set_stylebox("panel", "PanelContainer", box(PANEL))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result

static func box(color: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.set_border_width_all(2 if border.a > 0 else 0)
	style.border_color = border
	style.set_content_margin_all(14)
	return style

static func label(parent: Node, value: String, font_size: int = 18, color: Color = SAND) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result

static func button(parent: Node, value: String, callback: Callable, primary: bool = false) -> Button:
	var result := Button.new()
	result.text = value
	result.custom_minimum_size.y = 44
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		result.add_theme_stylebox_override("normal", box(ORANGE))
		result.add_theme_color_override("font_color", NAVY)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

static func card(parent: Node, width: float = 0.0) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	return column

static func input(parent: Node, hint: String, secret: bool = false) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.secret = secret
	field.custom_minimum_size.y = 44
	parent.add_child(field)
	return field

static func page(root: Control, title: String, subtitle: String) -> VBoxContainer:
	root.theme = theme()
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	root.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	label(heading, "horizOn  /  " + title, 30)
	label(column, subtitle, 16, MUTED)
	return column

static func art(parent: Node, path: String, height: float = 130.0) -> TextureRect:
	var image := TextureRect.new()
	image.texture = load(path) if ResourceLoader.exists(path) else load("res://assets/sprites/seagull_logo.png")
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(height, height)
	parent.add_child(image)
	return image

static func clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


static func scroll_card(parent: Node, width: float = 0.0) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = width
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column := card(scroll)
	column.add_theme_constant_override("separation", 8)
	return column
