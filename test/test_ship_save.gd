extends SceneTree

## Versioned atomic save: the ship log, the clock, the lights, and where the ship was.


func _init() -> void:
	var failed := _run()
	if failed > 0:
		push_error("Ship save tests failed (%d)." % failed)
		quit(1)
	else:
		print("Ship save tests passed.")
		quit(0)


func _run() -> int:
	var failed := 0
	var save_script: Script = load("res://scripts/flight/ship_save.gd")
	var keeper_script: Script = load("res://scripts/flight/ship_keeper.gd")
	var log_script: Script = load("res://scripts/flight/ship_log.gd")
	var term_script: Script = load("res://scripts/flight/cabin_terminal.gd")
	if save_script == null or keeper_script == null or log_script == null:
		push_error("ship save scripts missing")
		return 1
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path("user://save_test"))
	failed += _migrate(save_script)
	failed += _missing_and_corrupt(save_script)
	failed += _atomic(save_script)
	failed += _round_trip(keeper_script, log_script)
	failed += _return_line(save_script, keeper_script, log_script)
	failed += _hooks_survive(save_script, keeper_script, log_script)
	failed += _command(term_script)
	failed += _pause_and_timer(keeper_script, log_script)
	return failed


func _migrate(save_script: Script) -> int:
	var old := {
		"elapsed": 50.0,
		"flown": 12.0,
		"entries": [{"t": 1.0, "stamp": "D0 00:01", "text": "Pilot aboard"}],
	}
	var doc: Dictionary = save_script.migrate(old)
	if int(doc.get("save_version", 0)) != int(save_script.SAVE_VERSION):
		push_error("a versionless log should migrate up to the current save")
		return 1
	var log: Dictionary = doc.get("log", {})
	if absf(float(log.get("elapsed", -1.0)) - 50.0) > 0.01:
		push_error("migration should keep elapsed time")
		return 1
	var entries: Array = log.get("entries", [])
	if entries.is_empty() or str(entries[0].get("text", "")) != "Pilot aboard":
		push_error("migration should keep the old entries")
		return 1
	var current: Dictionary = save_script.migrate(doc)
	if int(current.get("save_version", 0)) != int(save_script.SAVE_VERSION):
		push_error("migrating the current version should leave it current")
		return 1
	if str(current.get("log", {}).get("entries", [])[0].get("text", "")) != "Pilot aboard":
		push_error("migrating the current version should keep the log")
		return 1
	var log_script: Script = load("res://scripts/flight/ship_log.gd")
	var restored = log_script.new()
	restored.from_save(doc.get("log", {}))
	restored.observe(0.1, 0.0, 800.0, 24.0, true, 0.0, false)
	if _count_text(restored, "Pilot aboard") != 1:
		push_error("a migrated log should not repeat aboard")
		return 1
	return 0


func _missing_and_corrupt(save_script: Script) -> int:
	var missing: Dictionary = save_script.read_path("user://save_test/does_not_exist.json")
	if missing.get("ok", true) or not missing.get("fresh", false):
		push_error("a missing save should start fresh")
		return 1
	var path := "user://save_test/corrupt.json"
	_write_raw(path, "{this is not json")
	var corrupt: Dictionary = save_script.read_path(path)
	if corrupt.get("ok", true) or not corrupt.get("fresh", false):
		push_error("a corrupt save should start fresh")
		return 1
	_write_raw(path, "{\"save_version\":99,\"log\":{}}")
	var newer: Dictionary = save_script.read_path(path)
	if newer.get("ok", true) or not newer.get("blocked", false):
		push_error("a newer save must not be treated as ours to overwrite")
		return 1
	return 0


func _atomic(save_script: Script) -> int:
	var path := "user://save_test/atomic.json"
	var first := {"save_version": 1, "log": {"elapsed": 3.0, "entries": []}}
	if not save_script.write_atomic(path, JSON.stringify(first)):
		push_error("atomic write failed")
		return 1
	_write_raw(path + ".tmp", "CRASHED MID WRITE")
	var kept: Dictionary = save_script.read_path(path)
	if not kept.get("ok", false):
		push_error("a crashed temp file should leave the last good save")
		return 1
	if absf(float(kept.get("doc", {}).get("log", {}).get("elapsed", -1.0)) - 3.0) > 0.01:
		push_error("the good save was replaced by the temp file")
		return 1
	var second := {"save_version": 1, "log": {"elapsed": 9.0, "entries": []}}
	if not save_script.write_atomic(path, JSON.stringify(second)):
		push_error("replacing a save failed")
		return 1
	var replaced: Dictionary = save_script.read_path(path)
	if absf(float(replaced.get("doc", {}).get("log", {}).get("elapsed", -1.0)) - 9.0) > 0.01:
		push_error("the new save should replace the old one")
		return 1
	return 0


