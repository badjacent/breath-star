# Self-measurement plan

Drafted 2026-11-10. The model's open questions have run out of published data. Each one below
turns on a contrast one person can measure at home: which side's ribs move more, whether the belly
takes more with the knees bent, what changes after a lesson. This plan says what to measure, how,
and what each result would change in the model. The model's predictions are written down first (the
table at the end, from `breathstar measure-predictions`, commit noted there), so a measurement can
contradict them.

Nothing here needs building before you decide to do it; the cheapest tier needs no hardware at all.

## 1. What each measurement decides

| Open question | Contrast | Model predicts | Would contradict it |
|---|---|---|---|
| Side-bend: which side's wall moves (ribs as struts) | D vs E, lateral lower ribs left vs right | crowded side **less** (0.63 vs 1.03 mm at the lowest ribs) | the crowded side moving as much or more |
| Knees bent (the belly wall as a membrane; `Legs`, 2026-11-11) | H vs G (knees bent, feet standing vs legs long); a marker or band low and high on the belly | knees bent: belly share **up** (67 → 69%); the **low** belly moves more (3.96 → 5.02 mm), the high belly about the same (4.99 → 4.82); lowest ribs down | the low belly moving less with the knees bent, or the change only high up |
| Standing (derived from the hips, 2026-11-11) | S vs A | standing: ribcage share a little **up** (55 → 57%), belly forward motion down (3.0 → 2.6 mm) | ribcage share down standing |
| Slumped sitting | B vs A | ribcage share **down** (55 → 44%), belly forward motion up | ribcage share unchanged or up |
| Extension (the known issue) | C and C2 vs A, lowest ribs | lower back arched: lateral lowest ribs about unchanged (0.82 → 0.79 mm), lower ribcage slightly up (0.92 → 0.94); mid-back arched: **down** (→ 0.57) | the mid-back arch moving them more than the lower-back arch |
| Rotation | F vs A | ribcage share down (55 → 45%), lowest ribs out more | ribcage share up |
| Supine shares | G, chest vs belly | ribcage 33%, belly 67% | ribcage near 50% or belly under 55% |
| Side-lying (anchors the method) | I | the floor side's lateral ribs move far less (0.69 vs 2.72 mm) | — (sourced; a check on the method) |
| Face down | J | lateral lowest ribs move a lot (5.1 mm), belly forward little; **known miss:** belly 74% of the breath vs LoMauro 2024's 42.5% (28 healthy, OEP) | lateral ribs no larger than supine |
| Before/after a lesson (stage 6) | G before vs G after | no slow state: no change; H2: belly share +3 points | a change in the other direction, or larger than ±5 points |
| Which side breathes (the lesson's scan) | G, left vs right | symmetric | your own asymmetry: it becomes a person-specific input, not a contradiction |

*Predictions revised 2026-11-10, before any recording: the seated base now fits Mendes's compartment
volumes as well as Takashima's markers (docs/RESULTS.md). The earlier set (markers only) is in git
the private history; the lower-back arch's prediction changed sign at the lowest ribs (up → about
unchanged) and the slump's at the lowest ribs (down → up).*

The model cannot be checked here on: tidal volume in litres (needs a spirometer), and each lung's
share (needs EIT). Everything below measures the wall.

## 2. Methods, cheapest first

**Tier 1: two phones as motion sensors (no purchase).** Lying down only. One phone flat on the
sternum, one on the belly just above the navel, each running a free sensor-recording app (phyphox
records the accelerometer and gyroscope and exports CSV). Each phone's tilt follows its surface:
the breath shows as a slow oscillation. Gives the chest/belly ratio for G, H, K and the
before/after, as relative motion. Not usable sitting (the trunk sways) or for left vs right.

**Tier 2: skin markers and a phone camera (stickers and a tripod).** Round high-contrast stickers
(~15 mm) at: the lateral lower ribs on both sides at the 9th–10th rib level and at the 7th–8th
(mid-axillary line), the front of the belly (two, either side of the navel), the sternum, and a
reference on the spine (T12 or L1 spinous process) for the sitting views. Phone on a tripod,
1–1.5 m away, 60 fps: from behind for the sitting side-bends, rotation and extension (lateral
markers in profile at the edges of the trunk); from above or the side lying down. A ruler or a
printed card in the plane of the markers for the mm scale. Gives the left/right and lateral
measures (D, E, C, F) and the front measures. Tracking is a short script (OpenCV), which can be
written when wanted.

