# Breath Star

A mechanical model of breathing in the trunk. Give it a configuration (how the body sits or lies,
what it rests on, how the spine is bent, where the legs are, which muscles are held) and a
breathing drive; it computes where the breath goes: how much the upper ribs, the lower ribs and the
belly move, on each side, and how each lung fills. It can step through a movement lesson as a
sequence of configurations and say, per step, what changes and which rule accounts for it.

This is **Breath Star version one**. Version zero was a hand-designed picture of the breath's
patterns (deprecated, not published). Version one computes those patterns from the body's
mechanics instead, so a pattern can be checked rather than drawn.

It is right in direction and proportion, not in millilitres; it is not a medical model. Every number
is either sourced (with the paper, in `reference/LITERATURE.md`), fitted (and said so), or
assumed (and said so).

## Build and run

Swift 6, macOS 14 or later. No dependencies.

```sh
swift build -c release
swift test                                   # 136 tests, about 30 s (known issues: see docs/STATUS.md)

.build/release/breathstar stage3             # the postures with data: seated, 45°, supine, side, face down
.build/release/breathstar stage4             # the spine's shape: side-bend, slump, extension, rotation
.build/release/breathstar legs               # lying on the back with the knees bent, one foot standing
.build/release/breathstar lesson             # the example lesson, step by step, with verdicts
.build/release/breathstar lesson --file my-lesson.json
.build/release/breathstar measure-predictions  # what a self-measurement should find (reference/SELF_MEASUREMENT_PLAN.md)
.build/release/breathstar viewer             # writes out/viewer.html: every case, scrubbable, with the lesson
```

Open `out/viewer.html` in a browser (it is self-contained). Run `breathstar` with no arguments for
every command.

## What it is

- **Anatomy (A1):** the trunk as a stack of half-ellipse sections from the pelvis to the top of the
  ribcage, two rib bands that rotate (pump and bucket handle) and dilate, two hemidiaphragms with a
  zone of apposition, an abdominal wall with a bulge and flanks. Volumes are measured as optical
  plethysmography measures them (surfaces between marker rings).
- **Mechanics (A2, sided):** linear springs on those coordinates, incompressible abdominal contents,
  two lungs and a compliant mediastinum, and three fixed-sign muscle groups (diaphragm, upper and
  lower rib muscles) fitted to published marker motion and compartment volumes.
- **Configuration → body (stages 2–4):** gravity in the body's frame, contact patches, the spine's
  shape and the legs set the body through general rules (a hydrostatic abdomen and a settle solve;
  contacts as springs; stiffness by how far the wall is stretched or crowded), with one parameter
  set for every posture.
- **Lessons (stages 5–7):** a lesson is a JSON file of steps (`docs/LESSON_ADAPTATION.md`,
  `Sources/BreathStar/Anatomy/LessonFile.swift`); slow changes over a lesson are switchable
  hypotheses, off by default; the viewer plays a lesson step by step.

## Documents

- `docs/DESIGN.md`: what the model is for, what it is not, and how it is built.
- `docs/RESULTS.md`: the model against each source, what was tried and rejected.
- `docs/STATUS.md`: open problems and known issues.
- `docs/LESSON_ADAPTATION.md`: the design notes behind configurations and lessons.
- `docs/PRIVATE.md`: about references to material that isn't in this repository.
- `reference/LITERATURE.md`: every source, how far it was read, and what was taken from it;
  `reference/*.json`: the numbers used.
- `reference/SELF_MEASUREMENT_PLAN.md`: how one person could test the model's predictions, with
  `Tools/measure/track.py` for tracking skin markers in a phone video.

## Licence

MIT. See `LICENSE`.
