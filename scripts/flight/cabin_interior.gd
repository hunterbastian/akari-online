extends Node3D

## Cozy cabin cheated a little larger than the fuselage, drawn on its own layer
## so the chase camera never sees it. Coordinates below are the glTF model's meters;
## build() scales them into this node's space (world meters under the counter-scale).

const _Dress := preload("res://scripts/flight/jumpship_dress.gd")
const _Walker := preload("res://scripts/flight/cabin_walker.gd")
const _CRT := preload("res://assets/shaders/crt_green.gdshader")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"

const INTERIOR_LAYER := 1 << 2

var paints: Array[ShaderMaterial] = []
var walker
var seat_point := Vector3.ZERO
var aisle_point := Vector3.ZERO
var standing_eye := 0.7
var seated_eye := 0.55
var sit_reach := 0.26

var _scale := 1.0
var _high := true
var _shadowers: Array[MeshInstance3D] = []
var _lines := {}
var _font: FontFile


func build(scale: float, high_quality: bool) -> void:
	_scale = scale
	_high = high_quality
	_font = load(_FONT)
	_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	_font.hinting = TextServer.HINTING_NONE
	_font.generate_mipmaps = false
	var wall := _paint(Color(0.24, 0.25, 0.27), 0.48, 0.08)
	var floor := _paint(Color(0.1, 0.105, 0.115), 0.78, 0.02)
	var trim := _paint(Color(0.2, 0.208, 0.22), 0.4, 0.12)
	var cloth := _paint(Color(0.09, 0.092, 0.105), 0.72, 0.0)
	var bunk := _paint(Color(0.16, 0.145, 0.125), 0.7, 0.0)
	var bezel := _paint(Color(0.07, 0.074, 0.082), 0.38, 0.18)
	var door := _paint(Color(0.12, 0.125, 0.138), 0.46, 0.2)

	# Floor and a ceiling that stops where the canopy opens, so the sun can reach the seat.
	_box("Floor", _v(0.0, -0.46, -1.35), _v(2.08, 0.06, 3.2), floor, false)
	_box("CeilingRear", _v(0.0, 1.58, -0.42), _v(2.08, 0.06, 1.45), wall, true)
	_box("CeilingL", _v(-0.78, 1.58, -2.05), _v(0.42, 0.06, 1.7), wall, true)
	_box("CeilingR", _v(0.78, 1.58, -2.05), _v(0.42, 0.06, 1.7), wall, true)
	_box("WallL", _v(-1.02, 0.56, -1.35), _v(0.06, 2.08, 3.2), wall, true)
	_box("WallR", _v(1.02, 0.56, -1.35), _v(0.06, 2.08, 3.2), wall, true)
	_box("WallRear", _v(0.0, 0.56, 0.24), _v(2.08, 2.08, 0.07), wall, true)
	_box("Kick", _v(0.0, -0.22, -2.72), _v(1.7, 0.42, 0.08), trim, true)

	_box("Console", _v(0.0, 0.02, -2.5), _v(1.45, 0.72, 0.42), trim, false)
	_box("Seat", _v(0.0, -0.18, -1.72), _v(0.46, 0.36, 0.42), cloth, false)
	_box("Backrest", _v(0.0, 0.36, -1.52), _v(0.26, 0.7, 0.07), cloth, false)
	_box("Bunk", _v(0.68, -0.22, -0.45), _v(0.58, 0.16, 1.15), bunk, false)
	_box("Pillow", _v(0.68, -0.1, -0.92), _v(0.36, 0.1, 0.22), bunk, false)
	_box("JumpSeat", _v(-0.72, -0.16, -0.5), _v(0.42, 0.28, 0.42), cloth, false)

	_box("Door", _v(0.0, 0.42, 0.18), _v(0.62, 1.15, 0.04), door, false)
	_box("DoorBar", _v(0.22, 0.48, 0.14), _v(0.16, 0.035, 0.035), trim, false)
	_glow("DoorTell", _v(-0.22, 0.95, 0.14), _v(0.035, 0.035, 0.02), Color(1.15, 0.16, 0.07))

	_glass(_v(0.0, 0.78, -2.86), Vector2(1.55, 0.78) * _scale, 0.18)
	_glass(_v(0.0, 1.32, -2.05), Vector2(1.35, 1.45) * _scale, 1.05)

	_glow("StripL", _v(-0.9, -0.3, -1.3), _v(0.02, 0.018, 2.55), Color(0.28, 0.62, 2.4))
	_glow("StripR", _v(0.9, -0.3, -1.3), _v(0.02, 0.018, 2.55), Color(0.28, 0.62, 2.4))
	_glow("BulbSeat", _v(-0.28, 1.42, -1.85), Vector3(0.035, 0.035, 0.035) * _scale, Color(1.15, 0.62, 0.28))
	_glow("BulbBunk", _v(0.55, 1.42, -0.4), Vector3(0.03, 0.03, 0.03) * _scale, Color(1.05, 0.55, 0.26))
	if high_quality:
		_omni(_v(0.0, 1.15, -1.7), Color(0.55, 0.72, 1.0), 0.55, 1.5)
		_omni(_v(-0.15, 1.2, -1.7), Color(1.0, 0.72, 0.42), 0.38, 1.15)
		_omni(_v(0.4, 1.15, -0.35), Color(1.0, 0.68, 0.4), 0.22, 0.9)

	var terminal_size := Vector2i(512, 320) if high_quality else Vector2i(360, 220)
	var side_size := Vector2i(320, 200) if high_quality else Vector2i(240, 150)
	_screen("Terminal", _v(0.0, 0.98, -2.12), Vector2(0.62, 0.4) * _scale, 0.22, 0.0, "terminal", terminal_size, bezel)
	_screen("Nav", _v(-0.46, 0.92, -2.1), Vector2(0.32, 0.24) * _scale, 0.2, 0.0, "nav", side_size, bezel)
	_screen("Drive", _v(0.46, 0.92, -2.1), Vector2(0.32, 0.24) * _scale, 0.2, 0.0, "drive", side_size, bezel)
	_screen("Bay", _v(0.0, 1.02, 0.15), Vector2(0.36, 0.22) * _scale, 0.0, PI, "bay", side_size, bezel)

	_build_walker()


