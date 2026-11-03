extends RefCounted

## One-line cabin terminal. HELP lists commands. LIGHTS is the first one.
## Later commands (AUTOPILOT, SCAN) can match here the same way.


static func submit(line: String, lamps, log = null) -> String:
	var text := line.strip_edges().to_upper()
	if text.is_empty():
		return ""
	var parts := text.split(" ", false)
	var cmd := str(parts[0])
	if cmd == "HELP":
		return "HELP  LIGHTS  LOG"
	if cmd == "LOG":
		if log == null:
			return "LOG EMPTY"
		return log.page()
	if cmd != "LIGHTS":
		return "?"
	if parts.size() < 2:
		return "WARM  COLD  RED  OFF"
	if not lamps.set_preset(str(parts[1]).to_lower()):
		return "LIGHTS?"
	return "LIGHTS " + str(parts[1])
