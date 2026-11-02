extends Node3D

## Mina test region. A hand-made kit (shaft, setback, cantilever, band, seam, bridge)
## stacked by rules into a canyon of brutalist slabs. Far away each tower is one box.

const _SLAB := preload("res://assets/shaders/mega_slab.gdshader")
const _CLOUD := preload("res://assets/shaders/mega_cloud.gdshader")
const _Post := preload("res://scripts/data/post_profile.gd")

var _white: ShaderMaterial
var _blue: ShaderMaterial
var _dark: ShaderMaterial
var _face: Texture2D
var _detail: Array = []
var _far: Array = []
var _seams: Array = []


func build(planet_radius: float, sun_dir: Vector3) -> void:
	name = "MegaCity"
	var sun := sun_dir.normalized()
	var up := (sun * 0.82 + Vector3(0.28, 0.08, -0.22)).normalized()
	position = up * planet_radius
	var side := up.cross(Vector3.RIGHT)
	if side.length() < 0.2:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	var x_axis := side.cross(up).normalized()
	basis = Basis(x_axis, up, -side).orthonormalized()
	_make_materials()
	_lay_city()
	_flush()
	_lay_clouds()


func _make_materials() -> void:
	_face = _face_texture()
	_white = _slab_material(Color(0.82, 0.8, 0.76))
	_blue = _slab_material(Color(0.42, 0.52, 0.64))
	_dark = _slab_material(Color(0.28, 0.3, 0.33))


func _slab_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _SLAB
	mat.set_shader_parameter("base_color", color)
	mat.set_shader_parameter("face_tex", _face)
	mat.set_shader_parameter("haze_near", 8.0)
	mat.set_shader_parameter("haze_far", 48.0 if _Post.quality() != "low" else 36.0)
	return mat


func _lay_city() -> void:
	var low := _Post.quality() == "low"
	# Three anchors, then a scatter of mid and small towers on either wall of the canyon.
	var specs: Array = [
		{"at": Vector3(-5.2, 0, -1.0), "w": 3.4, "d": 2.5, "floors": 24, "kind": "anchor"},
		{"at": Vector3(5.6, 0, 3.0), "w": 2.8, "d": 2.3, "floors": 18, "kind": "anchor"},
		{"at": Vector3(0.4, 0, 15.0), "w": 3.8, "d": 2.8, "floors": 28, "kind": "landmark"},
		{"at": Vector3(-4.2, 0, 5.5), "w": 1.7, "d": 1.3, "floors": 12, "kind": "mid"},
		{"at": Vector3(-6.4, 0, 8.0), "w": 1.4, "d": 1.6, "floors": 9, "kind": "mid"},
		{"at": Vector3(4.4, 0, -2.0), "w": 1.8, "d": 1.2, "floors": 14, "kind": "mid"},
		{"at": Vector3(6.8, 0, 8.5), "w": 1.5, "d": 1.4, "floors": 11, "kind": "mid"},
		{"at": Vector3(-3.6, 0, 11.0), "w": 1.1, "d": 0.9, "floors": 7, "kind": "small"},
		{"at": Vector3(3.8, 0, 11.5), "w": 0.95, "d": 1.2, "floors": 8, "kind": "small"},
		{"at": Vector3(7.2, 0, -0.5), "w": 1.0, "d": 0.8, "floors": 6, "kind": "small"},
		{"at": Vector3(-7.0, 0, 2.5), "w": 1.2, "d": 0.85, "floors": 6, "kind": "small"},
	]
	if low:
		specs = specs.slice(0, 7)
	var built: Array = []
	for spec in specs:
		var info: Dictionary = _tower(spec, low)
		built.append(info)
	if not low:
		_bridges(built)


func _tower(spec: Dictionary, low: bool) -> Dictionary:
	var origin: Vector3 = spec["at"]
	var width: float = spec["w"]
	var depth: float = spec["d"]
	var floors: int = spec["floors"]
	var kind: String = spec["kind"]
	var story := 0.78
	var y := -4.2
	var top := y
	for level in floors:
		if level > 0 and level % 4 == 0:
			width *= 0.8
			depth *= 0.84
		var blue := level % 5 == 4
		var center := origin + Vector3(0, y + story * 0.5, 0)
		if not low:
			_put(_detail, center, Vector3(width, story * 0.9, depth), blue)
			if level % 3 == 2:
				_put(_detail, center + Vector3(0, story * 0.28, 0), Vector3(width + 0.12, story * 0.22, depth + 0.08), false, true)
			if level % 7 == 6:
				var hang := width * 0.55
				_put(_detail, center + Vector3(hang, 0, 0), Vector3(width * 0.7, story * 0.45, depth * 0.5), not blue)
			if level % 4 == 3:
				_put_seam(center + Vector3(0, 0, depth * 0.52), width * 0.92)
			if kind == "landmark" and level % 2 == 0:
				_put_seam(center + Vector3(0, 0, depth * 0.52), 0.12)
		y += story
		top = y
	var height := top - (-4.2)
	var base_w: float = spec["w"]
	var base_d: float = spec["d"]
	var base_y := -4.2
	# Three masses so the distant silhouette still steps, without the full kit.
	_put(_far, origin + Vector3(0, base_y + height * 0.22, 0), Vector3(base_w, height * 0.44, base_d), kind == "small")
	_put(_far, origin + Vector3(0, base_y + height * 0.58, 0), Vector3(base_w * 0.72, height * 0.32, base_d * 0.78), kind != "anchor")
	_put(_far, origin + Vector3(0, base_y + height * 0.86, 0), Vector3(base_w * 0.46, height * 0.24, base_d * 0.5), false)
	return {"at": origin, "top": top, "w": spec["w"]}


