extends Node

## Scripted cabin walk for the movie writer. Moves the body and calls the same
## actions as E, the number keys, a slot drag, and Q.

var _time := 0.0
var _fired := {}
var _ship: Node
var _walk := false

const _WALK := [
	[0.0, 0.0, -0.45, 0.0, -0.06],
	[3.5, 0.0, -1.15, 0.0, -0.02],
	[6.5, 0.08, -1.55, 0.2, 0.02],
	[10.0, -0.05, -1.05, -0.15, -0.08],
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


func _process(delta: float) -> void:
	if _ship == null:
		return
	_time += delta
	var cabin = _ship.get("_cabin")
	if cabin == null or cabin.walker == null or cabin.inventory == null:
		return
	var walker = cabin.walker
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
