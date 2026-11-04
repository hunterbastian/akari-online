class_name PlanetBody
extends Node3D

## One seeded world. Relief is baked once. Clouds drift by scrolling a texture.
## The mesh does not spin, so the city pad stays on the flattened ground.

const _PLANET_SHADER := preload("res://assets/shaders/planet.gdshader")
const _CLOUD_SHADER := preload("res://assets/shaders/planet_cloud.gdshader")
const _ROCK_SHADER := preload("res://assets/shaders/planet_rock.gdshader")
const _ATMO_SHADER := preload("res://assets/shaders/atmosphere.gdshader")
const _RING_SHADER := preload("res://assets/shaders/ring.gdshader")
const _PostProfile := preload("res://scripts/data/post_profile.gd")

var planet: Dictionary = {}
var surface: MeshInstance3D
var _surface_mat: ShaderMaterial
var _cloud_mat: ShaderMaterial
var _rock_mat: ShaderMaterial
var _atmo_mat: ShaderMaterial
var _rock_mesh: ArrayMesh
var _spin: Node3D
var _survey: Dictionary = {}
var _phone := false
var _held := false
var _cloud_time := 0.0
var _radius := 1.0
var _seed := 0.0


func setup(data: Dictionary, sun_dir: Vector3) -> void:
	planet = data
	position = data.position
	var radius: float = data.radius
	_radius = radius
	var colors: Array = data.colors
	var sun := sun_dir.normalized()
	_seed = float(data.seed)
	_phone = PlanetTerrain.phone()
	var city_dir := (sun * 0.82 + Vector3(0.28, 0.08, -0.22)).normalized()
	var flatten := str(data.get("id", "")) == "sol:0"
	PlanetTerrain.prepare(_seed, sun, city_dir)
	_survey = PlanetTerrain.survey(_seed, radius, city_dir, sun)

	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)

	var palette: Array = [
		Color.html(str(colors[0])),
		Color.html(str(colors[1])),
		Color.html(str(colors[2])),
		Color.html(str(colors[3])),
	]
	var atmo_color := Color.html(str(data.atmosphere))
	var cloud_tex := ImageTexture.create_from_image(PlanetTerrain.cloud_image(_seed))
	var detail_tex := ImageTexture.create_from_image(PlanetTerrain.detail_image(_seed))

	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = _PLANET_SHADER
	_surface_mat.set_shader_parameter("u_sun_dir", sun)
	_surface_mat.set_shader_parameter("u_city_dir", city_dir)
	_surface_mat.set_shader_parameter("u_atmo", atmo_color)
	_surface_mat.set_shader_parameter("u_time", 0.0)
	_surface_mat.set_shader_parameter("u_detail_near", PlanetTerrain.detail_near(_phone))
	_surface_mat.set_shader_parameter("u_detail_far", PlanetTerrain.detail_far(_phone))
	_surface_mat.set_shader_parameter("u_cloud_bias", 0.1)
	_surface_mat.set_shader_parameter("u_detail", detail_tex)
	_surface_mat.set_shader_parameter("u_cloud", cloud_tex)

	var near_radial := PlanetTerrain.PHONE_NEAR_RADIAL if _phone else PlanetTerrain.NEAR_RADIAL
	var near_rings := PlanetTerrain.PHONE_NEAR_RINGS if _phone else PlanetTerrain.NEAR_RINGS
	var mid_radial := PlanetTerrain.PHONE_MID_RADIAL if _phone else PlanetTerrain.MID_RADIAL
	var mid_rings := PlanetTerrain.PHONE_MID_RINGS if _phone else PlanetTerrain.MID_RINGS
	var far_radial := PlanetTerrain.PHONE_FAR_RADIAL if _phone else PlanetTerrain.FAR_RADIAL
	var far_rings := PlanetTerrain.PHONE_FAR_RINGS if _phone else PlanetTerrain.FAR_RINGS
	var near_end := PlanetTerrain.near_end(_phone)
	var mid_end := PlanetTerrain.mid_end(_phone)
	var band := PlanetTerrain.fade(_phone)
	var near_mesh := PlanetTerrain.build_mesh(radius, _seed, near_radial, near_rings, palette, city_dir, flatten)
	var mid_mesh := PlanetTerrain.build_mesh(radius, _seed, mid_radial, mid_rings, palette, city_dir, flatten)
	var far_mesh := PlanetTerrain.build_mesh(radius, _seed, far_radial, far_rings, palette, city_dir, flatten)
	surface = _add_surface(near_mesh, "Surface", 0.0, near_end + band, band)
	_add_surface(mid_mesh, "SurfaceMid", near_end, mid_end + band, band)
	_add_surface(far_mesh, "SurfaceFar", mid_end, 0.0, band)

	_add_clouds(radius * 1.28, sun, city_dir, cloud_tex)
	_add_rocks(sun, atmo_color, city_dir)

	var shell_tint := _cool(atmo_color, 0.35)
	var inner_seg := 20 if _phone else 34
	var outer_seg := 14 if _phone else 24
	var inner_strength := 1.02 if _phone else 1.28
	var outer_strength := 0.4 if _phone else 0.52
	_atmo_mat = _add_atmosphere(radius * 1.36, shell_tint, sun, 4.8, 1.3, inner_strength, inner_seg)
	_add_atmosphere(radius * 1.56, shell_tint, sun, 2.05, 0.88, outer_strength, outer_seg)

	if data.rings:
		var rings := Node3D.new()
		rings.name = "Rings"
		rings.rotation_order = EULER_ORDER_XYZ
		rings.rotation = data.ringTilt
		add_child(rings)
		var ring_color := _cool(Color.html(data.ring), 0.62)
		var band_color := _cool(Color.html(colors[2]), 0.7)
		_add_ring(rings, radius * 1.42, radius * 1.62, ring_color, 0.55, data.position, radius, sun)
		_add_ring(rings, radius * 1.72, radius * 2.22, band_color, 0.28, data.position, radius, sun)

	var moons: Array = data.get("moons", [{"kind": "primary", "radius": 0.16, "color": data.moon, "roughness": 0.92, "craters": false}])
	var primary := _moon_offset(data)
	for i in moons.size():
		var spec: Dictionary = moons[i]
		var offset := primary if spec.kind == "primary" else _orbit_offset(spec, primary, radius)
		_add_moon("Moon" if i == 0 else "Moon%d" % (i + 1), spec, offset, radius)

	if flatten:
		var city = load("res://scripts/world/mega_city.gd").new()
		add_child(city)
		city.build(radius, sun)


