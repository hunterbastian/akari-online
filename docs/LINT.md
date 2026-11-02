# Lint

Every bug found gets a rule or a test. If a bug comes back, the check should fail before it ships.

`tools/lint.py` is the source check. `tools/check.sh` is the pre-commit-style run (lint, headless tests, then the flight bench). CI runs the same script. To hook git locally:

```
ln -sf ../../tools/check.sh .git/hooks/pre-commit
chmod +x tools/check.sh
```

## Hot paths

Functions that run every frame are marked with a `# hot` comment on the line above `func`. The iPhone target is 60 fps. A frame is 16 ms, and GDScript garbage collection hitches when the frame loop allocates. The lint flags these inside a `# hot` body:

- `.new()`
- lambdas
- string formatting (`"%s" % x`) and string concatenation
- `Array` and `Dictionary` literals

Value types such as `Vector3` and `Color` are fine. Format a string in a helper, and call that helper only when the value changed.

## State rules

Each rule is a snippet that must remain in the file that fixed the bug. The matching behavior is also covered by `test/test_statechart.gd`.

| Rule | What it guards |
| --- | --- |
| sit-through-console | Touch SIT/USE do nothing while the dev console or noclip is up |
| noclip-reload | Reload drops noclip so the title can take input |
| tp-steals-freecam | `tp` gives the freecam back instead of leaving another camera current |
| tp-cabin-title | `tp cabin` dismisses the title before it switches cameras |
| locker-stays-open | The locker panel closes when you walk away |
| e-grabs-crate | Near the seat, E sits before it can pick something up |
| terminal-ejects | E types into the seat terminal instead of leaving the seat |
| tp-dead-end | A fixed dev view unlocks so you can walk |
| burn-after-stand | Standing clears thrust so the engines stop burning |

## Budgets

`docs/budget.json` is the ceiling for worst frame time, draw calls, node count, and the packed size of `assets/`, `scripts/`, and `scenes/`. The bench (`--bench`) flies the cabin, the exterior, and the Mina towers, then `tools/budget.py` fails the run if a number is over the ceiling. The ceilings were taken from a measured run plus headroom. See `docs/BUDGET.md`.
