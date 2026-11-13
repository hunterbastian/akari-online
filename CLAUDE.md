# AKARI ONLINE

Handoff for continuing this game in Claude Code. Godot 4.6 project (Hunter plays 4.6.1 on macOS). GDScript. Desktop renderer is Forward+. iOS is set to the Mobile renderer for a later export. Physics is Jolt at 120 Hz.

This is its own game. It is not a 0x10c copy.

## Run

Open `project.godot` and press Play, or:

```
godot --path .
```

The title drifts past Mina. Any key or click fades into flight. Click the view to capture the mouse.

There is no `--mock` flag. Headless checks and the demo flags below are the stand-ins.

```
tools/check.sh
```

That runs the lint, every test, and the performance bench. Godot must be 4.6. The bench needs a display (the script uses xvfb when `DISPLAY` is unset).

### Controls

- W / S or arrows: throttle
- A / D or arrows: yaw
- Mouse: look
- Shift: boost
- Space / Ctrl: rise and drop
- Esc: release the mouse
- E: stand up from the seat into the cabin. Walk with WASD. E beside the seat sits back down. E by the bay lever opens the door. The green HUD says `E  STAND UP` while seated and `E  SIT` near the seat.

The flight world is drawn in a low-res `SubViewport` (`handle_input_locally = false`). `Main._input` forwards window events into that view with `push_input`. Flight keys are also polled from `Input` in the ship loop. Do not handle one-shot keys only inside the ship's `_input` without that forward, or they never arrive.

### Useful flags

- `--bench` performance run
- `--state-test` statechart plus atmosphere
- `--stand-test` presses E in flight and expects the pilot to be walking
- `--thrust-demo inside|outside`
- `--lights warm|cold|red|off` and `--lights-demo`
- `--walk-demo` head bob
- `--readout-demo` cockpit CRT numbers
- `--log-demo` `--time-demo`
- `--orbit-demo` and `--orbit-demo out`
- `--save-demo write` then `--save-demo read`
- `--tour`, `--atmo`, `--hull`, `--mega` are shot and tour tools

## Vision

The ship is home. You personalize it and it grows with you.

- Exterior: hand-made glossy white Destiny 1-inspired Blender jumpship, `assets/ships/jumpship.glb`, no Draco, dithered.
- Interior: blocky warehouse cabin and a Star Trek-style shuttle bay door.
- Ship computer: retro CRT-green screens only. No floating HUD glass. The only overlay is the small green pixel speed line and the E hint.
- Look: flat 2012-Minecraft lighting (per-face shading, soft corner AO, contact shadows) plus a little shader polish. Pixelated and dithered. Destiny filmic grade: teal shadows, warm highlights, lifted blacks, bloom, film grain.
- Mina: brutalist megastructures are the style reference. City work is paused.

## Code health

Every fixed bug gets a lint rule in `tools/lint.py` or a test under `test/`. A function marked `# hot` on the line above it must not allocate: no `.new()`, lambdas, string concat or formatting, or Array/Dictionary literals. `tools/check.sh` enforces that.

Performance budget in `tools/budget.py`, last measured on this merge:

- worst frame 75.0 ms (limit 140)
- 203 draw calls (limit 500)
- 414 nodes (limit 1200)
- pack 1,268,052 bytes (limit 1.8 MB)

## Architecture

`scripts/main.gd` builds the world, title, ship, and demos.

- `scripts/flight/ship_controller.gd` flight loop, seat toggle, flames, CRT readout push, ship log tick, orbit coast, save capture.
- `scripts/flight/chase_camera.gd` exterior camera. `scripts/flight/thrust_kick.gd` and `thrust_feel.gd` ease FOV, sway, and lag. Star streaks are `assets/shaders/star_streak.gdshader`. Tune with `FlightProfile` in `scripts/data/flight_profile.gd`: `SHAKE` (0 off, 1 default), `KICK_FOV`, `KICK_IN_TIME` (1.5 s), `CAM_LAG`, `STREAK_OUT`, `BOB` (0 off, 1 the gentle walk).
- `scripts/flight/cabin_interior.gd` warehouse cabin, CRT, terminal keyboard, lamps. `cabin_walker.gd` plus `cabin_bob.gd` walk and bob. `cabin_bay_door.gd` the shuttle bay. `cabin_lamps.gd` LIGHTS presets. The sun in `FlightProfile.SUN_OFFSET` is low and amber, with `FILL_COLOR` on the far side. Mina's limb carries a warm haze band. The nose glass casts `SunShaft`, aimed from the sun each frame, and phones skip that mesh. Those lights are on the world and the hull paint, so a spacewalk camera that can see the hull gets the same rim.
- `scripts/flight/cabin_terminal.gd` `submit(line, lamps, log)`. Add a command by matching the first word next to HELP, LOG, TIME, AUTOPILOT, and SAVE, and teach `terminal_submit()` in the cabin if the command has a side effect. HELP is one line: `HELP  LIGHTS  LOG  TIME  AUTOPILOT  SAVE`.
- LIGHTS: `WARM`, `COLD`, `RED`, `OFF`. The cabin notes the change in the log.
- `scripts/flight/ship_log.gd` session log. `MINA_DAY` is 180 real seconds. `note("text")` stamps ship time. `observe()` adds the automatic lines (aboard, first burn, Mina, air, bay, days). Add a new automatic event there, not in a `# hot` function.
- TIME prints ship clock (Mina days plus hh:mm of a 24-hour day squeezed into 180 real seconds), real time flown, and total time in space.
- `scripts/flight/orbit_pilot.gd` circular orbit. `AUTOPILOT ORBIT` eases onto it. Manual thrust, yaw, lift, or boost cancels it while seated. `AUTOPILOT OFF` and `STOP` cancel from anywhere. Walking the cabin does not cancel it. Engaging notes `Autopilot set to orbit Mina`.
- `scripts/flight/ship_save.gd` and `ship_keeper.gd` write `user://akari_save.json`. The file has `save_version` (currently 1). `migrate()` lifts an old bare log into version 1. A newer file is left alone. Writes go to a temp file, then rename. Sections: `log`, `lights`, `flight`, `autopilot`, `extras`. `extras` is the open slot for a ship name, decorations, and upgrades. The ship implements `save_autopilot()` / `load_autopilot()`. Autosave is about every 60 s, and also on pause, window close, and quit. `SAVE` prints `SHIP STATE SAVED`. A return notes `Pilot returned after N Mina days away` when at least one Mina day passed, otherwise `Pilot returned`.
- `scripts/world/planet_body.gd` Mina, atmosphere shells, and the paused megastructure city.
- `scripts/ui/flight_hud.gd` the green pixel HUD. `scripts/ui/title_director.gd` the title drift. It calls `set_flight_active(true)` when the fade finishes. Until then the ship is inactive on a normal launch.

## Workflow

Hunter's rules:

- One branch and one PR per feature. Show a video or screenshot of each feature.
- Check feature plans with Hunter before building big changes.
- Never push to main without his OK.
- Never install anything on his Mac or iPhone without asking.

## Roadmap

Next is a polish pass on everything already built.

Later, in this order of interest:

- iOS export preset and a run on his iPhone. Free Apple ID, 7-day signing. Xcode is not installed yet. Do not install it unless he asks.
- Landing on Mina.
- Ship personalization and decorations (the save file's `extras` section is the hook).
- More terminal commands: STATUS, DOOR, SCAN, MINA, command history and autocomplete, typing sounds, boot screen.
- The city on Mina. That work is paused.
