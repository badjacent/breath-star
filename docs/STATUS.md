# Status

As of 2026-11-11. All seven stages of the lesson plan (`docs/LESSON_ADAPTATION.md` §9) are built:
configuration → body, the gravity rules, the spine's shape, lessons as data, slow-state hypotheses,
and the viewer playing a lesson. Numbers are in `docs/RESULTS.md`.

## Known issues (the 8 `withKnownIssue` checks)

- **Face down** (`proneRibcageShare`, two checks): the belly takes 74% of the breath; LoMauro 2024
  measured 42.5%. The floor holds the chest back more than the belly, and the breath escapes through
  the flanks. See "Weight bearing" below.
- **45°'s path** (`reclinedHeldOut`): the shares at 45° match the data, but the belly is only 33%
  of the way from sitting to supine (data 44–50%).
- **Extension at the 9th rib** (`extensionDependsOnWhereTheArchIs`, two checks): an arch moves the
  lateral lower ribs less; one small study (n = 7, at 1.5× tidal volume) found more. In an arch the
  ribs ease; the belly wall and flanks stiffen. A lower-back arch alone moves the lower ribcage more,
  a mid-back arch both levels less (contrasts C and C2 of the self-measurement plan).
- **Patient patterns** (`breathstar patients`, `PatientTests`): the paradoxes themselves hold
  (ribcage inward with the rib muscles paralysed, Mortola 1978; front belly inward with the diaphragm
  paralysed, Higenbottam 1977). The belly paradox sitting, where Kreitzer 1978 saw none, is masked by a patient's expiratory
  abdominals (used upright, much less lying down; size assumed, ~1.5 cmH2O). Estenne 1985's inward lower front
  (diaphragm alone, supine) is met since 2026-11-11 by the costal arch's stiffness (×5, fitted inside
  the window where the seated patient directions hold); the diaphragm's insertional pull doesn't do
  it (`docs/RESULTS.md`).
  Whether each paradox is worse lying down flips with the convention (same drive or same breath),
  so the model doesn't decide it. On the earlier fitted supine body
  (`patientPatternsLyingDownKnownIssues`, `abdominalParadoxLyingDownKnownIssue`) the patterns were
  lost when volumes became OEP-style surface volumes.

## Open problems

- **The lower ribcage** is 15% of the seated breath against Mendes's 22% (1.2 SD). Not the
  compartment boundary, not the ribs' lower edge, not the band's stiffness. Closed for now as within
  the spread between people.
- **Weight bearing beyond the trunk.** Face down needs the trunk to rise off the floor as a whole;
  side-lying needs it not to (the hip and shoulder carry the weight). The fraction of weight the
  pelvis and shoulder girdle carry would decide both (`GravityRules.contactAnchoring`), but no
  per-segment weight share has been found. If it has to be fitted to face down, face down stops
  being a test.
- **The upper rib muscles face down.** The postural share (0.4, fitted) treats face down as "not
  upright". Human surface EMG (30 young women, LITERATURE pass 18) finds intercostal and diaphragm
  activity lower prone than supine, so the loss applies face down too, and removing it is not the
  way to fix face down: the answer has to be mechanical.
- **Unsourced sizes:** the tone factors (held ×5, light ×1.5, softened ×0.7), the belly wall's
  bulge peak with the knees bent, the bend's dome coupling (0.5), the wall's bend gain, the slow-state hypotheses' sizes (respiratory
  thixotropy is real but measured as volume after-effects lasting a few breaths, not stiffness
  over minutes: LITERATURE pass 15), and every angle in a lesson encoding.
- **Standing** is derived from the hips (`BodyConfiguration.standing`) without the tonic
  abdominal activity standing is known for (Druz & Sharp 1981), which nothing sizes.
- **Arms:** the direction is sourced (unsupported arm elevation takes motion from the upper
  ribcage, more sideways than forward; LITERATURE pass 16), the size is not; not built.
- **Not modelled:** the pelvic floor, a posterior abdominal wall, the head and neck, pelvic rocking.

## Next

The model's lesson-scale predictions can only be checked on a body: `reference/SELF_MEASUREMENT_PLAN.md`
lists ten contrasts with the predictions written down first, and `Tools/measure/track.py` tracks skin
markers in a phone video.
