extends RefCounted

## Hand-built hull pieces. Nose at -Z, the same way jumpship.glb faces.
## A socket's -Z points out of the part. Size classes only snap to the same class.
## Greebles use size "g" and fit a top or side socket of any hull.

const _Mesh := preload("res://scripts/ships/kit_mesh.gd")

const SIZES := ["s", "m", "l"]


static func catalog() -> Array:
	return [
		{"id": "nose_canopy", "category": "nose", "sizes": ["s", "m", "l"]},
		{"id": "nose_needle", "category": "nose", "sizes": ["s", "m"]},
		{"id": "nose_blunt", "category": "nose", "sizes": ["m", "l"]},
		{"id": "core_dart", "category": "core", "sizes": ["s"]},
		{"id": "core_spine", "category": "core", "sizes": ["m"]},
		{"id": "core_barge", "category": "core", "sizes": ["l"]},
		{"id": "wing_blade", "category": "wing", "sizes": ["s", "m"]},
		{"id": "wing_delta", "category": "wing", "sizes": ["m", "l"]},
		{"id": "wing_slab", "category": "wing", "sizes": ["l", "m"]},
		{"id": "wing_fin", "category": "wing", "sizes": ["s", "m", "l"]},
		{"id": "engine_needle", "category": "engine", "sizes": ["s", "m"]},
		{"id": "engine_twin", "category": "engine", "sizes": ["m", "l"]},
		{"id": "engine_cluster", "category": "engine", "sizes": ["l", "m"]},
		{"id": "greeble_antenna", "category": "greeble", "sizes": ["g"]},
		{"id": "greeble_panel", "category": "greeble", "sizes": ["g"]},
		{"id": "greeble_vent", "category": "greeble", "sizes": ["g"]},
		{"id": "greeble_light", "category": "greeble", "sizes": ["g"]},
	]


static func build(part_id: String, size: String) -> Node3D:
	match part_id:
		"nose_canopy":
			return _nose_canopy(size)
		"nose_needle":
			return _nose_needle(size)
		"nose_blunt":
			return _nose_blunt(size)
		"core_dart":
			return _core(size, 3.05, 0.92, 0.78)
		"core_spine":
			return _core(size, 4.5, 1.0, 0.82)
		"core_barge":
			return _core(size, 6.6, 1.12, 0.9)
		"wing_blade":
			return _wing_blade(size)
		"wing_delta":
			return _wing_delta(size)
		"wing_slab":
			return _wing_slab(size)
		"wing_fin":
			return _wing_fin(size)
		"engine_needle":
			return _engine_needle(size)
		"engine_twin":
			return _engine_twin(size)
		"engine_cluster":
			return _engine_cluster(size)
		"greeble_antenna":
			return _antenna(size)
		"greeble_panel":
			return _panel(size)
		"greeble_vent":
			return _vent(size)
		"greeble_light":
			return _light(size)
		_:
			return Node3D.new()


static func _dims(size: String) -> Dictionary:
	match size:
		"s":
			return {"beam": 0.64, "height": 0.4, "span": 1.55}
		"l":
			return {"beam": 1.5, "height": 0.82, "span": 2.15}
		_:
			return {"beam": 1.02, "height": 0.58, "span": 2.45}


