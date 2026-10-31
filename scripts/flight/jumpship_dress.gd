extends RefCounted

## Turns the imported jumpship into the white hull: open engine bells, no z-fighting pods,
## single-sided faces, clearcoat paint, and toned emissives.

const _PAINT := preload("res://assets/shaders/hull_paint.gdshader")
const _PAINT_LOW := preload("res://assets/shaders/hull_paint_low.gdshader")

const _DARK_PARTS := ["Engine_Bells", "Nacelle_Vents", "Greebles"]
const _SHELL_PARTS := ["Fuselage", "Canopy", "Canopy_Frame", "Dorsal_Spine", "Greebles"]

const _EXTERIOR_LAYER := 1 << 1


static func prepare(root: Node) -> void:
	var bells := root.find_child("Engine_Bells", true, false)
	if bells is MeshInstance3D:
		_strip_rear_caps(bells)
	var pods := root.find_child("Wing_Pods", true, false)
	if pods is MeshInstance3D:
		_drop_duplicate_tris(pods)


static func paint(root: Node, high_quality: bool) -> Array[ShaderMaterial]:
	var paints: Array[ShaderMaterial] = []
	_paint_node(root, high_quality, paints)
	return paints


static func shell_nodes(root: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for part_name in _SHELL_PARTS:
		var node := root.find_child(part_name, true, false)
		if node is GeometryInstance3D:
			found.append(node)
	return found


static func engine_anchors(root: Node) -> Array[Vector3]:
	var core := root.find_child("Thruster_Core", true, false) as MeshInstance3D
	if core == null or core.mesh == null:
		return []
	var sum_l := Vector3.ZERO
	var sum_r := Vector3.ZERO
	var count_l := 0
	var count_r := 0
	var max_l := -1000.0
	var max_r := -1000.0
	for surface in core.mesh.get_surface_count():
		var arrays: Array = core.mesh.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in verts:
			if absf(vertex.x) < 0.8:
				continue
			if vertex.x > 0.0:
				sum_r += vertex
				count_r += 1
				max_r = maxf(max_r, vertex.z)
			else:
				sum_l += vertex
				count_l += 1
				max_l = maxf(max_l, vertex.z)
	var anchors: Array[Vector3] = []
	if count_l > 0:
		var average := sum_l / float(count_l)
		anchors.append(Vector3(average.x, average.y, max_l + 0.28))
	if count_r > 0:
		var average := sum_r / float(count_r)
		anchors.append(Vector3(average.x, average.y, max_r + 0.28))
	return anchors


static func paint_material(color: Color, roughness: float, metallic: float, high_quality: bool, shift: float = 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _PAINT if high_quality else _PAINT_LOW
	material.set_shader_parameter("paint_color", color)
	material.set_shader_parameter("roughness_base", roughness)
	material.set_shader_parameter("metallic_base", metallic)
	material.set_shader_parameter("dither_strength", 0.016 if high_quality else 0.012)
	material.set_shader_parameter("panel_shift", shift)
	if high_quality:
		material.set_shader_parameter("clearcoat_amount", 0.84 if metallic < 0.2 else 0.55)
		material.set_shader_parameter("clearcoat_gloss", 0.065)
	return material


static func _paint_node(node: Node, high_quality: bool, paints: Array[ShaderMaterial]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.layers = _EXTERIOR_LAYER
		var mesh := mesh_instance.mesh
		if mesh:
			for surface in mesh.get_surface_count():
				var source := mesh.surface_get_material(surface)
				var material_name := _material_name(source)
				var painted := _material_for(mesh_instance.name, material_name, high_quality, paints)
				if painted:
					mesh.surface_set_material(surface, painted)
	for child in node.get_children():
		_paint_node(child, high_quality, paints)


static func _material_name(material: Material) -> String:
	if material == null:
		return ""
	var resource_name := material.resource_name
	if not resource_name.is_empty():
		return resource_name
	return material.name


static func _material_for(mesh_name: String, material_name: String, high_quality: bool, paints: Array[ShaderMaterial]) -> Material:
	if material_name == "Canopy_Glass" or mesh_name == "Canopy":
		return _canopy(high_quality)
	if material_name == "Nav_Light_Red" or mesh_name == "Mast_Lights":
		return _emission(Color(0.16, 0.015, 0.012), Color(0.62, 0.045, 0.03), 2.1 if high_quality else 1.4)
	if material_name == "Thruster_Glow" or mesh_name == "Thruster_Core" or mesh_name == "Pod_Glow":
		var hot := mesh_name != "Pod_Glow"
		var energy := (2.4 if hot else 1.8) if high_quality else (1.7 if hot else 1.3)
		return _emission(Color(0.05, 0.12, 0.16), Color(0.28, 0.72, 1.35), energy)
	if material_name == "Running_Light" or mesh_name == "Running_Lights":
		return _emission(Color(0.08, 0.16, 0.18), Color(0.32, 0.82, 1.05), 2.4 if high_quality else 1.6)
	var tint := _white_tint(mesh_name, material_name)
	var roughness := 0.34
	var metallic := 0.05
	if mesh_name in _DARK_PARTS:
		roughness = 0.5
		metallic = 0.28
	elif material_name == "Gunmetal" or material_name == "Panel_Grey":
		roughness = 0.42
		metallic = 0.16
	var shift := float(abs(mesh_name.hash()) % 17) * 0.37
	var painted := paint_material(tint, roughness, metallic, high_quality, shift)
	paints.append(painted)
	return painted


static func _white_tint(mesh_name: String, material_name: String) -> Color:
	if mesh_name in _DARK_PARTS:
		return Color(0.58, 0.59, 0.605)
	if mesh_name == "Hazard_Stripes" or material_name == "Hazard_Black":
		return Color(0.64, 0.65, 0.665)
	var base := Color(0.78, 0.768, 0.745)
	match mesh_name:
		"Fuselage":
			base = Color(0.785, 0.77, 0.742)
		"Wing":
			base = Color(0.752, 0.766, 0.786)
		"Wing_Flap":
			base = Color(0.746, 0.76, 0.778)
		"Wing_Stripe":
			base = Color(0.80, 0.772, 0.738)
		"Wing_Pods":
			base = Color(0.74, 0.756, 0.772)
		"Wingtip_Fin":
			base = Color(0.758, 0.77, 0.786)
		"Canard":
			base = Color(0.792, 0.776, 0.748)
		"Engine_Nacelle":
			base = Color(0.772, 0.762, 0.74)
		"Canopy_Frame":
			base = Color(0.70, 0.71, 0.724)
		"Dorsal_Spine":
			base = Color(0.796, 0.78, 0.75)
		"Tail_Fin":
			base = Color(0.748, 0.762, 0.782)
		"Chin_Cannons":
			base = Color(0.66, 0.668, 0.68)
		"Sensor_Array":
			base = Color(0.69, 0.698, 0.71)
	if material_name == "Hull_Yellow" or material_name == "Accent_Red":
		base = Color(minf(base.r + 0.018, 0.8), base.g, maxf(base.b - 0.012, 0.7))
	elif material_name == "Accent_Teal":
		base = Color(maxf(base.r - 0.012, 0.7), base.g, minf(base.b + 0.016, 0.8))
	elif material_name == "Gunmetal":
		base *= Color(0.9, 0.91, 0.93)
	elif material_name == "Panel_Grey":
		base *= Color(0.86, 0.87, 0.89)
	return base


static func _canopy(high_quality: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = "Canopy_Glass"
	material.albedo_color = Color(0.04, 0.06, 0.09)
	material.metallic = 0.72
	material.roughness = 0.03
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	if high_quality:
		material.clearcoat_enabled = true
		material.clearcoat = 1.0
		material.clearcoat_roughness = 0.02
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func _emission(albedo: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = 0.0
	material.roughness = 0.4
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func _strip_rear_caps(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null:
		return
	var rebuilt := ArrayMesh.new()
	var removed := 0
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty() or norms.is_empty():
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sanitize(arrays))
			_copy_surface_meta(source, rebuilt, surface)
			continue
		var kept := PackedInt32Array()
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			var normal_z := (norms[a].z + norms[b].z + norms[c].z) / 3.0
			var centroid_z := (verts[a].z + verts[b].z + verts[c].z) / 3.0
			# Rear discs of the bells. They sit aft of the glow and face the chase camera.
			if normal_z > 0.55 and centroid_z > 3.05:
				removed += 1
				continue
			kept.append(a)
			kept.append(b)
			kept.append(c)
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sanitize(arrays))
		_copy_surface_meta(source, rebuilt, surface)
	mesh_instance.mesh = rebuilt
	if removed > 0:
		print("JUMPSHIP opened engine bells, removed %d cap tris" % removed)


static func _drop_duplicate_tris(mesh_instance: MeshInstance3D) -> void:
	var source := mesh_instance.mesh as ArrayMesh
	if source == null:
		return
	var rebuilt := ArrayMesh.new()
	var seen := {}
	var removed := 0
	for surface in source.get_surface_count():
		var arrays: Array = source.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sanitize(arrays))
			_copy_surface_meta(source, rebuilt, surface)
			continue
		var kept := PackedInt32Array()
		for index in range(0, indices.size(), 3):
			var a := indices[index]
			var b := indices[index + 1]
			var c := indices[index + 2]
			var key := _tri_key(verts[a], verts[b], verts[c])
			if seen.has(key):
				removed += 1
				continue
			seen[key] = true
			kept.append(a)
			kept.append(b)
			kept.append(c)
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _sanitize(arrays))
		_copy_surface_meta(source, rebuilt, surface)
	mesh_instance.mesh = rebuilt
	if removed > 0:
		print("JUMPSHIP dropped %d duplicate wing-pod tris" % removed)


static func _tri_key(a: Vector3, b: Vector3, c: Vector3) -> String:
	var points: Array[Vector3] = [a, b, c]
	points.sort_custom(func(left: Vector3, right: Vector3) -> bool:
		if not is_equal_approx(left.x, right.x):
			return left.x < right.x
		if not is_equal_approx(left.y, right.y):
			return left.y < right.y
		return left.z < right.z
	)
	return "%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f" % [
		points[0].x, points[0].y, points[0].z,
		points[1].x, points[1].y, points[1].z,
		points[2].x, points[2].y, points[2].z,
	]


static func _sanitize(arrays: Array) -> Array:
	for channel in range(Mesh.ARRAY_MAX):
		var data: Variant = arrays[channel]
		if data == null:
			continue
		if _packed_size(data) == 0:
			arrays[channel] = null
	return arrays


static func _packed_size(data: Variant) -> int:
	if data is PackedVector3Array:
		return (data as PackedVector3Array).size()
	if data is PackedVector2Array:
		return (data as PackedVector2Array).size()
	if data is PackedFloat32Array:
		return (data as PackedFloat32Array).size()
	if data is PackedInt32Array:
		return (data as PackedInt32Array).size()
	if data is PackedColorArray:
		return (data as PackedColorArray).size()
	if data is PackedByteArray:
		return (data as PackedByteArray).size()
	return 1


static func _copy_surface_meta(source: ArrayMesh, rebuilt: ArrayMesh, surface: int) -> void:
	var index := rebuilt.get_surface_count() - 1
	rebuilt.surface_set_material(index, source.surface_get_material(surface))
	rebuilt.surface_set_name(index, source.surface_get_name(surface))
