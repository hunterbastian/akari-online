extends Node

## Flies from the seat so the cockpit CRT numbers change.

var _ship: Node
var _time := 0.0


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	if _time < 2.2:
		_ship.script_throttle = 0.35
	elif _time < 5.4:
		_ship.script_throttle = 1.0
	else:
		_ship.script_throttle = 0.2
	_ship.script_yaw = 0.22
	if _time >= 8.3:
		get_tree().quit()
