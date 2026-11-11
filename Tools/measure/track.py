# /// script
# requires-python = ">=3.10"
# dependencies = ["opencv-python-headless>=4.8", "numpy>=1.26", "scipy>=1.11"]
# ///
"""Skin-marker tracking for the self-measurement plan (reference/SELF_MEASUREMENT_PLAN.md).

Round high-contrast stickers on the trunk, a phone on a tripod, quiet breathing. This turns the
video into per-breath marker excursions (end expiration -> end inspiration, mm), the quantity
`breathstar measure-predictions` predicts.

    uv run Tools/measure/track.py detect VIDEO [--color dark|bright|hsv:h1,s1,v1,h2,s2,v2] --out frame0.png
        Finds the stickers in the first frame, saves the frame with each one numbered, and writes
        a labels template (VIDEO.labels.json) to fill in: a name per number, the reference marker
        (on the spine), and the scale (two points on a ruler and their distance, or mm per pixel).
    uv run Tools/measure/track.py track VIDEO --labels VIDEO.labels.json --out run.csv
        Follows every sticker through the video; writes time and each marker's position in mm
        relative to the reference (x to the image's right, y up).
    uv run Tools/measure/track.py breaths run.csv --signal NAME:AXIS[:-] --out summary.json
        Splits the recording into breaths on one marker's motion (":-" if inspiration moves it the
        negative way), and reports every marker's per-breath excursion: median, quartiles, count.
    uv run Tools/measure/track.py compare A.json B.json
        B against A for every measure: medians, ratio, and the share of breath pairs in which B
        exceeds A (a direction check).
    uv run Tools/measure/track.py phyphox FILE.csv --out summary.json
        The phones-lying-down tier: a phyphox accelerometer export; the phone's tilt per breath.
    uv run Tools/measure/track.py synth --out synthetic.mp4
        A test video with known motion (lateral markers 1.0 mm left, 2.0 mm right, belly 5 mm).
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from pathlib import Path

import cv2
import numpy as np
from scipy import signal as sps
from scipy.optimize import linear_sum_assignment


# ---------------------------------------------------------------- detection

def blob_mask(frame: np.ndarray, color: str) -> np.ndarray:
    """A binary mask of sticker pixels."""
    if color.startswith("hsv:"):
        v = [int(x) for x in color[4:].split(",")]
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        return cv2.inRange(hsv, np.array(v[:3]), np.array(v[3:]))
    gray = cv2.GaussianBlur(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), (5, 5), 0)
    mode = cv2.THRESH_BINARY_INV if color == "dark" else cv2.THRESH_BINARY
    _, m = cv2.threshold(gray, 0, 255, mode + cv2.THRESH_OTSU)
    return m


def find_blobs(frame: np.ndarray, color: str, min_area: float, max_area: float, min_circularity: float = 0.6) -> list[tuple[float, float]]:
    """Centres (sub-pixel, by moments) of round blobs within the area range."""
    m = blob_mask(frame, color)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    contours, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
    out = []
    for c in contours:
        a = cv2.contourArea(c)
        if not (min_area <= a <= max_area):
            continue
        p = cv2.arcLength(c, True)
        if p == 0 or 4 * math.pi * a / (p * p) < min_circularity:
            continue
        mo = cv2.moments(c)
        out.append((mo["m10"] / mo["m00"], mo["m01"] / mo["m00"]))
    return out


def open_video(path: str) -> tuple[cv2.VideoCapture, float]:
    cap = cv2.VideoCapture(path)
    if not cap.isOpened():
        sys.exit(f"cannot open {path}")
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    return cap, fps


def cmd_detect(a: argparse.Namespace) -> None:
    cap, _ = open_video(a.video)
    ok, frame = cap.read()
    if not ok:
        sys.exit("no frames")
    blobs = find_blobs(frame, a.color, a.min_area, a.max_area)
    shown = frame.copy()
    for i, (x, y) in enumerate(blobs):
        cv2.circle(shown, (int(x), int(y)), 14, (0, 0, 255), 2)
        cv2.putText(shown, str(i), (int(x) + 16, int(y) - 8), cv2.FONT_HERSHEY_SIMPLEX, 0.9, (0, 0, 255), 2)
    cv2.imwrite(a.out, shown)
    template = {
        "color": a.color, "min_area": a.min_area, "max_area": a.max_area,
        "markers": {str(i): f"marker{i}" for i in range(len(blobs))},
        "first_frame": {str(i): [round(x, 1), round(y, 1)] for i, (x, y) in enumerate(blobs)},
        "reference": "marker0",
        "scale": {"p1": [0, 0], "p2": [100, 0], "mm": 100, "mm_per_px": None},
        "start_s": 0, "end_s": None,
    }
    labels = Path(a.video).with_suffix(".labels.json")
    if labels.exists() and not a.force:
        print(f"{labels} exists; not overwritten (--force to replace)")
    else:
        labels.write_text(json.dumps(template, indent=2))
        print(f"wrote {labels}: name each marker, set the reference and the scale")
    print(f"{len(blobs)} markers found; numbered in {a.out}")
    for i, (x, y) in enumerate(blobs):
        print(f"  {i}: ({x:.1f}, {y:.1f}) px")


# ---------------------------------------------------------------- tracking

def scale_mm_per_px(s: dict) -> float:
    if s.get("mm_per_px"):
        return float(s["mm_per_px"])
    d = math.dist(s["p1"], s["p2"])
    if d <= 0:
        sys.exit("scale: p1 and p2 coincide; set two ruler points or mm_per_px")
    return float(s["mm"]) / d


def cmd_track(a: argparse.Namespace) -> None:
    L = json.loads(Path(a.labels).read_text())
    names = {int(k): v for k, v in L["markers"].items()}
    ids = sorted(names)
    prev = np.array([L["first_frame"][str(i)] for i in ids], dtype=float)
    k = scale_mm_per_px(L["scale"])
    ref = [names[i] for i in ids].index(L["reference"])
    cap, fps = open_video(a.video)
    start, end = float(L.get("start_s") or 0), L.get("end_s")
    cap.set(cv2.CAP_PROP_POS_MSEC, start * 1000)
    rows, lost, n = [], 0, 0
    max_jump = a.max_jump
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
        if end is not None and t > float(end):
            break
        blobs = np.array(find_blobs(frame, L["color"], L["min_area"], L["max_area"]), dtype=float)
        cur = prev.copy()
        if len(blobs):
            # Assign blobs to markers by least total distance; keep the old position if none is near.
            d = np.linalg.norm(prev[:, None, :] - blobs[None, :, :], axis=2)
            r, c = linear_sum_assignment(d)
            for i, j in zip(r, c):
                if d[i, j] <= max_jump:
                    cur[i] = blobs[j]
                else:
                    lost += 1
        lost += max(0, len(ids) - len(blobs))
        prev = cur
        n += 1
        rel = (cur - cur[ref]) * k
        rows.append([round(t, 4)] + [v for x, y in rel for v in (round(x, 4), round(-y, 4))])
    with open(a.out, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["t"] + [f"{names[i]}:{ax}" for i in ids for ax in ("x", "y")])
        w.writerows(rows)
    print(f"{n} frames at {fps:.1f} fps → {a.out} (mm, relative to {L['reference']}; {k:.4f} mm/px)")
    if lost:
        print(f"  {lost} marker-frames held at their last position (not found within {max_jump} px): check lighting or areas")


# ---------------------------------------------------------------- breaths

def breaths_in(t: np.ndarray, x: np.ndarray, lo: float = 0.08, hi: float = 0.8) -> list[tuple[int, int]]:
    """(trough, peak) index pairs: end expiration, then the next end inspiration."""
    fs = 1 / np.median(np.diff(t))
    b, a = sps.butter(2, [lo / (fs / 2), min(hi / (fs / 2), 0.99)], btype="band")
    y = sps.filtfilt(b, a, x - x.mean())
    dist = int(fs * 1.5)
    prom = 0.3 * np.std(y)
    peaks, _ = sps.find_peaks(y, distance=dist, prominence=prom)
    troughs, _ = sps.find_peaks(-y, distance=dist, prominence=prom)
    pairs = []
    for p in peaks:
        before = troughs[troughs < p]
        if len(before) and (not pairs or before[-1] > pairs[-1][1]):
            pairs.append((int(before[-1]), int(p)))
    return pairs


def summarize(values: list[float]) -> dict:
    v = np.array(values)
    return {"median": round(float(np.median(v)), 4), "q1": round(float(np.percentile(v, 25)), 4),
            "q3": round(float(np.percentile(v, 75)), 4), "n": int(len(v)), "per_breath": [round(float(x), 4) for x in v]}


def cmd_breaths(a: argparse.Namespace) -> None:
    with open(a.csv) as f:
        rd = csv.reader(f)
        head = next(rd)
        data = np.array([[float(v) for v in r] for r in rd])
    t = data[:, 0]
    col = {h: i for i, h in enumerate(head)}
    name, axis, *sign = a.signal.split(":")
    key = f"{name}:{axis}"
    if key not in col:
        sys.exit(f"no column {key}; have {', '.join(head[1:])}")
    s = data[:, col[key]] * (-1 if sign == ["-"] else 1)
    pairs = breaths_in(t, s)
    if len(pairs) < 3:
        sys.exit(f"only {len(pairs)} breaths found on {key}: check the signal or the recording")
    # Each channel's excursion between the signal's end expiration and end inspiration (unfiltered,
    # averaged over ±0.1 s to damp tracking jitter).
    fs = 1 / np.median(np.diff(t))
    w = max(1, int(0.1 * fs))
    def at(c: np.ndarray, i: int) -> float:
        return float(c[max(0, i - w): i + w + 1].mean())
    out = {"source": a.csv, "signal": a.signal, "breaths": len(pairs),
           "period_s": round(float(np.median(np.diff([t[p] for _, p in pairs]))), 3), "measures": {}}
    for h in head[1:]:
        c = data[:, col[h]]
        out["measures"][h] = summarize([at(c, p) - at(c, tr) for tr, p in pairs])
    Path(a.out).write_text(json.dumps(out, indent=2))
    print(f"{len(pairs)} breaths, period {out['period_s']} s → {a.out}")
    for h, m in out["measures"].items():
        print(f"  {h:28s} {m['median']:+8.3f} mm  (IQR {m['q1']:+.3f} … {m['q3']:+.3f})")


def cmd_compare(a: argparse.Namespace) -> None:
    A, B = json.loads(Path(a.a).read_text()), json.loads(Path(a.b).read_text())
    print(f"B = {a.b} against A = {a.a}")
    print(f"  {'measure':28s} {'A':>9s} {'B':>9s} {'B/A':>7s}  B > A in")
    rng = np.random.default_rng(0)
    for h, ma in A["measures"].items():
        mb = B["measures"].get(h)
        if not mb:
            continue
        ra = np.array(ma["per_breath"]); rb = np.array(mb["per_breath"])
        # Share of random breath pairs where B's excursion is larger (a direction check, 2000 draws).
        share = float(np.mean(rng.choice(rb, 2000) > rng.choice(ra, 2000)))
        ratio = mb["median"] / ma["median"] if abs(ma["median"]) > 1e-9 else float("nan")
        print(f"  {h:28s} {ma['median']:+9.3f} {mb['median']:+9.3f} {ratio:7.2f}  {share * 100:5.1f}%")


# ---------------------------------------------------------------- phones lying down

def cmd_phyphox(a: argparse.Namespace) -> None:
    """A phyphox accelerometer CSV (time, ax, ay, az): the phone's tilt from gravity, per breath."""
    with open(a.csv) as f:
        rd = csv.reader(f, delimiter=a.delimiter)
        next(rd)
        data = np.array([[float(v) for v in r[:4]] for r in rd if len(r) >= 4])
    t, g = data[:, 0], data[:, 1:4]
    # Tilt about the phone's long axis and its short axis, degrees; the breath rocks the phone.
    tilt_long = np.degrees(np.arctan2(g[:, 1], g[:, 2]))
    tilt_short = np.degrees(np.arctan2(g[:, 0], g[:, 2]))
    s = tilt_long if np.std(tilt_long) >= np.std(tilt_short) else tilt_short
    pairs = breaths_in(t, s)
    if len(pairs) < 3:
        sys.exit(f"only {len(pairs)} breaths found: lie still, phone flat on the skin")
    out = {"source": a.csv, "breaths": len(pairs), "measures": {"tilt_deg": summarize([s[p] - s[tr] for tr, p in pairs])}}
    Path(a.out).write_text(json.dumps(out, indent=2))
    m = out["measures"]["tilt_deg"]
    print(f"{len(pairs)} breaths; tilt per breath {m['median']:.3f}° (IQR {m['q1']:.3f} … {m['q3']:.3f}) → {a.out}")


