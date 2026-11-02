#!/usr/bin/env python3
"""Record a short movie from a Godot tour, then pack it under 14 MB."""
import glob
import os
import shutil
import subprocess
import sys

GODOT = os.environ.get("GODOT", "/tmp/godot/godot")
FPS = 12
MAX_BYTES = 14 * 1024 * 1024


def main() -> int:
    if len(sys.argv) < 3:
        print("usage: record_movie.py name seconds -- extra godot args", file=sys.stderr)
        return 2
    name = sys.argv[1]
    seconds = float(sys.argv[2])
    extra = sys.argv[3:]
    frames = int(seconds * FPS) + 4
    outdir = f"/tmp/akari-frames-{name}"
    shutil.rmtree(outdir, ignore_errors=True)
    os.makedirs(outdir)
    env = os.environ.copy()
    env.setdefault("VK_ICD_FILENAMES", "/usr/share/vulkan/icd.d/lvp_icd.json")
    env.setdefault("VK_DRIVER_FILES", "/usr/share/vulkan/icd.d/lvp_icd.json")
    env.setdefault("DISPLAY", ":1")
    cmd = [
        GODOT, "--path", "/workspace",
        "--display-driver", "x11",
        "--audio-driver", "Dummy",
        "--write-movie", os.path.join(outdir, "frame.png"),
        "--fixed-fps", str(FPS),
        "--quit-after", str(int(seconds * FPS) + 18),
        "--",
        *extra,
    ]
    print("RUN", " ".join(cmd), flush=True)
    proc = subprocess.run(cmd, env=env)
    pngs = sorted(glob.glob(os.path.join(outdir, "*.png")))
    print(f"frames {len(pngs)} exit {proc.returncode}", flush=True)
    if len(pngs) < FPS:
        return 1
    os.makedirs("/opt/cursor/artifacts", exist_ok=True)
    dest = f"/opt/cursor/artifacts/{name}.mp4"
    # CRF climbs until the file fits.
    for crf in (23, 26, 28, 30, 32):
        subprocess.run([
            "ffmpeg", "-y", "-framerate", str(FPS),
            "-i", os.path.join(outdir, "frame%08d.png"),
            "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", str(crf),
            "-movflags", "+faststart", dest,
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        size = os.path.getsize(dest)
        print(f"crf {crf} bytes {size}", flush=True)
        if size <= MAX_BYTES:
            return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
