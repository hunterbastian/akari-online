extends CanvasLayer

const _FONT := preload("res://assets/fonts/Tinos-Regular.ttf")
const _TITLE := "AKARI ONLINE"
const _PROMPT := "CLICK TO BEGIN"
const _TITLE_COLOR := Color("#E8EEF5")

var _title: Label
var _prompt: Label
var _glow: TextureRect
var _line: ColorRect
var _vignette: ColorRect
var _black: ColorRect
var _title_font: FontVariation
var _prompt_font: FontVariation
var _clock := 0.0
var _intro := 0.0
var _dismiss := -1.0


func _ready() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0, 0, 0, 1)
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = _vignette_shader()
	_vignette.material = vignette_material
	add_child(_vignette)

	_glow = TextureRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.5, 0.68, 0.95, 0.26),
		Color(0.35, 0.5, 0.8, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 512
	texture.height = 256
	_glow.texture = texture
	add_child(_glow)

	_title_font = FontVariation.new()
	_title_font.base_font = _FONT
	_title = Label.new()
	_title.text = _TITLE
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_override("font", _title_font)
	_title.add_theme_color_override("font_color", _TITLE_COLOR)
	add_child(_title)

	_line = ColorRect.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.color = Color(_TITLE_COLOR.r, _TITLE_COLOR.g, _TITLE_COLOR.b, 0.55)
	add_child(_line)

	_prompt_font = FontVariation.new()
	_prompt_font.base_font = _FONT
	_prompt = Label.new()
	_prompt.text = _PROMPT
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_override("font", _prompt_font)
	_prompt.add_theme_color_override("font_color", _TITLE_COLOR)
	add_child(_prompt)

	_black = ColorRect.new()
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.color = Color(0, 0, 0, 1)
	add_child(_black)

	get_viewport().size_changed.connect(_layout)
	_layout()


func set_dismiss(amount: float) -> void:
	_dismiss = amount


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var font_size := 104.0 * view.y / 1080.0
	var spacing := font_size * 0.4
	var size_px := int(round(font_size))
	_title_font.spacing_glyph = int(round(spacing))
	_title.add_theme_font_size_override("font_size", size_px)
	var advance := _title_font.get_string_size(_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var trailing := float(_title_font.spacing_glyph)
	var visual_width := advance.x - trailing
	var title_y := view.y * 0.40
	_title.position = Vector2((view.x - visual_width) * 0.5, title_y)
	_title.size = Vector2(advance.x, font_size * 1.35)

	var line_w := visual_width * 0.42
	_line.position = Vector2((view.x - line_w) * 0.5, title_y + font_size * 1.08)
	_line.size = Vector2(line_w, maxf(1.0, view.y / 1080.0))

	var glow_w := visual_width * 1.5
	var glow_h := font_size * 2.8
	_glow.position = Vector2((view.x - glow_w) * 0.5, title_y - font_size * 0.7)
	_glow.size = Vector2(glow_w, glow_h)

	var prompt_size := int(round(15.0 * view.y / 1080.0))
	_prompt_font.spacing_glyph = int(round(float(prompt_size) * 0.62))
	_prompt.add_theme_font_size_override("font_size", prompt_size)
	var prompt_advance := _prompt_font.get_string_size(_PROMPT, HORIZONTAL_ALIGNMENT_LEFT, -1, prompt_size)
	var prompt_visual := prompt_advance.x - float(_prompt_font.spacing_glyph)
	_prompt.position = Vector2((view.x - prompt_visual) * 0.5, view.y - 78.0 * view.y / 1080.0)
	_prompt.size = Vector2(prompt_advance.x, prompt_size * 1.8)


func _process(delta: float) -> void:
	_clock += delta
	_intro = minf(_intro + delta / 1.75, 1.0)
	var intro_alpha := 1.0 - _smooth(_intro)
	var veil := 0.0
	var ui_alpha := 1.0
	if _dismiss >= 0.0:
		ui_alpha = 1.0 - _smooth(clampf(_dismiss / 0.55, 0.0, 1.0))
		veil = sin(clampf(_dismiss, 0.0, 1.0) * PI) * 0.42
	_black.color = Color(0, 0, 0, maxf(intro_alpha, veil))
	_title.modulate.a = ui_alpha
	_line.modulate.a = ui_alpha
	_glow.modulate.a = ui_alpha
	_vignette.modulate.a = ui_alpha
	var pulse := 0.22 + 0.78 * (0.5 + 0.5 * sin(_clock * 1.35))
	_prompt.modulate.a = pulse * ui_alpha * _smooth(clampf((_intro - 0.35) / 0.4, 0.0, 1.0))


func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _vignette_shader() -> Shader:
	var shader := Shader.new()
	shader.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat dist = distance(UV, vec2(0.5));\n\tfloat vig = smoothstep(0.28, 0.86, dist);\n\tCOLOR = vec4(0.0, 0.01, 0.03, vig * 0.78);\n}\n"
	return shader
