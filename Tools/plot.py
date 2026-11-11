#!/usr/bin/env python3
"""Plot a `breathstar render` CSV as an SVG. No dependencies.

    swift run -q breathstar render --posture seated > out/seated.csv
    python3 Tools/plot.py out/seated.csv out/seated.svg

Draws lung, ribcage and abdomen volume (litres) over time, with the
diaphragm pressure trace underneath.
"""
import csv
import sys

W, H, PAD = 900, 420, 50
SERIES = [("vl", "lung", "#444"), ("vrc", "ribcage", "#c0603a"), ("vab", "abdomen", "#3a7cc0")]


def main(src: str, dst: str) -> None:
    with open(src) as f:
        rows = [{k: float(v) for k, v in r.items()} for r in csv.DictReader(f)]
    t = [r["t"] for r in rows]
    t0, t1 = t[0], t[-1]
    vols = [r[k] for r in rows for k, _, _ in SERIES]
    vmin, vmax = min(vols + [0]), max(vols)
    pmax = max(r["pdi"] for r in rows) or 1
    top_h = (H - 2 * PAD) * 0.72
    bot_y0 = PAD + top_h + 20
    bot_h = H - PAD - bot_y0

    def x(v: float) -> float:
        return PAD + (v - t0) / (t1 - t0) * (W - 2 * PAD)

    def y(v: float) -> float:
        return PAD + (vmax - v) / (vmax - vmin) * top_h

    def yp(v: float) -> float:
        return bot_y0 + (1 - v / pmax) * bot_h

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="sans-serif" font-size="12">',
           f'<rect width="{W}" height="{H}" fill="#fff"/>',
           f'<line x1="{PAD}" x2="{W - PAD}" y1="{y(0):.1f}" y2="{y(0):.1f}" stroke="#ccc"/>']
    step = max(1, len(rows) // 1500)
    for i, (key, label, color) in enumerate(SERIES):
        pts = " ".join(f"{x(r['t']):.1f},{y(r[key]):.1f}" for r in rows[::step])
        out.append(f'<polyline fill="none" stroke="{color}" stroke-width="1.6" points="{pts}"/>')
        out.append(f'<text x="{W - PAD - 70}" y="{PAD + 14 * i}" fill="{color}">{label}</text>')
    pts = " ".join(f"{x(r['t']):.1f},{yp(r['pdi']):.1f}" for r in rows[::step])
    out.append(f'<polyline fill="none" stroke="#999" stroke-width="1" points="{pts}"/>')
    out.append(f'<text x="{PAD}" y="{bot_y0 - 4}" fill="#999">diaphragm pressure (peak {pmax:.1f} cmH2O)</text>')
    out.append(f'<text x="{PAD}" y="{PAD - 10}">volume, L ({vmin:.2f} to {vmax:.2f})</text>')
    out.append(f'<text x="{W - PAD}" y="{H - 15}" text-anchor="end">{t1 - t0:.1f} s</text>')
    out.append("</svg>")
    with open(dst, "w") as f:
        f.write("\n".join(out))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
