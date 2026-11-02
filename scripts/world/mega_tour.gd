extends Node

## From orbit, down through the cloud deck, and along the tower canyon. No landing.

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
	if ship:
		ship.global_position = ship.global_position + Vector3(0.0, 400.0, 0.0)


func _process(delta: float) -> void:
	if _city == null or _camera == null:
		return
	_time += delta
	var u := clampf(_time / _END, 0.0, 1.0)
	_camera.global_position = _city.to_global(_spot(u))
	_camera.look_at(_city.to_global(_aim(u)), _city.global_basis.y)
	_camera.fov = lerpf(34.0, 52.0, smoothstep(0.2, 0.55, u))
	if _time >= _END:
		get_tree().quit()


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
