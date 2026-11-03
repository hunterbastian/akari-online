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
		return "HELP  LIGHTS  LOG  TIME  AUTOPILOT  SAVE  LOOK"
	if cmd == "TIME":
		if log == null or not log.has_method("time_report"):
			return "TIME?"
		return log.time_report()
	if cmd == "SAVE":
		return "SHIP STATE SAVED"
	if cmd == "LOG":
		if log == null:
			return "LOG EMPTY"
		return log.page()
	if cmd == "STOP":
		return "AUTOPILOT OFF"
	if cmd == "AUTOPILOT":
		if parts.size() < 2:
			return "ORBIT  OFF"
		if str(parts[1]) == "ORBIT":
			return "AUTOPILOT ORBIT"
		if str(parts[1]) == "OFF":
			return "AUTOPILOT OFF"
		return "AUTOPILOT?"
	if cmd == "LOOK":
		if parts.size() < 2:
			return "SIXTH  MODERN  PHONE"
		var choice := str(parts[1])
		if choice != "SIXTH" and choice != "MODERN" and choice != "PHONE":
			return "LOOK?"
		return "LOOK " + choice
	if cmd != "LIGHTS":
		return "?"
	if parts.size() < 2:
		return "WARM  COLD  RED  OFF"
	if not lamps.set_preset(str(parts[1]).to_lower()):
		return "LIGHTS?"
	return "LIGHTS " + str(parts[1])
