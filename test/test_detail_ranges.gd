extends SceneTree

## Detail levels move with distance, and a level does not flip on the line.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Detail range tests failed (%d)." % failed)
		quit(1)
	else:
		print("Detail range tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var script: Script = load("res://scripts/data/detail_ranges.gd")
	if script == null:
		push_error("detail ranges missing")
		return 1
	failed += _levels(script)
	failed += _hysteresis(script)
	failed += _mobile_tighter(script)
	failed += _fade(script)
	return failed


func _levels(script: Script) -> int:
	if script.level_for(10.0, false, -1) != 0:
		push_error("close to a body should be the full mesh")
		return 1
	if script.level_for(script.NEAR_END + 30.0, false, -1) != 1:
		push_error("past the near band should be the middle mesh")
		return 1
	if script.level_for(script.MID_END + 40.0, false, -1) != 2:
		push_error("far from a body should be the low mesh")
		return 1
	return 0


func _hysteresis(script: Script) -> int:
	var edge: float = script.NEAR_END
	if script.level_for(edge + 4.0, false, 0) != 0:
		push_error("the full mesh should hold a little past its edge")
		return 1
	if script.level_for(edge + script.HYSTERESIS + 6.0, false, 0) != 1:
		push_error("the full mesh should let go after the hysteresis band")
		return 1
	var far_edge: float = script.MID_END
	if script.level_for(far_edge - 4.0, false, 2) != 2:
		push_error("the far mesh should hold until the camera is clearly closer")
		return 1
	return 0


func _mobile_tighter(script: Script) -> int:
	var sample: float = script.MOBILE_NEAR_END + 10.0
	var phone: int = script.level_for(sample, true, -1)
	var desk: int = script.level_for(sample, false, -1)
	if phone <= desk:
		push_error("the phone preset should drop detail sooner, phone %d desk %d" % [phone, desk])
		return 1
	if script.MOBILE_SHIP_DETAIL >= script.SHIP_DETAIL:
		push_error("the phone hull range should be shorter")
		return 1
	return 0


func _fade(script: Script) -> int:
	var mesh := MeshInstance3D.new()
	script.show_near(mesh, 140.0, 48.0)
	if mesh.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
		push_error("detail swaps should dither-fade, not pop")
		return 1
	if mesh.visibility_range_end_margin < 8.0:
		push_error("the fade band should be wide enough to hide a pop")
		return 1
	if mesh.extra_cull_margin > 0.01:
		push_error("frustum culling should use the real bounds")
		return 1
	script.show_far(mesh, 520.0, 48.0)
	if mesh.visibility_range_begin_margin < 8.0:
		push_error("the far mesh should fade in")
		return 1
	mesh.free()
	return 0
