extends SceneTree

## Orbit pilot holds altitude and lets go when the pilot takes the stick.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Orbit pilot tests failed (%d)." % failed)
		quit(1)
	else:
		print("Orbit pilot tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var script: Script = load("res://scripts/flight/orbit_pilot.gd")
	if script == null:
		push_error("orbit pilot script missing")
		return 1
	failed += _holds_altitude(script)
	failed += _no_snap(script)
	failed += _cancel(script)
	return failed


func _holds_altitude(script: Script) -> int:
	var pilot = script.new()
	var radius := 24.0
	var pos := Vector3(0.0, 8.0, radius * 2.6)
	var vel := Vector3(-3.0, 0.4, 1.0)
	pilot.engage(pos, vel, Vector3.ZERO, radius)
	var dt := 0.05
	for i in 480:
		if not pilot.active:
			push_error("orbit dropped out on its own")
			return 1
		var desired: Vector3 = pilot.step(pos, dt)
		vel = vel.lerp(desired, 1.0 - exp(-1.15 * dt))
		pos += vel * dt
		if i > 200:
			var gap := absf(pos.length() - pilot.target_radius)
			if gap > pilot.target_radius * 0.12:
				push_error("left the orbit altitude by %s" % gap)
				return 1
	var radial := absf(vel.dot(pos.normalized()))
	if radial > 1.6:
		push_error("orbit is still climbing or falling, radial speed %s" % radial)
		return 1
	return 0


func _no_snap(script: Script) -> int:
	var pilot = script.new()
	var radius := 24.0
	var pos := Vector3(0.0, 0.0, radius * 8.0)
	var vel := Vector3(1.0, 0.0, 0.0)
	pilot.engage(pos, vel, Vector3.ZERO, radius)
	var desired: Vector3 = pilot.step(pos, 0.05)
	var eased := vel.lerp(desired, 1.0 - exp(-1.15 * 0.05))
	if eased.length() > vel.length() + 6.0:
		push_error("engaging orbit snapped the velocity to %s" % eased.length())
		return 1
	return 0


func _cancel(script: Script) -> int:
	var pilot = script.new()
	pilot.engage(Vector3(0, 0, 40), Vector3(1, 0, 0), Vector3.ZERO, 20.0)
	if pilot.cancel_if(true, false, false, false, true):
		push_error("walking the cabin should not cancel orbit")
		return 1
	if not pilot.active:
		push_error("orbit died while walking")
		return 1
	if not pilot.cancel_if(true, false, false, false, false):
		push_error("manual thrust should cancel orbit")
		return 1
	if pilot.active:
		push_error("orbit stayed active after manual input")
		return 1
	pilot.engage(Vector3(0, 0, 40), Vector3(1, 0, 0), Vector3.ZERO, 20.0)
	if not pilot.cancel_if(false, false, false, true, true):
		push_error("STOP should cancel even from the cabin")
		return 1
	return 0
