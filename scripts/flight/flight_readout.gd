extends RefCounted

## Four cockpit numbers. tick() is the 10 Hz gate; block() is the CRT text.

const INTERVAL := 0.1

var wait := 0.0


func tick(delta: float) -> bool:
	wait -= delta
	if wait > 0.0:
		return false
	wait = INTERVAL
	return true


static func block(speed: int, alt: int, heading: int, thrust: float) -> String:
	var spd := maxi(speed, 0)
	var height := maxi(alt, 0)
	var hdg := int(posmod(heading, 360))
	var thr := clampf(thrust, 0.0, 1.0)
	return "SPD %03d\nALT %05d\nHDG %03d\nTHR %04.2f" % [spd, height, hdg, thr]


## One glass: flight numbers, autopilot, and the old side and bay lines.
static func page(readout: String, orbit: bool, ship_name: String, hull: int, mina: String, bay_state: String) -> String:
	var text := readout
	if orbit:
		text += "\nAUTOPILOT: ORBIT"
	var rest := "\n%s\nHULL %d  MINA %s  BRG FWD\nBAY %s  CORE 312" % [ship_name, hull, mina, bay_state]
	text += rest
	return text
