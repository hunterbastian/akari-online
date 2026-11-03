extends SceneTree

## Cockpit CRT text, and the 10 Hz gate that keeps it off the hot path.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Flight readout tests failed (%d)." % failed)
		quit(1)
	else:
		print("Flight readout tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var script: Script = load("res://scripts/flight/flight_readout.gd")
	if script == null:
		push_error("flight readout script missing")
		return 1
	failed += _formats(script)
	failed += _gate(script)
	return failed


func _formats(script: Script) -> int:
	var text: String = script.block(42, 1240, 87, 0.65)
	if text != "SPD 042\nALT 01240\nHDG 087\nTHR 0.65":
		push_error("readout text diverged: %s" % text)
		return 1
	var wrapped: String = script.block(3, -4, -20, 1.2)
	if not wrapped.begins_with("SPD 003\nALT 00000\nHDG 340\nTHR 1.00"):
		push_error("readout should wrap heading and clamp, got %s" % wrapped)
		return 1
	return 0


func _gate(script: Script) -> int:
	var gate = script.new()
	if not gate.tick(0.0):
		push_error("the first tick should publish")
		return 1
	if gate.tick(0.04):
		push_error("readouts should not publish every frame")
		return 1
	if not gate.tick(0.07):
		push_error("readouts should publish again after a tenth of a second")
		return 1
	return 0
