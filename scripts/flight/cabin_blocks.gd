extends RefCounted

## Interior block library. Every module is a hard-edged box on a 0.5m grid.
## Each face gets its own 16x16 (nearest) so panel borders land on the block edge.
## Kinds: panel, vent, hazard, grate, ceiling, locker, crate, bunk, bezel.

const _SHADE := preload("res://assets/shaders/cabin_block.gdshader")
const _SHADOW := preload("res://assets/shaders/cabin_shadow.gdshader")

const CELL := 0.5

const BONE := Color("d9d3c4")
const BONE_DK := Color("6e685c")
const BONE_MD := Color("b3ab9c")
const RIVET := Color("f4f0e6")
const WEAR := Color("8a8172")
const FLOOR := Color("1c1a18")
const FLOOR_MD := Color("3a3632")
const ACCENT := Color("8d6844")
const CRATE := Color("8a6846")
const CRATE_DK := Color("3e3124")
const BUNK := Color("6e655c")
const BUNK_DK := Color("3f3a34")
const CLOTH := Color("8d7356")

static var _scale := 1.0
static var _tex: Dictionary = {}
static var _mats: Dictionary = {}
static var _boxes: Array = []
static var _records: Array = []
static var _shadow_mat: ShaderMaterial


static func prepare(scale: float) -> void:
	_scale = scale
	_boxes.clear()
	_records.clear()


static func texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var image := Image.create(16, 16, false, Image.FORMAT_RGB8)
	match kind:
		"grate":
			_paint_grate(image)
		"hazard":
			_paint_hazard(image)
		"vent":
			_paint_vent(image)
		"locker":
			_paint_locker(image)
		"crate":
			_paint_crate(image)
		"ceiling":
			_paint_ceiling(image)
		"bezel":
			_paint_bezel(image)
		"bunk":
			_paint_bunk(image)
		"lamp":
			_paint_lamp(image)
		"steel":
			_paint_steel(image)
		"rollup":
			_paint_rollup(image)
		"concrete":
			_paint_concrete(image)
		_:
			_paint_panel(image)
	var image_texture := ImageTexture.create_from_image(image)
	_tex[kind] = image_texture
	return image_texture


static func material(kind: String) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var mat := ShaderMaterial.new()
	mat.shader = _SHADE
	mat.set_shader_parameter("albedo_tex", texture(kind))
	var glow := 0.0
	if kind == "ceiling":
		glow = 0.1
	elif kind == "lamp":
		glow = 0.75
	mat.set_shader_parameter("lamp", glow)
	_mats[kind] = mat
	return mat


static func place(cabin, node_name: String, center: Vector3, size: Vector3, kind: String, cast_shadow: bool = false) -> MeshInstance3D:
	var box_id := _stamp(center, size)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _unit_box(cabin._v(size.x, size.y, size.z), false, center, size, box_id)
	mesh_instance.position = cabin._v(center.x, center.y, center.z)
	mesh_instance.material_override = material(kind)
	mesh_instance.layers = cabin.INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cabin.add_child(mesh_instance)
	_records.append({
		"node": mesh_instance,
		"size": cabin._v(size.x, size.y, size.z),
		"center": center,
		"extent": size,
		"stretch": false,
		"box": box_id,
	})
	return mesh_instance


static func retile(node: MeshInstance3D, kind: String, cast_shadow: bool = false) -> void:
	var box := node.mesh as BoxMesh
	if box == null:
		return
	var extent := box.size / _scale
	var center := node.position / _scale
	var box_id := _stamp(center, extent)
	node.mesh = _unit_box(box.size, false, center, extent, box_id)
	node.material_override = material(kind)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_records.append({
		"node": node,
		"size": box.size,
		"center": center,
		"extent": extent,
		"stretch": false,
		"box": box_id,
	})


static func bake() -> void:
	for rec in _records:
		var record: Dictionary = rec
		var node := record["node"] as MeshInstance3D
		if node == null:
			continue
		var local_size: Vector3 = record["size"]
		var center: Vector3 = record["center"]
		var extent: Vector3 = record["extent"]
		node.mesh = _unit_box(local_size, bool(record["stretch"]), center, extent, int(record["box"]))


