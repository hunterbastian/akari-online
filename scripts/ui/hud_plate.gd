extends Control

## Vector plate for the combiner glass. Drawn into a black SubViewport, then added
## onto the glass. Positions stay on whole pixels so Silkscreen locks to the grid.

const COLOR := Color(0.78, 1.0, 0.86, 1.0)
const DIM := Color(0.42, 0.72, 0.5, 1.0)
const FONT_SIZE := 16
const LINE := 20

var _font: Font
var _ship := ""
var _hull := ""
var _spd := ""
var _mina := ""
var _fuel := ""
var _autopilot := ""
var _route := ""
var _speed_value := 0.0
var _range_value := 0.0


func setup(font: Font) -> void:
	_font = font
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST


func set_readout(ship_name: String, hull: int, speed: float, mina_range: float, fuel: float, autopilot: String, route: String) -> void:
	var next_ship := ship_name.to_upper()
	var next_hull := str(hull)
	var next_spd := "%.1f" % speed
	var next_mina := "%05d" % clampi(int(round(maxf(mina_range, 0.0))), 0, 99999)
	var next_fuel := "%.2f" % fuel
	var next_auto := autopilot.to_upper()
	var next_route := route.to_upper()
	if (
		next_ship == _ship
		and next_hull == _hull
		and next_spd == _spd
		and next_mina == _mina
		and next_fuel == _fuel
		and next_auto == _autopilot
		and next_route == _route
	):
		return
	_ship = next_ship
	_hull = next_hull
	_spd = next_spd
	_mina = next_mina
	_fuel = next_fuel
	_autopilot = next_auto
	_route = next_route
	_speed_value = maxf(speed, 0.0)
	_range_value = maxf(mina_range, 0.0)
	queue_redraw()


func _ready() -> void:
	var parent := get_parent()
	if parent is SubViewport:
		size = Vector2(parent.size)
	queue_redraw()


func _draw() -> void:
	if _font == null or size.x < 8.0 or size.y < 8.0:
		return
	var frame := Rect2(Vector2(8, 8), size - Vector2(16, 16))
	draw_rect(frame, DIM, false, 1.0, false)
	_corners(14.0, 22.0)
	# Content sits in the upper part of the plate so the seat back does not cover it.
	var reticle := Vector2(round(size.x * 0.60) as float, round(size.y * 0.40) as float)
	_draw_ladder(Vector2(round(size.x * 0.08), reticle.y), _speed_value, true)
	_draw_ladder(Vector2(round(size.x * 0.92), reticle.y), _range_value, false)
	_draw_reticle(reticle)
	_draw_block(Vector2(round(size.x * 0.17), round(size.y * 0.08)))


func _draw_block(origin: Vector2) -> void:
	var rows: Array[String] = [
		_ship if not _ship.is_empty() else "SHIP",
		"HULL  " + _hull,
		"SPD   " + _spd,
		"MINA  " + _mina,
		"FUEL  " + _fuel,
	]
	var y := origin.y
	for row in rows:
		_text(Vector2(origin.x, y), row, COLOR)
		y += LINE
	y += 8.0
	_text(Vector2(origin.x, y), "AUTOPILOT " + _autopilot, COLOR)
	y += LINE
	_text(Vector2(origin.x, y), "ROUTE " + _route, COLOR)


func _draw_reticle(center: Vector2) -> void:
	var radius: float = round(size.y * 0.145)
	var gap: float = round(radius * 0.34)
	var arm: float = round(radius * 1.35)
	_dashed_circle(center, radius)
	draw_line(_px(center + Vector2(-arm, 0)), _px(center + Vector2(-gap, 0)), COLOR, -1.0, false)
	draw_line(_px(center + Vector2(gap, 0)), _px(center + Vector2(arm, 0)), COLOR, -1.0, false)
	draw_line(_px(center + Vector2(0, -arm * 0.78)), _px(center + Vector2(0, -gap)), COLOR, -1.0, false)
	draw_line(_px(center + Vector2(0, gap)), _px(center + Vector2(0, arm * 0.72)), COLOR, -1.0, false)
	var box := 5.0
	draw_rect(Rect2(center - Vector2(box, box), Vector2(box * 2.0, box * 2.0)), COLOR, false, 1.0, false)
	var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for dir in dirs:
		draw_line(_px(center + dir * (radius + 3.0)), _px(center + dir * (radius + 11.0)), DIM, -1.0, false)


