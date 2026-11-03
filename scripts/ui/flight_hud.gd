extends CanvasLayer

## One speed line. Hidden until the ship is actually flying.

const _PIXEL := preload("res://scripts/ui/pixel_text.gd")

var _ship: Node
var _speed: Label
var _hint: Label
var _font: FontVariation
var _hide_shot := false
var _shown_spd := -1
var _shown_hint := ""


func setup(ship: Node) -> void:
	_ship = ship
	layer = 4
	_font = FontVariation.new()
	_font.base_font = _PIXEL.font()
	_speed = _PIXEL.make_label("SPD  0")
	_speed.add_theme_font_override("font", _font)
	add_child(_speed)
	_hint = _PIXEL.make_label("E  STAND")
	_hint.add_theme_font_override("font", _font)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	get_viewport().size_changed.connect(_layout)
	_layout()
	visible = false
	_hide_shot = _beauty_shot()


func _layout() -> void:
	var view := get_viewport().get_visible_rect().size
	var size_px := _PIXEL.pixel_size(view.y)
	_font.spacing_glyph = maxi(1, size_px / 8)
	_speed.add_theme_font_size_override("font_size", size_px)
	var margin := size_px
	var text_h := size_px + 4
	_speed.position = Vector2(margin, int(view.y) - margin - text_h)
	_speed.size = Vector2(size_px * 14, text_h)
	_hint.position = Vector2((view.x - size_px * 12) * 0.5, int(view.y) - margin - text_h)
	_hint.size = Vector2(size_px * 12, text_h)


func _beauty_shot() -> bool:
	if OS.get_environment("AKARI_CABIN") != "":
		return true
	if OS.get_environment("AKARI_HERO") == "1" or OS.get_environment("AKARI_SIDE") == "1" or OS.get_environment("AKARI_SEAM") == "1":
		return true
	var args := OS.get_cmdline_user_args()
	if args.has("--hull") or args.has("--mega") or args.has("--atmo") or args.has("--interior") or args.has("--exterior") or args.has("--thrust-demo") or args.has("--lights") or args.has("--lights-demo") or args.has("--walk-demo") or args.has("--readout-demo") or args.has("--log-demo") or args.has("--time-demo") or args.has("--orbit-demo") or args.has("--lod-demo") or args.has("--save-demo"):
		return true
	for arg in args:
		if str(arg).begins_with("mega") or str(arg).begins_with("atmo"):
			return true
	return false


func _set_speed(spd: int) -> void:
	_speed.text = "SPD  %d" % spd


func _set_hint(text: String, show: bool) -> void:
	_hint.text = text
	_hint.visible = show


# hot
func _process(_delta: float) -> void:
	if _hide_shot:
		visible = false
		return
	var flying := _ship != null and bool(_ship.get("active"))
	visible = flying
	if not flying:
		return
	var velocity: Vector3 = _ship.get("velocity")
	var spd := int(round(velocity.length()))
	if spd != _shown_spd:
		_shown_spd = spd
		_set_speed(spd)
	var walking := bool(_ship.get("walking"))
	var cabin = _ship.get("_cabin")
	var hint := ""
	var show := false
	if walking and cabin != null and cabin.has_method("near_bay_lever") and cabin.near_bay_lever():
		hint = "E  BAY"
		show = true
	elif walking and _ship.has_method("near_seat") and _ship.near_seat():
		hint = "E  SIT"
		show = true
	elif not walking:
		hint = "E  STAND UP"
		show = true
	if hint != _shown_hint or show != _hint.visible:
		_shown_hint = hint
		_set_hint(hint, show)