func feature(kind: String) -> Dictionary:
	var dir: Vector3 = _survey.ridge
	var height: float = _survey.ridge_h
	if kind == "canyon":
		dir = _survey.canyon
		height = _survey.canyon_h
	elif kind == "crater":
		dir = _survey.crater
		height = _survey.crater_h
	elif kind == "land":
		dir = _survey.land
		height = _survey.land_h
	elif kind == "clouds":
		dir = _survey.clouds
		height = _survey.clouds_h
	var point := global_position + dir * height
	var tangent := dir.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = dir.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	return {"point": point, "normal": dir, "tangent": tangent}


func hold_for_shot() -> void:
	_held = true


# hot
func _process(delta: float) -> void:
	if _held:
		return
	_cloud_time += delta
	if _surface_mat:
		_surface_mat.set_shader_parameter("u_time", _cloud_time)
	if _cloud_mat:
		_cloud_mat.set_shader_parameter("u_time", _cloud_time)


func _cool(color: Color, toward: float) -> Color:
	return color.lerp(Color(0.5, 0.74, 0.88), toward)


func _add_surface(mesh: ArrayMesh, node_name: String, begin: float, end: float, margin: float) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _surface_mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	if begin > 0.0:
		mesh_instance.visibility_range_begin = begin
		mesh_instance.visibility_range_begin_margin = margin
	if end > 0.0:
		mesh_instance.visibility_range_end = end
		mesh_instance.visibility_range_end_margin = margin
	mesh_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	_spin.add_child(mesh_instance)
	return mesh_instance


