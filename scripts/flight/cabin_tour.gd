extends Node

## Scripted cabin walk for the movie writer. Moves the body and calls the same
## actions as E, the number keys, a slot drag, and Q.

var _time := 0.0
var _fired := {}
var _ship: Node
var _walk := false
var _film := false
var _zones := false
var _bay := false
var _bay_opened := false
var _bay_closed := false
var _seated := false
var _outside := false
var _inside := false

const _WALK := [
	[0.0, 0.0, -0.45, 0.0, -0.06],
	[3.5, 0.0, -1.15, 0.0, -0.02],
	[6.5, 0.08, -1.55, 0.2, 0.02],
	[10.0, -0.05, -1.05, -0.15, -0.08],
]

const _ORBIT := 14.0
const _SIT := 11.4
const _FLY := 15.6
const _END := 36.5
const _ZONE_SIT := 26.0
const _ZONE_END := 31.0
const _BAY_OPEN := 6.2
const _BAY_CLOSE := 14.2
const _BAY_END := 19.2

const _BAY := [
	[0.0, 0.0, -1.35, PI, -0.04],
	[4.2, 0.05, -0.42, PI, -0.02],
	[6.0, 0.12, -0.32, PI, 0.0],
]

## Rear bay, storage wall, bunk, workbench, then the seat.
const _ZONES := [
	[0.0, 0.0, -0.35, PI, -0.18],
	[3.2, 0.0, -0.4, PI, -0.06],
	[5.5, -0.15, -0.85, 1.57, -0.28],
	[9.0, -0.1, -0.9, 1.5, -0.16],
	[11.0, 0.15, -1.7, -1.15, -0.4],
	[14.5, 0.1, -1.75, -1.05, -0.25],
	[16.5, -0.1, -1.85, 0.75, -0.32],
	[19.5, -0.05, -1.9, 0.6, -0.18],
	[22.0, 0.0, -2.15, 0.0, -0.08],
	[25.5, 0.0, -2.35, 0.0, -0.12],
]

## Local times, after the exterior orbit. Rear bay, then up the aisle to the seat.
const _CABIN := [
	[0.0, 0.0, -0.2, PI, -0.16],
	[2.2, 0.0, -0.22, PI, -0.06],
	[4.4, 0.0, -0.32, 0.05, -0.08],
	[7.2, 0.0, -0.68, -0.55, -0.18],
	[9.2, 0.05, -1.05, 0.2, -0.04],
	[11.2, 0.0, -1.24, 0.0, -0.12],
]

const _KEYS := [
	[0.0, 0.0, -1.7, PI, -0.1],
	[2.4, 0.0, -1.7, PI, -0.02],
	[6.2, 0.05, -1.1, 0.1, -0.06],
	[7.5, -0.32, -1.68, 0.4, 0.02],
	[9.3, -0.12, -1.25, 0.15, -0.04],
	[13.2, 0.0, -1.0, 0.0, -0.18],
	[15.2, -0.1, -0.7, 2.2, -0.04],
	[18.2, -0.28, -0.58, 2.45, -0.08],
	[22.0, -0.05, -0.55, 2.7, -0.55],
]


func setup(ship: Node) -> void:
	_ship = ship
	_walk = OS.get_cmdline_user_args().has("--walk")
	_film = OS.get_cmdline_user_args().has("--film")
	_zones = OS.get_cmdline_user_args().has("--zones")
	_bay = OS.get_cmdline_user_args().has("--bay")
	if _film:
		var camera := _camera()
		if camera:
			camera.held = true
			camera.current = true


