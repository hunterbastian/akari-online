extends Node

## Idle, one long boost, then release. Long enough to feel the slow ramp.

var _ship: Node
var _time := 0.0


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	var burning := _time >= 1.35 and _time < 7.15
	_ship.script_throttle = 1.0 if burning else 0.0
	_ship.script_boost = burning
	if _time >= 9.7:
		get_tree().quit()
