extends RefCounted

## Snaps a kit together from a seed. The same seed always builds the same ship.
## Output is one mesh with a surface per material, plus a couple of live lights
## on a derelict so they can flicker without splitting the hull.

const _Parts := preload("res://scripts/ships/kit_parts.gd")
const _Mesh := preload("res://scripts/ships/kit_mesh.gd")
const _Dress := preload("res://scripts/flight/jumpship_dress.gd")
const _Post := preload("res://scripts/data/post_profile.gd")

const ARCHETYPES := ["scout", "hauler", "interceptor", "derelict"]
const ACCENTS := [
	Color(0.42, 0.62, 0.95),
	Color(0.93, 0.46, 0.2),
	Color(0.28, 0.3, 0.34),
]
const HULL := Color(0.785, 0.77, 0.745)
const RUST := Color(0.45, 0.24, 0.14)
const RUST_HULL := Color(0.2, 0.14, 0.12)


static func archetype_for(seed_value: int) -> String:
	var index := absi(seed_value) % ARCHETYPES.size()
	return ARCHETYPES[index]


static func build(seed_value: int, archetype: String = "") -> Node3D:
	var resolved := archetype if archetype != "" else archetype_for(seed_value)
	var damaged := resolved == "derelict"
	var base := resolved
	var rng := _Rng.new(seed_value)
	if damaged:
		base = ["scout", "hauler", "interceptor"][rng.nexti() % 3]
	var size := "m"
	if base == "scout":
		size = "s"
	elif base == "hauler":
		size = "l"
	var accent: Color = ACCENTS[rng.nexti() % ACCENTS.size()]
	var core_id := "core_spine"
	if size == "s":
		core_id = "core_dart"
	elif size == "l":
		core_id = "core_barge"
	var assembly := Node3D.new()
	assembly.name = "Assembly"
	var core := _Parts.build(core_id, size)
	assembly.add_child(core)
	_attach(assembly, core, "socket_front", "nose", size, rng, damaged)
	_attach(assembly, core, "socket_rear", "engine", size, rng, damaged)
	_attach_wing(assembly, core, size, rng, damaged)
	if not damaged or rng.nextf() > 0.35:
		_attach(assembly, core, "socket_top", "greeble", "g", rng, false)
	if not damaged or rng.nextf() > 0.55:
		_attach(assembly, core, "socket_top_b", "greeble", "g", rng, false)
	if not damaged or rng.nextf() > 0.4:
		_attach(assembly, core, "socket_side", "greeble", "g", rng, false)
	var ship := _merge(assembly, accent, damaged, seed_value)
	assembly.queue_free()
	ship.set_meta("seed", seed_value)
	ship.set_meta("archetype", resolved)
	ship.name = "KitShip"
	return ship


static func _attach(assembly: Node3D, core: Node3D, socket_name: String, category: String, size: String, rng, damaged: bool) -> void:
	var target := core.get_node_or_null(socket_name)
	if target == null:
		return
	if damaged and category == "greeble" and rng.nextf() < 0.5:
		return
	if damaged and category == "engine" and rng.nextf() < 0.22:
		return
	var part_id := _pick(category, size, rng)
	if part_id == "":
		return
	var part := _Parts.build(part_id, size)
	assembly.add_child(part)
	var plug := part.get_node_or_null(_plug_name(category))
	if plug == null:
		part.queue_free()
		return
	_snap(part, plug, target, assembly)


static func _attach_wing(assembly: Node3D, core: Node3D, size: String, rng, damaged: bool) -> void:
	var left := core.get_node_or_null("socket_wing_L")
	if left == null:
		return
	if damaged and rng.nextf() < 0.38:
		return
	var part_id := _pick("wing", size, rng)
	if part_id == "":
		return
	var wing := _Parts.build(part_id, size)
	assembly.add_child(wing)
	var plug := wing.get_node_or_null("socket_root")
	if plug == null:
		wing.queue_free()
		return
	_snap(wing, plug, left, assembly)
	if damaged and rng.nextf() < 0.45:
		return
	var mirror := wing.duplicate()
	assembly.add_child(mirror)
	# Reflect the placed left wing across the ship's centerline.
	var flip := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 1.0, 0.0), Vector3(0.0, 0.0, 1.0))
	mirror.transform = Transform3D(flip * wing.transform.basis, flip * wing.transform.origin)


static func _pick(category: String, size: String, rng) -> String:
	var found: Array[String] = []
	for entry in _Parts.catalog():
		var record: Dictionary = entry
		if str(record.category) != category:
			continue
		var sizes: Array = record.sizes
		if sizes.has(size):
			found.append(str(record.id))
	if found.is_empty():
		return ""
	return found[rng.nexti() % found.size()]


static func _plug_name(category: String) -> String:
	match category:
		"nose":
			return "socket_rear"
		"engine":
			return "socket_mount"
		_:
			return "socket_root"


static func _snap(part: Node3D, plug: Node3D, target: Node3D, assembly: Node) -> void:
	# Stay in parent space. The assembly is not in the scene tree yet, so global
	# transforms would come back empty.
	var target_xf := _relative(target, assembly)
	var opposed := Transform3D(target_xf.basis * Basis(Vector3.UP, PI), target_xf.origin)
	part.transform = opposed * plug.transform.inverse()


