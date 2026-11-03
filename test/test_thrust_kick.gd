extends SceneTree

## Thrust kick: FOV eases slowly, sway builds, and intensity 0 is still.


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
	failed += _ease_is_slow(feel_script)
	failed += _sway_builds(feel_script)
	failed += _push_is_soft(feel_script)
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


func _ease_is_slow(feel_script: Script) -> int:
	var rising = feel_script.new()
	_hold(rising, 1.0, 0.15)
	if rising.fov_extra > FlightProfile.KICK_FOV * 0.12:
		push_error("fov should not snap open, got %s" % rising.fov_extra)
		return 1
	_hold(rising, 1.0, 0.6)
	var mid: float = rising.fov_extra / FlightProfile.KICK_FOV
	if mid < 0.35 or mid > 0.7:
		push_error("fov should be mid-ramp around 0.75s, got %s" % rising.fov_extra)
		return 1
	var falling = feel_script.new()
	_hold(falling, 1.0, 2.0)
	_hold(falling, 0.0, 0.2)
	if falling.fov_extra < FlightProfile.KICK_FOV * 0.8:
		push_error("fov should ease out slowly, got %s" % falling.fov_extra)
		return 1
	_hold(falling, 0.0, 1.6)
	if falling.fov_extra > 0.35:
		push_error("fov should be home after the release, got %s" % falling.fov_extra)
		return 1
	return 0


func _sway_builds(feel_script: Script) -> int:
	var feel = feel_script.new()
	_hold(feel, 1.0, 0.1)
	var early: float = feel.shake_amp
	_hold(feel, 1.0, 1.4)
	if early >= feel.shake_amp:
		push_error("sway should build, early %s settled %s" % [early, feel.shake_amp])
		return 1
	if feel.shake_amp < 0.004:
		push_error("settled thrust should keep a sway, got %s" % feel.shake_amp)
		return 1
	var before: Vector3 = feel.shake_offset(1.0)
	feel.advance(1.0, 0.05)
	var after: Vector3 = feel.shake_offset(1.0)
	if absf(before.x - after.x) > 0.004:
		push_error("sway should stay low frequency")
		return 1
	var left = feel_script.new()
	var right = feel_script.new()
	_hold(left, 0.4, 0.8)
	_hold(right, 0.4, 0.8)
	if absf(left.shake_offset(1.0).y - right.shake_offset(1.0).y) > 0.00001:
		push_error("sway is not deterministic")
		return 1
	return 0


func _push_is_soft(feel_script: Script) -> int:
	var feel = feel_script.new()
	_hold(feel, 1.0, 0.04)
	var tap: float = feel.push
	_hold(feel, 1.0, 0.32)
	if feel.push < 0.2 or tap >= feel.push:
		push_error("boost push should ease in, tap %s then %s" % [tap, feel.push])
		return 1
	_hold(feel, 1.0, 2.0)
	if feel.push > 0.12:
		push_error("boost push should settle, got %s" % feel.push)
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