func _round_trip(keeper_script: Script, log_script: Script) -> int:
	var path := "user://save_test/round.json"
	var host := Host.new(log_script)
	host.lamps.preset = "cold"
	host.position = Vector3(12.0, -4.0, 30.0)
	host.velocity = Vector3(1.5, 0.25, -3.0)
	host.basis = Basis(Vector3.UP, 0.5)
	var log = host.ship_log()
	log.mark_aboard()
	log.observe(log_script.MINA_DAY * 2.0, 0.0, 800.0, 24.0, true, 0.0, false)
	var keeper = keeper_script.new()
	keeper.setup(host, path)
	keeper.unix_override = 500000
	if not keeper.save_now():
		push_error("save_now failed")
		return 1
	var raw := FileAccess.get_file_as_string(path)
	if not raw.contains("\"save_version\""):
		push_error("the file should name its save_version")
		return 1
	var other := Host.new(log_script)
	var loaded = keeper_script.new()
	loaded.setup(other, path)
	loaded.unix_override = 500000
	var result: Dictionary = loaded.load_now()
	if not result.get("ok", false):
		push_error("load failed")
		return 1
	var back = other.ship_log()
	if absf(back.elapsed - log.elapsed) > 0.01:
		push_error("elapsed time did not round trip")
		return 1
	if back.page().find("Pilot aboard") < 0:
		push_error("the log entries did not round trip: %s" % back.page())
		return 1
	if _count_text(back, "Pilot aboard") != 1:
		push_error("loading should not add a second aboard line")
		return 1
	back.observe(0.2, 0.0, 800.0, 24.0, true, 0.0, false)
	if _count_text(back, "Pilot aboard") != 1:
		push_error("continuing after a load should not repeat aboard")
		return 1
	if other.lamps.preset != "cold":
		push_error("lights preset did not round trip")
		return 1
	if other.position.distance_to(Vector3(12.0, -4.0, 30.0)) > 0.01:
		push_error("position did not round trip")
		return 1
	if other.velocity.distance_to(Vector3(1.5, 0.25, -3.0)) > 0.01:
		push_error("velocity did not round trip")
		return 1
	var aim: Vector3 = other.basis * Vector3(0, 0, -1)
	var want: Vector3 = Basis(Vector3.UP, 0.5) * Vector3(0, 0, -1)
	if aim.distance_to(want) > 0.02:
		push_error("orientation did not round trip")
		return 1
	return 0


func _return_line(save_script: Script, keeper_script: Script, log_script: Script) -> int:
	var path := "user://save_test/return.json"
	var host := Host.new(log_script)
	host.ship_log().note("Pilot aboard")
	var keeper = keeper_script.new()
	keeper.setup(host, path)
	keeper.unix_override = 1000000
	keeper.save_now()
	var other := Host.new(log_script)
	var loaded = keeper_script.new()
	loaded.setup(other, path)
	loaded.unix_override = 1000000 + int(log_script.MINA_DAY) * 2
	loaded.load_now()
	var page: String = other.ship_log().page()
	if not page.contains("Pilot returned after 2 Mina days away"):
		push_error("two Mina days away should be noted, got %s" % page)
		return 1
	if save_script.return_line(10, 10, 180.0) != "":
		push_error("no time away should not add a return line")
		return 1
	return 0


func _hooks_survive(save_script: Script, keeper_script: Script, log_script: Script) -> int:
	var path := "user://save_test/hooks.json"
	var planted := {
		"save_version": 1,
		"saved_unix": 20,
		"log": {"elapsed": 4.0, "entries": [{"t": 0.0, "stamp": "D0 00:00", "text": "Pilot aboard"}], "flags": {"aboard": true}},
		"lights": "",
		"flight": {},
		"autopilot": {"mode": "orbit"},
		"extras": {"ship_name": "DRIFTER", "decorations": ["plant"], "upgrades": ["lamp"]},
	}
	save_script.write_atomic(path, JSON.stringify(planted))
	var host := Host.new(log_script)
	if host.has_method("save_autopilot") or host.has_method("save_extras"):
		push_error("the host should keep autopilot and extras as hooks")
		return 1
	var keeper = keeper_script.new()
	keeper.setup(host, path)
	keeper.unix_override = 20
	keeper.load_now()
	keeper.save_now()
	var again: Dictionary = save_script.read_path(path)
	var doc: Dictionary = again.get("doc", {})
	if str(doc.get("autopilot", {}).get("mode", "")) != "orbit":
		push_error("autopilot state should survive a save on a build that does not fly it")
		return 1
	var extras: Dictionary = doc.get("extras", {})
	if str(extras.get("ship_name", "")) != "DRIFTER" or not extras.has("decorations") or not extras.has("upgrades"):
		push_error("future extras should round trip untouched")
		return 1
	return 0


