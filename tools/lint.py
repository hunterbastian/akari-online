#!/usr/bin/env python3
"""Lightweight GDScript checks. Every bug we fix gets a rule here or a test."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"

HOT_FORBIDDEN = [
    (re.compile(r"\.new\s*\("), "allocation .new()"),
    (re.compile(r"\blambda\b"), "lambda"),
    (re.compile(r"(?<![\w])func\s*\("), "lambda"),
    (re.compile(r'''"[^"\n]*"\s*\+|\+\s*"|'[^'\n]*'\s*\+|\+\s*' '''), "string concatenation"),
    (re.compile(r'"[^"\n]*"\s*%|\'[^\'\n]*\'\s*%'), "string formatting"),
    (re.compile(r"(?:^|[=,(])\s*\["), "Array literal"),
    (re.compile(r"(?:^|[=,(])\s*\{"), "Dictionary literal"),
]

# Source rules for the statechart bugs. Each one names the file and a snippet that must stay.
RULES = [
    ("sit-through-console", "scripts/ui/cabin_controls.gd", "DevConsole.blocks_gameplay()", "SIT/USE must refuse input while the console is open"),
    ("noclip-reload", "scripts/autoloads/dev_console.gd", "release_transient()", "reload must drop noclip before the next scene"),
    ("tp-steals-freecam", "scripts/autoloads/dev_console.gd", "hold_freecam()", "tp must give the freecam back"),
    ("tp-cabin-title", "scripts/main.gd", "abort_for_dev", "tp must dismiss the title before handing over a camera"),
    ("locker-stays-open", "scripts/flight/cabin_inventory.gd", "close_if_far", "an open locker closes when you walk away"),
    ("e-grabs-crate", "scripts/flight/ship_controller.gd", "near_seat()", "sitting is checked before a pickup"),
    ("terminal-ejects", "scripts/flight/ship_controller.gd", "terminal_wants_keys", "the terminal owns the E key while you are typing"),
    ("tp-dead-end", "scripts/flight/cabin_interior.gd", "release_fixed_view", "a dev view must be able to unlock"),
    ("burn-after-stand", "scripts/flight/ship_controller.gd", "thrust = 0.0", "standing up clears engine thrust"),
    ("thrust-shake-toggle", "scripts/flight/thrust_kick.gd", "FlightProfile.SHAKE", "shake intensity can be turned down"),
    ("thrust-shake-default", "scripts/data/flight_profile.gd", "const SHAKE := 1.0", "shake defaults to on"),
    ("star-streaks", "scripts/flight/thrust_kick.gd", "travel_dir", "boost stretches stars along the direction of travel"),
    ("lights-command", "scripts/flight/cabin_terminal.gd", "LIGHTS", "HELP can list the LIGHTS command"),
    ("cabin-bob", "scripts/data/flight_profile.gd", "const BOB := 1.0", "head bob defaults on and can be scaled off"),
    ("crt-readout", "scripts/flight/flight_readout.gd", "SPD", "the cockpit CRT prints speed, altitude, heading, and thrust"),
    ("beige-terminal", "scripts/flight/cabin_interior.gd", "BeigeTerminal", "the cockpit is one beige terminal"),
    ("beige-page", "scripts/flight/flight_readout.gd", "AUTOPILOT: ORBIT", "one screen carries autopilot and the old side readouts"),
    ("crt-linear", "assets/shaders/crt_green.gdshader", "filter_linear", "phosphor stays readable from the seat and the aisle"),
    ("ship-log", "scripts/flight/cabin_terminal.gd", "LOG", "HELP can list the LOG command"),
    ("time-command", "scripts/flight/cabin_terminal.gd", "TIME", "HELP can list the TIME command"),
    ("autopilot-command", "scripts/flight/cabin_terminal.gd", "AUTOPILOT", "HELP can list AUTOPILOT"),
    ("ship-save", "scripts/flight/cabin_terminal.gd", "SAVE", "HELP can list the SAVE command"),
    ("ship-save-flight", "scripts/flight/ship_controller.gd", "capture_flight", "the ship can be written into the save"),
    ("terminal-suggest", "scripts/flight/cabin_terminal.gd", "suggest", "a typo names the closest command"),
]


def hot_bodies(text: str):
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        if lines[i].strip() == "# hot" and i + 1 < len(lines) and lines[i + 1].startswith("func "):
            name = lines[i + 1].split("(")[0].replace("func ", "").strip()
            body = []
            i += 2
            while i < len(lines) and not (lines[i].startswith("func ") or lines[i].startswith("static func ")):
                if lines[i].strip() == "# hot":
                    break
                body.append(lines[i])
                i += 1
            yield name, body
            continue
        i += 1


def lint_hot(path: Path):
    errors = []
    text = path.read_text()
    for name, body in hot_bodies(text):
        for n, line in enumerate(body, start=1):
            code = line.split("#", 1)[0]
            if not code.strip():
                continue
            for pattern, label in HOT_FORBIDDEN:
                if pattern.search(code):
                    errors.append(f"{path.relative_to(ROOT)}:{name}: {label}: {code.strip()}")
    return errors


def lint_rules():
    errors = []
    for rule, rel, snippet, why in RULES:
        path = ROOT / rel
        if snippet not in path.read_text():
            errors.append(f"rule {rule} missing ({why}) in {rel}")
    return errors


def main():
    errors = []
    for path in sorted(SCRIPTS.rglob("*.gd")):
        errors.extend(lint_hot(path))
    errors.extend(lint_rules())
    if errors:
        print("lint failed:")
        for err in errors:
            print(" ", err)
        return 1
    print(f"lint ok ({len(RULES)} state rules, hot paths clean)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
