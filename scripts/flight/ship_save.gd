extends RefCounted

## Versioned ship state, written as JSON.
## Sections: log, lights, flight, autopilot, extras.
## extras is open for a future ship name, cabin decorations, and upgrades.
## autopilot is owned by save_autopilot() when that ship can fly itself.
## A build that does not understand a section still writes it back.

const SAVE_VERSION := 1
const PATH := "user://akari_save.json"


static func migrate(data: Dictionary) -> Dictionary:
	var doc := data.duplicate(true)
	var version := int(doc.get("save_version", 0))
	var guard := 0
	while version < SAVE_VERSION and guard < 8:
		doc = _step(doc, version)
		var next := int(doc.get("save_version", 0))
		if next <= version:
			break
		version = next
		guard += 1
	return doc


static func _step(doc: Dictionary, version: int) -> Dictionary:
	if version <= 0:
		return _to_v1(doc)
	# The next save version adds a branch here and raises SAVE_VERSION.
	doc["save_version"] = version + 1
	return doc


static func _to_v1(doc: Dictionary) -> Dictionary:
	var next := doc.duplicate(true)
	if not (next.get("log", null) is Dictionary):
		next["log"] = {
			"elapsed": float(doc.get("elapsed", 0.0)),
			"flown": float(doc.get("flown", 0.0)),
			"cabin_time": float(doc.get("cabin_time", 0.0)),
			"entries": doc.get("entries", []),
			"flags": doc.get("flags", {}),
		}
	if not next.has("lights"):
		next["lights"] = ""
	if not (next.get("flight", null) is Dictionary):
		next["flight"] = {}
	if not (next.get("autopilot", null) is Dictionary):
		next["autopilot"] = {}
	if not (next.get("extras", null) is Dictionary):
		next["extras"] = {}
	next["save_version"] = 1
	return next


static func return_line(saved_unix: int, now_unix: int, mina_day: float) -> String:
	var away := maxi(now_unix - saved_unix, 0)
	if away <= 0:
		return ""
	var days := int(float(away) / maxf(mina_day, 1.0))
	if days <= 0:
		return "Pilot returned"
	if days == 1:
		return "Pilot returned after 1 Mina day away"
	return "Pilot returned after %d Mina days away" % days


static func read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _fresh("missing")
	return read_text(FileAccess.get_file_as_string(path))


static func read_text(text: String) -> Dictionary:
	# Garbage never reaches the parser, so a bad file stays a quiet fresh start.
	if text.find("\"") < 0:
		return _fresh("corrupt")
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return _fresh("corrupt")
	var version := int(parsed.get("save_version", 0))
	if version > SAVE_VERSION:
		return {"ok": false, "fresh": true, "blocked": true, "reason": "newer", "doc": {}}
	return {"ok": true, "fresh": false, "blocked": false, "reason": "", "doc": migrate(parsed)}


static func write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var tmp_abs := ProjectSettings.globalize_path(tmp)
	var dst_abs := ProjectSettings.globalize_path(path)
	var err := DirAccess.rename_absolute(tmp_abs, dst_abs)
	if err != OK:
		DirAccess.remove_absolute(dst_abs)
		err = DirAccess.rename_absolute(tmp_abs, dst_abs)
	return err == OK


static func _fresh(reason: String) -> Dictionary:
	return {"ok": false, "fresh": true, "blocked": false, "reason": reason, "doc": {}}
