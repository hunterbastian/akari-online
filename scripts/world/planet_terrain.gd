class_name PlanetTerrain
extends RefCounted

## Baked Mina relief. Mountains, canyons, and craters are computed once at load
## and written into the mesh. Nothing here runs per frame.

const _Post := preload("res://scripts/data/post_profile.gd")

const NEAR_RADIAL := 56
const NEAR_RINGS := 36
const MID_RADIAL := 30
const MID_RINGS := 18
const FAR_RADIAL := 16
const FAR_RINGS := 10
const PHONE_NEAR_RADIAL := 32
const PHONE_NEAR_RINGS := 20
const PHONE_MID_RADIAL := 18
const PHONE_MID_RINGS := 12
const PHONE_FAR_RADIAL := 10
const PHONE_FAR_RINGS := 6

## Distance from the planet center. The surface sits near radius 25, so these
## cutovers are altitude above the center, not above the ground.
const NEAR_END := 100.0
const MID_END := 210.0
const PHONE_NEAR_END := 55.0
const PHONE_MID_END := 120.0
const FADE := 12.0
const PHONE_FADE := 6.0

## Camera distance at which the close-up grain and rocks appear.
const DETAIL_NEAR := 6.0
const DETAIL_FAR := 38.0
const PHONE_DETAIL_NEAR := 3.0
const PHONE_DETAIL_FAR := 16.0
const ROCK_END := 24.0
const PHONE_ROCK_END := 12.0
const ROCK_FADE := 8.0
const PHONE_ROCK_FADE := 4.0
const ROCK_CLUSTERS := 5
const PHONE_ROCK_CLUSTERS := 2
const ROCKS_EACH := 8
const PHONE_ROCKS_EACH := 4

const RELIEF := 0.2

static var _seed := -1.0
static var _base: FastNoiseLite
static var _ridge: FastNoiseLite
static var _cut: FastNoiseLite
static var _paint: FastNoiseLite
static var _craters: Array = []
static var _sun := Vector3.ZERO
static var _city := Vector3.ZERO
static var _bound := false


static func phone() -> bool:
	return _Post.quality() == "low"


static func near_end(is_phone: bool) -> float:
	return PHONE_NEAR_END if is_phone else NEAR_END


static func mid_end(is_phone: bool) -> float:
	return PHONE_MID_END if is_phone else MID_END


static func fade(is_phone: bool) -> float:
	return PHONE_FADE if is_phone else FADE


static func detail_far(is_phone: bool) -> float:
	return PHONE_DETAIL_FAR if is_phone else DETAIL_FAR


static func detail_near(is_phone: bool) -> float:
	return PHONE_DETAIL_NEAR if is_phone else DETAIL_NEAR


static func prepare(seed: float, sun: Vector3 = Vector3.ZERO, city: Vector3 = Vector3.ZERO) -> void:
	var seeded := _base != null and is_equal_approx(_seed, seed)
	var sun_changed := sun.length_squared() > 0.01 and (_sun.length_squared() < 0.01 or sun.normalized().dot(_sun) < 0.999)
	var city_changed := city.length_squared() > 0.01 and (_city.length_squared() < 0.01 or city.normalized().dot(_city) < 0.999)
	if seeded and _bound and not sun_changed and not city_changed:
		return
	if not seeded:
		_seed = seed
		var n := int(seed * 10007.0)
		_base = _noise(n, 0.34, FastNoiseLite.FRACTAL_FBM, 3)
		_ridge = _noise(n + 19, 0.55, FastNoiseLite.FRACTAL_RIDGED, 2)
		_cut = _noise(n + 41, 0.4, FastNoiseLite.FRACTAL_FBM, 2)
		_paint = _noise(n + 77, 2.4, FastNoiseLite.FRACTAL_FBM, 2)
		_bound = false
	if sun.length_squared() > 0.01:
		_sun = sun.normalized()
	elif _sun.length_squared() < 0.01:
		_sun = FlightProfile.SUN_OFFSET.normalized()
	if city.length_squared() > 0.01:
		_city = city.normalized()
	elif _city.length_squared() < 0.01:
		_city = (_sun * 0.82 + Vector3(0.28, 0.08, -0.22)).normalized()
	_craters = _place_craters(int(seed * 10007.0) + 101, _sun, _city)
	_bound = true