**Tier 3: two bands (respiratory inductance-style).** Two elastic belts with stretch sensing, one
around the lower ribcage at the xiphoid, one around the belly at the navel. Options: commercial
respiration belts; or conductive-rubber stretch cord with a small microcontroller. Needs an
isovolume calibration (below) to turn the two signals into ribcage and belly shares. Gives the
shares in every position, sitting included.

**Tier 4: a depth camera.** A phone with a depth sensor and an app that records depth video, aimed
at the trunk. Gives the whole surface's motion, directly comparable to the model's surface field
(the viewer's blur). Most informative and most work to process.

Recommended start: **Tier 2 plus Tier 1**. Together they cover the side-bend, extension and
rotation (the stage-4 questions), knees bent vs long, and the before/after, for the price of
stickers.

## 3. Protocol

- **Breathing:** quiet and unattended. Don't follow or shape the breath; look at something
  neutral. Record about 2 minutes (25–30 breaths) per condition, after 1 minute of settling.
- **Holding a position without effort:** sitting bends are held with support (a hand on the chair
  seat for a side-bend; a backrest edge for the arch) so the muscles holding the trunk stay quiet.
  Note any position that needs effort; effort is tone, which the model treats separately.
- **Order:** alternate the two sides of a contrast (A B A B, or D E D E), so slow drift can't
  masquerade as a difference. Repeat on at least two days.
- **Isovolume calibration (bands only):** at mid-breath, close the throat and gently shift the
  volume back and forth between chest and belly a few times; the two band signals must move in
  opposite directions by the same volume, which sets their relative gain. Repeat per position
  class (sitting, lying).
- **Before/after a lesson:** G for 3 minutes, then a lesson (any), then G
  immediately and again 10 minutes later. Note the lesson and its duration.
- **Log per recording:** position, side, time, anything unusual (cough, sigh, effort).

## 4. Analysis

Per breath, the peak-to-trough excursion of each signal; per condition, the median and the spread
across breaths. Contrasts are ratios within one session (left/right, knees bent/legs long,
after/before), which cancels most calibration error. A contrast counts when its direction holds in
most breaths and on both days. Then:

- **Agrees with the model:** the sign and rough size match: that rule moves from ASSUMED toward
  MEASURED (n = 1), and the measured size replaces the assumed gain.
- **Contradicts it:** the rule's sign flips (e.g., ribs eased when crowded), or the mechanism is
  missing, and the log says which.
- **Your own asymmetry** (G left vs right, or any side that differs at rest) becomes a
  person-specific starting state the lesson layer can carry.

## 5. Tracking tool (`Tools/measure/track.py`)

A self-contained Python script; `uv run` fetches its dependencies (OpenCV, NumPy, SciPy).

1. **Stickers.** Round, dark on light skin (or light on dark clothing edges), about 15 mm, flat to
   the skin, and one on the spine (T12 or L1 spinous process) as the reference. A ruler or printed
   card in the plane of the markers for the scale. Even light, no shadows across the stickers.
2. **Detect.** `uv run Tools/measure/track.py detect VIDEO --out frame0.png` finds the stickers in
   the first frame, saves the frame with each one numbered, and writes `VIDEO.labels.json` next to
   the video. Light stickers: `--color bright`; coloured ones: `--color hsv:h1,s1,v1,h2,s2,v2`.
   Wrong blobs or missing stickers: adjust `--min-area`/`--max-area` (pixels).
3. **Name them.** In the labels file, give each number a name, set `reference` to the spine
   marker's name, and the scale: `"mm_per_px"`, or two ruler points `p1`, `p2` (pixels) and their
   distance `mm`. `start_s`/`end_s` trim the settling minute.
4. **Track.** `uv run Tools/measure/track.py track VIDEO --labels VIDEO.labels.json --out run.csv`:
   every marker's position per frame in mm, relative to the spine marker, so the trunk's sway
   cancels. A marker not found within `--max-jump` pixels keeps its last position (the count is
   printed: if it is large, fix the light or the areas).
5. **Breaths.** `uv run Tools/measure/track.py breaths run.csv --signal belly_front:y --out A.json`
   splits the recording into breaths on one marker's motion (add `:-` if inspiration moves it the
   negative way), then gives every marker's excursion from end expiration to end inspiration:
   median, quartiles and each breath's value. This is what the predictions table gives.
