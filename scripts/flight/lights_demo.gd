extends Node

## Types each LIGHTS preset, then holds so the cabin can finish its blend.

const _LINES := ["LIGHTS WARM", "LIGHTS COLD", "LIGHTS RED", "LIGHTS OFF"]
const _TYPE := 0.065

var _ship: Node
var _index := 0
var _char := 0
var _hold := 0.0
var _armed := false


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	if _index >= _LINES.size():
		_hold += delta
		if _hold > 0.45:
			get_tree().quit()
		return
	_hold += delta
	var line: String = _LINES[_index]
	if not _armed:
		if _hold < _TYPE:
			return
		_hold = 0.0
		if _char < line.length():
			cabin.terminal_type(line.substr(_char, 1))
			_char += 1
			return
		cabin.terminal_submit()
		_armed = true
		return
	var pause := 2.15 if line.ends_with("RED") else 1.25
	if _hold < pause:
		return
	_index += 1
	_char = 0
	_armed = false
	_hold = 0.0