static func contact(cabin, center: Vector3, footprint: Vector2) -> void:
	if _shadow_mat == null:
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = _SHADOW
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Contact"
	var quad := QuadMesh.new()
	quad.size = Vector2(footprint.x, footprint.y) * cabin._scale
	mesh_instance.mesh = quad
	mesh_instance.position = cabin._v(center.x, -0.388, center.z)
	mesh_instance.rotation.x = -PI * 0.5
	mesh_instance.material_override = _shadow_mat
	mesh_instance.layers = cabin.INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	cabin.add_child(mesh_instance)


static func monitor_frame(parent: Node3D, size: Vector2, border: float, depth: float, layer: int) -> void:
	# Shallow chin and side bars. The glass sits in front of them, so nothing hoods the phosphor.
	var mat := material("bezel")
	_local_box(parent, "Back", Vector3(size.x + border * 2.0, size.y + border * 2.2, depth * 0.45), Vector3(0.0, -border * 0.1, -depth * 0.35), mat, layer, true)
	_local_box(parent, "Top", Vector3(size.x + border * 2.0, border, depth), Vector3(0.0, size.y * 0.5 + border * 0.5, depth * 0.2), mat, layer, true)
	_local_box(parent, "Bottom", Vector3(size.x + border * 2.0, border * 1.7, depth), Vector3(0.0, -size.y * 0.5 - border * 0.85, depth * 0.2), mat, layer, true)
	_local_box(parent, "Left", Vector3(border, size.y, depth), Vector3(-size.x * 0.5 - border * 0.5, 0.0, depth * 0.2), mat, layer, true)
	_local_box(parent, "Right", Vector3(border, size.y, depth), Vector3(size.x * 0.5 + border * 0.5, 0.0, depth * 0.2), mat, layer, true)


static func dress(cabin) -> void:
	prepare(cabin._scale)
	_retile_shell(cabin)
	_floor(cabin)
	_walls(cabin, cabin._high)
	_ceiling(cabin, cabin._high)
	_furniture(cabin)
	bake()


static func _retile_shell(cabin) -> void:
	_retile_named(cabin, "Floor", "concrete")
	var shade_cast: bool = cabin._high
	_retile_named(cabin, "WallL", "concrete", shade_cast)
	_retile_named(cabin, "WallR", "concrete", shade_cast)
	_retile_named(cabin, "WallRear", "concrete", shade_cast)
	_retile_named(cabin, "CeilingRear", "concrete")
	_retile_named(cabin, "CeilingL", "concrete")
	_retile_named(cabin, "CeilingR", "concrete")
	_retile_named(cabin, "Door", "rollup")
	_retile_named(cabin, "Kick", "hazard")
	_retile_named(cabin, "DoorBar", "steel")


static func _retile_named(cabin, node_name: String, kind: String, cast_shadow: bool = false) -> void:
	var node := cabin.get_node_or_null(NodePath(node_name)) as MeshInstance3D
	if node:
		retile(node, kind, cast_shadow)


static func _floor(cabin) -> void:
	var xs: Array[float] = [-1.5, -1.0, -0.5, 0.0, 0.5, 1.0, 1.5]
	var zs: Array[float] = [0.25, -0.25, -0.75, -1.25, -1.75, -2.25, -2.75, -3.25]
	for xi in xs.size():
		for zi in zs.size():
			var kind := "grate"
			var x: float = xs[xi]
			var z: float = zs[zi]
			if z > 0.0:
				kind = "hazard"
			elif absf(x) == 0.5 and zi % 2 == 0:
				kind = "hazard"
			elif x < -1.2 and z < -0.1 and z > -1.7 and (zi + xi) % 3 == 0:
				kind = "hazard"
			place(cabin, "Tile%d_%d" % [xi, zi], Vector3(x, -0.44, z), Vector3(0.5, 0.08, 0.5), kind)