6. **Compare.** `uv run Tools/measure/track.py compare A.json B.json`: per measure, the two
   medians, B/A, and the share of random breath pairs in which B's value is larger (signed: for a
   marker whose outward motion is negative, "larger" means less outward; read the sign).
7. **Phones lying down.** `uv run Tools/measure/track.py phyphox FILE.csv --out phone.json`: a
   phyphox accelerometer export (time, ax, ay, az); the phone's tilt per breath, in degrees.

**Conventions.** x to the image's right, y up, mm, relative to the spine marker. Filmed from
behind, the person's left is on the image's left, so the left lateral ribs moving out is −x; filmed
from in front, the person's left is on the image's right (+x). Lying down filmed from above, y is
toward the head in the image, not forward: the belly's forward motion is not visible from above
(film from the side, or use the phones).

**Names that match the predictions table:** `lat_lowest_L`, `lat_lowest_R` (9th–10th ribs,
mid-axillary line: "lat. lowest"), `lat_lower_L`, `lat_lower_R` (7th–8th: "lat. lower"),
`belly_front`, `chest_front`, `spine` (the reference). The model's millimetres are for a 0.56 L
breath; compare ratios and directions, not absolute sizes.

**Checked on a synthetic video** (`uv run Tools/measure/track.py synth`, known motion, a reference
that sways 3 mm): recovered lateral −0.995 / +1.992 mm (true −1.0 / +2.0), belly +4.997 (+5.0),
chest +1.995 (+2.0), 14 of 15 breaths; `compare` of a run with one marker scaled ×1.5 gives 1.50
and 100% of pairs; `phyphox` on a 0.8° tilt per breath gives 0.815°.

## 6. Model predictions (`breathstar measure-predictions`)

```
Model predictions for the self-measurement plan (quiet breath 0.56 L; rules as of this commit).
rc/ab: ribcage and belly shares of the breath (two bands, after an isovolume calibration).
Markers (mm, outward): lateral lower ribs L/R (9th–10th rib level, z 13–18 / lower ribcage z 18–25),
front belly (umbilicus region, forward), front upper chest (forward).

     position                        rc/ab %    lat. lowest L/R  lat. lower L/R  belly fwd  chest fwd  lungs L/R mL
  A  sitting upright                 55/45      0.80/0.80        0.91/0.91       3.04       2.74       280/280
  S  standing                        57/43      0.78/0.78        0.93/0.93       2.57       2.88       280/280
  B  sitting slumped                 44/56      0.91/0.91        0.85/0.85       5.37       2.16       280/280
  C  sitting, lower back arched 15°  57/43      0.77/0.77        0.93/0.93       2.54       2.89       280/280
  C2 sitting, mid-back arched 15°    61/39      0.56/0.56        0.81/0.81       2.57       2.99       280/280
  D  sitting, side-bend left 20°     55/45      0.62/1.02        0.72/1.13       3.02       2.74       284/276
  E  sitting, side-bend right 20°    55/45      1.02/0.62        1.13/0.72       3.02       2.74       276/284
  F  sitting, turned left 30°        44/56      1.20/1.20        0.95/0.95       4.17       2.24       280/280
  G  lying on the back, legs long    33/67      2.26/2.26        1.45/1.45       5.47       1.89       280/280
  H  lying on the back, knees bent   31/69      1.98/1.98        1.37/1.37       5.94       1.79       280/280
  I  lying on the right side         32/68      2.71/0.68        1.86/0.96       7.30       1.94       228/332
  J  lying face down                 26/74      5.06/5.06        2.37/2.37       0.45       1.47       280/280
  K  reclined 45°                    48/52      1.29/1.29        1.16/1.16       3.77       2.52       280/280

  G vs H, front belly (mm forward): low (2–8 cm above the iliac crests) 3.94 → 4.99, high (10–16 cm) 4.96 → 4.80.

  Before/after Example: sitting, lying, one foot standing: belly share scan → final-rest: no slow state 67.0 → 67.0; H2 (use loosens, gain 0.3, τ 5 min) 67.1 → 70.5.
```

Generated at commit 8ef38f7 (the commit that added this file; rerun the command after any rules change and keep the original table for the comparison).
