extends Node

## From orbit, down through the cloud deck, and along the tower canyon. No landing.

var _time := 0.0
var _city: Node3D
var _camera: Camera3D
var _atmo := false
var _end := 28.0


func setup(planet: Node, ship: Node) -> void:
	_city = planet.get_node_or_null("MegaCity") as Node3D
	_camera = ship.get("_chase") as Camera3D
	if _camera:
		_camera.held = true
		_camera.current = true
	if ship:
		ship.global_position = ship.global_position + Vector3(0.0, 400.0, 0.0)
	_atmo = OS.get_cmdline_user_args().has("--atmo")
	_end = 24.0 if _atmo else 28.0


func _process(delta: float) -> void:
	if _city == null or _camera == null:
		return
	_time += delta
	var u := clampf(_time / _end, 0.0, 1.0)
	var spot: Vector3 = _atmo_spot(u) if _atmo else _spot(u)
	var aim: Vector3 = _atmo_aim(u) if _atmo else _aim(u)
	_camera.global_position = _city.to_global(spot)
	_camera.look_at(_city.to_global(aim), _city.global_basis.y)
	_camera.fov = lerpf(28.0 if _atmo else 34.0, 52.0, smoothstep(0.25, 0.6, u))
	if _time >= _end:
		get_tree().quit()


func _atmo_spot(u: float) -> Vector3:
	if u < 0.35:
		var t := u / 0.35
		return Vector3(lerpf(12.0, 6.0, t), lerpf(92.0, 36.0, t), lerpf(40.0, 22.0, t))
	if u < 0.7:
		var t := (u - 0.35) / 0.35
		return Vector3(lerpf(6.0, 0.6, t), lerpf(36.0, 6.0, t), lerpf(22.0, 10.0, t))
	var t := (u - 0.7) / 0.3
	return Vector3(lerpf(0.6, 0.2, t), lerpf(6.0, 3.0, t), lerpf(10.0, 5.0, t))


func _atmo_aim(u: float) -> Vector3:
	if u < 0.4:
		return Vector3(0.0, -6.0, 2.0)
	return Vector3(0.3, 12.0, 15.0)


func _spot(u: float) -> Vector3:
	if u < 0.28:
		var t := u / 0.28
		return Vector3(lerpf(16.0, 3.0, t), lerpf(46.0, 14.0, t), lerpf(28.0, 12.0, t))
	if u < 0.48:
		var t := (u - 0.28) / 0.2
		return Vector3(lerpf(3.0, 0.35, t), lerpf(14.0, 3.4, t), lerpf(12.0, 7.0, t))
	if u < 0.78:
		var t := (u - 0.48) / 0.3
		return Vector3(lerpf(0.35, -0.2, t), lerpf(3.4, 2.6, t), lerpf(7.0, 1.0, t))
	var t := (u - 0.78) / 0.22
	return Vector3(lerpf(-0.2, 1.2, t), lerpf(2.6, 4.5, t), lerpf(1.0, -2.0, t))


func _aim(u: float) -> Vector3:
	if u < 0.28:
		return Vector3(0.0, 10.0, 6.0)
	if u < 0.48:
		return Vector3(0.2, 8.0, 15.0)
	return Vector3(0.4, 16.0, 15.0)