func _dashed_circle(center: Vector2, radius: float) -> void:
	var steps := 32
	for i in steps:
		if i % 2 == 1:
			continue
		var a0 := TAU * float(i) / float(steps)
		var a1 := TAU * float(i + 1) / float(steps)
		draw_line(
			_px(center + Vector2(cos(a0), sin(a0)) * radius),
			_px(center + Vector2(cos(a1), sin(a1)) * radius),
			COLOR,
			-1.0,
			false
		)


func _draw_ladder(origin: Vector2, value: float, speed_tape: bool) -> void:
	var step := _tape_step(value, speed_tape)
	var px := 22.0
	var span := 3
	var inward := 1.0 if speed_tape else -1.0
	var top := origin.y - float(span) * px
	var bottom := origin.y + float(span) * px
	draw_line(_px(Vector2(origin.x, top)), _px(Vector2(origin.x, bottom)), DIM, -1.0, false)
	var base: float = floor(value / step) * step
	for n in range(-span - 2, span + 3):
		var mark: float = base + float(n) * step
		if mark < -0.001:
			continue
		var py: float = origin.y + (value - mark) / step * px
		if py < top - 1.0 or py > bottom + 1.0:
			continue
		var index := int(round(mark / step))
		var major := index % 2 == 0 or step >= 50.0
		var tick := 16.0 if major else 8.0
		draw_line(_px(Vector2(origin.x, py)), _px(Vector2(origin.x + inward * tick, py)), DIM if absf(py - origin.y) > 10.0 else COLOR, -1.0, false)
		if not major or absf(py - origin.y) < px * 0.45:
			continue
		var label := str(int(round(mark)))
		var label_w := _width(label)
		var tx := origin.x - tick - 6.0 - label_w if speed_tape else origin.x + tick + 6.0
		_text(Vector2(tx, py - FONT_SIZE * 0.5), label, DIM)
	var caret_x := origin.x + inward * 4.0
	_caret(Vector2(caret_x, origin.y), inward)
	var readout := _spd if speed_tape else str(int(round(value)))
	var readout_w := _width(readout)
	var rx := origin.x - 22.0 - readout_w if speed_tape else origin.x + 22.0
	_text(Vector2(rx, origin.y - FONT_SIZE * 0.5), readout, COLOR)


func _caret(at: Vector2, dir: float) -> void:
	var tip := at + Vector2(dir * 9.0, 0.0)
	var top := at + Vector2(0.0, -5.0)
	var bottom := at + Vector2(0.0, 5.0)
	draw_line(_px(top), _px(tip), COLOR, -1.0, false)
	draw_line(_px(bottom), _px(tip), COLOR, -1.0, false)


func _tape_step(value: float, speed_tape: bool) -> float:
	if speed_tape:
		if value < 40.0:
			return 5.0
		if value < 160.0:
			return 10.0
		return 20.0
	if value < 80.0:
		return 10.0
	if value < 500.0:
		return 50.0
	if value < 2500.0:
		return 100.0
	return 500.0


func _corners(margin: float, length: float) -> void:
	var points: Array[Vector2] = [
		Vector2(margin, margin),
		Vector2(size.x - margin, margin),
		Vector2(margin, size.y - margin),
		Vector2(size.x - margin, size.y - margin),
	]
	var signs: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
	for i in points.size():
		var point: Vector2 = points[i]
		var sign: Vector2 = signs[i]
		draw_line(point, point + Vector2(sign.x * length, 0.0), COLOR, -1.0, false)
		draw_line(point, point + Vector2(0.0, sign.y * length), COLOR, -1.0, false)


func _text(at: Vector2, text: String, color: Color) -> void:
	if _font == null or text.is_empty():
		return
	var baseline := _px(at) + Vector2(0.0, _font.get_ascent(FONT_SIZE))
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, color)


func _width(text: String) -> float:
	if _font == null:
		return float(text.length() * FONT_SIZE)
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE).x


func _px(point: Vector2) -> Vector2:
	return Vector2(round(point.x), round(point.y))