static func _walls(cabin, _detailed: bool) -> void:
	# A few high vents. The floor stays open; zones are not walled off.
	var zs: Array[float] = [-0.4, -1.5, -2.6, -3.4]
	var sides: Array[float] = [-1.0, 1.0]
	for si in sides.size():
		var sign: float = sides[si]
		for zi in zs.size():
			place(cabin, "Vent%d_%d" % [si, zi], Vector3(sign * 1.68, 2.15, zs[zi]), Vector3(0.08, 0.42, 0.7), "vent", cabin._high)


static func _ceiling(cabin, _detailed: bool) -> void:
	var zs: Array[float] = [0.35, -0.7, -1.75, -2.8, -3.55]
	for i in zs.size():
		var z: float = zs[i]
		place(cabin, "Truss%d" % i, Vector3(0.0, 2.48, z), Vector3(3.35, 0.08, 0.08), "steel")
		place(cabin, "TrussTop%d" % i, Vector3(0.0, 2.68, z), Vector3(3.35, 0.05, 0.05), "steel")
		place(cabin, "TrussPostL%d" % i, Vector3(-1.15, 2.58, z), Vector3(0.06, 0.22, 0.06), "steel")
		place(cabin, "TrussPostR%d" % i, Vector3(1.15, 2.58, z), Vector3(0.06, 0.22, 0.06), "steel")
	place(cabin, "PipeL", Vector3(-1.45, 2.32, -1.7), Vector3(0.08, 0.08, 4.4), "steel")
	place(cabin, "PipeR", Vector3(1.45, 2.32, -1.7), Vector3(0.08, 0.08, 4.4), "steel")
	place(cabin, "PipeC", Vector3(0.0, 2.62, -1.7), Vector3(0.07, 0.07, 4.2), "bezel")


static func _rack(cabin, prefix: String, at: Vector3, cast_shadow: bool) -> void:
	place(cabin, prefix + "PostA", at + Vector3(-0.28, 0.7, -0.28), Vector3(0.06, 2.3, 0.06), "steel", cast_shadow)
	place(cabin, prefix + "PostB", at + Vector3(0.28, 0.7, -0.28), Vector3(0.06, 2.3, 0.06), "steel", cast_shadow)
	place(cabin, prefix + "PostC", at + Vector3(-0.28, 0.7, 0.28), Vector3(0.06, 2.3, 0.06), "steel", cast_shadow)
	place(cabin, prefix + "PostD", at + Vector3(0.28, 0.7, 0.28), Vector3(0.06, 2.3, 0.06), "steel", cast_shadow)
	for shelf in [0.15, 0.85, 1.55]:
		place(cabin, "%sShelf%.0f" % [prefix, shelf * 10.0], at + Vector3(0.0, shelf, 0.0), Vector3(0.7, 0.05, 0.7), "steel", cast_shadow)


