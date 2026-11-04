class_name FlightProfile
extends RefCounted

## flySpace tuning from the web flight model. Frame delta is capped at DT_CAP.
## Speeds come from flightProfile(ship.stats.speed) in shared/universe.js.

const MOUSE_YAW := 0.0032
const MOUSE_PITCH := 0.0022
const KEY_YAW_RATE := 1.15
const PITCH_LIMIT := 1.05
const BANK_YAW_SCALE := 5.5
const BANK_LIMIT := 0.42
const BANK_DAMP := 5.0
const THROTTLE_LERP := 2.5
const COAST_DRAG := 0.32
const REVERSE_SCALE := 0.45
const VERTICAL_ACCEL := 16.0
const CAM_DIST := 7.6
const CAM_DIST_BOOST := 9.2
const CAM_HEIGHT := 1.15
const CAM_CHASE := 5.2
const CAM_LOOK_AHEAD := 28.0
const FOV := 52.0
const FOV_BOOST := 60.0
const FOV_DAMP := 4.0
## Extra degrees at full thrust. Smoothstep in over KICK_IN_TIME, out over KICK_OUT_TIME.
const KICK_FOV := 9.0
const KICK_IN_TIME := 1.5
const KICK_OUT_TIME := 1.5
## How long the heavy sway and the chase lag take to build.
const SWAY_TIME := 1.4
## Camera shake scale. 0 holds the view still. 1 is the default sway.
const SHAKE := 1.0
## Radians of pitch sway at full thrust. Roll uses a little more.
const SHAKE_SWAY := 0.011
const PUSH_IN := 0.45
const PUSH_OUT := 1.15
const PUSH_NOD := 0.018
## Cabin feels the burn harder than the chase camera.
const CABIN_SWAY := 1.9
const CABIN_PUSH := 0.13
const CABIN_HOLD := 0.045
const CABIN_FOV := 1.35
## Outside streaks are a milder version of the cabin window streaks.
const STREAK_OUT := 0.42
## Extra chase distance, in meters, once the boost has fully settled.
const CAM_LAG := 3.6
const CAM_CHASE_BOOST := 1.55
## Cabin head bob. 0 holds the view still. 1 is the default gentle walk.
const BOB := 1.0
const DT_CAP := 0.05
const HULL_SCALE := 1.28
## jumpship.glb is about 7.0 wide. 0.466 brings that in line with the old hull's chase-cam size.
const JUMPSHIP_SCALE := 0.466
const STAR_CLEARANCE := 12.0
const PLANET_CLEARANCE := 8.0
const SPAWN := Vector3(0, 6, 48)
## Directional key from the space scene, aimed at the origin.
const SUN_OFFSET := Vector3(28, 46, 18)

## Nozzle centers in glTF space. From the ship entry in model meta.
## Fallback nozzle mouths in jumpship.glb space. Dress code measures the real cores.
const ENGINE_ANCHORS = [Vector3(-1.55, -0.04, 3.42), Vector3(1.55, -0.04, 3.42)]


static func for_speed_stat(speed_stat: float = 1.0) -> Dictionary:
	var safe := speed_stat if speed_stat != 0.0 else 1.0
	var agility := minf(2.4, 1.0 / safe)
	var cruise := 30.0 * (0.85 + 0.28 * agility)
	return {
		"cruise": cruise,
		"boost": cruise * 2.05,
		"pulse": 120.0 * (0.92 + 0.2 * agility),
	}


static func damp(current: float, target: float, lambda: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-lambda * delta))
