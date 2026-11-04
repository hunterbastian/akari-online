extends SceneTree

## Hull bank follows yaw rate in rad/s, so a full key turn leans the same
## amount at 12 fps and at 60 fps.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Bank tests failed (%d)." % failed)
		quit(1)
	else:
		print("Bank tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var profile: Script = load("res://scripts/data/flight_profile.gd")
	if profile == null or not profile.has_method("bank_for_rate"):
		push_error("bank_for_rate missing")
		return 1
	failed += _full_turn(profile)
	failed += _signs(profile)
	failed += _clamp(profile)
	failed += _frame_rate(profile)
	return failed


func _full_turn(profile: Script) -> int:
	var lean := absf(profile.bank_for_rate(profile.KEY_YAW_RATE))
	var degrees := rad_to_deg(lean)
	if degrees < 20.0 or degrees > 30.0:
		push_error("full key yaw should bank 20-30 degrees, got %s" % degrees)
		return 1
	return 0


func _signs(profile: Script) -> int:
	if absf(profile.bank_for_rate(0.0)) > 0.00001:
		push_error("zero yaw rate should level the hull")
		return 1
	var left: float = profile.bank_for_rate(profile.KEY_YAW_RATE)
	var right: float = profile.bank_for_rate(-profile.KEY_YAW_RATE)
	if left >= 0.0 or absf(left + right) > 0.00001:
		push_error("left and right turns should bank opposite ways")
		return 1
	return 0


func _clamp(profile: Script) -> int:
	var hard := absf(profile.bank_for_rate(40.0))
	if absf(hard - profile.BANK_LIMIT) > 0.00001:
		push_error("a huge yaw rate should clamp at BANK_LIMIT, got %s" % hard)
		return 1
	return 0


func _frame_rate(profile: Script) -> int:
	var target: float = profile.bank_for_rate(profile.KEY_YAW_RATE)
	var slow := _settle(profile, target, 1.0 / 12.0)
	var fast := _settle(profile, target, 1.0 / 60.0)
	if absf(slow - fast) > 0.02:
		push_error("bank settle depends on frame rate, 12fps %s 60fps %s" % [slow, fast])
		return 1
	if absf(fast - target) > 0.03:
		push_error("bank should arrive near the rate target, got %s want %s" % [fast, target])
		return 1
	return 0


func _settle(profile: Script, target: float, dt: float) -> float:
	var bank := 0.0
	var t := 0.0
	while t < 2.5:
		bank = profile.damp(bank, target, profile.BANK_DAMP, dt)
		t += dt
	return bank
