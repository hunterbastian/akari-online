extends RefCounted

## Flat-shaded triangles for the ship kits. Faces are wound counter-clockwise
## when seen from the outside so the white paint shader catches the sun.

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()


func add_box(xf: Transform3D, size: Vector3) -> void:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z),
		xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, h.y, -h.z),
		xf * Vector3(-h.x, h.y, -h.z),
		xf * Vector3(-h.x, -h.y, h.z),
		xf * Vector3(h.x, -h.y, h.z),
		xf * Vector3(h.x, h.y, h.z),
		xf * Vector3(-h.x, h.y, h.z),
	]
	# +Z, -Z, +X, -X, +Y, -Y. Each quad is CCW from the outside.
	_quad([p[4], p[5], p[6], p[7]])
	_quad([p[1], p[0], p[3], p[2]])
	_quad([p[5], p[1], p[2], p[6]])
	_quad([p[0], p[4], p[7], p[3]])
	_quad([p[3], p[7], p[6], p[2]])
	_quad([p[0], p[1], p[5], p[4]])


func add_taper(xf: Transform3D, length: float, rear: Vector2, front: Vector2) -> void:
	# Local +Z is the rear, -Z the nose. rear and front are full width, height.
	var z0 := -length * 0.5
	var z1 := length * 0.5
	var fr := front * 0.5
	var rr := rear * 0.5
	var p := [
		xf * Vector3(-fr.x, -fr.y, z0),
		xf * Vector3(fr.x, -fr.y, z0),
		xf * Vector3(fr.x, fr.y, z0),
		xf * Vector3(-fr.x, fr.y, z0),
		xf * Vector3(-rr.x, -rr.y, z1),
		xf * Vector3(rr.x, -rr.y, z1),
		xf * Vector3(rr.x, rr.y, z1),
		xf * Vector3(-rr.x, rr.y, z1),
	]
	_quad([p[0], p[1], p[2], p[3]])
	_quad([p[5], p[4], p[7], p[6]])
	_quad([p[1], p[5], p[6], p[2]])
	_quad([p[4], p[0], p[3], p[7]])
	_quad([p[3], p[2], p[6], p[7]])
	_quad([p[4], p[5], p[1], p[0]])


func add_cylinder(xf: Transform3D, length: float, radius_rear: float, radius_front: float, sides: int) -> void:
	var n := maxi(sides, 6)
	var z0 := -length * 0.5
	var z1 := length * 0.5
	for i in n:
		var a0 := TAU * float(i) / float(n)
		var a1 := TAU * float(i + 1) / float(n)
		var p00 := xf * Vector3(cos(a0) * radius_front, sin(a0) * radius_front, z0)
		var p01 := xf * Vector3(cos(a1) * radius_front, sin(a1) * radius_front, z0)
		var p11 := xf * Vector3(cos(a1) * radius_rear, sin(a1) * radius_rear, z1)
		var p10 := xf * Vector3(cos(a0) * radius_rear, sin(a0) * radius_rear, z1)
		_quad([p00, p10, p11, p01])
	_cap(xf, z0, radius_front, n, true)
	_cap(xf, z1, radius_rear, n, false)


func add_disk(xf: Transform3D, radius: float, sides: int) -> void:
	_cap(xf, 0.0, radius, maxi(sides, 6), true)


func append_transformed(other, xf: Transform3D) -> void:
	var base := vertices.size()
	var flip := xf.basis.determinant() < 0.0
	for i in other.vertices.size():
		vertices.append(xf * other.vertices[i])
		normals.append((xf.basis * other.normals[i]).normalized())
		uvs.append(other.uvs[i])
	for i in range(0, other.indices.size(), 3):
		if flip:
			indices.append(base + other.indices[i])
			indices.append(base + other.indices[i + 2])
			indices.append(base + other.indices[i + 1])
		else:
			indices.append(base + other.indices[i])
			indices.append(base + other.indices[i + 1])
			indices.append(base + other.indices[i + 2])


func to_array_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _cap(xf: Transform3D, z: float, radius: float, sides: int, front: bool) -> void:
	var center := xf * Vector3(0.0, 0.0, z)
	var normal := (xf.basis * Vector3(0.0, 0.0, -1.0 if front else 1.0)).normalized()
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var p0 := xf * Vector3(cos(a0) * radius, sin(a0) * radius, z)
		var p1 := xf * Vector3(cos(a1) * radius, sin(a1) * radius, z)
		if front:
			_tri(center, p1, p0, normal)
		else:
			_tri(center, p0, p1, normal)


func _quad(points: Array) -> void:
	var p0: Vector3 = points[0]
	var p1: Vector3 = points[1]
	var p2: Vector3 = points[2]
	var p3: Vector3 = points[3]
	var normal: Vector3 = (p1 - p0).cross(p3 - p0)
	if normal.length_squared() < 0.0000001:
		return
	normal = normal.normalized()
	var base := vertices.size()
	var quad: Array[Vector3] = [p0, p1, p2, p3]
	for i in 4:
		vertices.append(quad[i])
		normals.append(normal)
		uvs.append(Vector2(float(i % 2), float(i / 2)))
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
	indices.append(base)
	indices.append(base + 2)
	indices.append(base + 3)


func _tri(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	var base := vertices.size()
	vertices.append(a)
	vertices.append(b)
	vertices.append(c)
	normals.append(normal)
	normals.append(normal)
	normals.append(normal)
	uvs.append(Vector2(0.5, 0.5))
	uvs.append(Vector2(1.0, 0.0))
	uvs.append(Vector2(0.0, 0.0))
	indices.append(base)
	indices.append(base + 1)
	indices.append(base + 2)