static func _furniture(cabin) -> void:
	# Open floor. Racks, the bunk, and the bench mark the zones. Nothing crosses the aisle.
	var shade_cast: bool = cabin._high
	_rack(cabin, "RackL", Vector3(-1.35, 0.0, -0.55), shade_cast)
	_rack(cabin, "RackR", Vector3(-1.35, 0.0, -1.3), shade_cast)
	# The named lockers are the faces you can open, on the aisle side of each rack.
	place(cabin, "LockerL", Vector3(-1.0, 0.85, -0.55), Vector3(0.05, 1.5, 0.08), "locker", shade_cast)
	place(cabin, "LockerR", Vector3(-1.0, 0.85, -1.3), Vector3(0.05, 1.5, 0.08), "locker", shade_cast)
	place(cabin, "CrateA", Vector3(-1.35, 0.38, -0.55), Vector3(0.42, 0.36, 0.42), "crate", shade_cast)
	place(cabin, "CrateB", Vector3(-1.35, 1.08, -0.55), Vector3(0.38, 0.32, 0.38), "crate", shade_cast)
	place(cabin, "CrateL", Vector3(-1.35, 0.38, -1.3), Vector3(0.4, 0.34, 0.4), "crate", shade_cast)
	place(cabin, "RackCrate", Vector3(-1.35, 1.08, -1.3), Vector3(0.32, 0.28, 0.32), "crate", shade_cast)
	place(cabin, "Pallet", Vector3(-1.15, -0.38, -1.85), Vector3(0.7, 0.08, 0.7), "crate")
	contact(cabin, Vector3(-1.35, 0.0, -0.55), Vector2(0.9, 0.9))
	contact(cabin, Vector3(-1.35, 0.0, -1.3), Vector2(0.9, 0.9))
	contact(cabin, Vector3(-1.15, 0.0, -1.85), Vector2(0.85, 0.85))
	# Workbench, still on the left, with room to walk around it.
	place(cabin, "BenchTop", Vector3(-1.28, 0.0, -2.25), Vector3(0.7, 0.08, 0.65), "panel", shade_cast)
	place(cabin, "BenchLeg", Vector3(-1.5, -0.26, -2.25), Vector3(0.1, 0.46, 0.5), "steel", shade_cast)
	place(cabin, "BenchShelf", Vector3(-1.45, 1.15, -2.25), Vector3(0.4, 0.05, 0.55), "steel")
	contact(cabin, Vector3(-1.28, 0.0, -2.25), Vector2(0.85, 0.8))
	# Bunk is a pallet bed on the right, not a walled nook.
	place(cabin, "BunkBase", Vector3(1.28, -0.32, -1.85), Vector3(0.7, 0.1, 1.15), "steel", shade_cast)
	place(cabin, "BunkPad", Vector3(1.28, -0.2, -1.85), Vector3(0.64, 0.12, 1.05), "bunk", shade_cast)
	place(cabin, "BunkPillow", Vector3(1.28, -0.1, -2.28), Vector3(0.5, 0.1, 0.28), "bunk", shade_cast)
	contact(cabin, Vector3(1.28, 0.0, -1.85), Vector2(0.9, 1.35))
	# Hanging industrial lamps. Short rods drop them off the trusses.
	var lamps: Array[Vector3] = [
		Vector3(0.0, 1.72, -0.15),
		Vector3(-0.55, 1.72, -0.9),
		Vector3(0.45, 1.72, -1.9),
		Vector3(0.0, 1.78, -3.05),
	]
	for i in lamps.size():
		var at: Vector3 = lamps[i]
		place(cabin, "HangRod%d" % i, Vector3(at.x, 2.25, at.z), Vector3(0.04, 0.9, 0.04), "steel")
		place(cabin, "HangLamp%d" % i, at, Vector3(0.28, 0.08, 0.16), "lamp")


static func _local_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material, layer: int, stretch: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = _unit_box(size, stretch, Vector3.ZERO, Vector3.ZERO)
	mesh_instance.position = pos
	mesh_instance.material_override = mat
	mesh_instance.layers = layer
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	parent.add_child(mesh_instance)


static func _stamp(center: Vector3, size: Vector3) -> int:
	_boxes.append({"c": center, "h": size * 0.5})
	return _boxes.size() - 1


static func _hits(point: Vector3, ignore: int) -> bool:
	for i in _boxes.size():
		if i == ignore:
			continue
		var box: Dictionary = _boxes[i]
		var center: Vector3 = box["c"]
		var half: Vector3 = box["h"]
		if absf(point.x - center.x) <= half.x and absf(point.y - center.y) <= half.y and absf(point.z - center.z) <= half.z:
			return true
	return false


static func _light_at(point: Vector3) -> Vector2:
	var warm := 0.0
	var lamps: Array[Vector3] = [
		Vector3(0.0, 1.72, -0.15),
		Vector3(-0.55, 1.72, -0.9),
		Vector3(0.45, 1.72, -1.9),
		Vector3(0.0, 1.78, -3.05),
	]
	var reach: Array[float] = [3.3, 3.1, 3.2, 3.0]
	for i in lamps.size():
		var fall := 1.0 - point.distance_to(lamps[i]) / reach[i]
		warm = maxf(warm, clampf(fall, 0.0, 1.0))
	var green := 0.0
	var screens: Array[Vector3] = [
		Vector3(-0.85, 0.9, -3.35),
		Vector3(0.85, 0.9, -3.35),
		Vector3(0.0, 0.45, -3.1),
		Vector3(0.0, 1.9, 0.55),
	]
	for screen in screens:
		var fall := 1.0 - point.distance_to(screen) / 0.62
		green = maxf(green, clampf(fall, 0.0, 1.0))
	return Vector2(warm, green)


