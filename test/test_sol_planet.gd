extends SceneTree

## Headless check: Sol's generated worlds match the web build's universe.js output.

const _EXPECTED := "res://test/sol_web_expected.json"


func _init() -> void:
	var failures := _run()
	if failures > 0:
		push_error("Sol planet seed test failed (%d checks)." % failures)
		quit(1)
	else:
		print("Sol planet seed tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var ticks := int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
	var engine := str(ProjectSettings.get_setting("physics/3d/physics_engine"))
	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	var mobile := str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"))
	if ticks != 120:
		push_error("physics ticks %d" % ticks)
		failed += 1
	if engine != "Jolt Physics":
		push_error("physics engine %s" % engine)
		failed += 1
	if renderer != "forward_plus":
		push_error("renderer %s" % renderer)
		failed += 1
	if mobile != "mobile":
		push_error("mobile renderer %s" % mobile)
		failed += 1

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_EXPECTED))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("expected JSON missing")
		return failed + 1
	var expected: Dictionary = parsed

	if Universe.hash_string("sol") != int(expected.hash_sol):
		push_error("hash sol %d != %s" % [Universe.hash_string("sol"), expected.hash_sol])
		failed += 1

	var chart := Universe.generate_system(Galaxy.system_by_id("sol"))
	var planets: Array = chart.planets
	var expected_planets: Array = expected.planets
	if planets.size() != expected_planets.size():
		push_error("planet count %d != %d" % [planets.size(), expected_planets.size()])
		return failed + 1

	for i in planets.size():
		failed += _planet(planets[i], expected_planets[i])

	failed += _moons(planets)

	var ship := Ships.get_ship("starter")
	var speeds := FlightProfile.for_speed_stat(float(ship.stats.speed))
	var want: Dictionary = expected.starter
	failed += _near(speeds.cruise, float(want.cruise), 1e-6, "cruise")
	failed += _near(speeds.boost, float(want.boost), 1e-6, "boost")
	failed += _near(speeds.pulse, float(want.pulse), 1e-6, "pulse")

	if chart.sky.top != expected.sky.top or chart.sky.star != expected.sky.star:
		push_error("Sol sky colors diverged")
		failed += 1
	var spawn: Vector3 = chart.spawn
	if spawn != Vector3(expected.spawn[0], expected.spawn[1], expected.spawn[2]):
		push_error("spawn diverged")
		failed += 1
	return failed


func _planet(got: Dictionary, want: Dictionary) -> int:
	var failed := 0
	var label: String = str(want.id)
	if got.id != want.id or got.name != want.name or got.biome != want.biome:
		push_error("%s identity %s %s %s" % [label, got.id, got.name, got.biome])
		failed += 1
	if got.biomeLabel != want.biomeLabel:
		push_error("%s biome label" % label)
		failed += 1
	failed += _near(float(got.relief), float(want.relief), 1e-9, label + " relief")
	failed += _near(float(got.radius), float(want.radius), 1e-5, label + " radius")
	failed += _near(float(got.seed), float(want.seed), 1e-9, label + " seed")
	failed += _vec(got.position, want.position, 1e-4, label + " position")
	failed += _vec(got.ringTilt, want.ringTilt, 1e-5, label + " ringTilt")
	if bool(got.rings) != bool(want.rings):
		push_error("%s rings" % label)
		failed += 1
	if got.atmosphere != want.atmosphere or got.ring != want.ring or got.moon != want.moon:
		push_error("%s colors atmosphere/ring/moon" % label)
		failed += 1
	var colors: Array = got.colors
	var want_colors: Array = want.colors
	if colors != want_colors:
		push_error("%s palette %s != %s" % [label, colors, want_colors])
		failed += 1
	if got.resources != want.resources:
		push_error("%s resources" % label)
		failed += 1
	return failed


## Moons are derived data (not part of the web parity set): every world has its
## primary moon, ringed worlds (Mina in Sol) add a shepherd clear of the rings.
func _moons(planets: Array) -> int:
	var failed := 0
	for planet in planets:
		var moons: Array = planet.get("moons", [])
		var want := 2 if bool(planet.rings) else 1
		if moons.size() != want:
			push_error("%s moon count %d != %d" % [planet.name, moons.size(), want])
			failed += 1
			continue
		if moons[0].kind != "primary" or moons[0].color != planet.moon:
			push_error("%s primary moon" % planet.name)
			failed += 1
		if want == 2:
			var shepherd: Dictionary = moons[1]
			if float(shepherd.orbit) <= 2.22 + 0.5 or float(shepherd.radius) >= float(moons[0].radius):
				push_error("%s shepherd orbit/size" % planet.name)
				failed += 1
	if (planets[0].moons as Array).size() != 2:
		push_error("Mina should have two moons")
		failed += 1
	return failed


func _vec(got: Vector3, want: Array, eps: float, label: String) -> int:
	var failed := 0
	failed += _near(got.x, float(want[0]), eps, label + ".x")
	failed += _near(got.y, float(want[1]), eps, label + ".y")
	failed += _near(got.z, float(want[2]), eps, label + ".z")
	return failed


func _near(got: float, want: float, eps: float, label: String) -> int:
	if absf(got - want) > eps:
		push_error("%s: %s != %s" % [label, got, want])
		return 1
	return 0