func set_walking(on: bool) -> void:
	if not _high:
		return
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh in _shadowers:
		mesh.cast_shadow = mode


func update_readouts(speed: float, throttle: float, mina_range: float, ship_name: String) -> void:
	var spd := "%03d" % int(round(speed))
	var rng := "%05d" % int(round(maxf(mina_range, 0.0)))
	var thr := "%04.2f" % clampf(throttle, 0.0, 1.0)
	_set_line("terminal", "AKARI  %s\nSYS    SOL\nHULL   50\nSPD    %s\nMINA   %s\nFUEL   1.00\n\nSHIP COMPUTER\nAUTOPILOT  STANDBY\nROUTE      NONE\n>" % [ship_name, spd, rng])
	_set_line("nav", "NAV\nMINA\nRNG   %s\nBRG   FWD\nLINK  HOLD" % rng)
	_set_line("drive", "DRIVE\nSPD   %s\nTHR   %s\nSTAT  NOM" % [spd, thr])
	_set_line("bay", "ENG BAY\nSEALED\nCORE  NOM\nTEMP  312")


func snap_view(mode: String) -> void:
	if mode == "seat":
		walker.snap(seat_point, seated_eye, -0.22, 0.0)
	else:
		walker.snap(aisle_point, standing_eye, 0.14, 0.0)


func _build_walker() -> void:
	var floor_y := _scale * -0.4
	standing_eye = _scale * 1.5
	seated_eye = _scale * 1.12
	seat_point = _v(0.0, 0.0, -1.22)
	aisle_point = _v(0.0, 0.0, -1.02)
	sit_reach = _scale * 0.62
	walker = _Walker.new()
	walker.name = "Walker"
	walker.floor_y = floor_y
	walker.eye_height = standing_eye
	walker.speed = _scale * 1.45
	walker.radius = _scale * 0.24
	walker._bob_amp = _scale * 0.028
	walker.position = Vector3(aisle_point.x, floor_y, aisle_point.z)
	walker.limit_min = _v(-0.7, 0.0, -2.05)
	walker.limit_max = _v(0.38, 0.0, 0.02)
	walker.boxes = [
		_aabb(_v(0.0, 0.0, -2.5), _v(1.5, 0.2, 0.46)),
		_aabb(_v(0.0, 0.0, -1.66), _v(0.42, 0.2, 0.5)),
		_aabb(_v(0.68, 0.0, -0.45), _v(0.62, 0.2, 1.2)),
		_aabb(_v(-0.78, 0.0, -0.5), _v(0.46, 0.2, 0.46)),
		_aabb(_v(-1.05, 0.0, -1.35), _v(0.16, 0.2, 3.3)),
		_aabb(_v(1.05, 0.0, -1.35), _v(0.16, 0.2, 3.3)),
		_aabb(_v(0.0, 0.0, 0.22), _v(2.2, 0.2, 0.16)),
		_aabb(_v(0.0, 0.0, -2.95), _v(2.2, 0.2, 0.2)),
	]
	add_child(walker)


