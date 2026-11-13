extends SceneTree

## The sun stays low and warm, and the cabin shaft only lights when light enters the nose.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Golden hour tests failed (%d)." % failed)
		quit(1)
	else:
		print("Golden hour tests passed.")
		quit(0)


func _run() -> int:
	var profile: Script = load("res://scripts/data/flight_profile.gd")
	if profile == null:
		push_error("flight profile missing")
		return 1
	var failed := 0
	var elev: float = profile.sun_elevation()
	if elev < deg_to_rad(6.0) or elev > deg_to_rad(16.0):
		push_error("sun should sit low, elevation rad %s" % elev)
		failed += 1
	var sun: Color = profile.SUN_COLOR
	if sun.r < 0.9 or sun.r <= sun.g or sun.g <= sun.b:
		push_error("key should be warm amber, got %s" % sun)
		failed += 1
	var fill: Color = profile.FILL_COLOR
	if fill.b <= fill.r or fill.g <= fill.r:
		push_error("fill should be cool teal, got %s" % fill)
		failed += 1
	if profile.SUN_ENERGY_LOW >= profile.SUN_ENERGY:
		push_error("phones should use a cheaper sun")
		failed += 1
	if profile.FILL_ENERGY_LOW >= profile.FILL_ENERGY:
		push_error("phones should use a cheaper fill")
		failed += 1
	if profile.shaft_gain(-0.4) > 0.02:
		push_error("a sun behind the cabin should not cast a shaft")
		failed += 1
	if profile.shaft_gain(1.0) < 0.95:
		push_error("light through the nose glass should open the shaft")
		failed += 1
	var mid: float = profile.shaft_gain(0.3)
	if mid < 0.2 or mid > 0.85:
		push_error("the shaft should ease in, got %s" % mid)
		failed += 1
	return failed
