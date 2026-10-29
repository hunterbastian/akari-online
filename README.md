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

The desktop renderer is Forward+. iOS is set to the Mobile renderer for a later export. Physics is Jolt at 120 ticks per second. There is no HUD, landing, trading, or login in this milestone.

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

Godot cannot import the Draco-compressed glBs. `assets/models/ship.glb` is the starter hull with Draco removed. To rebuild assets from Blender without compressing them:

```
blender -b --python tools/blender/build_assets.py -- --uncompressed
```

That writes plain glBs into `assets/models/` and skips the Draco pass. Omit `--uncompressed` to keep the old Draco export under `public/models/`.