static func height_of(dir: Vector3, seed: float, radius: float) -> float:
	prepare(seed)
	var sample := _Sample.new()
	_eval(dir.normalized(), radius, _city, false, sample)
	return sample.height


static func survey(seed: float, radius: float, city_dir: Vector3, sun_dir: Vector3 = Vector3.ZERO) -> Dictionary:
	prepare(seed, sun_dir, city_dir)
	var sun := _sun
	var sample := _Sample.new()
	var best_ridge := Vector3.UP
	var best_ridge_score := -1.0e9
	var best_cut := Vector3.FORWARD
	var best_cut_score := 1.0e9
	var have_cut := false
	var fallback := Vector3.FORWARD
	var fallback_h := 1.0e9
	var land := Vector3.RIGHT
	var land_score := 1.0e9
	var clouds := Vector3.UP
	var cloud_score := -1.0
	var cloud_fallback := Vector3.UP
	var cloud_fallback_score := -1.0
	var step := 14
	for y in step:
		var phi := PI * (float(y) + 0.5) / float(step)
		for x in step * 2:
			var theta := TAU * float(x) / float(step * 2)
			var dir := _dir(phi, theta)
			if dir.dot(city_dir) > 0.48:
				continue
			_eval(dir, radius, city_dir, false, sample)
			var light := clampf(dir.dot(sun), 0.0, 1.0)
			if light < 0.18:
				continue
			var ridge_score := (sample.height - radius) * (0.3 + light)
			if ridge_score > best_ridge_score:
				best_ridge_score = ridge_score
				best_ridge = dir
			if sample.crater < 0.25 and sample.height < fallback_h:
				fallback_h = sample.height
				fallback = dir
			if sample.cut > 0.42 and sample.crater < 0.18:
				var cut_score := sample.height - light * radius * 0.02
				if not have_cut or cut_score < best_cut_score:
					best_cut_score = cut_score
					best_cut = dir
					have_cut = true
			var flat := absf(sample.height - radius) + sample.crater * radius + sample.cut * radius * 0.15
			flat += (1.0 - light) * radius * 0.08
			flat -= sample.cloud * radius * 0.04
			if light > 0.4 and flat < land_score:
				land_score = flat
				land = dir
			if sample.crater < 0.2 and light > 0.35 and sample.cloud > cloud_fallback_score:
				cloud_fallback_score = sample.cloud
				cloud_fallback = dir
			if light > 0.5 and sample.cloud > cloud_score and sample.crater < 0.2:
				cloud_score = sample.cloud
				clouds = dir
	if not have_cut:
		best_cut = fallback
	if cloud_score < 0.0:
		clouds = cloud_fallback
	var crater_dir := Vector3.FORWARD
	var crater_rad := 0.2
	var best_crater := -1.0
	for crater in _craters:
		var cdir: Vector3 = crater.dir
		if cdir.dot(city_dir) > 0.8:
			continue
		var light := cdir.dot(sun)
		if light < 0.2:
			continue
		var score := float(crater.rad) * 5.0 + light
		if score > best_crater:
			best_crater = score
			crater_dir = cdir
			crater_rad = float(crater.rad)
	if best_crater < 0.0 and not _craters.is_empty():
		var picked: Dictionary = _craters[0]
		crater_dir = picked.dir
		crater_rad = float(picked.rad)
	var crater_sample := _Sample.new()
	_eval(crater_dir, radius, city_dir, false, crater_sample)
	return {
		"ridge": best_ridge,
		"ridge_h": _height_only(best_ridge, radius, city_dir),
		"canyon": best_cut,
		"canyon_h": _height_only(best_cut, radius, city_dir),
		"crater": crater_dir,
		"crater_h": crater_sample.height,
		"crater_rad": crater_rad,
		"land": land,
		"land_h": _height_only(land, radius, city_dir),
		"clouds": clouds,
		"clouds_h": _height_only(clouds, radius, city_dir),
	}


