extends Node

## Scripted cabin, exterior, and Mina city passes. Writes frame time, draw calls, and node count.

var _main: Node
var _ship: Node
var _time := 0.0
var _phase := 0
var _samples: Array[Dictionary] = []
var _worst_ms := 0.0
var _worst_draws := 0
var _worst_nodes := 0
var _warm := 0


func setup(main: Node, ship: Node) -> void:
	_main = main
	_ship = ship
	_enter_cabin()


func _process(delta: float) -> void:
	_time += delta
	_sample(delta)
	if _phase == 0 and _time >= 2.0:
		_phase = 1
		_warm = 0
		_leave_cabin()
	elif _phase == 1 and _time >= 4.0:
		_phase = 2
		_warm = 0
		_enter_city()
	elif _phase == 2 and _time >= 6.0:
		_write()
		get_tree().quit()


func _sample(delta: float) -> void:
	_warm += 1
	if _warm < 12:
		return
	var ms := delta * 1000.0
	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if ms > _worst_ms:
		_worst_ms = ms
	if draws > _worst_draws:
		_worst_draws = draws
	if nodes > _worst_nodes:
		_worst_nodes = nodes
	_samples.append({"ms": ms, "draws": draws, "nodes": nodes, "phase": _phase})


func _enter_cabin() -> void:
	if _ship and _ship.has_method("start_cabin_view"):
		_ship.start_cabin_view("aisle")


func _leave_cabin() -> void:
	if _ship and _ship.has_method("dev_leave_cabin"):
		_ship.dev_leave_cabin()


func _enter_city() -> void:
	if _main and _main.has_method("_frame_mega"):
		_main._frame_mega("mega-canyon")


func _write() -> void:
	var total := 0.0
	for row in _samples:
		total += float(row["ms"])
	var avg := total / maxf(float(_samples.size()), 1.0)
	var pack := _pack_bytes()
	var text := "frames=%d avg_ms=%.2f worst_ms=%.2f worst_draws=%d worst_nodes=%d pack_bytes=%d\n" % [
		_samples.size(), avg, _worst_ms, _worst_draws, _worst_nodes, pack
	]
	var path := "user://bench.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()
	print("BENCH ", text.strip_edges())


func _pack_bytes() -> int:
	var root := ProjectSettings.globalize_path("res://")
	var total := 0
	total += _dir_bytes(root + "/assets")
	total += _dir_bytes(root + "/scripts")
	total += _dir_bytes(root + "/scenes")
	return total


func _dir_bytes(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var total := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name != "." and name != "..":
			var full := path + "/" + name
			if dir.current_is_dir():
				total += _dir_bytes(full)
			else:
				total += FileAccess.get_file_as_bytes(full).size()
		name = dir.get_next()
	return total
