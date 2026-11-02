extends RefCounted

## Regression checks for the cabin and dev-console state bugs.
## Run with: godot --headless --path . -- --state-test


static func run() -> int:
	var failed := 0
	failed += _touch_blocked()
	failed += _reload_drops_noclip()
	failed += _freecam_hold()
	failed += _locker_closes()
	failed += _stand_clears_thrust()
	failed += _seat_before_pickup()
	failed += _terminal_keeps_e()
	failed += _view_unlocks()
	failed += _title_abort()
	if failed > 0:
		push_error("Statechart tests failed (%d)." % failed)
	else:
		print("Statechart tests passed.")
	return failed


static func _touch_blocked() -> int:
	var controls = load("res://scripts/ui/cabin_controls.gd").new()
	var ship = load("res://scripts/flight/ship_controller.gd").new()
	DevConsole.open = true
	if not DevConsole.blocks_gameplay():
		push_error("open console should block gameplay")
		DevConsole.open = false
		return 1
	controls._ship = ship
	controls._on_seat()
	controls._on_use()
	if ship.walking:
		push_error("SIT worked while the console was open")
		DevConsole.open = false
		return 1
	DevConsole.open = false
	return 0


static func _reload_drops_noclip() -> int:
	DevConsole._freecam_on = true
	DevConsole.release_transient()
	if DevConsole.freecam_active() or DevConsole.blocks_gameplay():
		push_error("reload left noclip blocking input")
		DevConsole._freecam_on = false
		return 1
	return 0


static func _freecam_hold() -> int:
	var cam := Camera3D.new()
	Engine.get_main_loop().root.add_child(cam)
	DevConsole._freecam = cam
	DevConsole._freecam_on = true
	cam.current = false
	DevConsole.hold_freecam()
	var ok: bool = cam.current
	DevConsole.release_transient()
	if is_instance_valid(cam):
		cam.queue_free()
	if not ok:
		push_error("tp did not give the freecam back")
		return 1
	return 0


static func _locker_closes() -> int:
	var inv = load("res://scripts/flight/cabin_inventory.gd").new()
	inv._scale = 1.0
	inv._locker_pos["LockerL"] = Vector3(0, 0, 0)
	inv.open_bank = "LockerL"
	inv.close_if_far(Vector3(0, 0, 3))
	if inv.open_bank != "":
		push_error("locker stayed open after walking away")
		return 1
	inv.open_bank = "LockerL"
	inv.close_if_far(Vector3(0, 0, 0.2))
	if inv.open_bank != "LockerL":
		push_error("locker closed while still in reach")
		return 1
	return 0


static func _stand_clears_thrust() -> int:
	var ship = load("res://scripts/flight/ship_controller.gd").new()
	ship.thrust = 0.8
	ship.boosting = true
	ship._enter_cabin()
	if ship.thrust != 0.0 or ship.boosting:
		push_error("standing left the engines thrusting")
		return 1
	if ship._pickup_until <= Time.get_ticks_msec():
		push_error("standing did not block the immediate pickup")
		return 1
	return 0


static func _seat_before_pickup() -> int:
	var source := FileAccess.get_file_as_string("res://scripts/flight/ship_controller.gd")
	var interact := source.find("is_action_pressed(\"interact\")")
	var seat := source.find("near_seat()", interact)
	var pickup := source.find("try_interact()", interact)
	if interact < 0 or seat < 0 or pickup < 0 or seat > pickup:
		push_error("E checks pickup before the seat")
		return 1
	return 0


static func _terminal_keeps_e() -> int:
	var cabin = load("res://scripts/flight/cabin_interior.gd").new()
	var walker = load("res://scripts/flight/cabin_walker.gd").new()
	cabin.walker = walker
	walker.locked = true
	walker.eye = Camera3D.new()
	walker.eye.current = true
	if not cabin.terminal_wants_keys():
		push_error("seat terminal did not claim the keyboard")
		return 1
	walker.locked = false
	if cabin.terminal_wants_keys():
		push_error("walking still claims the terminal")
		return 1
	return 0


static func _view_unlocks() -> int:
	var cabin = load("res://scripts/flight/cabin_interior.gd").new()
	var walker = load("res://scripts/flight/cabin_walker.gd").new()
	cabin.walker = walker
	walker.locked = true
	cabin.release_fixed_view()
	if walker.locked:
		push_error("dev view stayed locked")
		return 1
	return 0


static func _title_abort() -> int:
	var director = load("res://scripts/ui/title_director.gd").new()
	var cam := Camera3D.new()
	director._camera = cam
	director._finished = false
	cam.current = true
	Engine.get_main_loop().root.add_child(cam)
	director.abort_for_dev()
	var ok: bool = director._finished and not cam.current
	cam.queue_free()
	if not ok:
		push_error("title kept its camera after tp")
		return 1
	return 0