static func _ao_level(gltf_pos: Vector3, normal: Vector3, ignore: int) -> float:
	# Three-neighbor test just outside the face: two edges and the corner.
	var origin := gltf_pos + normal * 0.06
	var axis_a := Vector3(1.0, 0.0, 0.0)
	var axis_b := Vector3(0.0, 0.0, 1.0)
	if absf(normal.y) > 0.5:
		axis_a = Vector3(1.0, 0.0, 0.0)
		axis_b = Vector3(0.0, 0.0, 1.0)
	elif absf(normal.x) > 0.5:
		axis_a = Vector3(0.0, 1.0, 0.0)
		axis_b = Vector3(0.0, 0.0, 1.0)
	else:
		axis_a = Vector3(1.0, 0.0, 0.0)
		axis_b = Vector3(0.0, 1.0, 0.0)
	var reach := 0.2
	var side_a := _hits(origin + axis_a * reach, ignore) or _hits(origin - axis_a * reach, ignore)
	var side_b := _hits(origin + axis_b * reach, ignore) or _hits(origin - axis_b * reach, ignore)
	var corner := false
	if not (side_a and side_b):
		corner = _hits(origin + axis_a * reach + axis_b * reach, ignore) or _hits(origin + axis_a * reach - axis_b * reach, ignore) or _hits(origin - axis_a * reach + axis_b * reach, ignore) or _hits(origin - axis_a * reach - axis_b * reach, ignore)
	var level := 0
	if side_a:
		level += 1
	if side_b:
		level += 1
	if side_a and side_b:
		level = 3
	elif corner:
		level += 1
	# Something close along the face normal: under a desk, bunk, or shelf.
	if _hits(gltf_pos + normal * 0.22, ignore) or _hits(gltf_pos + normal * 0.4, ignore):
		level += 1
	level = mini(level, 3)
	if level <= 0:
		return 1.0
	if level == 1:
		return 0.5
	if level == 2:
		return 0.32
	return 0.18


