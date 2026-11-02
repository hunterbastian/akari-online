extends Node

## Records idle, boost, release, boost, release. Drives the real throttle path.

var _ship: Node
var _time := 0.0


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	var burning := (_time >= 1.15 and _time < 3.15) or (_time >= 4.55 and _time < 6.55)
	_ship.script_throttle = 1.0 if burning else 0.0
	_ship.script_boost = burning
	if _time >= 8.15:
		get_tree().quit()
