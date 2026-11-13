extends Node

## Screensaver orbit. After a quiet half-minute in flight the camera dollies
## through three framings and the HUD fades. Held flight controls keep the
## chase view. Any new input snaps back.

const IDLE_SEC := 30.0
const APPROACH := 2.8
const PASS := 3.6
const HOLD := 1.4
const FADE_SEC := 1.15

var _ship: Node3D
var _cam: Camera3D
var _items: Array[CanvasItem] = []
var _item_count := 0
var _bound := false
var _idle := 0.0
var _active := false
var _photo := false
var _t := 0.0
var _shot := 0
var _anchor := Vector3.ZERO
var _from := Vector3.ZERO
var _mid := Vector3.ZERO
var _to := Vector3.ZERO
var _aim_from := Vector3.ZERO
var _aim_mid := Vector3.ZERO
var _aim_to := Vector3.ZERO
var _look := Vector3.ZERO
var _fov_from := 52.0
var _fov_mid := 52.0
var _fov_to := 52.0
var _planet := Vector3.ZERO
var _moon := Vector3.ZERO
var _moon2 := Vector3.ZERO
var _has_moon := false
var _has_moon2 := false


static func should_start(idle: float, flying: bool, steering := false) -> bool:
	return flying and not steering and idle >= IDLE_SEC


static func advance_idle(idle: float, step: float, steering: bool) -> float:
	if steering:
		return 0.0
	return idle + step


static func piloting(throttle: bool, turn: bool, lift: bool, boost: bool, scripted: bool) -> bool:
	return throttle or turn or lift or boost or scripted