static func _nose_canopy(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var beam: float = dim.beam
	var height: float = dim.height
	var length := beam * 2.15
	var root := _root("nose_canopy")
	var hull := _Mesh.new()
	var xf := Transform3D.IDENTITY
	hull.add_taper(xf, length, Vector2(beam, height * 0.92), Vector2(beam * 0.16, height * 0.22))
	# Canopy blister, dark glass, sitting on the upper nose.
	var glass := _Mesh.new()
	var canopy_xf := Transform3D(Basis.IDENTITY, Vector3(0.0, height * 0.28, -length * 0.08))
	glass.add_taper(canopy_xf, length * 0.62, Vector2(beam * 0.46, height * 0.28), Vector2(beam * 0.1, height * 0.08))
	_paint(root, "glass", glass)
	_paint(root, "hull", hull)
	_line(root, Vector3(0.0, height * 0.46, 0.05), Vector3(beam * 0.7, 0.012, 0.02))
	_socket(root, "socket_rear", Vector3(0.0, 0.0, length * 0.5), Vector3(0.0, 0.0, 1.0), size)
	return root


static func _nose_needle(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var beam: float = dim.beam
	var height: float = dim.height
	var length := beam * 2.8
	var root := _root("nose_needle")
	var hull := _Mesh.new()
	hull.add_taper(Transform3D.IDENTITY, length, Vector2(beam * 0.82, height * 0.72), Vector2(0.04, 0.04))
	_paint(root, "hull", hull)
	_socket(root, "socket_rear", Vector3(0.0, 0.0, length * 0.5), Vector3(0.0, 0.0, 1.0), size)
	return root


static func _nose_blunt(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var beam: float = dim.beam
	var height: float = dim.height
	var length := beam * 1.15
	var root := _root("nose_blunt")
	var hull := _Mesh.new()
	hull.add_taper(Transform3D.IDENTITY, length, Vector2(beam, height), Vector2(beam * 0.72, height * 0.7))
	var chin := Transform3D(Basis.IDENTITY, Vector3(0.0, -height * 0.18, -length * 0.15))
	hull.add_box(chin, Vector3(beam * 0.78, height * 0.28, length * 0.55))
	_paint(root, "hull", hull)
	_line(root, Vector3(0.0, height * 0.5, 0.0), Vector3(beam * 0.84, 0.015, 0.02))
	_socket(root, "socket_rear", Vector3(0.0, 0.0, length * 0.5), Vector3(0.0, 0.0, 1.0), size)
	return root


static func _core(size: String, length: float, width_scale: float, height_scale: float) -> Node3D:
	var dim: Dictionary = _dims(size)
	var beam: float = dim.beam * width_scale
	var height: float = dim.height * height_scale
	var root := _root("core")
	var hull := _Mesh.new()
	# A long tapered spine. Slightly wider at the wing root than at the nose joint.
	hull.add_taper(Transform3D.IDENTITY, length, Vector2(beam * 0.92, height * 0.88), Vector2(beam, height))
	var belly := Transform3D(Basis.IDENTITY, Vector3(0.0, -height * 0.42, length * 0.06))
	hull.add_box(belly, Vector3(beam * 0.62, height * 0.16, length * 0.72))
	_paint(root, "hull", hull)
	# Panel lines: a spine seam and two flank breaks.
	_line(root, Vector3(0.0, height * 0.5, 0.0), Vector3(0.018, 0.012, length * 0.78))
	_line(root, Vector3(beam * 0.28, height * 0.5, -length * 0.05), Vector3(0.012, 0.01, length * 0.46))
	_line(root, Vector3(-beam * 0.28, height * 0.5, -length * 0.05), Vector3(0.012, 0.01, length * 0.46))
	_line(root, Vector3(0.0, -height * 0.5, length * 0.08), Vector3(beam * 0.4, 0.01, 0.015))
	_socket(root, "socket_front", Vector3(0.0, 0.0, -length * 0.5), Vector3(0.0, 0.0, -1.0), size)
	_socket(root, "socket_rear", Vector3(0.0, 0.0, length * 0.5), Vector3(0.0, 0.0, 1.0), size)
	_socket(root, "socket_wing_L", Vector3(-beam * 0.5, 0.0, length * 0.02), Vector3(-1.0, 0.0, 0.0), size)
	_socket(root, "socket_wing_R", Vector3(beam * 0.5, 0.0, length * 0.02), Vector3(1.0, 0.0, 0.0), size)
	_socket(root, "socket_top", Vector3(0.0, height * 0.5, -length * 0.12), Vector3(0.0, 1.0, 0.0), "g")
	_socket(root, "socket_top_b", Vector3(0.0, height * 0.5, length * 0.22), Vector3(0.0, 1.0, 0.0), "g")
	_socket(root, "socket_side", Vector3(beam * 0.48, height * 0.05, length * 0.18), Vector3(1.0, 0.0, 0.0), "g")
	return root


static func _span_basis() -> Basis:
	# Local +Z runs out to the left (-X), so a taper becomes a wing.
	return Basis(Vector3.UP, -PI * 0.5)


static func _wing_blade(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var span: float = dim.span
	var chord: float = dim.beam * 1.15
	var root := _root("wing_blade")
	var hull := _Mesh.new()
	var xf := Transform3D(_span_basis().rotated(Vector3.UP, -0.18), Vector3(-span * 0.46, 0.0, 0.12))
	hull.add_taper(xf, span, Vector2(chord * 0.22, 0.035), Vector2(chord, 0.07))
	_paint(root, "hull", hull)
	_line(root, Vector3(-span * 0.42, 0.04, 0.08), Vector3(span * 0.62, 0.008, 0.012))
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), size)
	return root


static func _wing_delta(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var span: float = dim.span * 1.05
	var chord: float = dim.beam * 1.85
	var root := _root("wing_delta")
	var hull := _Mesh.new()
	var xf := Transform3D(_span_basis(), Vector3(-span * 0.46, 0.0, 0.05))
	hull.add_taper(xf, span, Vector2(chord * 0.18, 0.03), Vector2(chord, 0.075))
	_paint(root, "hull", hull)
	var stripe := _Mesh.new()
	stripe.add_box(Transform3D(Basis.IDENTITY, Vector3(-span * 0.4, 0.042, 0.02)), Vector3(span * 0.55, 0.012, 0.07))
	_paint(root, "accent", stripe)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), size)
	return root


static func _wing_slab(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var span: float = dim.span * 0.78
	var chord: float = dim.beam * 1.55
	var root := _root("wing_slab")
	var hull := _Mesh.new()
	hull.add_box(Transform3D(Basis.IDENTITY, Vector3(-span * 0.5, -0.02, 0.16)), Vector3(span, 0.09, chord))
	_paint(root, "hull", hull)
	_line(root, Vector3(-span * 0.42, 0.04, 0.12), Vector3(span * 0.7, 0.01, 0.016))
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), size)
	return root