# ---------------------------------------------------------------- synthetic test

def cmd_synth(a: argparse.Namespace) -> None:
    """Five dark stickers on a light trunk, 0.5 mm per pixel; a 4 s breath for 60 s at 30 fps.
    Known excursions (end expiration → end inspiration): lat_L x −1.0 mm (outward = left in the
    image), lat_R x +2.0 mm, belly y +5.0 mm, chest y +2.0 mm; the spine reference sways 3 mm."""
    W, H, fps, mmpp = 640, 720, 30, 0.5
    base = {"spine": (320, 600), "lat_L": (180, 420), "lat_R": (460, 420), "belly": (320, 470), "chest": (320, 250)}
    amp = {"spine": (0, 0), "lat_L": (-1.0, 0), "lat_R": (2.0, 0), "belly": (0, 5.0), "chest": (0, 2.0)}
    vw = cv2.VideoWriter(a.out, cv2.VideoWriter_fourcc(*"mp4v"), fps, (W, H))
    rng = np.random.default_rng(1)
    for f in range(60 * fps):
        t = f / fps
        b = 0.5 * (1 - math.cos(2 * math.pi * t / 4))  # 0 at end expiration, 1 at end inspiration
        sway = 6 * math.sin(2 * math.pi * t / 23)       # px: the whole trunk drifts (the reference cancels it)
        img = np.full((H, W, 3), 210, np.uint8)
        cv2.ellipse(img, (320, 420), (190, 330), 0, 0, 360, (190, 200, 215), -1)
        for k, (x, y) in base.items():
            dx, dy = amp[k]
            cx = x + sway + dx / mmpp * b
            cy = y - dy / mmpp * b  # image y down; motion "up" in mm
            cv2.circle(img, (int(round(cx * 8)), int(round(cy * 8))), 15 * 8, (30, 30, 30), -1, cv2.LINE_AA, shift=3)
        img = np.clip(img.astype(int) + rng.integers(-6, 7, img.shape), 0, 255).astype(np.uint8)
        vw.write(img)
    vw.release()
    print(f"wrote {a.out}: 60 s, 0.5 mm/px; known: lat_L x −1.0, lat_R x +2.0, belly y +5.0, chest y +2.0 mm")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("detect"); d.add_argument("video"); d.add_argument("--out", default="frame0.png")
    d.add_argument("--color", default="dark"); d.add_argument("--min-area", type=float, default=60)
    d.add_argument("--max-area", type=float, default=5000); d.add_argument("--force", action="store_true")
    t = sub.add_parser("track"); t.add_argument("video"); t.add_argument("--labels", required=True)
    t.add_argument("--out", default="run.csv"); t.add_argument("--max-jump", type=float, default=25)
    b = sub.add_parser("breaths"); b.add_argument("csv"); b.add_argument("--signal", required=True); b.add_argument("--out", default="summary.json")
    c = sub.add_parser("compare"); c.add_argument("a"); c.add_argument("b")
    ph = sub.add_parser("phyphox"); ph.add_argument("csv"); ph.add_argument("--out", default="phone.json"); ph.add_argument("--delimiter", default=",")
    s = sub.add_parser("synth"); s.add_argument("--out", default="synthetic.mp4")
    a = p.parse_args()
    {"detect": cmd_detect, "track": cmd_track, "breaths": cmd_breaths, "compare": cmd_compare,
     "phyphox": cmd_phyphox, "synth": cmd_synth}[a.cmd](a)


if __name__ == "__main__":
    main()
