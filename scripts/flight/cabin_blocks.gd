extends RefCounted

## Interior block library. Every module is a hard-edged box on a 0.5m grid.
## Each face gets its own 16x16 (nearest) so panel borders land on the block edge.
## Kinds: panel, vent, hazard, grate, ceiling, locker, crate, bunk, bezel.

const _SHADE := preload("res://assets/shaders/cabin_block.gdshader")
const _SHADOW := preload("res://assets/shaders/cabin_shadow.gdshader")

const CELL := 0.5

const METAL := Color("8a8e94")
const METAL_DK := Color("2e3238")
const METAL_MD := Color("5c6168")
const METAL_LT := Color("d5d8dc")
const RIVET := Color("eef1f4")
const HAZ := Color("b8923e")
const CRATE := Color("8a7352")
const CRATE_DK := Color("4a3d2e")
const BUNK := Color("5e6570")
const BUNK_DK := Color("3c424c")

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
	mat.set_shader_parameter("lamp", 0.16 if kind == "ceiling" else 0.0)
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
	cabin._glow("BayStrip", cabin._v(0.0, 1.22, 0.1), cabin._v(0.62, 0.035, 0.025), Color(0.45, 0.9, 1.05))


static func _retile_shell(cabin) -> void:
	_retile_named(cabin, "Floor", "bezel")
	var shade_cast: bool = cabin._high
	_retile_named(cabin, "WallL", "panel", shade_cast)
	_retile_named(cabin, "WallR", "panel", shade_cast)
	_retile_named(cabin, "WallRear", "panel", shade_cast)
	_retile_named(cabin, "CeilingRear", "ceiling")
	_retile_named(cabin, "CeilingL", "ceiling")
	_retile_named(cabin, "CeilingR", "ceiling")
	_retile_named(cabin, "Door", "locker")
	_retile_named(cabin, "Kick", "hazard")
	_retile_named(cabin, "DoorBar", "bezel")


static func _retile_named(cabin, node_name: String, kind: String, cast_shadow: bool = false) -> void:
	var node := cabin.get_node_or_null(NodePath(node_name)) as MeshInstance3D
	if node:
		retile(node, kind, cast_shadow)


static func _floor(cabin) -> void:
	var xs: Array[float] = [-0.75, -0.25, 0.25, 0.75]
	var zs: Array[float] = [-0.25, -0.75, -1.25, -1.75, -2.25]
	for xi in xs.size():
		for zi in zs.size():
			var kind := "grate"
			if zs[zi] > -0.4 and absf(xs[xi]) < 0.5:
				kind = "hazard"
			place(cabin, "Tile%d_%d" % [xi, zi], Vector3(xs[xi], -0.44, zs[zi]), Vector3(0.5, 0.08, 0.5), kind)


static func _walls(cabin, detailed: bool) -> void:
	var zs: Array[float] = [-0.25, -0.75, -1.25, -1.75]
	var ys: Array[float] = [-0.15, 0.35, 0.85, 1.25]
	var sides: Array[float] = [-1.0, 1.0]
	for si in sides.size():
		var sign: float = sides[si]
		for zi in zs.size():
			for yi in ys.size():
				var y: float = ys[yi]
				var z: float = zs[zi]
				if _blocked(sign, y, z):
					continue
				var proud := (zi + yi) % 2 == 0
				if not proud and not detailed:
					continue
				var depth := 0.18 if proud else 0.06
				var kind := "panel"
				if not proud:
					kind = "vent"
				elif yi == 0 and zi % 2 == 0:
					kind = "hazard"
				var center_x := sign * (0.99 - depth * 0.5)
				place(cabin, "Wall%d_%d_%d" % [si, zi, yi], Vector3(center_x, y, z), Vector3(depth, 0.5, 0.5), kind, cabin._high)


static func _blocked(sign: float, y: float, z: float) -> bool:
	if z > -0.55 and y < 0.7:
		return true
	if sign > 0.0 and z < -0.35 and z > -0.95 and y < 0.75:
		return true
	if sign > 0.0 and z < -0.85 and z > -1.95 and y < 0.2:
		return true
	if sign < 0.0 and z < -0.85 and z > -1.75 and y < 1.35:
		return true
	return false


