extends Node

## Flies out from Mina and back. A pop in the planet would show up here.

var _ship: Node3D
var _time := 0.0


func setup(ship: Node3D) -> void:
	_ship = ship
	_place(0.0)


func _process(delta: float) -> void:
	_time += delta
	var trip := _time / 10.0
	var out := trip < 0.5
	var k := trip * 2.0 if out else (1.0 - trip) * 2.0
	k = clampf(k, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	_place(k)
	if _time >= 10.4:
		get_tree().quit()


func _place(k: float) -> void:
	if _ship == null:
		return
	var center: Vector3 = _ship.planet_position
	var radius: float = _ship.planet_radius
	var dist := lerpf(radius * 2.4, 680.0, k)
	_ship.set("velocity", Vector3.ZERO)
	_ship.global_position = center + Vector3(0.12, 0.22, 1.0).normalized() * dist
	_ship.look_at(center, Vector3.UP)
