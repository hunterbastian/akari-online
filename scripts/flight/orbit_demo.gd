extends Node

## Types AUTOPILOT ORBIT, watches Mina slide past, then taps thrust to cancel.
## "out" skips the typing and leaves the chase camera on the orbit.

const _LINE := "AUTOPILOT ORBIT"

var _ship: Node
var _outside := false
var _time := 0.0
var _char := 0
var _hold := 0.0
var _sent := false
var _cancelled := false


func setup(ship: Node, outside: bool) -> void:
	_ship = ship
	_outside = outside
	var center: Vector3 = ship.planet_position
	var radius: float = ship.planet_radius
	var away: Vector3 = ship.global_position - center
	if away.length() < 1.0:
		away = Vector3(0.0, 0.3, 1.0)
	ship.global_position = center + away.normalized() * radius * 2.55
	ship.look_at(center + Vector3.UP * radius * 0.15, Vector3.UP)


func _process(delta: float) -> void:
	_time += delta
	if _outside:
		if not _sent:
			_ship.engage_orbit()
			_sent = true
		if _time >= 8.0:
			get_tree().quit()
		return
	if not _sent:
		_hold += delta
		if _hold < 0.07:
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
		return
	if not _cancelled and _time >= 10.4:
		Input.action_press("throttle_forward")
		_cancelled = true
	if _time >= 12.4:
		Input.action_release("throttle_forward")
		get_tree().quit()
