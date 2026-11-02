# Performance budget

The bench flies three places for about six seconds: the cabin aisle, the exterior chase view, and the Mina tower canyon. It ignores the first 12 frames of each place so shader startup is not the score. `tools/budget.py` fails if any number is over the ceiling in `docs/budget.json`.

Measured on this machine with the software Vulkan renderer (lavapipe), after warmup:

| | Measured | Ceiling |
| --- | ---: | ---: |
| Worst frame | 74 ms | 140 ms |
| Worst draw calls | 227 | 500 |
| Worst node count | 701 | 1200 |
| Packed `assets/` + `scripts/` + `scenes/` | 1.20 MB | 1.80 MB |

The frame time is the software renderer, not a phone. The ceiling is about twice that measurement so a noisy CI machine still passes, and so the tower region can get denser without a free pass. Draw calls and nodes have the same kind of headroom. The byte ceiling is the unpacked game data, which is what an export pack is built from. A full store export needs the export templates, which CI does not download.

iPhone is the reason the frame loop is not allowed to allocate. 60 fps leaves 16 ms, and a garbage collection pause on device is a dropped frame. See `docs/LINT.md`.
