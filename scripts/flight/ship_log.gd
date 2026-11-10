extends RefCounted

## Session captain's log. to_save() is the packet a future save system can write.

const MINA_DAY := 180.0
const ORBIT := 2.0
const AIR := 1.15
const FLOWN_STEP := 250.0

var elapsed := 0.0
var flown := 0.0
var flight_time := 0.0
var cabin_time := 0.0
var entries: Array[Dictionary] = []
var blip := false

var _aboard := false
var _burn := false
var _orbit := false
var _air := false
var _bay := false
var _space_mark := 0
var _cabin_mark := false
var _flown_mark := 0
var _eva_out := false


func mark_aboard() -> void:
	if _aboard:
		return
	_aboard = true
	note("Pilot aboard")


func mark_eva_out() -> void:
	if _eva_out:
		return
	_eva_out = true
	note("Pilot stepped out")


func mark_eva_in() -> void:
	if not _eva_out:
		return
	_eva_out = false
	note("Pilot returned to the ship")


func note(text: String) -> void:
	entries.append({"t": elapsed, "stamp": _stamp(), "text": text})
	blip = true


func observe(delta: float, speed: float, alt: float, radius: float, aboard: bool, thrust: float, bay_open: bool) -> void:
	elapsed += delta
	if speed > 0.4:
		flight_time += delta
		flown += speed * delta
	if aboard:
		cabin_time += delta
	if aboard and not _aboard:
		note("Pilot aboard")
	_aboard = aboard
	if thrust >= 0.8 and not _burn:
		_burn = true
		note("First burn")
	var span := maxf(radius, 1.0)
	if not _orbit and alt < span * ORBIT:
		_orbit = true
		note("Pilot went to Mina")
	if not _air and alt < span * AIR:
		_air = true
		note("Pilot entered Mina air")
	if bay_open and not _bay:
		note("Bay open")
	_bay = bay_open
	var days := int(elapsed / MINA_DAY)
	if days >= 3 and _space_mark < 3:
		_space_mark = days
		note("Pilot has been in space for 3 Mina days")
	if cabin_time >= MINA_DAY and not _cabin_mark:
		_cabin_mark = true
		note("Pilot has spent a Mina day aboard")
	var mark := int(flown / FLOWN_STEP)
	if mark > _flown_mark:
		_flown_mark = mark
		note("Flown %d" % int(mark * FLOWN_STEP))


func page() -> String:
	blip = false
	if entries.is_empty():
		return "LOG EMPTY"
	var lines := ""
	var start := maxi(entries.size() - 6, 0)
	for i in range(start, entries.size()):
		if not lines.is_empty():
			lines += "\n"
		var item: Dictionary = entries[i]
		lines += str(item.stamp) + "  " + str(item.text)
	return lines


func to_save() -> Dictionary:
	return {
		"elapsed": elapsed,
		"flown": flown,
		"flight_time": flight_time,
		"cabin_time": cabin_time,
		"count": entries.size(),
		"entries": entries.duplicate(true),
		"flags": {
			"aboard": _aboard,
			"burn": _burn,
			"orbit": _orbit,
			"air": _air,
			"bay": _bay,
			"space_mark": _space_mark,
			"cabin_mark": _cabin_mark,
			"flown_mark": _flown_mark,
			"eva_out": _eva_out,
		},
	}


func time_report() -> String:
	return "SHIP %s\nFLOWN %s\nSPACE %s" % [_clock(elapsed), _hms(flight_time), _hms(elapsed)]


func from_save(data: Dictionary) -> void:
	elapsed = float(data.get("elapsed", 0.0))
	flown = float(data.get("flown", 0.0))
	flight_time = float(data.get("flight_time", 0.0))
	cabin_time = float(data.get("cabin_time", 0.0))
	entries.clear()
	var raw = data.get("entries", [])
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				entries.append({
					"t": float(item.get("t", 0.0)),
					"stamp": str(item.get("stamp", "")),
					"text": str(item.get("text", "")),
				})
	blip = false
	_aboard = false
	_burn = false
	_orbit = false
	_air = false
	_bay = false
	_space_mark = 0
	_cabin_mark = false
	_flown_mark = 0
	_eva_out = false
	var flags = data.get("flags", {})
	if flags is Dictionary and not flags.is_empty():
		_aboard = bool(flags.get("aboard", false))
		_burn = bool(flags.get("burn", false))
		_orbit = bool(flags.get("orbit", false))
		_air = bool(flags.get("air", false))
		_bay = bool(flags.get("bay", false))
		_space_mark = int(flags.get("space_mark", 0))
		_cabin_mark = bool(flags.get("cabin_mark", false))
		_flown_mark = int(flags.get("flown_mark", 0))
		_eva_out = bool(flags.get("eva_out", false))
	else:
		_infer_flags()
	# Leaving the seat clears the live flag. The entry is what makes boarding permanent.
	if not _aboard:
		for item in entries:
			if str(item.get("text", "")) == "Pilot aboard":
				_aboard = true
				break


func _infer_flags() -> void:
	for item in entries:
		var text := str(item.get("text", ""))
		if text == "Pilot aboard":
			_aboard = true
		elif text == "First burn":
			_burn = true
		elif text == "Pilot went to Mina":
			_orbit = true
		elif text.contains("Mina air"):
			_air = true
		elif text == "Bay open":
			_bay = true
		elif text.contains("Mina day aboard"):
			_cabin_mark = true
		elif text.contains("3 Mina days"):
			_space_mark = 3
	if _space_mark < 3 and elapsed >= MINA_DAY * 3.0:
		_space_mark = int(elapsed / MINA_DAY)
	if not _cabin_mark and cabin_time >= MINA_DAY:
		_cabin_mark = true
	var mark := int(flown / FLOWN_STEP)
	if mark > _flown_mark:
		_flown_mark = mark


func _stamp() -> String:
	return _clock(elapsed)


func _clock(t: float) -> String:
	var day := int(t / MINA_DAY)
	var frac := fmod(maxf(t, 0.0), MINA_DAY) / MINA_DAY
	var mins := int(frac * 24.0 * 60.0)
	return "D%d %02d:%02d" % [day, int(mins / 60.0), mins % 60]


func _hms(t: float) -> String:
	var whole := int(maxf(t, 0.0))
	var hour := int(whole / 3600.0)
	var minute := int(whole / 60.0) % 60
	var second := whole % 60
	return "%02d:%02d:%02d" % [hour, minute, second]
