extends RefCounted

## Session captain's log. to_save() is the packet a future save system can write.

const MINA_DAY := 180.0
const ORBIT := 2.0
const AIR := 1.15
const FLOWN_STEP := 250.0

var elapsed := 0.0
var flown := 0.0
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


func mark_aboard() -> void:
	if _aboard:
		return
	_aboard = true
	note("Pilot aboard")


func note(text: String) -> void:
	entries.append({"t": elapsed, "stamp": _stamp(), "text": text})
	blip = true


func observe(delta: float, speed: float, alt: float, radius: float, aboard: bool, thrust: float, bay_open: bool) -> void:
	elapsed += delta
	if speed > 0.0:
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
		"count": entries.size(),
		"entries": entries.duplicate(true),
	}


func _stamp() -> String:
	var day := int(elapsed / MINA_DAY)
	var into := int(elapsed) % int(MINA_DAY)
	var minute := int(into / 60.0)
	var second := into % 60
	return "D%d %02d:%02d" % [day, minute, second]
