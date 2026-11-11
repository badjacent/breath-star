# Design

## Why

1. **A picture of the breath doesn't explain it.** Breath Star version zero drew the breath's
   patterns by hand; it couldn't say why lying on one side, twisting or holding the belly changes
   them. In a mechanical model, side-lying is a change of gravity and of which surface takes the
   weight, and the breath's new distribution follows from it.
2. **Movement lessons make mechanical claims about the breath.** "Compression on one side pushes
   the breath to the other; flexion goes with the exhale; effort takes the belly out of the breath."
   A model can compute those relations, and say when one is attention or felt sense rather than
   mechanics.
3. **Holding becomes literal.** A hold raises a region's stiffness; the same drive meets more
   resistance there, and the volume goes wherever is softer.

## What it is not

- Not a medical or clinical model. It needs to be right in direction and proportion, not in
  millilitres.
- Not a finite-element ribcage. It starts from a handful of coordinates and adds detail only where
  two cases need telling apart.
- Not a movement simulator. Movement enters as a slow change of configuration (a side-bend, a
  slump, a bent knee), not as dynamics.

## Principles

- **State drives every display.** Nothing on screen is drawn by hand; each view reads the model's
  state.
- **A deterministic engine, apart from its views.** A library with a command-line tool and tests;
  the viewer is a client.
- **Measured, not tuned by eye.** A change to a parameter is checked against fixed reference cases,
  one step at a time, and the result is recorded (in `docs/RESULTS.md` for what stands).
- **Sourced, fitted or assumed, always said.** A fitted number is not presented as a finding;
  an assumed one is labelled where it is used.
- **No per-posture fitted factors.** If a new position needs its own number, a rule is missing.
- **One input vocabulary.** Lesson steps become configurations, and nothing else drives the model.

## Two rendering contracts

- **Anatomical:** modelled wall and diaphragm motion, and air. The line views.
- **Experiential:** emphasis and the breath's felt shape, never presented as air going there. The
  blur view is a felt container (round, no corners, its light by how much each area moves), with its
  mapping stated on the page and reversible.

A pattern from version zero that the model cannot produce from a plausible configuration may be a
model gap, or it may be attention or felt connection, which a trunk model does not cover. It is not
evidence that no body makes it.

## How it is built

| Layer | Code | What it does |
|---|---|---|
| A1 geometry | `Anatomy/Anatomy.swift` | Sections, rib bands, diaphragm, abdominal wall; displacement of any surface point; OEP-style volumes; marker sectors |
| A2 mechanics | `Anatomy/Mechanics.swift`, `Sided.swift`, `MuscleGroups.swift` | Jacobians by finite differences, stiffness, couplings (costal arch, sternum, mediastinum), muscle groups, simulation |
| Configuration | `Anatomy/Configuration.swift` | Gravity, contact patches, spine, legs, tone |
| Rules | `Anatomy/Settle.swift`, `Bending.swift` | Hydrostatic abdomen and settle solve; contacts; stiffness by strain (ribs as struts, the wall as a membrane); posture-dependent drive |
| Lessons | `Anatomy/Lesson.swift`, `LessonFile.swift`, `SlowState.swift` | Steps as data, claims and verdicts, slow-state hypotheses |
| Views | `BreathStarCLI/Viewer*.swift` | The self-contained HTML viewer |

Stages 2–7 follow `docs/LESSON_ADAPTATION.md` §9; `docs/STATUS.md` says where each stands.