static func blend(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func setup(ship: Node3D, camera: Camera3D) -> void:
	_ship = ship
	_cam = camera
	# After ThrustKick (priority 20), so this shot keeps the fov it just set.
	process_priority = 40
	_planet = ship.planet_position
	_look = ship.global_position + Vector3.UP * 0.4
	var world := ship.get_parent()
	if world == null:
		return
	var moon := world.find_child("Moon", true, false) as Node3D
	if moon:
		_moon = moon.global_position
		_has_moon = true
	var second := world.find_child("Moon2", true, false) as Node3D
	if second:
		_moon2 = second.global_position
		_has_moon2 = true


func start_photo() -> void:
	if not _bound:
		_bind()
	_photo = true
	_idle = IDLE_SEC
	if _ship:
		_ship.set("hud_alpha", 0.0)
	if not _active:
		_start()
	_paint(0.0)


# hot
func _process(delta: float) -> void:
	if _ship == null or _cam == null:
		return
	if not _bound:
		_bind()
	var step := minf(delta, FlightProfile.DT_CAP)
	if not _flying():
		_idle = 0.0
		if _active:
			_stop()
		_fade(step, 1.0)
		return
	if _active:
		_run(step)
		_fade(step, 0.0)
		return
	var steering := _hands_on()
	_idle = advance_idle(_idle, step, steering)
	_fade(step, 1.0)
	if should_start(_idle, true, steering):
		_start()


func _input(event: InputEvent) -> void:
	if not _real(event):
		return
	_idle = 0.0
	if _active:
		_stop()


func _bind() -> void:
	_bound = true
	if _ship == null:
		return
	var found := _ship.get_tree().get_nodes_in_group("akari_hud")
	for node in found:
		_collect_items(node)
	var hud := _ship.get_tree().root.find_child("InventoryHud", true, false)
	if hud != null:
		_collect_items(hud)
	_item_count = _items.size()


func _start() -> void:
	_active = true
	_t = 0.0
	_shot = 0
	_cam.set("drift_hold", true)
	_cam.current = true
	_look = _ship.global_position + Vector3.UP * 0.4
	_arm()


func _stop() -> void:
	_active = false
	_photo = false
	if _cam and _cam.has_method("release_drift"):
		_cam.call("release_drift")


func _arm() -> void:
	var pos := _ship.global_position
	_anchor = pos
	_from = _cam.global_position
	_aim_from = _look
	_fov_from = _cam.fov
	var forward := -_ship.global_basis.z
	var right := _ship.global_basis.x
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	var to_planet := _planet - pos
	if to_planet.length_squared() < 1.0:
		to_planet = forward
	to_planet = to_planet.normalized()
	var side := to_planet.cross(Vector3.UP)
	if side.length_squared() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	if _shot == 0:
		var away := pos - _planet
		if away.length_squared() < 1.0:
			away = Vector3(0.0, 0.2, 1.0)
		away = away.normalized()
		var flank := away.cross(Vector3.UP)
		if flank.length_squared() < 0.001:
			flank = Vector3.RIGHT
		flank = flank.normalized()
		_mid = pos + away * 11.5 + flank * 6.2 + Vector3.UP * 2.4
		_to = pos + away * 12.8 + flank * 4.0 + Vector3.UP * 2.8
		_aim_mid = pos.lerp(_planet, 0.22)
		_aim_to = pos.lerp(_planet, 0.38) + Vector3.UP * 2.0
		_fov_mid = 42.0
		_fov_to = 46.0
	elif _shot == 1:
		_mid = pos + forward * 2.8 + right * 1.4 - Vector3.UP * 2.35
		_to = pos - forward * 6.4 + right * 0.7 - Vector3.UP * 1.4
		_aim_mid = pos - Vector3.UP * 0.2
		_aim_to = pos - Vector3.UP * 0.05
		_fov_mid = 34.0
		_fov_to = 36.0
	else:
		var focus := _planet
		if _has_moon:
			focus = _moon.lerp(_planet, 0.4)
		var span := maxf(pos.distance_to(focus), 96.0)
		var outward := pos - _planet
		if outward.length_squared() < 1.0:
			outward = -to_planet
		outward = outward.normalized()
		var mid_focus := pos.lerp(focus, 0.55)
		_mid = mid_focus + outward * span * 0.95 + Vector3.UP * span * 0.28
		_to = _mid + side * span * 0.12 + Vector3.UP * span * 0.04
		_aim_mid = mid_focus
		_aim_to = mid_focus + Vector3.UP * span * 0.04
		_fov_mid = 52.0
		_fov_to = 56.0


# hot
func _run(step: float) -> void:
	_t += step
	var limit := APPROACH + PASS + HOLD
	if _t >= limit:
		_t = 0.0
		_shot = (_shot + 1) % 3
		_arm()
	var u := 1.0
	var pos := _to
	var aim := _aim_to
	var fov := _fov_to
	if _t < APPROACH:
		u = blend(_t / APPROACH)
		pos = _from.lerp(_mid, u)
		aim = _aim_from.lerp(_aim_mid, u)
		fov = lerpf(_fov_from, _fov_mid, u)
	elif _t < APPROACH + PASS:
		u = blend((_t - APPROACH) / PASS)
		pos = _mid.lerp(_to, u)
		aim = _aim_mid.lerp(_aim_to, u)
		fov = lerpf(_fov_mid, _fov_to, u)
	var shift := _ship.global_position - _anchor
	pos += shift
	aim += shift
	_cam.global_position = pos
	_cam.fov = fov
	_look = aim
	_point(pos, aim)


# hot
func _point(pos: Vector3, aim: Vector3) -> void:
	var dir := aim - pos
	if dir.length_squared() < 0.0004:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.96:
		up = Vector3.RIGHT
	_cam.look_at(aim, up)


# hot
func _fade(step: float, target: float) -> void:
	var current := float(_ship.get("hud_alpha"))
	var nxt := target
	if not (_photo and target <= 0.0):
		nxt = move_toward(current, target, step / FADE_SEC)
	_ship.set("hud_alpha", nxt)
	_paint(nxt)


func _collect_items(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			_items.append(child)


# hot
func _paint(alpha: float) -> void:
	var i := 0
	while i < _item_count:
		_items[i].modulate.a = alpha
		i += 1


# hot
func _hands_on() -> bool:
	var throttle := Input.is_action_pressed("throttle_forward") or Input.is_action_pressed("throttle_back")
	var turn := Input.is_action_pressed("yaw_left") or Input.is_action_pressed("yaw_right")
	var lift := Input.is_action_pressed("lift") or Input.is_action_pressed("drop")
	var boost := Input.is_action_pressed("boost")
	var scripted := float(_ship.get("script_throttle")) >= 0.0
	if absf(float(_ship.get("script_yaw"))) > 0.0:
		scripted = true
	if bool(_ship.get("demo_fly")):
		scripted = true
	return piloting(throttle, turn, lift, boost, scripted)


# hot
func _flying() -> bool:
	if not bool(_ship.get("active")) or bool(_ship.get("walking")):
		return false
	var eva: Variant = _ship.get("_eva")
	if eva != null and eva.has_method("holds_ship") and bool(eva.call("holds_ship")):
		return false
	return true


func _real(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).relative.length_squared() > 0.01
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) > 0.2
	return false
