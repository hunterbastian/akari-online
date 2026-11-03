extends Node

## Burns toward Mina, sets the lights, then types LOG.

const _LINES := ["LIGHTS WARM", "LOG"]

var _ship: Node
var _time := 0.0
var _index := 0
var _char := 0
var _hold := 0.0
var _typing := false


func setup(ship: Node) -> void:
	_ship = ship
	var center: Vector3 = ship.planet_position
	var radius: float = ship.planet_radius
	var away: Vector3 = ship.global_position - center
	if away.length() < 1.0:
		away = Vector3(0.0, 0.2, 1.0)
	ship.global_position = center + away.normalized() * radius * 3.1
	ship.look_at(center, Vector3.UP)


func _process(delta: float) -> void:
	_time += delta
	if _time < 3.4:
		_ship.script_throttle = 1.0
		return
	_ship.script_throttle = 0.0
	if _index >= _LINES.size():
		if _time >= 10.6:
			get_tree().quit()
		return
	_hold += delta
	if _hold < 0.09:
		return
	_hold = 0.0
	var cabin = _ship.get("_cabin")
	if cabin == null:
		return
	var line: String = _LINES[_index]
	if _char < line.length():
		cabin.terminal_type(line.substr(_char, 1))
		_char += 1
		return
	cabin.terminal_submit()
	_index += 1
	_char = 0
	_hold = -0.45