func _process(delta: float) -> void:
	if _ship == null:
		return
	_time += delta
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.walker == null or cabin.inventory == null:
		return
	var walker = cabin.walker
	if _film:
		_play_film(cabin, walker, delta)
		return
	if _zones:
		_play_zones(cabin, walker, delta)
		return
	if _bay:
		_play_bay(cabin, walker, delta)
		return
	walker.locked = false
	if walker.eye:
		walker.eye.current = true
	_glide(cabin, walker, delta)
	if _walk:
		if _time >= 10.2:
			get_tree().quit()
		return
	_once(cabin, 7.6, "helm", func() -> void: cabin.inventory.pickup_kind("helmet"))
	_once(cabin, 9.1, "mug", func() -> void: cabin.inventory.pickup_kind("mug"))
	_once(cabin, 9.8, "s1", func() -> void: cabin.inventory.select(0))
	_once(cabin, 10.5, "s2", func() -> void: cabin.inventory.select(1))
	_once(cabin, 11.2, "s3", func() -> void: cabin.inventory.select(2))
	_once(cabin, 11.9, "s4", func() -> void: cabin.inventory.select(3))
	_once(cabin, 12.6, "s5", func() -> void: cabin.inventory.select(4))
	_once(cabin, 14.6, "open", func() -> void: cabin.inventory.open("LockerL"))
	_once(cabin, 16.0, "to_locker", func() -> void: cabin.inventory.transfer("hotbar", 0, "LockerL", 0))
	_once(cabin, 17.2, "to_pack", func() -> void: cabin.inventory.transfer("LockerL", 0, "pack", 0))
	_once(cabin, 18.2, "close", func() -> void: cabin.inventory.try_interact())
	_once(cabin, 19.0, "crate", func() -> void: _take_crate(cabin))
	_once(cabin, 20.0, "drop", func() -> void: cabin.inventory.drop_selected())
	if _time >= 22.4:
		get_tree().quit()


func _take_crate(cabin) -> void:
	cabin.inventory.select(4)
	cabin.inventory.give("crate", 1)


func _holding(cabin, kind: String) -> bool:
	var hot: Array = cabin.inventory.slots["hotbar"]
	for slot in hot:
		var data: Dictionary = slot
		if str(data["id"]) == kind and int(data["count"]) > 0:
			return true
	return false


func _once(cabin, at: float, id: String, action: Callable) -> void:
	if _time < at or _fired.has(id):
		return
	_fired[id] = true
	action.call()


func _play_zones(cabin, walker, delta: float) -> void:
	if _time < _ZONE_SIT:
		walker.locked = true
		if walker.eye:
			walker.eye.current = true
		_glide_keys(cabin, walker, delta, _ZONES, _time)
	elif not _seated:
		_seated = true
		cabin.snap_view("seat")
		if walker.eye:
			walker.eye.current = true
	elif walker.eye:
		walker.eye.current = true
		var u := clampf((_time - _ZONE_SIT) / (_ZONE_END - _ZONE_SIT), 0.0, 1.0)
		walker.rotation.y = sin(u * TAU) * 0.32
		walker.pitch = -0.12 + sin(u * PI) * 0.06
		walker.eye.rotation.x = walker.pitch
	if _time >= _ZONE_END:
		get_tree().quit()


func _play_bay(cabin, walker, delta: float) -> void:
	walker.locked = true
	if walker.eye:
		walker.eye.current = true
	if _time < _BAY_OPEN:
		_glide_keys(cabin, walker, delta, _BAY, _time)
	elif not _bay_opened:
		_bay_opened = true
		cabin.pulse_bay()
	elif _time >= _BAY_CLOSE and not _bay_closed:
		_bay_closed = true
		cabin.pulse_bay()
	if _time >= _BAY_END:
		get_tree().quit()


func _camera() -> Camera3D:
	return _ship.get("_chase") as Camera3D


