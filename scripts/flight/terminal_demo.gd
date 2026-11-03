extends Node

## Boots the CRT, types a command, misses one, then tabs and recalls it.

var _ship: Node
var _time := 0.0
var _hold := 0.0
var _step := 0
var _acts: PackedStringArray = PackedStringArray()


func setup(ship: Node) -> void:
	_ship = ship
	_acts = PackedStringArray([
		"H", "E", "L", "P", "enter",
		"L", "I", "G", "H", "S", "enter",
		"L", "I", "tab", "up",
	])


func _process(delta: float) -> void:
	_time += delta
	if _time < 1.7:
		return
	if _step >= _acts.size():
		if _time > 8.4:
			get_tree().quit()
		return
	_hold += delta
	if _hold < 0.11:
		return
	_hold = 0.0
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	var act := _acts[_step]
	_step += 1
	if act == "enter":
		cabin.terminal_submit()
		_hold = -0.35
	elif act == "tab":
		cabin.terminal_tab()
	elif act == "up":
		cabin.terminal_history(-1)
	else:
		cabin.terminal_type(act)