func _bridges(built: Array) -> void:
	for i in built.size():
		var a: Dictionary = built[i]
		var a_at: Vector3 = a["at"]
		for j in range(i + 1, built.size()):
			var b: Dictionary = built[j]
			var b_at: Vector3 = b["at"]
			if a_at.x * b_at.x > 0.0:
				continue
			if absf(a_at.z - b_at.z) > 4.5:
				continue
			var span: Vector3 = b_at - a_at
			var length := Vector2(span.x, span.z).length()
			if length < 3.0 or length > 12.0:
				continue
			var height := minf(float(a["top"]), float(b["top"])) * 0.55
			var mid := (a_at + b_at) * 0.5
			mid.y = height
			_put(_detail, mid, Vector3(absf(span.x) + 0.4, 0.35, 0.55), true)
			_put_seam(mid + Vector3(0, 0.2, 0), absf(span.x))
			break


func _put(bucket: Array, origin: Vector3, size: Vector3, blue: bool, dark: bool = false) -> void:
	var which := 1 if blue else 0
	if dark:
		which = 2
	bucket.append({"o": origin, "s": size, "m": which})


func _put_seam(origin: Vector3, width: float) -> void:
	_seams.append({"o": origin, "s": Vector3(width, 0.045, 0.03)})


func _flush() -> void:
	var low := _Post.quality() == "low"
	if not low:
		_emit(_detail, false)
		_emit_seams()
	_emit(_far, true)


func _emit(rows: Array, far: bool) -> void:
	var groups: Array = [[], [], []]
	for row in rows:
		var item: Dictionary = row
		groups[int(item["m"])].append(item)
	var mats: Array[ShaderMaterial] = [_white, _blue, _dark]
	for i in groups.size():
		var group: Array = groups[i]
		if group.is_empty():
			continue
		var instance := _multimesh(group, mats[i])
		if far:
			if _Post.quality() != "low":
				instance.visibility_range_begin = 32.0
				instance.visibility_range_begin_margin = 8.0
		else:
			instance.visibility_range_end = 46.0
			instance.visibility_range_end_margin = 8.0


func _emit_seams() -> void:
	if _seams.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.9, 0.78)
	mat.emission_enabled = true
	mat.emission = Color(0.35, 1.1, 0.9)
	mat.emission_energy_multiplier = 2.4
	var instance := _multimesh(_seams, mat)
	instance.visibility_range_end = 40.0
	instance.visibility_range_end_margin = 6.0


func _multimesh(rows: Array, mat: Material) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = box
	multi.instance_count = rows.size()
	for i in rows.size():
		var item: Dictionary = rows[i]
		var size: Vector3 = item["s"]
		var origin: Vector3 = item["o"]
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(size), origin))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


func _lay_clouds() -> void:
	var tex := _cloud_texture()
	var layers := 1 if _Post.quality() == "low" else 3
	for i in layers:
		var deck := MeshInstance3D.new()
		deck.name = "Clouds%d" % i
		var quad := QuadMesh.new()
		quad.size = Vector2(20.0, 16.0)
		deck.mesh = quad
		deck.position = Vector3(0.0, 0.15 + float(i) * 0.7, 4.0)
		deck.rotation.x = -PI * 0.5
		var mat := ShaderMaterial.new()
		mat.shader = _CLOUD
		mat.set_shader_parameter("cloud_tex", tex)
		mat.set_shader_parameter("cloud_alpha", 0.72 - float(i) * 0.16)
		deck.material_override = mat
		deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(deck)


func _face_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.93, 0.91, 0.88))
	var seam := Color(0.55, 0.56, 0.58)
	var fine := Color(0.72, 0.73, 0.74)
	for i in 64:
		if i % 16 == 0:
			for x in 64:
				image.set_pixel(x, i, seam)
				image.set_pixel(i, x, seam)
		elif i % 4 == 0:
			for x in range(0, 64, 2):
				image.set_pixel(x, i, fine)
	# Machinery band and vents.
	for y in range(40, 48):
		for x in 64:
			image.set_pixel(x, y, Color(0.34, 0.36, 0.38))
	for x in range(4, 60, 10):
		for y in range(41, 47):
			image.set_pixel(x, y, Color(0.15, 0.16, 0.18))
	# Vertical window strip.
	var lit := Color(1.0, 0.78, 0.34)
	for y in range(8, 38, 3):
		image.set_pixel(30, y, lit)
		image.set_pixel(31, y, lit)
		image.set_pixel(8, y, lit)
	var ink := Color(0.72, 0.09, 0.08)
	_stamp(image, 44, 6, "04", ink)
	return ImageTexture.create_from_image(image)


func _stamp(image: Image, x: int, y: int, text: String, color: Color) -> void:
	var glyphs := {
		"0": "11110100011000110001100011000111110",
		"4": "10001100011000111111000010000100001",
	}
	var cursor := x
	for i in text.length():
		var rows: String = glyphs[text.substr(i, 1)]
		for row in 7:
			for col in 5:
				if rows.substr(row * 5 + col, 1) != "1":
					continue
				var px := cursor + col
				var py := y + row
				if px < 64 and py < 64:
					image.set_pixel(px, py, color)
		cursor += 6


func _cloud_texture() -> ImageTexture:
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var u := float(x) / 64.0
			var v := float(y) / 64.0
			var n := 0.55 + sin(u * TAU * 2.0) * sin(v * TAU * 1.5) * 0.25 + sin((u + v) * TAU * 3.0) * 0.12
			image.set_pixel(x, y, Color(n, n, n))
	return ImageTexture.create_from_image(image)
