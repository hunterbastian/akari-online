extends Node

## Cabin inventory. Slots, lockers, and dropped piles are plain dictionaries so a
## later save can store to_dict() without a save system existing yet.

const _Blocks := preload("res://scripts/flight/cabin_blocks.gd")

const HOTBAR := 5
const PACK := 4
const LOCKER := 4
const KINDS := {
	"helmet": "HELM",
	"mug": "MUG",
	"cartridge": "CART",
	"crate": "CRATE",
}

var selected := 0
var open_bank := ""
var dirty := true
var slots := {}

var _cabin
var _scale := 1.0
var _world: Array = []
var _locker_pos := {}
var _serial := 0
var _flat: StandardMaterial3D
var _dark: StandardMaterial3D


func setup(cabin) -> void:
	_cabin = cabin
	_scale = cabin._scale
	boot_empty()
	_flat = StandardMaterial3D.new()
	_flat.albedo_color = Color(0.82, 0.8, 0.76)
	_flat.roughness = 0.9
	_flat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_dark = StandardMaterial3D.new()
	_dark.albedo_color = Color(0.12, 0.13, 0.15)
	_dark.roughness = 0.8
	_dark.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_track("helmet", ["Helmet", "Visor"])
	_track("mug", ["Mug"])
	for i in 5:
		_track("cartridge", ["Tape%d" % i])
	for node_name in ["CrateL", "CrateA", "CrateB", "RackCrate"]:
		_track("crate", [node_name])
	for node_name in ["LockerL", "LockerR"]:
		var node := _cabin.get_node_or_null(NodePath(node_name)) as Node3D
		if node:
			_locker_pos[node_name] = node.position


func boot_empty() -> void:
	slots = {
		"hotbar": _row(HOTBAR),
		"pack": _row(PACK),
		"LockerL": _row(LOCKER),
		"LockerR": _row(LOCKER),
	}
	selected = 0
	open_bank = ""
	dirty = true


func give(item_id: String, count: int) -> bool:
	var kind := item_id.to_lower()
	if not KINDS.has(kind) or count < 1:
		return false
	if not _add(kind, count):
		return false
	dirty = true
	return true


func store(bank: String, item_id: String, count: int) -> bool:
	if not slots.has(bank) or bank == "hotbar" or bank == "pack":
		return false
	if not KINDS.has(item_id) or count < 1:
		return false
	var row: Array = slots[bank]
	if not _pour_any(row, item_id, count):
		return false
	dirty = true
	return true


func select(index: int) -> void:
	selected = clampi(index, 0, HOTBAR - 1)
	dirty = true


func transfer(src_bank: String, src_i: int, dst_bank: String, dst_i: int) -> void:
	if src_bank == dst_bank and src_i == dst_i:
		return
	if not slots.has(src_bank) or not slots.has(dst_bank):
		return
	var src: Array = slots[src_bank]
	var dst: Array = slots[dst_bank]
	if src_i < 0 or dst_i < 0 or src_i >= src.size() or dst_i >= dst.size():
		return
	var a: Dictionary = src[src_i]
	var b: Dictionary = dst[dst_i]
	if int(a["count"]) < 1:
		return
	if str(b["id"]) == str(a["id"]) and int(b["count"]) > 0:
		b["count"] = int(b["count"]) + int(a["count"])
		dst[dst_i] = b
		src[src_i] = _blank()
	else:
		src[src_i] = b
		dst[dst_i] = a
	dirty = true


func drop_selected() -> bool:
	if _cabin == null or _cabin.walker == null:
		return false
	var hot: Array = slots["hotbar"]
	var slot: Dictionary = hot[selected]
	if int(slot["count"]) < 1:
		return false
	var kind := str(slot["id"])
	var cell := _drop_cell(kind)
	slot["count"] = int(slot["count"]) - 1
	if int(slot["count"]) < 1:
		hot[selected] = _blank()
	else:
		hot[selected] = slot
	_spawn(kind, cell, true)
	dirty = true
	return true


func try_interact() -> bool:
	if _cabin == null or _cabin.walker == null or _cabin.walker.locked:
		return false
	if open_bank != "":
		open_bank = ""
		dirty = true
		return true
	var origin: Vector3 = _cabin.walker.position
	var reach := _scale * 0.95
	var best := reach
	var locker := ""
	for locker_name in _locker_pos.keys():
		var at: Vector3 = _locker_pos[locker_name]
		var dist := Vector2(origin.x, origin.z).distance_to(Vector2(at.x, at.z))
		if dist < best:
			best = dist
			locker = str(locker_name)
	var item := -1
	for i in _world.size():
		var rec: Dictionary = _world[i]
		if not bool(rec["alive"]):
			continue
		var at: Vector3 = rec["pos"]
		var dist := Vector2(origin.x, origin.z).distance_to(Vector2(at.x, at.z))
		if dist < best:
			best = dist
			locker = ""
			item = i
	if locker != "":
		open_bank = locker
		dirty = true
		return true
	if item >= 0:
		return _take(item)
	return false


