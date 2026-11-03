extends RefCounted

## Line editing for the seat CRT: history, tab completion, and a typo hint.

const COMMANDS: PackedStringArray = ["HELP", "LIGHTS", "LOG", "TIME", "AUTOPILOT", "SAVE", "STOP"]
const LIGHTS: PackedStringArray = ["WARM", "COLD", "RED", "OFF"]
const MODES: PackedStringArray = ["ORBIT", "OFF"]

var line := ""
var history: Array[String] = []
var _at := -1
var _draft := ""


func type_char(ch: String) -> void:
	if line.length() >= 24:
		return
	line += ch.to_upper()
	_at = -1


func backspace() -> void:
	line = line.substr(0, maxi(line.length() - 1, 0))
	_at = -1


func remember(text: String) -> void:
	var clean := text.strip_edges()
	line = ""
	_at = -1
	_draft = ""
	if clean.is_empty():
		return
	if history.is_empty() or history[history.size() - 1] != clean:
		history.append(clean)
	if history.size() > 24:
		history.remove_at(0)


func up() -> void:
	if history.is_empty():
		return
	if _at < 0:
		_draft = line
		_at = history.size() - 1
	elif _at > 0:
		_at -= 1
	line = history[_at]


func down() -> void:
	if _at < 0:
		return
	_at += 1
	if _at >= history.size():
		_at = -1
		line = _draft
		return
	line = history[_at]


func complete() -> void:
	var done := complete_text(line)
	if done != "":
		line = done
	_at = -1


static func complete_text(source: String) -> String:
	var upper := source.to_upper()
	if upper.strip_edges().is_empty():
		return "HELP"
	var trailing := upper.ends_with(" ")
	var parts := upper.split(" ", false)
	if parts.size() == 1 and not trailing:
		var cmd := _finish(str(parts[0]), COMMANDS)
		return cmd if cmd != "" else source
	var head := str(parts[0])
	if head == "LIGHTS":
		var pref := ""
		if not trailing and parts.size() >= 2:
			pref = str(parts[1])
		var preset := _finish(pref, LIGHTS)
		if preset == "":
			return source
		return "LIGHTS " + preset
	if head == "AUTOPILOT":
		var mode_pref := ""
		if not trailing and parts.size() >= 2:
			mode_pref = str(parts[1])
		var mode := _finish(mode_pref, MODES)
		if mode == "":
			return source
		return "AUTOPILOT " + mode
	return source


static func suggest(cmd: String) -> String:
	var best := ""
	var best_d := 99
	for name in COMMANDS:
		var dist := _dist(cmd, name)
		if dist < best_d:
			best_d = dist
			best = name
	if best == "" or best_d == 0 or best_d > 2:
		return "?"
	return "?  TRY " + best


static func _finish(prefix: String, options: PackedStringArray) -> String:
	var matches: PackedStringArray = PackedStringArray()
	for opt in options:
		if prefix.is_empty() or str(opt).begins_with(prefix):
			matches.append(str(opt))
	if matches.is_empty():
		return ""
	if matches.size() == 1:
		return matches[0]
	var common := matches[0]
	for i in range(1, matches.size()):
		common = _shared(common, matches[i])
	if common.length() <= prefix.length():
		return ""
	return common


static func _shared(a: String, b: String) -> String:
	var n := mini(a.length(), b.length())
	var i := 0
	while i < n and a.unicode_at(i) == b.unicode_at(i):
		i += 1
	return a.substr(0, i)


static func _dist(a: String, b: String) -> int:
	var n := a.length()
	var m := b.length()
	var prev: Array[int] = []
	var cur: Array[int] = []
	prev.resize(m + 1)
	cur.resize(m + 1)
	for j in m + 1:
		prev[j] = j
	for i in n:
		cur[0] = i + 1
		for j in m:
			var cost := 0 if a.unicode_at(i) == b.unicode_at(j) else 1
			cur[j + 1] = mini(cur[j] + 1, mini(prev[j + 1] + 1, prev[j] + cost))
		var swap := prev
		prev = cur
		cur = swap
	return prev[m]
