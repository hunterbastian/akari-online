extends CanvasLayer

const _FONT := preload("res://assets/fonts/EBGaramond.ttf")


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 22)
	center.add_child(stack)

	var title := Label.new()
	title.text = "AKARI ONLINE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_font := FontVariation.new()
	title_font.base_font = _FONT
	title_font.spacing_glyph = 14
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 54)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96))
	stack.add_child(title)

	var hint := Label.new()
	hint.text = "Click to fly"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_font := FontVariation.new()
	hint_font.base_font = _FONT
	hint_font.spacing_glyph = 2
	hint.add_theme_font_override("font", hint_font)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.95, 0.95, 0.96, 0.82))
	stack.add_child(hint)


func _process(_delta: float) -> void:
	visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