static func _wing_fin(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var height: float = dim.height * 1.65
	var chord: float = dim.beam * 0.85
	var root := _root("wing_fin")
	var hull := _Mesh.new()
	var basis := Basis(Vector3.RIGHT, -PI * 0.5)
	var xf := Transform3D(basis, Vector3(-0.05, height * 0.46, 0.0))
	hull.add_taper(xf, height, Vector2(0.028, chord * 0.38), Vector2(0.07, chord))
	_paint(root, "hull", hull)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.0, 0.0), size)
	return root


static func _engine_needle(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var radius: float = dim.beam * 0.22
	var length := radius * 5.2
	var root := _root("engine_needle")
	var hull := _Mesh.new()
	var bell := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, length * 0.15))
	hull.add_cylinder(bell, length, radius * 1.15, radius * 0.62, 8)
	_paint(root, "hull", hull)
	var glow := _Mesh.new()
	var glow_xf := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, length * 0.15 + length * 0.5))
	glow.add_disk(glow_xf, radius * 0.82, 8)
	_paint(root, "glow", glow)
	_socket(root, "socket_mount", Vector3(0.0, 0.0, -length * 0.35), Vector3(0.0, 0.0, -1.0), size)
	return root


static func _engine_twin(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var radius: float = dim.beam * 0.2
	var gap: float = dim.beam * 0.38
	var length := radius * 4.4
	var root := _root("engine_twin")
	var hull := _Mesh.new()
	var glow := _Mesh.new()
	for side in [-1.0, 1.0]:
		var bell := Transform3D(Basis.IDENTITY, Vector3(side * gap, 0.0, length * 0.2))
		hull.add_cylinder(bell, length, radius * 1.2, radius * 0.55, 8)
		var glow_xf := Transform3D(Basis.IDENTITY, Vector3(side * gap, 0.0, length * 0.2 + length * 0.5))
		glow.add_disk(glow_xf, radius * 0.78, 8)
	var yoke := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -length * 0.15))
	hull.add_box(yoke, Vector3(gap * 2.2, radius * 0.7, radius * 1.4))
	_paint(root, "hull", hull)
	_paint(root, "glow", glow)
	_socket(root, "socket_mount", Vector3(0.0, 0.0, -length * 0.42), Vector3(0.0, 0.0, -1.0), size)
	return root


