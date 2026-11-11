# Results

The model's defaults as of 2026-11-11, against each source. Quiet breathing is held at 0.56 L, so
"drive" is what a configuration needs relative to sitting. Shares are upper ribcage / lower ribcage
/ belly, % of the breath. Sources are in `reference/LITERATURE.md`. Every command named here prints
the full table.

## The seated base (`breathstar volume-fit`)

Three fixed-sign muscle groups (diaphragm, upper rib muscles, lower rib muscles) fitted to
Takashima 2017's seated marker motion **and** Mendes 2020's seated compartment volumes (men).

| | upper | lower | belly | markers within SD |
|---|---|---|---|---|
| model | 39.9 | 15.2 | 44.9 | 12/12 |
| Mendes 2020, men seated (OEP, n = 31) | 37.4 ± 8.4 | 21.9 ± 5.8 | 40.8 ± 10.5 | – |

Fitting the markers alone gives 32/12/56 just as well (χ² 1.1 against 1.9 over 12 components): the
markers don't pin the shares, the volumes do. The lower ribcage stays ~1.2 SD low (see STATUS).

## Postures (`breathstar stage3`)

One parameter set; supine and right side down are fitted (contact stiffness, belly-wall gain, the
upper rib muscles' postural share), 45° and face down are held out.

| | model | data |
|---|---|---|
| standing (derived from the hips: lumbar 13.5° more extended than sitting) | 41.3/15.3/43.4; end-expiratory volume as sitting | a little more ribcage than sitting (Verschakelen 1995, Gómez-Recio 2024); FRC as sitting (Attali 2024) |
| 45°, shares | 34.5/13.3/52.2 | Mendes men 31.0/14.3/55.4; LoMauro 2024 belly 52.0 |
| supine, shares | 23.0/9.8/67.3 | Mendes men 19.5/11.5/69.8; Kouyama 2016 14/18/66 |
| side-lying, floor-side lung | 59.3% | 51–62% (Amano, Grant) |
| side-lying, floor-side chest wall | moves less (234 vs 326 mL) | less (Nozoe 2014) |
| sitting → supine, end-expiratory volume | −0.84 L | −0.81 L (Lumb & Nunn) |
| sitting → side, end-expiratory volume | −0.40 L | −0.46 L |
| face down, belly | 73.6% | **42.5% (LoMauro 2024): a known miss** |
| supine drive | diaphragm ×1.04, upper rib muscles ×0.62 | parasternals 0.90–0.95 (Wakode), scalenes about halved when inverted, diaphragm unchanged |

## The spine's shape (`breathstar stage4`)

| | model | data |
|---|---|---|
| slumped / upright ribcage volume | 0.80 | 0.86 (Hazaki & Okada) |
| rotation 30°: lateral motion at the axilla | less (1.81 → 1.49 mm) | less (sitting-posture study, n = 7) |
| extension 15°: lateral motion at the 9th rib | less | **more (same study): a known miss** |
| side-bend 20°: wall | the open side moves more (295 vs 265 mL) | no data |
| side-bend 20°: lungs | the crowded side fills more (284 vs 276 mL) | no data |

## Legs (`breathstar legs`)

Knees bent, feet standing: the belly share rises 1.5 points, and the **low** belly moves ~27% more
(3.96 → 5.02 mm) while the high belly doesn't. The lumbar-flexion rule (0.15 × hip flexion) sits
inside supine MRI's 3–6° difference between legs flexed over a cushion and legs straight. The other
sizes are assumed; this is contrast H of the self-measurement plan.

## Lessons (`breathstar lesson`)

The example lesson's claims are mechanical and the model carries them (slumped: less ribcage;
braced: more; lifted lightly: the belly back; knees bent: more belly). For lessons drawn from real
recordings the pattern so far is: the model carries the mechanical relations (bracing against
proportional tone, the breath as a gauge of effort) and none of the attentional ones (tracing,
which side, integration). "One side breathes more" is a few millilitres either way.

## Tried and not adopted

Each is kept as an option, so it can be revisited.

- **An arched boundary for the compartments, as OEP draws it** (`compartments`): makes the lower
  ribcage smaller, not larger.
- **Ribs reaching lower at the side** (`AnatomyModel.lateralRibMargin`): +1–3 points of lower
  ribcage, at a cost to the marker fit.
- **Rib muscles regulated, diaphragm held:** needs the supine rib drive at 0.41, against
  0.90–0.95 measured.
- **The postural factor on the squared upright component** (`uprightSquared`): fits 45° almost
  exactly, but was chosen after looking at 45°, which would stop it being a test.
- **The bend's effect on the domes, solved from a fluid abdomen** (`bendDomeSolved`): makes
  extension worse and erases the side-bend's lung effect (the contents would just flow across).
- **Face down: stiffer flanks** (`flankStiffness`): too slow. **A free lift off the floor**
  (`contactFreeLift`, `contactAnchoring`): fixes face down (44%) only together with no postural
  loss, and breaks side-lying.
