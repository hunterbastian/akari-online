extends CanvasLayer

## One speed line. Hidden until the ship is actually flying.

const _PIXEL := preload("res://scripts/ui/pixel_text.gd")

var _ship: Node
var _speed: Label
var _font: FontVariation


func setup(ship: Node) -> void:
	_ship = ship
	layer = 4
	_font = FontVariation.new()
	_font.base_font = _PIXEL.font()
	_speed = _PIXEL.make_label("SPD  0")
	_speed.add_theme_font_override("font", _font)
	add_child(_speed)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var size_px := _PIXEL.pixel_size(view.y)
	_font.spacing_glyph = maxi(1, size_px / 8)
	_speed.add_theme_font_size_override("font_size", size_px)
	var margin := size_px
	var text_h := size_px + 4
	_speed.position = Vector2(margin, int(view.y) - margin - text_h)
	_speed.size = Vector2(size_px * 14, text_h)


func _process(_delta: float) -> void:
	var flying := _ship != null and bool(_ship.get("active"))
	visible = flying
	if not flying:
		return
	var velocity: Vector3 = _ship.get("velocity")
	_speed.text = "SPD  %d" % int(round(velocity.length()))