static func build_mesh(radius: float, seed: float, radial: int, rings: int, colors: Array, city_dir: Vector3, flatten_city: bool) -> ArrayMesh:
	prepare(seed)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	var count := (rings + 1) * radial
	verts.resize(count)
	norms.resize(count)
	cols.resize(count)
	var sample := _Sample.new()
	for y in rings + 1:
		var phi := PI * float(y) / float(rings)
		for x in radial:
			var theta := TAU * float(x) / float(radial)
			var dir := _dir(phi, theta)
			_eval(dir, radius, city_dir, flatten_city, sample)
			var i := y * radial + x
			verts[i] = dir * sample.height
			cols[i] = _color(sample, colors)
	var acc := PackedVector3Array()
	acc.resize(count)
	for y in rings:
		var y0 := y * radial
		var y1 := (y + 1) * radial
		for x in radial:
			var x1 := (x + 1) % radial
			var a := y0 + x
			var b := y0 + x1
			var c := y1 + x1
			var d := y1 + x
			# a -> d is south, a -> b is east. That cross faces outward.
			var n0 := (verts[d] - verts[a]).cross(verts[b] - verts[a])
			var n1 := (verts[d] - verts[b]).cross(verts[c] - verts[b])
			acc[a] += n0
			acc[d] += n0
			acc[b] += n0
			acc[b] += n1
			acc[d] += n1
			acc[c] += n1
			indices.append(a)
			indices.append(d)
			indices.append(b)
			indices.append(b)
			indices.append(d)
			indices.append(c)
	for i in count:
		var n: Vector3 = acc[i]
		if n.length_squared() < 0.000001:
			n = verts[i]
		elif n.dot(verts[i]) < 0.0:
			n = -n
		norms[i] = n.normalized()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func cloud_image(seed: float) -> Image:
	prepare(seed)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		var phi := PI * (float(y) + 0.5) / 32.0
		for x in 64:
			var theta := TAU * (float(x) + 0.5) / 64.0
			var dir := _dir(phi, theta)
			var density := _cloud_density(dir)
			var byte := int(clampf(density, 0.0, 1.0) * 255.0)
			image.set_pixel(x, y, Color8(byte, byte, byte, 255))
	return image


static func detail_image(seed: float) -> Image:
	prepare(seed)
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var n := _paint.get_noise_2d(float(x) * 1.7, float(y) * 1.7)
			var v := clampf(n * 0.5 + 0.5, 0.0, 1.0)
			var byte := int(v * 255.0)
			image.set_pixel(x, y, Color8(byte, byte, byte, 255))
	return image


static func _height_only(dir: Vector3, radius: float, city_dir: Vector3) -> float:
	var sample := _Sample.new()
	_eval(dir, radius, city_dir, false, sample)
	return sample.height


static func _eval(dir: Vector3, radius: float, city_dir: Vector3, flatten_city: bool, out: _Sample) -> void:
	var p := dir
	var base := _base.get_noise_3dv(p)
	var ridge := clampf(_ridge.get_noise_3dv(p), 0.0, 1.0)
	var warp := _cut.get_noise_3dv(p + Vector3(2.0, 0.4, 1.2))
	var valley := _cut.get_noise_3dv(p * 1.25 + Vector3(warp, warp * 0.3, -warp) * 0.4)
	var cut := 1.0 - smoothstep(0.02, 0.2, absf(valley))
	var amp := radius * RELIEF
	var h := radius
	h += base * amp * 0.48
	h += ridge * ridge * amp * 0.85 * (1.0 - cut * 0.8)
	h -= cut * amp * 0.95
	var crater := _crater_delta(dir, amp)
	h += crater.x
	if flatten_city:
		var align := dir.dot(city_dir)
		if align > 0.9:
			var pad := smoothstep(0.9, 0.975, align)
			h = lerpf(h, radius, pad)
	h = clampf(h, radius - amp * 1.05, radius + amp * 1.15)
	out.height = h
	out.ridge = ridge
	out.cut = cut
	out.crater = clampf(-crater.x / maxf(amp, 0.001), 0.0, 1.0)
	out.cloud = _cloud_density(dir)
	out.paint = _paint.get_noise_3dv(p * 3.0)


