extends SceneTree

## Spacewalk tether, visor ease, rear-door passage, and the two log lines.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("EVA tests failed (%d)." % failed)
		quit(1)
	else:
		print("EVA tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var motion: Script = load("res://scripts/flight/eva_motion.gd")
	if motion == null:
		push_error("eva motion missing")
		return 1
	failed += _tether(motion)
	failed += _drift(motion)
	failed += _thrust(motion)
	failed += _visor(motion)
	failed += _phone(motion)
	failed += _log()
	failed += _rear_wall()
	return failed


func _tether(motion: Script) -> int:
	var body = motion.new()
	body.pos = Vector3(0.0, 0.0, 48.0)
	body.vel = Vector3(0.0, 0.0, 2.0)
	for _i in 240:
		body.step(Vector3.ZERO, 1.0 / 60.0)
	if body.pos.length() > 40.05:
		push_error("tether should hold the pilot within 40 m, got %s" % body.pos.length())
		return 1
	var soft = motion.new()
	soft.pos = Vector3(36.0, 0.0, 0.0)
	soft.vel = Vector3(1.4, 0.0, 0.0)
	for _j in 180:
		soft.step(Vector3.ZERO, 1.0 / 60.0)
	if soft.pos.length() > 40.05:
		push_error("a push near the tether should not break 40 m")
		return 1
	if soft.vel.x > 0.2:
		push_error("the tether spring should kill outward speed, got %s" % soft.vel.x)
		return 1
	return 0


func _drift(motion: Script) -> int:
	var body = motion.new()
	body.pos = Vector3(0.0, 0.0, 2.0)
	body.vel = Vector3(0.0, 0.0, 1.2)
	body.step(Vector3.ZERO, 0.5)
	var speed: float = body.vel.length()
	if speed > 1.15 or speed < 0.4:
		push_error("coast should damp gently, got %s" % speed)
		return 1
	return 0


func _thrust(motion: Script) -> int:
	var body = motion.new()
	for _i in 60:
		body.step(Vector3(0.0, 0.0, -1.0), 1.0 / 60.0)
	if body.vel.z > -0.4 or body.pos.z >= 0.0:
		push_error("thrust should start a float, vel %s pos %s" % [body.vel.z, body.pos.z])
		return 1
	return 0


func _visor(motion: Script) -> int:
	if absf(motion.drop_amount(0.0)) > 0.0001 or absf(motion.drop_amount(1.0) - 1.0) > 0.0001:
		push_error("visor should ease from 0 to 1 across one second")
		return 1
	if motion.drop_amount(0.2) > 0.16:
		push_error("visor ease should start slowly")
		return 1
	return 0


func _phone(motion: Script) -> int:
	if motion.mote_count(true) > 4 or motion.mote_count(false) <= motion.mote_count(true):
		push_error("phones should get fewer ice motes")
		return 1
	return 0


func _log() -> int:
	var log = load("res://scripts/flight/ship_log.gd").new()
	log.mark_eva_out()
	log.mark_eva_out()
	if log.entries.size() != 1 or str(log.entries[0].get("text", "")) != "Pilot stepped out":
		push_error("stepping out should log once")
		return 1
	log.mark_eva_in()
	log.mark_eva_in()
	if log.entries.size() != 2 or str(log.entries[1].get("text", "")) != "Pilot returned to the ship":
		push_error("returning should log once")
		return 1
	return 0


func _rear_wall() -> int:
	var motion: Script = load("res://scripts/flight/eva_motion.gd")
	if not motion.wall_blocks(false, true, 0.0, 0.4, -1.0, 1.0, 0.3, 0.5, 0.05):
		push_error("a closed bay should block the rear wall")
		return 1
	if motion.wall_blocks(true, true, 0.0, 0.4, -1.0, 1.0, 0.3, 0.5, 0.05):
		push_error("an open bay should let the pilot through the rear wall")
		return 1
	if not motion.wall_blocks(true, false, 0.0, 0.4, -1.0, 1.0, 0.3, 0.5, 0.05):
		push_error("an open bay should still block the other walls")
		return 1
	return 0