static func _ceiling(cabin, detailed: bool) -> void:
	if not detailed:
		return
	var cells: Array[Vector3] = [
		Vector3(-0.75, 1.48, -0.25),
		Vector3(0.25, 1.48, -0.25),
		Vector3(-0.25, 1.48, -0.75),
		Vector3(0.75, 1.48, -0.75),
		Vector3(-0.75, 1.48, -1.25),
		Vector3(0.75, 1.48, -1.25),
		Vector3(-0.75, 1.48, -1.75),
		Vector3(0.75, 1.48, -1.75),
		Vector3(-0.75, 1.48, -2.25),
		Vector3(0.75, 1.48, -2.25),
	]
	for i in cells.size():
		var at: Vector3 = cells[i]
		place(cabin, "CeilTile%d" % i, at, Vector3(0.5, 0.08, 0.5), "ceiling")


static func _furniture(cabin) -> void:
	# Lockers flank the bay door. Two 0.5m bays stacked read as one column.
	var shade_cast: bool = cabin._high
	place(cabin, "LockerL", Vector3(-0.72, 0.1, -0.15), Vector3(0.5, 1.0, 0.5), "locker", shade_cast)
	place(cabin, "LockerR", Vector3(0.72, 0.1, -0.15), Vector3(0.5, 1.0, 0.5), "locker", shade_cast)
	contact(cabin, Vector3(-0.72, 0.0, -0.15), Vector2(0.72, 0.72))
	contact(cabin, Vector3(0.72, 0.0, -0.15), Vector2(0.72, 0.72))
	# Tucked on the left wall, aft of the aisle camera, so the forward view stays open.
	place(cabin, "CrateL", Vector3(-0.8, -0.28, -0.42), Vector3(0.3, 0.24, 0.3), "crate", shade_cast)
	contact(cabin, Vector3(-0.8, 0.0, -0.42), Vector2(0.28, 0.28))
	place(cabin, "CrateA", Vector3(0.72, -0.15, -0.62), Vector3(0.5, 0.5, 0.5), "crate", shade_cast)
	place(cabin, "CrateB", Vector3(0.72, 0.35, -0.62), Vector3(0.5, 0.5, 0.5), "crate", shade_cast)
	contact(cabin, Vector3(0.72, 0.0, -0.62), Vector2(0.78, 0.78))
	place(cabin, "BunkBase", Vector3(0.72, -0.32, -1.42), Vector3(0.5, 0.16, 1.0), "bezel", shade_cast)
	place(cabin, "BunkPad", Vector3(0.72, -0.16, -1.42), Vector3(0.48, 0.14, 0.96), "bunk", shade_cast)
	place(cabin, "BunkPillow", Vector3(0.72, -0.06, -1.84), Vector3(0.42, 0.1, 0.24), "bunk", shade_cast)
	contact(cabin, Vector3(0.72, 0.0, -1.42), Vector2(0.72, 1.25))
	# Wall rack on the left, inboard of the proud panels.
	place(cabin, "RackBack", Vector3(-0.72, 0.78, -1.3), Vector3(0.06, 0.9, 0.7), "panel")
	place(cabin, "RackLow", Vector3(-0.64, 0.48, -1.3), Vector3(0.14, 0.08, 0.66), "panel")
	place(cabin, "RackHigh", Vector3(-0.64, 1.12, -1.3), Vector3(0.14, 0.08, 0.66), "panel")
	place(cabin, "RackCrate", Vector3(0.55, -0.26, -0.48), Vector3(0.26, 0.26, 0.26), "crate")
	place(cabin, "ConduitL", Vector3(-0.55, 1.28, -1.15), Vector3(0.08, 0.08, 1.7), "bezel")
	place(cabin, "ConduitR", Vector3(0.55, 1.28, -1.05), Vector3(0.08, 0.08, 1.5), "bezel")
	place(cabin, "ConduitDrop", Vector3(-0.55, 1.05, -0.45), Vector3(0.08, 0.4, 0.08), "bezel")


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
		return 0.62
	if level == 2:
		return 0.42
	return 0.28


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
			var gltf_z := ao_center.z + point.z / _scale
			var nose := clampf((-gltf_z + 0.15) / 2.7, 0.0, 1.0) if use_ao else 0.5
			colors.append(Color(ao, nose, 1.0, 1.0))
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
	_fill(image, METAL)
	_rect(image, 0, 0, 16, 1, METAL_DK)
	_rect(image, 0, 15, 16, 1, METAL_DK)
	_rect(image, 0, 0, 1, 16, METAL_DK)
	_rect(image, 15, 0, 1, 16, METAL_DK)
	_rect(image, 7, 1, 1, 14, METAL_MD)
	_px(image, 2, 2, RIVET)
	_px(image, 13, 2, RIVET)
	_px(image, 2, 13, RIVET)
	_px(image, 13, 13, RIVET)