static func _engine_cluster(size: String) -> Node3D:
	var dim: Dictionary = _dims(size)
	var radius: float = dim.beam * 0.16
	var length := radius * 4.0
	var root := _root("engine_cluster")
	var hull := _Mesh.new()
	var glow := _Mesh.new()
	var spots := [Vector3(0.0, radius * 0.85, 0.0), Vector3(-radius * 1.15, -radius * 0.35, 0.0), Vector3(radius * 1.15, -radius * 0.35, 0.0)]
	for spot in spots:
		var bell := Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.0, length * 0.25))
		hull.add_cylinder(bell, length, radius * 1.25, radius * 0.5, 7)
		var glow_xf := Transform3D(Basis.IDENTITY, spot + Vector3(0.0, 0.0, length * 0.25 + length * 0.5))
		glow.add_disk(glow_xf, radius * 0.7, 7)
	_paint(root, "hull", hull)
	_paint(root, "glow", glow)
	_socket(root, "socket_mount", Vector3(0.0, 0.0, -length * 0.2), Vector3(0.0, 0.0, -1.0), size)
	return root


static func _antenna(_size: String) -> Node3D:
	var root := _root("greeble_antenna")
	var hull := _Mesh.new()
	hull.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.28, 0.0)), 0.52, 0.02, 0.015, 6)
	hull.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), Vector3(0.08, 0.06, 0.08))
	_paint(root, "hull", hull)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), "g")
	return root


static func _panel(_size: String) -> Node3D:
	var root := _root("greeble_panel")
	var hull := _Mesh.new()
	hull.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, 0.0)), Vector3(0.28, 0.03, 0.42))
	_paint(root, "line", hull)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), "g")
	return root


static func _vent(_size: String) -> Node3D:
	var root := _root("greeble_vent")
	var hull := _Mesh.new()
	for i in 3:
		var xf := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.02, float(i - 1) * 0.07))
		hull.add_box(xf, Vector3(0.22, 0.025, 0.028))
	_paint(root, "line", hull)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), "g")
	return root


static func _light(_size: String) -> Node3D:
	var root := _root("greeble_light")
	var glow := _Mesh.new()
	glow.add_box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.03, 0.0)), Vector3(0.06, 0.04, 0.1))
	_paint(root, "glow", glow)
	root.set_meta("live_light", true)
	_socket(root, "socket_root", Vector3(0.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0), "g")
	return root


static func _root(part_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = part_name
	return root


static func _paint(root: Node3D, bucket: String, mesh) -> void:
	var instance := MeshInstance3D.new()
	instance.name = bucket.capitalize()
	instance.mesh = mesh.to_array_mesh()
	instance.set_meta("bucket", bucket)
	root.add_child(instance)


static func _line(root: Node3D, pos: Vector3, size: Vector3) -> void:
	var mesh := _Mesh.new()
	mesh.add_box(Transform3D(Basis.IDENTITY, pos), size)
	_paint(root, "line", mesh)


static func _socket(root: Node3D, socket_name: String, pos: Vector3, outward: Vector3, size: String) -> void:
	var marker := Marker3D.new()
	marker.name = socket_name
	marker.position = pos
	var up := Vector3.UP
	if absf(outward.normalized().dot(Vector3.UP)) > 0.85:
		up = Vector3.FORWARD
	marker.basis = Basis.looking_at(outward, up)
	marker.set_meta("size", size)
	root.add_child(marker)
