extends Node

## Types a light change and SAVE, or after a restart types LOG.

var _ship: Node
var _lines: PackedStringArray = PackedStringArray()
var _time := 0.0
var _index := 0
var _char := 0
var _hold := 0.0
var _done := 0.0


func setup(ship: Node, mode: String) -> void:
	_ship = ship
	if mode == "read":
		_lines = PackedStringArray(["LOG"])
		_done = 6.2
	else:
		_lines = PackedStringArray(["LIGHTS COLD", "SAVE"])
		_done = 6.0


func _process(delta: float) -> void:
	_time += delta
	if _time < 0.45:
		return
	if _index >= _lines.size():
		if _time >= _done:
			get_tree().quit()
		return
	_hold += delta
	if _hold < 0.08:
		return
	_hold = 0.0
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	var line: String = _lines[_index]
	if _char < line.length():
		cabin.terminal_type(line.substr(_char, 1))
		_char += 1
		return
	cabin.terminal_submit()
	_index += 1
	_char = 0
	_hold = -0.7