static func _paint_grate(image: Image) -> void:
	_fill(image, METAL_DK)
	_rect(image, 0, 0, 16, 2, METAL_MD)
	_rect(image, 0, 14, 16, 2, METAL_MD)
	_rect(image, 0, 0, 2, 16, METAL_MD)
	_rect(image, 14, 0, 2, 16, METAL_MD)
	for i in [4, 5, 10, 11]:
		_rect(image, 2, i, 12, 1, METAL_LT)
		_rect(image, i, 2, 1, 12, METAL)


static func _paint_hazard(image: Image) -> void:
	for y in 16:
		for x in 16:
			var stripe := int((x + y) / 4) % 2 == 0
			_px(image, x, y, HAZ if stripe else METAL_DK)
	_rect(image, 0, 0, 16, 1, METAL_DK)
	_rect(image, 0, 15, 16, 1, METAL_DK)
	_rect(image, 0, 0, 1, 16, METAL_DK)
	_rect(image, 15, 0, 1, 16, METAL_DK)


static func _paint_vent(image: Image) -> void:
	_fill(image, METAL)
	_rect(image, 0, 0, 16, 1, METAL_DK)
	_rect(image, 0, 15, 16, 1, METAL_DK)
	_rect(image, 0, 0, 1, 16, METAL_DK)
	_rect(image, 15, 0, 1, 16, METAL_DK)
	for y in [3, 6, 9, 12]:
		_rect(image, 2, y, 12, 2, METAL_DK)


static func _paint_locker(image: Image) -> void:
	_paint_panel(image)
	_rect(image, 3, 2, 1, 12, METAL_DK)
	_rect(image, 12, 6, 2, 4, METAL_LT)
	_px(image, 12, 7, Color("c4a15a"))


static func _paint_crate(image: Image) -> void:
	_fill(image, CRATE)
	_rect(image, 0, 0, 16, 2, CRATE_DK)
	_rect(image, 0, 14, 16, 2, CRATE_DK)
	_rect(image, 0, 0, 2, 16, CRATE_DK)
	_rect(image, 14, 0, 2, 16, CRATE_DK)
	for i in 12:
		_px(image, 2 + i, 2 + i, CRATE_DK)
		_px(image, 13 - i, 2 + i, CRATE_DK)


static func _paint_ceiling(image: Image) -> void:
	_paint_panel(image)
	_rect(image, 6, 6, 4, 4, Color("f2efe4"))
	_rect(image, 7, 7, 2, 2, Color("fff8e8"))


static func _paint_bezel(image: Image) -> void:
	_fill(image, Color("1a1d22"))
	_rect(image, 0, 0, 16, 2, Color("3a3e46"))
	_rect(image, 0, 14, 16, 2, Color("0c0e11"))
	_px(image, 2, 3, Color("6a6e76"))
	_px(image, 13, 3, Color("6a6e76"))


static func _paint_bunk(image: Image) -> void:
	_fill(image, BUNK)
	_rect(image, 0, 0, 16, 1, BUNK_DK)
	_rect(image, 0, 15, 16, 1, BUNK_DK)
	_rect(image, 0, 0, 1, 16, BUNK_DK)
	_rect(image, 15, 0, 1, 16, BUNK_DK)
	_rect(image, 1, 7, 14, 2, BUNK_DK)
	_rect(image, 1, 8, 14, 1, Color("7d8794"))
