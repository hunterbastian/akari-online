extends Node

## Frames Mina for stills and the descent clip. The planet keeps its spin held
## so a ridge picked at load stays under the camera.

var _camera: Camera3D
var _body: Node3D
var _sun := Vector3.FORWARD
var _mode := "orbit"
var _time := 0.0
var _from := Vector3.ZERO
var _from_look := Vector3.ZERO
var _to := Vector3.ZERO
var _to_look := Vector3.ZERO
var _from_fov := 34.0
var _to_fov := 50.0


func setup(camera: Camera3D, body: Node3D, sun: Vector3, mode: String) -> void:
	_camera = camera
	_body = body
	_sun = sun.normalized()
	_mode = mode
	if mode != "fly" and body.has_method("hold_for_shot"):
		body.hold_for_shot()
	camera.held = true
	camera.current = true
	if mode == "fly":
		var start := _pose("orbit")
		var end := _pose("ridge")
		_from = start.pos
		_from_look = start.look
		_from_fov = start.fov
		_to = end.pos
		_to_look = end.look
		_to_fov = end.fov
		_apply(start.pos, start.look, start.fov)
		set_process(true)
		return
	var pose := _pose(mode)
	_apply(pose.pos, pose.look, pose.fov)
	set_process(false)


func _process(delta: float) -> void:
	_time += delta
	var t := clampf(_time / 7.5, 0.0, 1.0)
	var s := t * t * (3.0 - 2.0 * t)
	_apply(_from.lerp(_to, s), _from_look.lerp(_to_look, s), lerpf(_from_fov, _to_fov, s))


func _apply(pos: Vector3, look: Vector3, fov: float) -> void:
	_camera.global_position = pos
	_camera.look_at(look, Vector3.UP)
	_camera.fov = fov


func _pose(mode: String) -> Dictionary:
	var center: Vector3 = _body.global_position
	var radius := 24.0
	if _body.get("planet") is Dictionary:
		radius = float(_body.planet.radius)
	if mode == "orbit" or not _body.has_method("feature"):
		return _orbit(center, radius)
	var kind := mode
	if mode == "clouds":
		kind = "clouds"
	elif mode == "land":
		kind = "land"
	elif mode == "crater":
		kind = "crater"
	elif mode == "canyon" or mode == "ridge":
		kind = mode
	else:
		return _orbit(center, radius)
	var feat: Dictionary = _body.feature(kind)
	return _low(feat, mode, radius)


func _orbit(center: Vector3, radius: float) -> Dictionary:
	var right := _sun.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(_sun).normalized()
	# Off the sun axis so the lit face, the terminator, and the bright limb all sit in frame.
	var dir := (right * 0.78 + up * 0.22 + _sun * 0.38).normalized()
	return {
		"pos": center + dir * radius * 3.05,
		"look": center - up * radius * 0.02,
		"fov": 36.0,
	}


func _low(feat: Dictionary, mode: String, _radius: float) -> Dictionary:
	var point: Vector3 = feat.point
	var normal: Vector3 = feat.normal
	var tangent: Vector3 = feat.tangent
	var hover := 7.0
	var back := 14.0
	var ahead := 22.0
	var lift := 1.6
	var fov := 44.0
	if mode == "crater":
		hover = 20.0
		back = 2.5
		ahead = 0.0
		lift = 0.0
		fov = 50.0
	elif mode == "canyon":
		hover = 6.5
		back = 3.0
		ahead = 8.0
		lift = 0.2
		fov = 52.0
	elif mode == "land":
		hover = 4.2
		back = 1.4
		ahead = 4.5
		lift = -0.6
		fov = 58.0
	elif mode == "clouds":
		hover = 11.0
		back = 2.0
		ahead = 1.5
		lift = -1.5
		fov = 52.0
	elif mode == "ridge":
		hover = 7.5
		back = 5.5
		ahead = 10.0
		lift = 0.6
		fov = 50.0
	return {
		"pos": point + normal * hover - tangent * back,
		"look": point + tangent * ahead + normal * lift,
		"fov": fov,
	}