func open(bank: String) -> void:
	if slots.has(bank) and bank != "hotbar" and bank != "pack":
		open_bank = bank
		dirty = true


func clear_all() -> void:
	for bank in slots.keys():
		var row: Array = slots[bank]
		for i in row.size():
			row[i] = _blank()
	var kept: Array = []
	for rec in _world:
		var record: Dictionary = rec
		if bool(record.get("spawned", false)):
			_hide(record)
			if record.has("blocker") and _cabin and _cabin.walker:
				_cabin.walker.boxes.erase(record["blocker"])
		else:
			kept.append(record)
	_world = kept
	open_bank = ""
	selected = 0
	dirty = true


func list_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("hotbar %d" % (selected + 1))
	for bank in ["hotbar", "pack", "LockerL", "LockerR"]:
		lines.append("%s  %s" % [bank, _row_text(bank)])
	var piles := 0
	for rec in _world:
		var record: Dictionary = rec
		if bool(record.get("spawned", false)) and bool(record["alive"]):
			piles += 1
	lines.append("dropped %d" % piles)
	return lines


func to_dict() -> Dictionary:
	var saved := {}
	for bank in slots.keys():
		var row: Array = slots[bank]
		var copy: Array = []
		for i in row.size():
			var slot: Dictionary = row[i]
			copy.append({"id": str(slot["id"]), "count": int(slot["count"])})
		saved[str(bank)] = copy
	var dropped: Array = []
	for rec in _world:
		var record: Dictionary = rec
		if bool(record.get("spawned", false)) and bool(record["alive"]):
			var at: Vector3 = record["gltf"]
			dropped.append({
				"id": str(record["id"]),
				"count": int(record["count"]),
				"x": at.x,
				"y": at.y,
				"z": at.z,
			})
	return {"selected": selected, "slots": saved, "dropped": dropped}


func from_dict(data: Dictionary) -> void:
	boot_empty()
	selected = clampi(int(data.get("selected", 0)), 0, HOTBAR - 1)
	var saved: Dictionary = data.get("slots", {})
	for bank in saved.keys():
		if not slots.has(bank):
			continue
		var incoming: Array = saved[bank]
		var row: Array = slots[bank]
		for i in mini(incoming.size(), row.size()):
			var slot: Dictionary = incoming[i]
			var count := int(slot.get("count", 0))
			var item_id := str(slot.get("id", ""))
			if count > 0 and KINDS.has(item_id):
				row[i] = {"id": item_id, "count": count}
	var dropped: Array = data.get("dropped", [])
	for pile in dropped:
		var record: Dictionary = pile
		var kind := str(record.get("id", ""))
		var count := int(record.get("count", 1))
		if not KINDS.has(kind) or count < 1 or _cabin == null:
			continue
		var cell := Vector3(float(record.get("x", 0.0)), float(record.get("y", -0.15)), float(record.get("z", 0.0)))
		_spawn(kind, cell, true)
		var last: Dictionary = _world[_world.size() - 1]
		last["count"] = count
		_world[_world.size() - 1] = last
	dirty = true


func _boot_check() -> bool:
	return slots.has("hotbar")


func _row(n: int) -> Array:
	var row: Array = []
	for _i in n:
		row.append(_blank())
	return row


func _blank() -> Dictionary:
	return {"id": "", "count": 0}


func _add(kind: String, count: int) -> bool:
	var hot: Array = slots["hotbar"]
	var sel: Dictionary = hot[selected]
	if int(sel["count"]) == 0 or str(sel["id"]) == kind:
		_pour(hot, selected, kind, count)
		return true
	if _pour_any(hot, kind, count):
		return true
	var pack: Array = slots["pack"]
	return _pour_any(pack, kind, count)


func _pour_any(row: Array, kind: String, count: int) -> bool:
	for i in row.size():
		var slot: Dictionary = row[i]
		if str(slot["id"]) == kind and int(slot["count"]) > 0:
			_pour(row, i, kind, count)
			return true
	for i in row.size():
		var slot: Dictionary = row[i]
		if int(slot["count"]) == 0:
			_pour(row, i, kind, count)
			return true
	return false


