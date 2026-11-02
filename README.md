# AKARI ONLINE

A Godot 4.6 flight scene in Sol. You launch beside Mina, an ice world seeded to match the previous web build, under a nebula sky.

## Run

Install [Godot 4.6](https://godotengine.org/download/archive/4.6-stable/) and open this folder, or from a shell:

```
godot --path .
```

The game opens on a title drift past Mina. Click or press any key, and the view fades into flight. Then click the view to capture the mouse.

- **W / S** or the arrow keys throttle forward and back
- **A / D** or the arrow keys yaw
- **Mouse** looks
- **Shift** boosts
- **Space / Ctrl** rise and drop
- **Esc** releases the mouse
- **E** stands up from the pilot seat into the cabin. Walk with **WASD**, look with the mouse, and press **E** beside the seat to fly again. The ship keeps its velocity while you are up. On iPhone, the seat button stands and sits, a joystick walks, and dragging the right side of the screen looks.

The desktop renderer is Forward+. iOS is set to the Mobile renderer for a later export. Physics is Jolt at 120 ticks per second. There is no landing, trading, or login in this milestone. Speed stays on the pixel HUD, including while you walk the cabin.

## Seed check

```
godot --headless --path . --script res://test/test_sol_planet.gd
```

That regenerates Sol and compares every world's seed, name, biome, radius, and position with `test/sol_web_expected.json`, captured from the web build's `universe.js`.

## macOS export

`export_presets.cfg` has a macOS preset named `macOS` (universal, ad-hoc signature, testing distribution). Export templates for 4.6 are required:

```
godot --headless --export-debug "macOS" "build/macos/AKARI ONLINE.zip"
```

## Ship mesh

The player hull is `assets/ships/jumpship.glb` (nose at -Z, engines at +Z), scaled to the old chase-cam size. Godot cannot import the Draco-compressed glBs. `assets/models/ship.glb` is the previous starter hull with Draco removed. To rebuild assets from Blender without compressing them:

```
blender -b --python tools/blender/build_assets.py -- --uncompressed
```

That writes plain glBs into `assets/models/` and skips the Draco pass. Omit `--uncompressed` to keep the old Draco export under `public/models/`.
