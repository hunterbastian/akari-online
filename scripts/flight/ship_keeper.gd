extends Node

## Autosave and resume. The per-frame path only adds a float.
## The file write happens on the 60 second mark, on SAVE, and when the app pauses or closes.

const _Save := preload("res://scripts/flight/ship_save.gd")

var interval := 60.0
var unix_override := -1
var armed := true
var blocked := false

var _host
var _path := ""
var _wait := 0.0
var _carried_autopilot: Dictionary = {}
var _carried_extras: Dictionary = {}


func setup(host, path: String) -> void:
	_host = host
	_path = path


func save_now() -> bool:
	if blocked or _host == null or _path.is_empty():
		return false
	return _Save.write_atomic(_path, JSON.stringify(_capture()))


func load_now() -> Dictionary:
	var result: Dictionary = _Save.read_path(_path)
	blocked = bool(result.get("blocked", false))
	if not result.get("ok", false):
		return result
	_apply(result.get("doc", {}))
	return result


func wipe() -> void:
	blocked = false
	_carried_autopilot = {}
	_carried_extras = {}
	if _path.is_empty():
		return
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
	var tmp := _path + ".tmp"
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))


func _process(delta: float) -> void:
	if not armed or blocked:
		return
	_wait += delta
	if _wait < interval:
		return
	_wait = 0.0
	save_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


func _exit_tree() -> void:
	# quit() does not send a close request. Leaving the tree still has to land the file.
	if armed:
		save_now()


func _now() -> int:
	if unix_override >= 0:
		return unix_override
	return int(Time.get_unix_time_from_system())


func _log():
	if _host != null and _host.has_method("ship_log"):
		return _host.ship_log()
	return null


func _capture() -> Dictionary:
	var log_packet: Dictionary = {}
	var log = _log()
	if log != null and log.has_method("to_save"):
		var packet = log.to_save()
		if packet is Dictionary:
			log_packet = packet
	var lights := ""
	if _host.has_method("cabin_lamp_preset"):
		lights = str(_host.cabin_lamp_preset())
	var flight: Dictionary = {}
	if _host.has_method("capture_flight"):
		var captured = _host.capture_flight()
		if captured is Dictionary:
			flight = captured
	var autopilot := _carried_autopilot.duplicate(true)
	if _host.has_method("save_autopilot"):
		var owned = _host.save_autopilot()
		if owned is Dictionary:
			autopilot = owned
	var extras := _carried_extras.duplicate(true)
	if _host.has_method("save_extras"):
		var extra = _host.save_extras()
		if extra is Dictionary:
			extras.merge(extra, true)
	return {
		"save_version": _Save.SAVE_VERSION,
		"saved_unix": _now(),
		"log": log_packet,
		"lights": lights,
		"flight": flight,
		"autopilot": autopilot,
		"extras": extras,
	}


func _apply(doc: Dictionary) -> void:
	var carried_auto = doc.get("autopilot", {})
	if carried_auto is Dictionary:
		_carried_autopilot = carried_auto.duplicate(true)
	var carried_extra = doc.get("extras", {})
	if carried_extra is Dictionary:
		_carried_extras = carried_extra.duplicate(true)
	var log = _log()
	var packet = doc.get("log", {})
	if log != null and packet is Dictionary and log.has_method("from_save"):
		log.from_save(packet)
	if _host.has_method("restore_lamp_preset"):
		var lights := str(doc.get("lights", ""))
		if not lights.is_empty():
			_host.restore_lamp_preset(lights)
	var flight = doc.get("flight", {})
	if flight is Dictionary and not flight.is_empty() and _host.has_method("apply_flight"):
		_host.apply_flight(flight)
	if not _carried_autopilot.is_empty() and _host.has_method("load_autopilot"):
		_host.load_autopilot(_carried_autopilot)
	if not _carried_extras.is_empty() and _host.has_method("load_extras"):
		_host.load_extras(_carried_extras)
	if log != null and log.has_method("note"):
		var day := float(log.MINA_DAY)
		var line := _Save.return_line(int(doc.get("saved_unix", _now())), _now(), day)
		if not line.is_empty():
			log.note(line)
