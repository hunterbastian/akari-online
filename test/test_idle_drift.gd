extends SceneTree

## The screensaver waits half a minute of flight, and PHOTO is a real command.

var _failed := 0


func _init() -> void:
	_failed = _run()
	if _failed > 0:
		push_error("Idle drift tests failed (%d)." % _failed)
		quit(1)


func _process(_delta: float) -> bool:
	_failed += _held_controls(load("res://scripts/flight/idle_drift.gd"))
	_failed += _drift_keeps_fov(load("res://scripts/flight/thrust_kick.gd"))
	if _failed > 0:
		push_error("Idle drift tests failed (%d)." % _failed)
		quit(1)
	else:
		print("Idle drift tests passed.")
		quit(0)
	return true


func _run() -> int:
	var drift: Script = load("res://scripts/flight/idle_drift.gd")
	var term: Script = load("res://scripts/flight/cabin_terminal.gd")
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	if drift == null or term == null or lamps_script == null:
		push_error("drift scripts missing")
		return 1
	var failed := 0
	if drift.should_start(29.9, true):
		push_error("29.9s of quiet flight should keep the chase camera")
		failed += 1
	if not drift.should_start(30.0, true):
		push_error("30s of quiet flight should start the orbit")
		failed += 1
	if drift.should_start(40.0, false):
		push_error("the orbit stays off while walking or docked")
		failed += 1
	if drift.should_start(40.0, true, true):
		push_error("held flight controls should keep the chase camera")
		failed += 1
	if drift.advance_idle(29.0, 1.0, true) != 0.0:
		push_error("held controls should clear the idle timer")
		failed += 1
	if absf(drift.advance_idle(10.0, 0.5, false) - 10.5) > 0.001:
		push_error("quiet flight should accumulate idle time")
		failed += 1
	if not drift.piloting(true, false, false, false, false):
		push_error("throttle should count as flying the ship")
		failed += 1
	if not drift.piloting(false, true, false, false, false):
		push_error("a held turn should count as flying the ship")
		failed += 1
	if not drift.piloting(false, false, true, false, false):
		push_error("lift or drop should count as flying the ship")
		failed += 1
	if not drift.piloting(false, false, false, true, false):
		push_error("boost should count as flying the ship")
		failed += 1
	if not drift.piloting(false, false, false, false, true):
		push_error("a scripted burn should count as flying the ship")
		failed += 1
	if drift.piloting(false, false, false, false, false):
		push_error("quiet hands should let the screensaver arm")
		failed += 1
	var kick: Script = load("res://scripts/flight/thrust_kick.gd")
	if kick == null:
		push_error("thrust kick script missing")
		return failed + 1
	if not kick.skips_chase(false, true):
		push_error("the thrust kick should leave the drift camera alone")
		failed += 1
	if not kick.skips_chase(true, false):
		push_error("the thrust kick should leave a held title camera alone")
		failed += 1
	if kick.skips_chase(false, false):
		push_error("the chase camera should take the thrust kick while flying")
		failed += 1
	if absf(drift.blend(0.0)) > 0.001 or absf(drift.blend(1.0) - 1.0) > 0.001:
		push_error("the dolly ease should sit on 0 and 1")
		failed += 1
	if absf(drift.blend(0.5) - 0.5) > 0.001:
		push_error("the dolly ease should pass through the middle")
		failed += 1
	var lamps = lamps_script.new()
	var help: String = term.submit("HELP", lamps)
	if not help.contains("PHOTO"):
		push_error("HELP should list PHOTO, got %s" % help)
		failed += 1
	if term.submit("PHOTO", lamps) != "PHOTO":
		push_error("PHOTO should reply PHOTO")
		failed += 1
	if term.submit("SCAN", lamps) != "?":
		push_error("unknown commands stay unknown")
		failed += 1
	return failed


func _held_controls(drift: Script) -> int:
	var ship := _Hull.new()
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/flight/chase_camera.gd"))
	root.add_child(ship)
	ship.add_child(cam)
	var node = drift.new()
	ship.add_child(node)
	node.setup(ship, cam)
	var failed := 0
	Input.action_press("throttle_forward")
	_step(node, 40.0)
	if bool(cam.get("drift_hold")):
		push_error("holding throttle for 40s should keep the chase camera")
		failed += 1
	Input.action_release("throttle_forward")
	ship.script_throttle = 1.0
	_step(node, 40.0)
	if bool(cam.get("drift_hold")):
		push_error("a scripted burn should keep the chase camera")
		failed += 1
	ship.script_throttle = -1.0
	_step(node, 31.0)
	if not bool(cam.get("drift_hold")):
		push_error("quiet flight should start the orbit")
		failed += 1
	ship.free()
	return failed


func _drift_keeps_fov(kick: Script) -> int:
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/flight/chase_camera.gd"))
	root.add_child(cam)
	cam.fov = 34.0
	cam.set("drift_hold", true)
	cam.current = true
	var node = kick.new()
	node._chase = cam
	node._feel.advance(1.0, 2.0)
	node._apply_view()
	var failed := 0
	if absf(cam.fov - 34.0) > 0.01:
		push_error("drift should keep its fov, got %s" % cam.fov)
		failed += 1
	cam.set("drift_hold", false)
	cam.fov = FlightProfile.FOV
	node._apply_view()
	if cam.fov <= FlightProfile.FOV + 1.0:
		push_error("the kick should widen fov once the shot gives the camera back, got %s" % cam.fov)
		failed += 1
	cam.free()
	node.free()
	return failed


func _step(node: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		node._process(FlightProfile.DT_CAP)
		left -= FlightProfile.DT_CAP


class _Hull:
	extends Node3D
	var active := true
	var walking := false
	var hud_alpha := 1.0
	var planet_position := Vector3.ZERO
	var script_throttle := -1.0
	var script_yaw := 0.0
	var demo_fly := false