static func _unit_box(size: Vector3, stretch: bool, ao_center: Vector3 = Vector3.ZERO, ao_extent: Vector3 = Vector3.ZERO, ignore: int = -1) -> ArrayMesh:
	var use_ao := ao_extent.length_squared() > 0.0001
	var cell := maxf(CELL * _scale, 0.001)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	_face(verts, normals, uvs, colors, indices, size, Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), stretch, use_ao, ao_center, cell, ignore)
	_face(verts, normals, uvs, colors, indices, size, Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), stretch, use_ao, ao_center, cell, ignore)
	_face(verts, normals, uvs, colors, indices, size, Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), stretch, use_ao, ao_center, cell, ignore)
	_face(verts, normals, uvs, colors, indices, size, Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), stretch, use_ao, ao_center, cell, ignore)
	_face(verts, normals, uvs, colors, indices, size, Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), stretch, use_ao, ao_center, cell, ignore)
	_face(verts, normals, uvs, colors, indices, size, Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), stretch, use_ao, ao_center, cell, ignore)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _face(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array, size: Vector3, normal: Vector3, axis_u: Vector3, axis_v: Vector3, stretch: bool, use_ao: bool, ao_center: Vector3, cell: float, ignore: int) -> void:
	var half_n := absf(size.dot(normal)) * 0.5
	var half_u := absf(size.dot(axis_u)) * 0.5
	var half_v := absf(size.dot(axis_v)) * 0.5
	var step := cell * 0.5
	var steps_u := 1 if stretch else maxi(1, int(ceil(maxf(half_u * 2.0, 0.001) / step)))
	var steps_v := 1 if stretch else maxi(1, int(ceil(maxf(half_v * 2.0, 0.001) / step)))
	var grid: Array = []
	for iu in steps_u + 1:
		var row: Array = []
		var tu := lerpf(-half_u, half_u, float(iu) / float(steps_u))
		for iv in steps_v + 1:
			var tv := lerpf(-half_v, half_v, float(iv) / float(steps_v))
			var point := normal * half_n + axis_u * tu + axis_v * tv
			var ao := 1.0
			if use_ao:
				ao = _ao_level(ao_center + point / _scale, normal, ignore)
			var index := verts.size()
			verts.append(point)
			normals.append(normal)
			var u := (tu + half_u) / cell if not stretch else (tu + half_u) / maxf(half_u * 2.0, 0.001)
			var v := (half_v - tv) / cell if not stretch else (half_v - tv) / maxf(half_v * 2.0, 0.001)
			uvs.append(Vector2(u, v))
			var gltf_pos := ao_center + point / _scale
			var nose := clampf((-gltf_pos.z - 0.2) / 4.2, 0.0, 1.0) if use_ao else 0.35
			var light := _light_at(gltf_pos) if use_ao else Vector2(0.35, 0.0)
			colors.append(Color(ao, nose, light.x, light.y))
			row.append(index)
		grid.append(row)
	for iu in steps_u:
		for iv in steps_v:
			var a: int = grid[iu][iv]
			var b: int = grid[iu + 1][iv]
			var c: int = grid[iu + 1][iv + 1]
			var d: int = grid[iu][iv + 1]
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(a)
			indices.append(d)
			indices.append(c)


static func _fill(image: Image, color: Color) -> void:
	image.fill(color)


static func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x > 15 or y > 15:
		return
	image.set_pixel(x, y, color)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in h:
		for xx in w:
			_px(image, x + xx, y + yy, color)


static func _paint_panel(image: Image) -> void:
	_fill(image, BONE)
	_rect(image, 0, 0, 16, 1, BONE_DK)
	_rect(image, 0, 15, 16, 1, BONE_DK)
	_rect(image, 0, 0, 1, 16, BONE_DK)
	_rect(image, 15, 0, 1, 16, BONE_DK)
	_rect(image, 0, 8, 16, 1, BONE_MD)
	_px(image, 2, 2, RIVET)
	_px(image, 13, 2, RIVET)
	_px(image, 2, 13, RIVET)
	_px(image, 13, 13, RIVET)
	_px(image, 6, 4, WEAR)
	_px(image, 7, 11, WEAR)
	_px(image, 10, 5, BONE_MD)


static func _paint_grate(image: Image) -> void:
	_fill(image, FLOOR)
	_rect(image, 0, 0, 16, 2, FLOOR_MD)
	_rect(image, 0, 14, 16, 2, FLOOR_MD)
	_rect(image, 0, 0, 2, 16, FLOOR_MD)
	_rect(image, 14, 0, 2, 16, FLOOR_MD)
	for i in [4, 5, 10, 11]:
		_rect(image, 2, i, 12, 1, Color("5a534a"))
		_rect(image, i, 2, 1, 12, Color("2a2724"))
	_px(image, 6, 7, WEAR)
	_px(image, 9, 8, Color("121110"))


static func _paint_hazard(image: Image) -> void:
	for y in 16:
		for x in 16:
			var stripe := int((x + y) / 4) % 2 == 0
			_px(image, x, y, ACCENT if stripe else FLOOR)
	_rect(image, 0, 0, 16, 1, FLOOR)
	_rect(image, 0, 15, 16, 1, FLOOR)


static func _paint_vent(image: Image) -> void:
	_fill(image, Color("8c8578"))
	_rect(image, 0, 0, 16, 1, BONE_DK)
	_rect(image, 0, 15, 16, 1, BONE_DK)
	_rect(image, 0, 0, 1, 16, BONE_DK)
	_rect(image, 15, 0, 1, 16, BONE_DK)
	for y in [3, 6, 9, 12]:
		_rect(image, 2, y, 12, 2, Color("2c2926"))
	_px(image, 4, 1, RIVET)
	_px(image, 11, 14, RIVET)