func _pour(row: Array, index: int, kind: String, count: int) -> void:
	var slot: Dictionary = row[index]
	if int(slot["count"]) == 0:
		row[index] = {"id": kind, "count": count}
	else:
		slot["count"] = int(slot["count"]) + count
		row[index] = slot


func _take(index: int) -> bool:
	var rec: Dictionary = _world[index]
	var count := int(rec.get("count", 1))
	if not give(str(rec["id"]), count):
		return false
	rec["alive"] = false
	_hide(rec)
	if rec.has("blocker") and _cabin.walker:
		_cabin.walker.boxes.erase(rec["blocker"])
	_world[index] = rec
	return true


func _hide(rec: Dictionary) -> void:
	var nodes: Array = rec["nodes"]
	for node in nodes:
		(node as Node3D).visible = false


func _track(kind: String, names: Array) -> void:
	var nodes: Array = []
	var pos := Vector3.ZERO
	for node_name in names:
		var node := _cabin.get_node_or_null(NodePath(str(node_name))) as Node3D
		if node:
			nodes.append(node)
			pos = node.position
	if nodes.is_empty():
		return
	_world.append({
		"id": kind,
		"count": 1,
		"nodes": nodes,
		"alive": true,
		"spawned": false,
		"pos": pos,
		"gltf": pos / _scale,
	})


func _drop_cell(kind: String) -> Vector3:
	var walker = _cabin.walker
	var forward := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, walker.rotation.y)
	var right := Vector3(1.0, 0.0, 0.0).rotated(Vector3.UP, walker.rotation.y)
	# Beside the forward line, so a drop from the aisle is not hidden by the seat.
	var ahead: Vector3 = walker.position + forward * _scale * 0.6 - right * _scale * 0.7
	var cell := _snap_cell(ahead)
	for _step in 4:
		if not walker._blocked(cell):
			break
		ahead += forward * _scale * 0.5
		cell = _snap_cell(ahead)
	cell.y = _scale * _floor_y(kind)
	return cell


func _snap_cell(local: Vector3) -> Vector3:
	var gx: float = _snap_axis(local.x / _scale)
	var gz: float = _snap_axis(local.z / _scale)
	return Vector3(gx * _scale, 0.0, gz * _scale)


func _snap_axis(value: float) -> float:
	var n: float = round((value - 0.25) / 0.5)
	return n * 0.5 + 0.25


func _floor_y(kind: String) -> float:
	if kind == "crate":
		return -0.15
	if kind == "helmet":
		return -0.31
	return -0.36


func _spawn(kind: String, local: Vector3, spawned: bool) -> void:
	_serial += 1
	var node_name := "Drop%d" % _serial
	var gltf := local / _scale
	gltf.y = _floor_y(kind)
	local = _cabin._v(gltf.x, gltf.y, gltf.z)
	var nodes: Array = []
	if kind == "crate":
		nodes.append(_Blocks.place(_cabin, node_name, gltf, Vector3(0.5, 0.5, 0.5), "crate"))
	elif kind == "mug":
		nodes.append(_cabin._cyl(node_name, local, 0.035, 0.07, Vector3.ZERO, _flat))
	elif kind == "helmet":
		_cabin._sphere(node_name, local, 0.09, _flat)
		nodes.append(_cabin.get_node(NodePath(node_name)))
		nodes.append(_cabin._box(node_name + "Visor", local + _cabin._v(0.07, 0.02, 0.0), _cabin._v(0.04, 0.05, 0.1), _dark, false))
	else:
		nodes.append(_cabin._box(node_name, local, _cabin._v(0.08, 0.12, 0.05), _dark, false))
	var blocker = null
	if kind == "crate" and _cabin.walker:
		blocker = _cabin._aabb(Vector3(local.x, 0.0, local.z), _cabin._v(0.5, 0.3, 0.5))
		_cabin.walker.boxes.append(blocker)
	_world.append({
		"id": kind,
		"count": 1,
		"nodes": nodes,
		"alive": true,
		"spawned": spawned,
		"pos": local,
		"gltf": gltf,
		"blocker": blocker,
	})


func _row_text(bank: String) -> String:
	var row: Array = slots[bank]
	var parts: PackedStringArray = PackedStringArray()
	for i in row.size():
		var slot: Dictionary = row[i]
		if int(slot["count"]) < 1:
			parts.append("-")
		elif int(slot["count"]) == 1:
			parts.append(str(KINDS[str(slot["id"])]))
		else:
			parts.append("%s x%d" % [str(KINDS[str(slot["id"])]), int(slot["count"])])
	return " ".join(parts)
