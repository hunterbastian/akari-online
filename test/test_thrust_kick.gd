extends SceneTree

## Thrust kick: FOV eases with thrust, shake bursts then hums, and intensity 0 is still.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Thrust kick tests failed (%d)." % failed)
		quit(1)
	else:
		print("Thrust kick tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var feel_script: Script = load("res://scripts/flight/thrust_feel.gd")
	if feel_script == null:
		push_error("thrust feel script missing")
		return 1
	failed += _fov_settles(feel_script)
	failed += _ease_in_is_quicker(feel_script)
	failed += _shake_burst_then_hum(feel_script)
	failed += _shake_off(feel_script)
	failed += _rumble_loops()
	return failed


func _fov_settles(feel_script: Script) -> int:
	var idle = feel_script.new()
	_hold(idle, 0.0, 2.0)
	if idle.fov_extra > 0.05:
		push_error("idle fov kick should settle to 0, got %s" % idle.fov_extra)
		return 1
	var full = feel_script.new()
	_hold(full, 1.0, 2.0)
	if absf(full.fov_extra - FlightProfile.KICK_FOV) > 0.2:
		push_error("full thrust fov should reach KICK_FOV, got %s" % full.fov_extra)
		return 1
	var half = feel_script.new()
	_hold(half, 0.5, 2.0)
	if absf(half.fov_extra - FlightProfile.KICK_FOV * 0.5) > 0.2:
		push_error("fov kick should scale with thrust, got %s" % half.fov_extra)
		return 1
	return 0


func _ease_in_is_quicker(feel_script: Script) -> int:
	var rising = feel_script.new()
	_hold(rising, 1.0, 0.12)
	var rise: float = rising.fov_extra
	var falling = feel_script.new()
	_hold(falling, 1.0, 2.0)
	_hold(falling, 0.0, 0.12)
	var drop: float = FlightProfile.KICK_FOV - falling.fov_extra
	if rise <= drop * 1.35:
		push_error("fov should ease in faster than it eases out (rise %s, drop %s)" % [rise, drop])
		return 1
	return 0


func _shake_burst_then_hum(feel_script: Script) -> int:
	var feel = feel_script.new()
	_hold(feel, 0.0, 0.5)
	feel.advance(1.0, 1.0 / 60.0)
	var burst: float = feel.shake_amp
	_hold(feel, 1.0, 2.0)
	var hum: float = feel.shake_amp
	if burst <= hum * 1.6:
		push_error("boost start should shake harder than the settled hum (burst %s, hum %s)" % [burst, hum])
		return 1
	if hum < 0.004:
		push_error("settled thrust should keep a light hum, got %s" % hum)
		return 1
	var moving := false
	for _i in 20:
		feel.advance(1.0, 1.0 / 60.0)
		if feel.shake_offset(1.0).length() > 0.004:
			moving = true
	if not moving:
		push_error("shake wave should move the camera")
		return 1
	var left = feel_script.new()
	var right = feel_script.new()
	_hold(left, 0.35, 0.4)
	_hold(right, 0.35, 0.4)
	if absf(left.shake_offset(1.0).y - right.shake_offset(1.0).y) > 0.00001:
		push_error("shake is not deterministic")
		return 1
	return 0


func _shake_off(feel_script: Script) -> int:
	var feel = feel_script.new()
	feel.advance(1.0, 1.0 / 60.0)
	if feel.shake_offset(0.0).length() > 0.00001:
		push_error("shake intensity 0 should hold the camera still")
		return 1
	return 0


func _rumble_loops() -> int:
	var kick_script: Script = load("res://scripts/flight/thrust_kick.gd")
	if kick_script == null:
		push_error("thrust kick script missing")
		return 1
	var stream: AudioStreamWAV = kick_script.make_rumble()
	if stream == null or stream.data.is_empty():
		push_error("rumble should be a generated loop")
		return 1
	if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
		push_error("rumble should loop")
		return 1
	return 0


func _hold(feel, amount: float, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 1.0 / 60.0)
		feel.advance(amount, step)
		left -= step
