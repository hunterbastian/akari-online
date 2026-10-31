extends Node

## Spawns seeded kit ships near Mina, and serves the debug console.

const _Builder := preload("res://scripts/ships/ship_builder.gd")
const _Npc := preload("res://scripts/ships/npc_ship.gd")
const _FONT := "res://assets/fonts/Silkscreen-Regular.ttf"

const FAVORITES := "res://data/ship_favorites.json"
const GALLERY_SEEDS := 16

var planet_center := Vector3.ZERO
var planet_radius := 24.0
var _fleet: Node3D
var _gallery: Node3D
var _next_seed := 100
var _font: Font


func setup(center: Vector3, radius: float) -> void:
	planet_center = center
	planet_radius = radius
	_fleet = Node3D.new()
	_fleet.name = "Traffic"
	add_child(_fleet)
	_font = load(_FONT)
	_spawn_fleet()
	if DevConsole.enabled():
		DevConsole.register_command("ship", _on_ship, "ship spawn [seed] [archetype] | regen | gallery | save <seed>")


func build_gallery() -> Vector3:
	_clear_gallery()
	if _fleet:
		_fleet.visible = false
	_gallery = Node3D.new()
	_gallery.name = "Gallery"
	add_child(_gallery)
	var origin := planet_center + Vector3(planet_radius * 16.0, planet_radius * 3.0, 0.0)
	var spacing := 10.5
	for i in GALLERY_SEEDS:
		var seed_value := i + 1
		var archetype := _Builder.archetype_for(seed_value)
		var col := i % 4
		var row := int(i / 4)
		var at := origin + Vector3((float(col) - 1.5) * spacing, 0.0, (float(row) - 1.5) * spacing)
		var ship := _place(seed_value, archetype, at, true)
		_gallery.add_child(ship)
		if ship.has_method("setup"):
			ship.setup(at, 0.0, 0.0, 0.0, 0.0, archetype == "derelict", planet_center)
			ship.hold = true
		ship.rotation = Vector3(-0.3, 0.55, 0.0)
		_label(ship, "%02d %s" % [seed_value, archetype])
	return origin


func build_showcase(seed_value: int, archetype: String) -> Vector3:
	_clear_gallery()
	if _fleet:
		_fleet.visible = false
	_gallery = Node3D.new()
	_gallery.name = "Showcase"
	add_child(_gallery)
	var origin := planet_center + Vector3(0.0, planet_radius + 55.0, 40.0)
	var ship := _place(seed_value, archetype, origin, true)
	_gallery.add_child(ship)
	if ship.has_method("setup"):
		ship.setup(origin, 0.0, 0.0, 0.0, 0.0, archetype == "derelict", planet_center)
		ship.hold = true
	ship.rotation = Vector3(-0.2, 0.65, 0.08 if archetype == "derelict" else 0.0)
	return origin


func _spawn_fleet() -> void:
	for child in _fleet.get_children():
		child.queue_free()
	var specs := [
		{"seed": 11, "orbit": planet_radius * 4.2, "rate": 0.07, "phase": 0.4, "lift": 3.0},
		{"seed": 22, "orbit": planet_radius * 5.1, "rate": 0.045, "phase": 2.1, "lift": 6.0},
		{"seed": 33, "orbit": planet_radius * 6.0, "rate": 0.055, "phase": 4.2, "lift": -2.0},
		{"seed": 44, "orbit": planet_radius * 3.4, "rate": 0.02, "phase": 1.2, "lift": 1.5},
	]
	for spec in specs:
		var seed_value: int = spec.seed
		var archetype := _Builder.archetype_for(seed_value)
		var ship := _place(seed_value, archetype, planet_center, false)
		_fleet.add_child(ship)
		if ship.has_method("setup"):
			ship.setup(planet_center, float(spec.orbit), float(spec.rate), float(spec.phase), float(spec.lift), archetype == "derelict", planet_center)


func _place(seed_value: int, archetype: String, at: Vector3, _frozen: bool) -> Node3D:
	var visual := _Builder.build(seed_value, archetype)
	visual.position = Vector3.ZERO
	var body := Node3D.new()
	body.name = "Npc%d" % seed_value
	body.set_script(_Npc)
	body.add_child(visual)
	body.position = at
	body.set_meta("seed", seed_value)
	body.set_meta("archetype", archetype)
	return body


func _label(body: Node3D, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = _font
	label.font_size = 42
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.92, 1.0, 0.94)
	label.outline_modulate = Color(0.02, 0.04, 0.05, 0.85)
	label.outline_size = 6
	label.position = Vector3(0.0, 1.35, 0.0)
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.outline_size = 0
	body.add_child(label)


func _clear_gallery() -> void:
	if _gallery:
		_gallery.queue_free()
		_gallery = null


func _on_ship(args: PackedStringArray) -> void:
	if args.is_empty():
		DevConsole._echo("ship spawn [seed] [archetype] | regen | gallery | save <seed>")
		return
	var verb := args[0].to_lower()
	if verb == "spawn":
		_cmd_spawn(args)
	elif verb == "regen":
		_next_seed += 1
		_spawn_fleet()
		if _fleet:
			_fleet.visible = true
		_clear_gallery()
		DevConsole._echo("regen fleet from %d" % _next_seed)
	elif verb == "gallery":
		var origin := build_gallery()
		var eye := origin + Vector3(28.0, 16.0, 34.0)
		DevConsole.place_freecam(eye, origin)
		DevConsole._echo("gallery 16 seeds")
	elif verb == "save":
		if args.size() < 2 or not args[1].is_valid_int():
			DevConsole._echo("ship save <seed>", "warn")
			return
		var seed_value := int(args[1])
		var archetype := _Builder.archetype_for(seed_value)
		if args.size() >= 3:
			archetype = args[2].to_lower()
		DevConsole._echo(_save(seed_value, archetype))
	else:
		DevConsole._echo("unknown ship command '%s'" % verb, "err")


func _cmd_spawn(args: PackedStringArray) -> void:
	var seed_value := _next_seed
	_next_seed += 1
	if args.size() >= 2 and args[1].is_valid_int():
		seed_value = int(args[1])
	var archetype := ""
	if args.size() >= 3:
		archetype = args[2].to_lower()
	if archetype == "":
		archetype = _Builder.archetype_for(seed_value)
	var player := get_parent().get_node_or_null("Ship") as Node3D
	var at := planet_center + Vector3(planet_radius * 3.2, 4.0, 0.0)
	if player:
		at = player.global_position + (-player.global_basis.z) * 18.0 + Vector3.UP * 2.0
	var ship := _place(seed_value, archetype, at, false)
	_fleet.add_child(ship)
	if ship.has_method("setup"):
		ship.setup(at, 8.0, 0.15, 0.0, 0.0, archetype == "derelict", planet_center)
		ship.hold = true
		ship.global_position = at
	DevConsole._echo("spawn %d %s" % [seed_value, archetype])


func _save(seed_value: int, archetype: String) -> String:
	var data := {"favorites": []}
	if FileAccess.file_exists(FAVORITES):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FAVORITES))
		if typeof(parsed) == TYPE_DICTIONARY:
			data = parsed
	var list: Array = data.get("favorites", [])
	list.append({"seed": seed_value, "archetype": archetype})
	data["favorites"] = list
	var file := FileAccess.open(FAVORITES, FileAccess.WRITE)
	if file == null:
		return "save failed: %s" % error_string(FileAccess.get_open_error())
	file.store_string(JSON.stringify(data, "\t"))
	return "saved %d %s -> %s" % [seed_value, archetype, FAVORITES]
