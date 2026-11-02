extends Node3D

## One test region on Mina: slab towers stacked from a small hand-made kit.
## Low quality keeps a single box per tower. Near views use the stacked kit.

const _SLAB := preload("res://assets/shaders/mega_slab.gdshader")
const _CLOUD := preload("res://assets/shaders/mega_cloud.gdshader")
const _Post := preload("res://scripts/data/post_profile.gd")

var _white: ShaderMaterial
var _blue: ShaderMaterial
var _face: Texture2D


func build(planet_radius: float, sun_dir: Vector3) -> void:
	name = "MegaCity"
	var sun := sun_dir.normalized()
	var up := (sun * 0.82 + Vector3(0.28, 0.08, -0.22)).normalized()
	position = up * planet_radius
	var side := up.cross(Vector3.RIGHT)
	if side.length() < 0.2:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	var x := side.cross(up).normalized()
	basis = Basis(x, up, -side).orthonormalized()
	_make_materials()
	_lay_lots()
	_lay_clouds()


func _make_materials() -> void:
	_face = _face_texture()
	_white = _slab_material(Color(0.8, 0.78, 0.74))
	_blue = _slab_material(Color(0.46, 0.56, 0.66))


func _slab_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _SLAB
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("face_tex", _face)
	var far := 70.0 if _Post.quality() == "low" else 110.0
	mat.set_shader_parameter("haze_far", far)
	return mat


func _lay_lots() -> void:
	var low := _Post.quality() == "low"
	var med := _Post.quality() == "med"
	var cols := 3 if low else (4 if med else 5)
	var rows := 3 if low else (3 if med else 4)
	var gap := 1.8
	var step := 2.7
	for iz in rows:
		for ix in cols:
			var x := (float(ix) - float(cols - 1) * 0.5) * step
			if x > 0.2:
				x += gap
			elif x < -0.2:
				x -= gap
			var z := (float(iz) - float(rows - 1) * 0.5) * step
			var floors := 6 + ((ix * 3 + iz * 5) % 9)
			if low:
				floors = 5 + ((ix + iz * 2) % 5)
			var wide := (ix + iz) % 3 != 0
			_tower(Vector3(x, 0.0, z), floors, wide, low)


func _tower(at: Vector3, floors: int, wide: bool, low: bool) -> void:
	var width := 1.45 if wide else 0.95
	var depth := 1.05 if wide else 0.72
	var story := 0.82
	var height := float(floors) * story
	var root := Node3D.new()
	root.position = at
	add_child(root)
	if not low:
		for level in floors:
			var blue := level % 4 == 3
			var y := story * (float(level) + 0.5)
			var slab := _box(root, Vector3(0, y, 0), Vector3(width, story * 0.92, depth), _blue if blue else _white)
			slab.visibility_range_end = 46.0
			slab.visibility_range_end_margin = 10.0
			if level % 5 == 4 and _Post.high_quality():
				var band := _box(root, Vector3(0, y, 0), Vector3(width + 0.08, story * 0.28, depth + 0.08), _blue if not blue else _white)
				band.visibility_range_end = 28.0
			if level % 4 == 3:
				var seam := _seam(root, Vector3(0, y + story * 0.42, depth * 0.5 + 0.01), width)
				seam.visibility_range_end = 32.0
	var impostor := _box(root, Vector3(0, height * 0.5, 0), Vector3(width, height, depth), _white if (floors % 2 == 0) else _blue)
	if not low:
		impostor.visibility_range_begin = 38.0
		impostor.visibility_range_begin_margin = 10.0


func _box(parent: Node3D, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _seam(parent: Node3D, at: Vector3, width: float) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width * 0.92, 0.035, 0.02)
	mesh.mesh = box
	mesh.position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.85, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 1.05, 0.85)
	mat.emission_energy_multiplier = 2.2
	mesh.material_override = mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


func _lay_clouds() -> void:
	var tex := _cloud_texture()
	var layers := 1 if _Post.quality() == "low" else 3
	var offsets := [Vector3.ZERO, Vector3(2.2, 0, 1.4), Vector3(-1.6, 0, -1.8)]
	for i in layers:
		var deck := MeshInstance3D.new()
		deck.name = "Clouds%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(14.0, 12.0)
		deck.mesh = quad
		var shift: Vector3 = offsets[i]
		deck.position = Vector3(shift.x, 0.45 + float(i) * 0.55, shift.z)
		deck.rotation.x = -PI * 0.5
		var mat := ShaderMaterial.new()
		mat.shader = _CLOUD
		mat.set_shader_parameter("cloud_tex", tex)
		mat.set_shader_parameter("cloud_alpha", 0.62 - float(i) * 0.14)
		deck.material_override = mat
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(deck)


func _face_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.94, 0.93, 0.9))
	var line := Color(0.45, 0.46, 0.48)
	for i in range(0, 64, 8):
		for x in 64:
			image.set_pixel(x, i, line)
			image.set_pixel(i, x, line)
	var window := Color(1.0, 0.78, 0.32)
	var dots := [Vector2i(6, 10), Vector2i(14, 18), Vector2i(22, 12), Vector2i(30, 22), Vector2i(40, 14), Vector2i(50, 26), Vector2i(18, 40), Vector2i(36, 46)]
	for dot in dots:
		image.set_pixel(dot.x, dot.y, window)
		if dot.x + 1 < 64:
			image.set_pixel(dot.x + 1, dot.y, window)
	var ink := Color(0.75, 0.08, 0.07)
	_digit(image, 8, 4, 0, ink)
	_digit(image, 20, 4, 4, ink)
	return ImageTexture.create_from_image(image)


func _digit(image: Image, x: int, y: int, which: int, color: Color) -> void:
	var glyph := "11110100011000110001100011000111110" if which == 0 else "11111100011000110001111110000100001"
	for row in 7:
		for col in 5:
			if glyph.substr(row * 5 + col, 1) != "1":
				continue
			var px := x + col
			var py := y + row
			if px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)


func _cloud_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var u := float(x) / 64.0
			var v := float(y) / 64.0
			var a := sin(u * TAU * 3.0) * sin(v * TAU * 2.0)
			var b := sin((u + v) * TAU * 1.5)
			var n := clampf(0.55 + a * 0.28 + b * 0.18, 0.0, 1.0)
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)
