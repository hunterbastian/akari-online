extends RefCounted

const FONT_PATH := "res://assets/fonts/Silkscreen-Regular.ttf"
const COLOR := Color("#E8EEF5")
const UNIT := 8


static func font() -> FontFile:
	var file := load(FONT_PATH) as FontFile
	file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	file.hinting = TextServer.HINTING_NONE
	file.generate_mipmaps = false
	file.oversampling = 1.0
	return file


static func pixel_size(viewport_height: float) -> int:
	var steps := maxi(2, int(round(viewport_height / 540.0)))
	return UNIT * steps


static func make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", font())
	label.add_theme_color_override("font_color", COLOR)
	return label
