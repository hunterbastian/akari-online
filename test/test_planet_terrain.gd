extends SceneTree

## Baked relief is deterministic, the crater has a rim, and the phone ranges sit closer.


func _init() -> void:
	var failures := _run()
	if failures > 0:
		push_error("Planet terrain test failed (%d checks)." % failures)
		quit(1)
	else:
		print("Planet terrain tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var seed := 0.4948453608247423
	var radius := 24.533373176585883
	var sun := FlightProfile.SUN_OFFSET.normalized()
	var city := (sun * 0.82 + Vector3(0.28, 0.08, -0.22)).normalized()
	var dir := Vector3(0.2, 0.9, 0.15).normalized()
	var first := PlanetTerrain.height_of(dir, seed, radius)
	var second := PlanetTerrain.height_of(dir, seed, radius)
	if absf(first - second) > 0.0001:
		push_error("height drifted")
		failed += 1

	var info := PlanetTerrain.survey(seed, radius, city, sun)
	if float(info.ridge_h) <= float(info.canyon_h):
		push_error("ridge should stand above the canyon")
		failed += 1
	var crater_dir: Vector3 = info.crater
	var center_h := PlanetTerrain.height_of(crater_dir, seed, radius)
	var axis := crater_dir.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var rim_h := PlanetTerrain.height_of(crater_dir.rotated(axis, float(info.crater_rad)), seed, radius)
	if rim_h <= center_h + 0.15:
		push_error("crater rim %.2f should stand above the bowl %.2f" % [rim_h, center_h])
		failed += 1
	if PlanetTerrain.near_end(true) >= PlanetTerrain.near_end(false):
		push_error("phone near range should be stricter")
		failed += 1
	if PlanetTerrain.detail_far(true) >= PlanetTerrain.detail_far(false):
		push_error("phone detail should fade sooner")
		failed += 1
	if PlanetTerrain.PHONE_ROCK_END >= PlanetTerrain.ROCK_END:
		push_error("phone rocks should fade sooner")
		failed += 1

	var colors: Array = [Color.html("#7ecfe2"), Color.html("#c5eef4"), Color.html("#f2fafa"), Color.html("#f6e0d4")]
	var mesh := PlanetTerrain.build_mesh(radius, seed, 24, 16, colors, city, true)
	if mesh.get_surface_count() != 1:
		push_error("mesh missing")
		failed += 1
	else:
		var arrays: Array = mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var best := 0.0
		var best_len := 0.0
		for i in verts.size():
			var vert := verts[i]
			var align := vert.normalized().dot(city)
			if align > best:
				best = align
				best_len = vert.length()
		if absf(best_len - radius) > 0.2:
			push_error("city pad height %.2f should sit on the radius" % best_len)
			failed += 1
		var peak := 0.0
		for i in verts.size():
			peak = maxf(peak, verts[i].length() - radius)
		if peak > FlightProfile.PLANET_CLEARANCE - 0.5:
			push_error("peak %.2f exceeds clearance" % peak)
			failed += 1
	return failed
