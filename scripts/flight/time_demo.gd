extends Node

## Types TIME on the seat CRT after the session clock has moved.

const _LINE := "TIME"

var _ship: Node
var _time := 0.0
var _char := 0
var _hold := 0.0
var _sent := false


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	if _time < 1.1:
		return
	if _sent:
		if _time >= 6.4:
			get_tree().quit()
		return
	_hold += delta
	if _hold < 0.14:
		return
	_hold = 0.0
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	if _char < _LINE.length():
		cabin.terminal_type(_LINE.substr(_char, 1))
		_char += 1
		return
	cabin.terminal_submit()
	_sent = true