func _command(term_script: Script) -> int:
	var lamps_script: Script = load("res://scripts/flight/cabin_lamps.gd")
	var lamps = lamps_script.new()
	var help: String = term_script.submit("SAVE", lamps)
	if help != "SHIP STATE SAVED":
		push_error("SAVE should print SHIP STATE SAVED, got %s" % help)
		return 1
	var listed: String = term_script.submit("HELP", lamps)
	if not listed.contains("SAVE"):
		push_error("HELP should list SAVE, got %s" % listed)
		return 1
	return 0


func _pause_and_timer(keeper_script: Script, log_script: Script) -> int:
	var path := "user://save_test/pause.json"
	_remove(path)
	var host := Host.new(log_script)
	host.ship_log().note("Pilot aboard")
	var keeper = keeper_script.new()
	keeper.setup(host, path)
	keeper.interval = 60.0
	keeper._process(59.0)
	if FileAccess.file_exists(path):
		push_error("autosave fired before 60 seconds")
		return 1
	keeper._process(1.0)
	if not FileAccess.file_exists(path):
		push_error("autosave should fire at 60 seconds")
		return 1
	_remove(path)
	keeper._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if not FileAccess.file_exists(path):
		push_error("pausing the app should save")
		return 1
	_remove(path)
	keeper._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if not FileAccess.file_exists(path):
		push_error("closing the window should save")
		return 1
	var blocked_path := "user://save_test/blocked.json"
	_write_raw(blocked_path, "{\"save_version\":99}")
	var blocked = keeper_script.new()
	blocked.setup(Host.new(log_script), blocked_path)
	var result: Dictionary = blocked.load_now()
	if not result.get("blocked", false):
		push_error("a newer file should block the keeper")
		return 1
	if blocked.save_now():
		push_error("a blocked keeper must not overwrite a newer save")
		return 1
	var still := FileAccess.get_file_as_string(blocked_path)
	if not still.contains("99"):
		push_error("the newer save was overwritten")
		return 1
	return 0


func _count_text(log, text: String) -> int:
	var count := 0
	for item in log.entries:
		if str(item.get("text", "")) == text:
			count += 1
	return count


func _write_raw(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


class Lamps:
	extends RefCounted
	var preset := ""

	func lamp_preset() -> String:
		return preset

	func restore_lamp_preset(name: String) -> void:
		preset = name


## The same methods the ship implements. Autopilot and extras stay optional hooks.
class Host:
	extends RefCounted
	var lamps: Lamps
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var basis := Basis.IDENTITY
	var _log

	func _init(log_script: Script) -> void:
		lamps = Lamps.new()
		_log = log_script.new()

	func ship_log():
		return _log

	func cabin_lamp_preset() -> String:
		return lamps.lamp_preset()

	func restore_lamp_preset(name: String) -> void:
		lamps.restore_lamp_preset(name)

	func capture_flight() -> Dictionary:
		var b := basis
		return {
			"position": [position.x, position.y, position.z],
			"velocity": [velocity.x, velocity.y, velocity.z],
			"basis": [b.x.x, b.x.y, b.x.z, b.y.x, b.y.y, b.y.z, b.z.x, b.z.y, b.z.z],
		}

	func apply_flight(packet: Dictionary) -> void:
		var p: Array = packet.get("position", [])
		if p.size() == 3:
			position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		var v: Array = packet.get("velocity", [])
		if v.size() == 3:
			velocity = Vector3(float(v[0]), float(v[1]), float(v[2]))
		var raw: Array = packet.get("basis", [])
		if raw.size() == 9:
			basis = Basis(
				Vector3(float(raw[0]), float(raw[1]), float(raw[2])),
				Vector3(float(raw[3]), float(raw[4]), float(raw[5])),
				Vector3(float(raw[6]), float(raw[7]), float(raw[8]))
			)
