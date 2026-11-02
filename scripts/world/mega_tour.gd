extends Node

## Orbit, then down through the cloud deck into the tower canyon. No landing.

var _time := 0.0
var _city: Node3D
var _camera: Camera3D

const _END := 28.0


func setup(planet: Node, ship: Node) -> void:
	_city = planet.get_node_or_null("MegaCity") as Node3D
	_camera = ship.get("_chase") as Camera3D
	if _camera:
		_camera.held = true
		_camera.current = true
	if ship.has_method("set_flight_active"):
		ship.global_position = ship.global_position + Vector3(0.0, 400.0, 0.0)


func _process(delta: float) -> void:
	if _city == null or _camera == null:
		return
	_time += delta
	var u := clampf(_time / _END, 0.0, 1.0)
	var spot := _spot(u)
	var aim := _aim(u)
	_camera.global_position = _city.to_global(spot)
	_camera.look_at(_city.to_global(aim), _city.global_basis.y)
	_camera.fov = lerpf(36.0, 50.0, smoothstep(0.25, 0.55, u))
	if _time >= _END:
		get_tree().quit()


func _spot(u: float) -> Vector3:
	if u < 0.28:
		var t := u / 0.28
		return Vector3(lerpf(14.0, 4.0, t), lerpf(62.0, 14.0, t), lerpf(28.0, 8.0, t))
	if u < 0.5:
		var t := (u - 0.28) / 0.22
		return Vector3(lerpf(4.0, 1.2, t), lerpf(14.0, 4.2, t), lerpf(8.0, 1.5, t))
	if u < 0.75:
		var t := (u - 0.5) / 0.25
		return Vector3(lerpf(1.2, -1.4, t), lerpf(4.2, 3.1, t), lerpf(1.5, -0.6, t))
	var t := (u - 0.75) / 0.25
	return Vector3(lerpf(-1.4, 0.6, t), lerpf(3.1, 2.5, t), lerpf(-0.6, 2.2, t))


func _aim(u: float) -> Vector3:
	if u < 0.28:
		return Vector3(0.0, lerpf(12.0, 6.0, u / 0.28), 0.0)
	if u < 0.5:
		return Vector3(0.0, 3.0, -1.0)
	if u < 0.75:
		return Vector3(1.6, 9.0, -2.0)
	return Vector3(-0.4, 7.0, -1.2)
