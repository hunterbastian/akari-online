class_name PlanetBody
extends Node3D

## One seeded world: readable face, atmosphere rim, rings and moons when the seed says so.

const _PLANET_SHADER := preload("res://assets/shaders/planet.gdshader")
const _ATMO_SHADER := preload("res://assets/shaders/atmosphere.gdshader")
const _RING_SHADER := preload("res://assets/shaders/ring.gdshader")
const _PostProfile := preload("res://scripts/data/post_profile.gd")
const _Ranges := preload("res://scripts/data/detail_ranges.gd")

var planet: Dictionary = {}
var surface: MeshInstance3D
var _surface_mat: ShaderMaterial
var _atmo_mat: ShaderMaterial
var _spin: Node3D


func setup(data: Dictionary, sun_dir: Vector3) -> void:
	planet = data
	position = data.position
	var radius: float = data.radius
	var colors: Array = data.colors
	var sun := sun_dir.normalized()

	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)

	_surface_mat = ShaderMaterial.new()
	_surface_mat.shader = _PLANET_SHADER
	_surface_mat.set_shader_parameter("u_center", data.position)
	_surface_mat.set_shader_parameter("u_sun_dir", sun)
	_surface_mat.set_shader_parameter("u_c0", Color.html(colors[0]))
	_surface_mat.set_shader_parameter("u_c1", Color.html(colors[1]))
	_surface_mat.set_shader_parameter("u_c2", Color.html(colors[2]))
	_surface_mat.set_shader_parameter("u_c3", Color.html(colors[3]))
	_surface_mat.set_shader_parameter("u_atmo", Color.html(data.atmosphere))
	_surface_mat.set_shader_parameter("u_seed", float(data.seed))
	_surface_mat.set_shader_parameter("u_biome", Universe.biome_index(data.biome))
	_surface_mat.set_shader_parameter("u_time", 0.0)
	_surface_mat.set_shader_parameter("u_simple", 0.0)
	var phone := _Ranges.mobile()
	var near_d := _Ranges.near_end(phone)
	var mid_d := _Ranges.mid_end(phone)
	var band := _Ranges.fade(phone)
	var near_seg := 40 if phone else 64
	var near_rings := 28 if phone else 48
	surface = _add_surface("Surface", radius, near_seg, near_rings, _surface_mat)
	if _Ranges.enabled():
		_Ranges.show_near(surface, near_d, band)
		var mid_mat := _surface_mat.duplicate() as ShaderMaterial
		mid_mat.set_shader_parameter("u_simple", 1.0)
		var mid := _add_surface("SurfaceMid", radius, 24 if phone else 32, 16 if phone else 22, mid_mat)
		_Ranges.show_mid(mid, near_d, mid_d, band)
		var far := _add_surface("SurfaceFar", radius, 12, 8, mid_mat)
		_Ranges.show_far(far, mid_d, band)

	var atmo_color := _cool(Color.html(data.atmosphere), 0.55)
	var detailed := _PostProfile.detailed()
	var shell_seg := 28 if phone else (40 if detailed else 24)
	if detailed and not phone:
		var inner := _add_atmosphere(radius * 1.025, atmo_color, sun, 3.6, 2.6, 0.85, shell_seg)
		var haze := _add_atmosphere(radius * 1.18, atmo_color, sun, 2.1, 1.6, 0.32, 28)
		if _Ranges.enabled():
			_Ranges.show_near(inner, near_d, band)
			_Ranges.cull_after(haze, near_d, band)
			var far_inner := _add_atmosphere(radius * 1.04, atmo_color, sun, 2.2, 1.7, 0.4, 16)
			var far_haze := _add_atmosphere(radius * 1.16, atmo_color, sun, 1.6, 1.3, 0.22, 12)
			_Ranges.show_far(far_inner, near_d, band)
			_Ranges.show_far(far_haze, near_d, band)
	else:
		var inner := _add_atmosphere(radius * 1.06, atmo_color, sun, 2.4, 1.8, 0.55, shell_seg)
		if _Ranges.enabled():
			_Ranges.show_near(inner, mid_d, band)
			var far_atmo := _add_atmosphere(radius * 1.05, atmo_color, sun, 1.8, 1.4, 0.35, 12)
			_Ranges.show_far(far_atmo, mid_d, band)

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
		if _Ranges.enabled() and rings.get_child_count() > 1:
			_Ranges.cull_after(rings.get_child(1), mid_d, band)

	var moons: Array = data.get("moons", [{"kind": "primary", "radius": 0.16, "color": data.moon, "roughness": 0.92, "craters": false}])
	var primary := _moon_offset(data)
	for i in moons.size():
		var spec: Dictionary = moons[i]
		var offset := primary if spec.kind == "primary" else _orbit_offset(spec, primary, radius)
		_add_moon("Moon" if i == 0 else "Moon%d" % (i + 1), spec, offset, radius)

	if str(data.get("id", "")) == "sol:0":
		var city = load("res://scripts/world/mega_city.gd").new()
		add_child(city)
		city.build(radius, sun)


# hot
func _process(delta: float) -> void:
	if _spin:
		_spin.rotate_y(delta * 0.02)
	if _surface_mat:
		var time := float(_surface_mat.get_shader_parameter("u_time"))
		_surface_mat.set_shader_parameter("u_time", time + delta)


func _cool(color: Color, toward: float) -> Color:
	return color.lerp(Color(0.5, 0.74, 0.88), toward)


func _add_surface(surface_name: String, radius: float, radial: int, rings: int, material: ShaderMaterial) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = radial
	sphere.rings = rings
	var body := MeshInstance3D.new()
	body.name = surface_name
	body.mesh = sphere
	body.material_override = material
	body.extra_cull_margin = 0.0
	_spin.add_child(body)
	return body


func _add_atmosphere(shell_radius: float, color: Color, sun: Vector3, power: float, falloff: float, strength: float, segments: int) -> MeshInstance3D:
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
	atmo.extra_cull_margin = 0.0
	add_child(atmo)
	if _atmo_mat == null:
		_atmo_mat = material
	return atmo


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
		# Cheap pocked look: one small cellular-noise texture, made once.
		moon_mat.albedo_texture = _crater_texture()
	moon.material_override = moon_mat
	moon.position = offset
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.extra_cull_margin = 0.0
	add_child(moon)
	if _Ranges.enabled():
		var phone := _Ranges.mobile()
		var reach := _Ranges.moon_near(phone)
		var band := _Ranges.fade(phone)
		_Ranges.show_near(moon, reach, band)
		var far := MeshInstance3D.new()
		far.name = moon_name + "Far"
		var low := SphereMesh.new()
		low.radius = moon_radius
		low.height = moon_radius * 2.0
		low.radial_segments = 8
		low.rings = 6
		far.mesh = low
		far.material_override = moon_mat
		far.position = offset
		far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		far.extra_cull_margin = 0.0
		add_child(far)
		_Ranges.show_far(far, reach, band)


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


## A secondary moon sits on its own wider, tilted orbit, a fixed lead angle
## around from the primary so the two never line up.
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
