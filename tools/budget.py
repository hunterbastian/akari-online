#!/usr/bin/env python3
"""Fail when a bench report exceeds docs/budget.json."""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_bench(text: str) -> dict:
    # frames=N avg_ms=F worst_ms=F worst_draws=N worst_nodes=N pack_bytes=N
    out = {}
    for part in text.replace("BENCH ", "").split():
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        out[key] = float(value) if "." in value else int(value)
    return out


def main():
    report = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "tools" / "last_bench.txt"
    budget = json.loads((ROOT / "docs" / "budget.json").read_text())
    if not report.exists():
        print("no bench report", report)
        return 1
    got = parse_bench(report.read_text())
    failed = False
    for key, limit in budget["limits"].items():
        value = got.get(key)
        if value is None:
            print(f"missing {key}")
            failed = True
            continue
        ok = value <= limit
        print(f"{key}: {value} / {limit} {'ok' if ok else 'OVER'}")
        if not ok:
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
