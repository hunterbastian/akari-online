extends SceneTree

## Head bob scales with FlightProfile.BOB, steps on a stride, and can be turned off.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Cabin bob tests failed (%d)." % failed)
		quit(1)
	else:
		print("Cabin bob tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var script: Script = load("res://scripts/flight/cabin_bob.gd")
	if script == null:
		push_error("cabin bob script missing")
		return 1
	failed += _off_is_still(script)
	failed += _stride_steps(script)
	failed += _clank_is_rare(script)
	failed += _smooth(script)
	return failed


func _off_is_still(script: Script) -> int:
	var bob = script.new()
	var off: Vector3 = bob.advance(1.2, 0.1, 0.0)
	if off.length() > 0.00001 or bob.foot or bob.clank:
		push_error("bob scale 0 should hold the head still")
		return 1
	return 0


func _stride_steps(script: Script) -> int:
	var bob = script.new()
	var stepped := false
	var walked := 0.0
	while walked < 0.7:
		bob.advance(0.05, 0.05, 1.0)
		walked += 0.05
		if bob.foot:
			stepped = true
	if not stepped:
		push_error("a stride should plant a foot")
		return 1
	var dip: Vector3 = bob.advance(0.05, 0.05, 1.0)
	if dip.length() < 0.002:
		push_error("walking should bob the head, got %s" % dip)
		return 1
	return 0


func _clank_is_rare(script: Script) -> int:
	var bob = script.new()
	var clanks := 0
	var feet := 0
	for _i in 80:
		bob.advance(0.1, 0.05, 1.0)
		if bob.foot:
			feet += 1
		if bob.clank:
			clanks += 1
	if feet < 8:
		push_error("expected several steps, got %d" % feet)
		return 1
	if clanks < 1 or clanks >= feet:
		push_error("clanks should be occasional, %d of %d steps" % [clanks, feet])
		return 1
	return 0


func _smooth(script: Script) -> int:
	var bob = script.new()
	var prev := 0.0
	for _i in 12:
		var off: Vector3 = bob.advance(0.02, 0.016, 1.0)
		if absf(off.y - prev) > 0.01:
			push_error("bob should move smoothly, jump %s" % absf(off.y - prev))
			return 1
		prev = off.y
	var left = script.new()
	var right = script.new()
	left.advance(0.4, 0.2, 1.0)
	right.advance(0.4, 0.2, 1.0)
	if absf(left.advance(0.1, 0.05, 1.0).y - right.advance(0.1, 0.05, 1.0).y) > 0.00001:
		push_error("bob is not deterministic")
		return 1
	return 0
