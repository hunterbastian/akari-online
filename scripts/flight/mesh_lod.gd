extends RefCounted

## Far copy of a hull mesh with fewer triangles, crossfaded so it does not pop.
## Small parts (greeble, stencil, spine light) are hidden past a set distance.

const _Ranges := preload("res://scripts/data/detail_ranges.gd")

const _CULL := ["Greebles", "HullStencil", "SpineLight"]


static func apply(root: Node) -> void:
	if root == null or not _Ranges.enabled():
		return
	var found: Array[MeshInstance3D] = []
	_collect(root, found)
	var phone := _Ranges.mobile()
	var detail := _Ranges.ship_detail(phone)
	var band := _Ranges.SHIP_FADE
	var greeble := _Ranges.greeble_end(phone)
	for mesh in found:
		if _cull_name(mesh.name):
			_Ranges.cull_after(mesh, greeble, _Ranges.GREEBLE_FADE)
		elif mesh.name.ends_with("Far"):
			pass
		elif _triangles(mesh.mesh) >= 120:
			_split(mesh, detail, band)


static func decimate(mesh: Mesh, stride: int) -> ArrayMesh:
	var out := ArrayMesh.new()
	var step := maxi(stride, 2)
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			index = PackedInt32Array()
			index.resize(verts.size())
			for i in verts.size():
				index[i] = i
		var next := PackedInt32Array()
		var i := 0
		var jump := step * 3
		while i + 2 < index.size():
			next.append(index[i])
			next.append(index[i + 1])
			next.append(index[i + 2])
			i += jump
		if next.size() < 3:
			next = index
		arrays[Mesh.ARRAY_INDEX] = next
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(surface), arrays)
	return out


static func _split(mesh: MeshInstance3D, detail: float, band: float) -> void:
	if mesh.mesh == null or mesh.get_parent() == null:
		return
	var far := MeshInstance3D.new()
	far.name = mesh.name + "Far"
	far.mesh = decimate(mesh.mesh, 5)
	far.transform = mesh.transform
	far.material_override = mesh.material_override
	far.cast_shadow = mesh.cast_shadow
	far.layers = mesh.layers
	mesh.get_parent().add_child(far)
	_Ranges.show_near(mesh, detail, band)
	_Ranges.show_far(far, detail, band)


static func _cull_name(node_name: String) -> bool:
	for entry in _CULL:
		if node_name == entry:
			return true
	return false


static func _triangles(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if index.is_empty():
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total += int(verts.size() / 3.0)
		else:
			total += int(index.size() / 3.0)
	return total


static func _collect(node: Node, found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		_collect(child, found)
