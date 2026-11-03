extends Node

## Walks the cabin aisle so the head bob and boot sounds can be recorded.

var _ship: Node
var _time := 0.0


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.walker == null:
		return
	var walker = cabin.walker
	walker.locked = false
	walker.active_walk = true
	walker.eye.current = true
	var leg := int(_time / 1.7) % 4
	var wish := Vector2.ZERO
	if leg == 0:
		wish = Vector2(0.0, -1.0)
	elif leg == 1:
		wish = Vector2(0.7, 0.0)
	elif leg == 2:
		wish = Vector2(0.0, 1.0)
	else:
		wish = Vector2(-0.7, 0.0)
	walker.script_wish = wish
	if _time >= 8.2:
		get_tree().quit()