func _add_clouds(shell_radius: float, sun: Vector3, city_dir: Vector3, cloud_tex: ImageTexture) -> void:
	var shell := SphereMesh.new()
	shell.radius = shell_radius
	shell.height = shell_radius * 2.0
	var segments := 24 if _phone else 56
	shell.radial_segments = segments
	shell.rings = maxi(segments / 2, 8)
	var cloud := MeshInstance3D.new()
	cloud.name = "Clouds"
	cloud.mesh = shell
	_cloud_mat = ShaderMaterial.new()
	_cloud_mat.shader = _CLOUD_SHADER
	_cloud_mat.set_shader_parameter("u_cloud", cloud_tex)
	_cloud_mat.set_shader_parameter("u_sun_dir", sun)
	_cloud_mat.set_shader_parameter("u_city_dir", city_dir)
	_cloud_mat.set_shader_parameter("u_time", 0.0)
	_cloud_mat.set_shader_parameter("u_color", Color(0.86, 0.93, 0.97))
	cloud.material_override = _cloud_mat
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(cloud)


func _add_rocks(sun: Vector3, atmo_color: Color, city_dir: Vector3) -> void:
	_rock_mesh = _make_rock_mesh()
	_rock_mat = ShaderMaterial.new()
	_rock_mat.shader = _ROCK_SHADER
	_rock_mat.set_shader_parameter("u_sun_dir", sun)
	_rock_mat.set_shader_parameter("u_atmo", atmo_color)
	var crater_dir: Vector3 = _survey.crater
	var axis := crater_dir.cross(Vector3.UP)
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	var rim := crater_dir.rotated(axis.normalized(), float(_survey.crater_rad))
	var spots: Array = [rim, _survey.ridge, _survey.canyon, _survey.land, _survey.clouds]
	var clusters := PlanetTerrain.PHONE_ROCK_CLUSTERS if _phone else PlanetTerrain.ROCK_CLUSTERS
	for i in mini(clusters, spots.size()):
		var dir: Vector3 = spots[i]
		if dir.dot(city_dir) > 0.88:
			continue
		_add_rock_cluster(dir, i)


func _add_rock_cluster(dir: Vector3, slot: int) -> void:
	var normal := dir.normalized()
	var tangent := normal.cross(Vector3.UP)
	if tangent.length_squared() < 0.0001:
		tangent = normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := normal.cross(tangent)
	var count := PlanetTerrain.PHONE_ROCKS_EACH if _phone else PlanetTerrain.ROCKS_EACH
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _rock_mesh
	multi.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seed * 10007.0) + slot * 17 + 3
	for i in count:
		var along := rng.randf_range(-3.4, 3.4)
		var across := rng.randf_range(-3.4, 3.4)
		var sample_dir := (normal * _radius + tangent * along + bitangent * across).normalized()
		var height := PlanetTerrain.height_of(sample_dir, _seed, _radius)
		var pos := sample_dir * (height + 0.03)
		var align := Basis.IDENTITY
		if absf(normal.dot(Vector3.UP)) > 0.995:
			if normal.y < 0.0:
				align = Basis(Vector3.RIGHT, PI)
		else:
			align = Basis(Quaternion(Vector3.UP, normal))
		var scale := Vector3(rng.randf_range(0.75, 1.55), rng.randf_range(0.55, 1.25), rng.randf_range(0.75, 1.45))
		var basis := align * Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(scale)
		multi.set_instance_transform(i, Transform3D(basis, pos))
		var shade := 0.55 + rng.randf() * 0.4
		multi.set_instance_color(i, Color(shade * 0.78, shade * 0.92, shade))
	var inst := MultiMeshInstance3D.new()
	inst.name = "Rocks%d" % slot
	inst.multimesh = multi
	inst.material_override = _rock_mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.visibility_range_end = PlanetTerrain.PHONE_ROCK_END if _phone else PlanetTerrain.ROCK_END
	inst.visibility_range_end_margin = PlanetTerrain.PHONE_ROCK_FADE if _phone else PlanetTerrain.ROCK_FADE
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(inst)


func _make_rock_mesh() -> ArrayMesh:
	var top := Vector3(0, 0.55, 0)
	var bot := Vector3(0, -0.32, 0)
	var ring: Array = [
		Vector3(0.42, 0.04, 0),
		Vector3(0, 0.04, 0.38),
		Vector3(-0.4, 0.04, 0),
		Vector3(0, 0.04, -0.36),
	]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		_tri(tool, top, a, b)
		_tri(tool, bot, b, a)
	return tool.commit()


func _tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.000001:
		normal = Vector3.UP
	tool.set_normal(normal.normalized())
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)