static func _paint_locker(image: Image) -> void:
	_paint_panel(image)
	_rect(image, 2, 2, 1, 12, BONE_DK)
	_rect(image, 12, 6, 2, 4, ACCENT)
	_px(image, 12, 7, Color("c4a15a"))
	_px(image, 8, 12, WEAR)


static func _paint_crate(image: Image) -> void:
	_fill(image, CRATE)
	_rect(image, 0, 0, 16, 2, CRATE_DK)
	_rect(image, 0, 14, 16, 2, CRATE_DK)
	_rect(image, 0, 0, 2, 16, CRATE_DK)
	_rect(image, 14, 0, 2, 16, CRATE_DK)
	_rect(image, 0, 7, 16, 2, CRATE_DK)
	for i in 12:
		_px(image, 3 + i, 3, Color("a07a52"))
	_px(image, 5, 10, Color("6a4e32"))
	_px(image, 11, 11, Color("6a4e32"))


static func _paint_ceiling(image: Image) -> void:
	_paint_panel(image)
	_rect(image, 6, 6, 4, 4, Color("efe4cc"))
	_rect(image, 7, 7, 2, 2, Color("fff1d0"))


static func _paint_bezel(image: Image) -> void:
	_fill(image, Color("241f1c"))
	_rect(image, 0, 0, 16, 2, Color("4a433c"))
	_rect(image, 0, 14, 16, 2, Color("120f0d"))
	_px(image, 2, 3, Color("6e655c"))
	_px(image, 13, 3, Color("6e655c"))


static func _paint_bunk(image: Image) -> void:
	_fill(image, BUNK)
	_rect(image, 0, 0, 16, 1, BUNK_DK)
	_rect(image, 0, 15, 16, 1, BUNK_DK)
	_rect(image, 0, 0, 1, 16, BUNK_DK)
	_rect(image, 15, 0, 1, 16, BUNK_DK)
	_rect(image, 1, 6, 14, 3, CLOTH)
	_rect(image, 1, 8, 14, 1, Color("c4a574"))
	_px(image, 4, 12, WEAR)


static func _paint_steel(image: Image) -> void:
	_fill(image, Color("6d737c"))
	_rect(image, 0, 0, 16, 2, Color("9aa1ab"))
	_rect(image, 0, 14, 16, 2, Color("3e444c"))
	_px(image, 3, 4, Color("c5ccd4"))
	_px(image, 12, 4, Color("c5ccd4"))
	_px(image, 3, 11, Color("2c3138"))
	_px(image, 12, 11, Color("2c3138"))


static func _paint_rollup(image: Image) -> void:
	_fill(image, Color("8a9098"))
	for y in [0, 3, 6, 9, 12, 15]:
		_rect(image, 0, y, 16, 1, Color("3a4048"))
	_rect(image, 0, 0, 1, 16, Color("5c636c"))
	_rect(image, 15, 0, 1, 16, Color("5c636c"))
	_px(image, 8, 7, ACCENT)


static func _paint_concrete(image: Image) -> void:
	_fill(image, Color("8e8a84"))
	_rect(image, 0, 7, 16, 1, Color("6a6660"))
	_rect(image, 7, 0, 1, 16, Color("6a6660"))
	_px(image, 3, 3, Color("6e6a64"))
	_px(image, 12, 4, Color("a8a49c"))
	_px(image, 5, 11, Color("5e5a54"))
	_px(image, 11, 12, Color("b0aca4"))
	_px(image, 14, 9, Color("7a766f"))


static func _paint_lamp(image: Image) -> void:
	_fill(image, Color("3a342c"))
	_rect(image, 2, 2, 12, 12, Color("f0d7a4"))
	_rect(image, 5, 5, 6, 6, Color("fff4d4"))
	_rect(image, 0, 0, 16, 1, Color("2a241c"))
	_rect(image, 0, 15, 16, 1, Color("2a241c"))