static func _relative(node: Node, ancestor: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


static func _merge(assembly: Node3D, accent: Color, damaged: bool, seed_value: int) -> Node3D:
	var buckets := {
		"hull": _Mesh.new(),
		"accent": _Mesh.new(),
		"line": _Mesh.new(),
		"glass": _Mesh.new(),
		"glow": _Mesh.new(),
	}
	_collect(assembly, Transform3D.IDENTITY, buckets)
	var root := Node3D.new()
	var mesh := ArrayMesh.new()
	var surface := 0
	var hull_color := RUST_HULL if damaged else HULL
	var hull_rough := 0.86 if damaged else 0.34
	var hull_metal := 0.22 if damaged else 0.05
	for bucket_name in ["hull", "accent", "line", "glass", "glow"]:
		var kit = buckets[bucket_name]
		if kit.vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = kit.vertices
		arrays[Mesh.ARRAY_NORMAL] = kit.normals
		arrays[Mesh.ARRAY_TEX_UV] = kit.uvs
		arrays[Mesh.ARRAY_INDEX] = kit.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, _material(bucket_name, accent, hull_color, hull_rough, hull_metal, damaged, seed_value))
		surface += 1
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = mesh
	hull.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _Post.detailed() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hull)
	root.set_meta("tri_count", mesh.get_faces().size())
	if damaged:
		_add_flicker(root, seed_value)
	var scale := 0.5
	if damaged:
		scale = 0.55
	root.scale = Vector3.ONE * scale
	return root


static func _collect(node: Node, parent_xf: Transform3D, buckets: Dictionary) -> void:
	var local := Transform3D.IDENTITY
	if node is Node3D:
		local = (node as Node3D).transform
	var xf: Transform3D = parent_xf * local
	if node is MeshInstance3D and node.has_meta("bucket"):
		var bucket_name := str(node.get_meta("bucket"))
		if buckets.has(bucket_name) and node.mesh != null:
			var mesh := node.mesh as ArrayMesh
			if mesh and mesh.get_surface_count() > 0:
				var arrays: Array = mesh.surface_get_arrays(0)
				var kit = buckets[bucket_name]
				_append_arrays(kit, arrays, xf)
	for child in node.get_children():
		_collect(child, xf, buckets)


static func _append_arrays(kit, arrays: Array, xf: Transform3D) -> void:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var base: int = kit.vertices.size()
	var flip := xf.basis.determinant() < 0.0
	for i in verts.size():
		kit.vertices.append(xf * verts[i])
		var normal := Vector3.UP
		if i < norms.size():
			normal = (xf.basis * norms[i]).normalized()
		if flip:
			normal = -normal
		kit.normals.append(normal)
		if i < uv.size():
			kit.uvs.append(uv[i])
		else:
			kit.uvs.append(Vector2.ZERO)
	if index.is_empty():
		return
	for i in range(0, index.size(), 3):
		if flip:
			kit.indices.append(base + index[i])
			kit.indices.append(base + index[i + 2])
			kit.indices.append(base + index[i + 1])
		else:
			kit.indices.append(base + index[i])
			kit.indices.append(base + index[i + 1])
			kit.indices.append(base + index[i + 2])


static func _material(bucket_name: String, accent: Color, hull_color: Color, rough: float, metal: float, damaged: bool, seed_value: int) -> Material:
	if bucket_name == "glow":
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.cull_mode = BaseMaterial3D.CULL_DISABLED
		glow.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		if damaged:
			glow.albedo_color = Color(1.4, 0.55, 0.22, 0.85)
		else:
			glow.albedo_color = Color(2.6, 3.4, 5.2, 0.9)
		return glow
	if bucket_name == "glass":
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.05, 0.07, 0.1, 1.0)
		glass.metallic = 0.72
		glass.roughness = 0.04
		if _Post.high_quality():
			glass.clearcoat_enabled = true
			glass.clearcoat = 1.0
			glass.clearcoat_roughness = 0.03
		return glass
	var color := hull_color
	var roughness := rough
	var metallic := metal
	if bucket_name == "accent":
		color = accent.darkened(0.35) if damaged else accent
		roughness = 0.4
		metallic = 0.18
	elif bucket_name == "line":
		color = RUST.darkened(0.2) if damaged else Color(0.16, 0.17, 0.19)
		roughness = 0.55
		metallic = 0.28
	elif damaged and bucket_name == "hull":
		color = hull_color.lerp(RUST, 0.72)
	var painted := _Dress.paint_material(color, roughness, metallic, _Post.detailed(), float(absi(seed_value) % 17) * 0.37)
	return painted


static func _add_flicker(root: Node3D, seed_value: int) -> void:
	var bulb := MeshInstance3D.new()
	bulb.name = "Flicker"
	var box := BoxMesh.new()
	box.size = Vector3(0.18, 0.1, 0.14)
	bulb.mesh = box
	bulb.position = Vector3(0.42, 0.22, 0.15)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.6, 0.45, 0.16, 1.0)
	bulb.material_override = material
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.set_meta("flicker_phase", float(absi(seed_value) % 100) * 0.07)
	root.add_child(bulb)


class _Rng:
	var state: int

	func _init(seed_value: int) -> void:
		state = seed_value & 0xFFFFFFFF
		if state == 0:
			state = 1

	func nexti() -> int:
		var x := state & 0xFFFFFFFF
		x = (x ^ ((x << 13) & 0xFFFFFFFF)) & 0xFFFFFFFF
		x = (x ^ (x >> 17)) & 0xFFFFFFFF
		x = (x ^ ((x << 5) & 0xFFFFFFFF)) & 0xFFFFFFFF
		state = x
		return x

	func nextf() -> float:
		return float(nexti() % 10000) / 10000.0
