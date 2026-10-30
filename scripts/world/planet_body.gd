class_name PlanetBody
extends Node3D

## One seeded world: readable face, atmosphere rim, rings and moon when the seed says so.

const _PLANET_SHADER := preload("res://assets/shaders/planet.gdshader")
const _ATMO_SHADER := preload("res://assets/shaders/atmosphere.gdshader")
const _RING_SHADER := preload("res://assets/shaders/ring.gdshader")

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

	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 48

	surface = MeshInstance3D.new()
	surface.name = "Surface"
	surface.mesh = sphere
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
	surface.material_override = _surface_mat
	_spin.add_child(surface)

	var atmo_color := _cool(Color.html(data.atmosphere), 0.74)
	_atmo_mat = _add_atmosphere(radius * 1.045, atmo_color, sun, 2.6, 2.4, 1.25)
	_add_atmosphere(radius * 1.16, atmo_color, sun, 2.2, 1.4, 0.5)

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

	var moon := MeshInstance3D.new()
	moon.name = "Moon"
	var moon_radius := radius * 0.16
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = moon_radius
	moon_mesh.height = moon_radius * 2.0
	moon_mesh.radial_segments = 20
	moon_mesh.rings = 14
	moon.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.albedo_color = Color.html(data.moon)
	moon_mat.metallic = 0.04
	moon_mat.roughness = 0.92
	moon.material_override = moon_mat
	moon.position = _moon_offset(data)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)


func _process(delta: float) -> void:
	if _spin:
		_spin.rotate_y(delta * 0.02)
	if _surface_mat:
		var time := float(_surface_mat.get_shader_parameter("u_time"))
		_surface_mat.set_shader_parameter("u_time", time + delta)


func _cool(color: Color, toward: float) -> Color:
	return color.lerp(Color(0.5, 0.74, 0.88), toward)


func _add_atmosphere(shell_radius: float, color: Color, sun: Vector3, power: float, falloff: float, strength: float) -> ShaderMaterial:
	var shell := SphereMesh.new()
	shell.radius = shell_radius
	shell.height = shell_radius * 2.0
	shell.radial_segments = 64
	shell.rings = 40
	var atmo := MeshInstance3D.new()
	atmo.name = "Atmosphere"
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