func _aabb(center: Vector3, size: Vector3) -> Dictionary:
	var half := size * 0.5
	return {
		"min_x": center.x - half.x,
		"max_x": center.x + half.x,
		"min_z": center.z - half.z,
		"max_z": center.z + half.z,
	}


func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z) * _scale


func _paint(color: Color, roughness: float, metallic: float) -> ShaderMaterial:
	var material := _Dress.paint_material(color, roughness, metallic, _high, color.r * 3.0)
	if _high:
		material.set_shader_parameter("clearcoat_amount", 0.04)
		material.set_shader_parameter("clearcoat_gloss", 0.4)
	paints.append(material)
	return material


func _box(node_name: String, pos: Vector3, size: Vector3, material: Material, shadows: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	if shadows:
		_shadowers.append(mesh_instance)
	return mesh_instance


func _glow(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	if size.x < 0.08 and absf(size.x - size.y) < 0.001:
		var sphere := SphereMesh.new()
		sphere.radius = size.x
		sphere.height = size.x * 2.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mesh_instance.mesh = sphere
	else:
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.position = pos
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.0
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _glass(pos: Vector3, size: Vector2, tilt: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	mesh_instance.position = pos
	mesh_instance.rotation.x = tilt
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.05, 0.12, 0.14, 0.16)
	material.metallic = 0.55
	material.roughness = 0.06
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if _high:
		material.clearcoat_enabled = true
		material.clearcoat = 0.8
		material.clearcoat_roughness = 0.04
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _omni(pos: Vector3, color: Color, energy: float, range: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range
	light.shadow_enabled = false
	light.light_specular = 0.4
	add_child(light)


func _screen(node_name: String, pos: Vector3, size: Vector2, tilt: float, yaw: float, kind: String, view_size: Vector2i, bezel: Material) -> void:
	var bezel_pad := _scale * 0.03
	_box(node_name + "Bezel", pos, Vector3(size.x + bezel_pad, size.y + bezel_pad, 0.02 * _scale), bezel, false)
	var viewport := SubViewport.new()
	viewport.name = node_name + "View"
	viewport.size = view_size
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.gui_disable_input = true
	var background := ColorRect.new()
	background.color = Color(0.02, 0.09, 0.035)
	background.size = Vector2(view_size)
	viewport.add_child(background)
	var label := Label.new()
	label.position = Vector2(10, 8)
	label.size = Vector2(view_size) - Vector2(16, 12)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", 18 if view_size.y >= 280 else 14)
	label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.62))
	label.text = "AKARI"
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(label)
	add_child(viewport)
	_lines[kind] = label

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var quad := QuadMesh.new()
	quad.size = size
	mesh_instance.mesh = quad
	var face := 1.0 if yaw < 0.1 else -1.0
	mesh_instance.position = pos + Vector3(0.0, 0.0, 0.045 * face)
	mesh_instance.rotation = Vector3(tilt, yaw, 0.0)
	var material := ShaderMaterial.new()
	material.shader = _CRT
	material.set_shader_parameter("screen_tex", viewport.get_texture())
	material.set_shader_parameter("glow_spread", 0.004 if _high else 0.0)
	material.set_shader_parameter("brightness", 1.3 if _high else 1.15)
	mesh_instance.material_override = material
	mesh_instance.layers = INTERIOR_LAYER
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)


func _set_line(kind: String, text: String) -> void:
	var label: Label = _lines.get(kind)
	if label:
		label.text = text