static func _crater_delta(dir: Vector3, amp: float) -> Vector2:
	var delta := 0.0
	for crater in _craters:
		var axis: Vector3 = crater.dir
		var ang := acos(clampf(dir.dot(axis), -1.0, 1.0))
		var rad: float = crater.rad
		if ang > rad * 1.45:
			continue
		var u := ang / rad
		var bowl := smoothstep(1.0, 0.2, u)
		var rim := smoothstep(0.72, 0.98, u) * (1.0 - smoothstep(0.98, 1.35, u))
		delta += -bowl * amp * float(crater.depth) + rim * amp * float(crater.rim)
	return Vector2(delta, 0.0)


static func _cloud_density(dir: Vector3) -> float:
	var band := _base.get_noise_3dv(dir * 1.55 + Vector3(4.0, 0.2, 1.0))
	var puff := _cut.get_noise_3dv(dir * 1.3 + Vector3(1.0, 3.0, 0.4))
	var d := smoothstep(0.08, 0.58, band * 0.72 + puff * 0.28)
	return clampf(d, 0.0, 1.0)


static func _color(sample: _Sample, colors: Array) -> Color:
	var low: Color = colors[0]
	var mid: Color = colors[1]
	var high: Color = colors[2]
	var peak: Color = colors[3]
	var lift := clampf(sample.ridge * (1.0 - sample.cut) + sample.paint * 0.15, 0.0, 1.0)
	var albedo := low.lerp(mid, smoothstep(0.15, 0.55, lift))
	albedo = albedo.lerp(high, smoothstep(0.45, 0.82, lift))
	albedo = albedo.lerp(peak, smoothstep(0.78, 1.0, sample.ridge) * (1.0 - sample.cut))
	albedo = albedo.lerp(low.darkened(0.45), sample.cut * 0.75)
	albedo = albedo.lerp(low.darkened(0.55), sample.crater * 0.85)
	return Color(_step(albedo.r), _step(albedo.g), _step(albedo.b), 1.0)


static func _step(value: float) -> float:
	return floor(value * 10.0 + 0.5) / 10.0


static func _place_craters(salt: int, sun: Vector3, city: Vector3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var side := sun.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var hero := (sun * 0.58 + side * 0.78 - city * 0.2).normalized()
	if hero.dot(city) > 0.7:
		hero = (sun * 0.42 + side).normalized()
	if hero.dot(sun) < 0.28:
		hero = (sun * 0.75 + side * 0.4).normalized()
	var list: Array = []
	list.append({"dir": hero, "rad": 0.42, "depth": 1.15, "rim": 0.55})
	for _i in 11:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		if dir.length_squared() < 0.01:
			dir = Vector3.UP
		dir = dir.normalized()
		if dir.dot(hero) > 0.82:
			dir = (dir + side * 0.8).normalized()
		list.append({
			"dir": dir,
			"rad": 0.07 + rng.randf() * 0.08,
			"depth": 0.45 + rng.randf() * 0.3,
			"rim": 0.18 + rng.randf() * 0.12,
		})
	return list


static func _noise(salt: int, frequency: float, fractal: int, octaves: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = salt
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	return noise


static func _dir(phi: float, theta: float) -> Vector3:
	return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))


class _Sample:
	var height := 0.0
	var ridge := 0.0
	var cut := 0.0
	var crater := 0.0
	var cloud := 0.0
	var paint := 0.0