func _play_film(cabin, walker, delta: float) -> void:
	var camera := _camera()
	if _time < _ORBIT:
		_orbit(camera)
	elif not _inside:
		_inside = true
		if camera:
			camera.current = false
		_ship.start_cabin_view("rear")
	else:
		var local := _time - _ORBIT
		if local < _SIT:
			walker.locked = true
			if walker.eye:
				walker.eye.current = true
			_glide_keys(cabin, walker, delta, _CABIN, local)
		elif not _seated:
			_seated = true
			cabin.snap_view("seat")
			if walker.eye:
				walker.eye.current = true
		elif local < _FLY:
			if walker.eye:
				walker.eye.current = true
				var u := clampf((local - _SIT) / (_FLY - _SIT), 0.0, 1.0)
				walker.rotation.y = sin(u * TAU) * 0.28
				walker.pitch = -0.12 + sin(u * PI) * 0.05
				walker.eye.rotation.x = walker.pitch
		elif not _outside:
			_outside = true
			if _ship.has_method("dev_leave_cabin"):
				_ship.dev_leave_cabin()
			_ship.demo_fly = true
			if camera:
				var forward: Vector3 = -_ship.global_basis.z
				camera.global_position = _ship.global_position + Vector3.UP * 1.15 - forward * 7.6
				camera.look_at(_ship.global_position + forward * 18.0, Vector3.UP)
				camera.held = false
				camera.current = true
				camera.fov = 52.0
	if _time >= _END:
		get_tree().quit()


func _orbit(camera: Camera3D) -> void:
	if camera == null:
		return
	camera.held = true
	camera.current = true
	var u := clampf(_time / _ORBIT, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	# Behind the ship (Mina beyond the hull), around the side, to a sunlit front quarter.
	var angle := lerpf(0.15, 2.45, u)
	var radius := lerpf(12.0, 8.4, u)
	var height := 1.35 + sin(u * PI) * 1.7
	var forward: Vector3 = -_ship.global_basis.z
	var right: Vector3 = _ship.global_basis.x
	var offset: Vector3 = (-forward * cos(angle) + right * sin(angle)) * radius + Vector3.UP * height
	camera.global_position = _ship.global_position + offset
	camera.look_at(_ship.global_position + forward * 0.8 + Vector3.UP * 0.25, Vector3.UP)
	camera.fov = lerpf(40.0, 32.0, u)


func _glide_keys(cabin, walker, delta: float, keys: Array, time: float) -> void:
	var pose := _sample(keys, time)
	var target: Vector3 = cabin._v(float(pose[0]), 0.0, float(pose[1]))
	var blend := 1.0 - exp(-3.2 * delta)
	walker.position.x = lerpf(walker.position.x, target.x, blend)
	walker.position.z = lerpf(walker.position.z, target.z, blend)
	walker.rotation.y = lerp_angle(walker.rotation.y, float(pose[2]), blend)
	walker.pitch = lerpf(walker.pitch, float(pose[3]), blend)
	if walker.eye:
		walker.eye.rotation.x = walker.pitch


func _glide(cabin, walker, delta: float) -> void:
	var pose := _pose(_time)
	var target: Vector3 = cabin._v(float(pose[0]), 0.0, float(pose[1]))
	var blend := 1.0 - exp(-3.2 * delta)
	walker.position.x = lerpf(walker.position.x, target.x, blend)
	walker.position.z = lerpf(walker.position.z, target.z, blend)
	walker.rotation.y = lerp_angle(walker.rotation.y, float(pose[2]), blend)
	walker.pitch = lerpf(walker.pitch, float(pose[3]), blend)
	if walker.eye:
		walker.eye.rotation.x = walker.pitch


func _pose(time: float) -> Array:
	var keys: Array = _WALK if _walk else _KEYS
	return _sample(keys, time)


func _sample(keys: Array, time: float) -> Array:
	var prev: Array = keys[0]
	for i in keys.size():
		var row: Array = keys[i]
		if time < float(row[0]):
			var span := maxf(float(row[0]) - float(prev[0]), 0.001)
			var u := clampf((time - float(prev[0])) / span, 0.0, 1.0)
			return [
				lerpf(float(prev[1]), float(row[1]), u),
				lerpf(float(prev[2]), float(row[2]), u),
				lerp_angle(float(prev[3]), float(row[3]), u),
				lerpf(float(prev[4]), float(row[4]), u),
			]
		prev = row
	return [prev[1], prev[2], prev[3], prev[4]]