func _add_atmosphere(shell_radius: float, color: Color, sun: Vector3, power: float, falloff: float, strength: float, segments: int) -> ShaderMaterial:
	var shell := SphereMesh.new()
	shell.radius = shell_radius
	shell.height = shell_radius * 2.0
	shell.radial_segments = segments
	shell.rings = maxi(segments / 2, 8)
	var atmo := MeshInstance3D.new()
	atmo.name = "Atmosphere"
	atmo.add_to_group("planet_atmo")
	atmo.mesh = shell
	var material := ShaderMaterial.new()
	material.shader = _ATMO_SHADER
	material.set_shader_parameter("u_color", color)
	material.set_shader_parameter("u_sun_dir", sun)
	material.set_shader_parameter("u_power", power)
	material.set_shader_parameter("u_falloff", falloff)
	material.set_shader_parameter("u_strength", strength)
	atmo.material_override = material
	atmo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(atmo)
	return material


func _add_ring(parent: Node3D, inner: float, outer: float, color: Color, alpha: float, center: Vector3, planet_radius: float, sun: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _annulus(inner, outer)
	var material := ShaderMaterial.new()
	material.shader = _RING_SHADER
	material.set_shader_parameter("u_color", color)
	material.set_shader_parameter("u_center", center)
	material.set_shader_parameter("u_sun_dir", sun)
	material.set_shader_parameter("u_planet_radius", planet_radius)
	material.set_shader_parameter("u_inner", inner)
	material.set_shader_parameter("u_outer", outer)
	material.set_shader_parameter("u_alpha", alpha)
	mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)


func _annulus(inner: float, outer: float, segments: int = 96) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var inner_0 := Vector3(cos(a0) * inner, sin(a0) * inner, 0.0)
		var outer_0 := Vector3(cos(a0) * outer, sin(a0) * outer, 0.0)
		var inner_1 := Vector3(cos(a1) * inner, sin(a1) * inner, 0.0)
		var outer_1 := Vector3(cos(a1) * outer, sin(a1) * outer, 0.0)
		_quad(tool, inner_0, outer_0, outer_1, inner_1, Vector3(0, 0, 1))
		_quad(tool, inner_0, inner_1, outer_1, outer_0, Vector3(0, 0, -1))
	return tool.commit()


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(d)


func _add_moon(moon_name: String, spec: Dictionary, offset: Vector3, planet_radius: float) -> void:
	var high := _PostProfile.high_quality()
	var moon := MeshInstance3D.new()
	moon.name = moon_name
	var moon_radius := planet_radius * float(spec.radius)
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = moon_radius
	moon_mesh.height = moon_radius * 2.0
	moon_mesh.radial_segments = 20 if high else 14
	moon_mesh.rings = 14 if high else 9
	moon.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color.html(spec.color)
	moon_mat.metallic = 0.04
	moon_mat.roughness = float(spec.roughness)
	if bool(spec.craters) and high:
		moon_mat.albedo_texture = _crater_texture()
	moon.material_override = moon_mat
	moon.position = offset
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)


func _crater_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	noise.frequency = 0.035
	noise.seed = int(planet.get("seed", 0.0) * 1000.0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(0.45, 0.45, 0.47), Color(0.8, 0.8, 0.82), Color(1, 1, 1), Color(0.92, 0.92, 0.94)])
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	texture.color_ramp = ramp
	return texture


func _orbit_offset(spec: Dictionary, primary: Vector3, planet_radius: float) -> Vector3:
	var base := atan2(primary.z, primary.x) + float(spec.lead)
	var incl := float(spec.inclination)
	var flat := Vector3(cos(base), 0.0, sin(base))
	return (flat * cos(incl) + Vector3.UP * sin(incl)) * planet_radius * float(spec.orbit)


func _moon_offset(data: Dictionary) -> Vector3:
	var to_star: Vector3 = data.position
	if to_star.length_squared() < 1.0:
		to_star = Vector3(0, 0, 1)
	to_star = to_star.normalized() * -1.0
	var side := to_star.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3(1, 0, 0)
	side = side.normalized()
	var radius: float = data.radius
	var seed: float = data.seed
	var side_sign := 0.7 if fmod(seed, 1.0) < 0.5 else -0.7
	return to_star * radius * 1.85 + Vector3.UP * radius * 1.2 + side * radius * side_sign
