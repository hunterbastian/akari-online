extends Node

## Walks up the aisle and looks at the beige terminal.

var _ship: Node
var _time := 0.0
var _armed := false


func setup(ship: Node) -> void:
	_ship = ship


func _process(delta: float) -> void:
	_time += delta
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.walker == null:
		return
	var walker = cabin.walker
	if not _armed:
		_armed = true
		cabin.snap_view("aisle")
		walker.locked = false
		walker.position = cabin._v(0.0, 0.0, -0.2)
		_look(walker, -0.22)
	walker.active_walk = true
	walker.eye.current = true
	var wish := Vector2(0.0, -1.0)
	if _time > 2.2:
		wish = Vector2.ZERO
		_look(walker, -0.46)
	walker.script_wish = wish
	if _time >= 4.0:
		get_tree().quit()


func _look(walker, pitch: float) -> void:
	walker.pitch = pitch
	walker.eye.rotation.x = pitch
