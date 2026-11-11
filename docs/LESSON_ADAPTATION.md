# Adapting the model to whole lessons

Design notes, 2026-11-10, written after an independent review of the model (private) and before
stages 2–7 were built. They are kept as the rationale for the configuration → body architecture.
What was built since follows them closely, with the differences recorded in `docs/STATUS.md`
and `docs/RESULTS.md` (for example: the stage-3 rules, the membrane wall, `Legs` for §4.6, lessons
as JSON files). Where a choice belonged to the author, these notes say so.

## The goal, as the author put it

> Ultimately I want to model breath through different shapes of the body, basically anything
> that could come up in a Feldenkrais lesson, and track this a bit through a lesson
> (elasticity could change over time as you breathe in various positions).

Two extensions, then:

1. **Shape.** Any trunk configuration a lesson asks for, not three named postures.
2. **Time.** The body's properties drift during a lesson, so the same position breathes
   differently at minute 40 than at minute 2.

## The short version

- **Keep the breath solver. Change where its bodies come from.** Today a posture is a
  hand-built body with its own fitted factors. It has to become the output of one function:
  configuration in, body out.
- **Use three timescales.** A breath (seconds, the existing linear solve), a position
  (settling under gravity and contact, a new static solve), and a lesson (minutes, a few
  slowly drifting state variables).
- **Replace per-posture factors with three general rules:** a hydrostatic abdomen, stiffness
  that depends on how far a part is from its neutral shape, and contacts as a list of
  patches.
- **Do the three prerequisite fixes from the review first.** Each one becomes much more
  expensive to fix after this generalisation.
- **Be plain about evidence.** Almost nothing in the literature measures breathing in lesson
  positions, or before and after a lesson. The honest product is direction and rough
  proportion, each result labelled with what it rests on.

## 1. Why the current structure will not stretch

Each posture so far has cost a day and produced its own numbers:

| Posture | How it was built | Fitted for that posture alone |
|---|---|---|
| Seated | `AnatomyModel()` from Takashima's seated diameters | the whole reference breath |
| Supine | `AnatomyModel.supine()`, a second profile | ribcage ×1.79, abdomen ×1.35 |
| Right side down | `rightSideDown()`, a third profile | ribcage ×2.5, abdomen ×1.8, bed 1, dome share 2.0, shoulder ×2 |

The supine factors were first copied to side-lying and did not fit. That is the important
signal: **when every posture needs different multipliers, the rule that produces them is
missing.** A lesson has dozens of positions and no marker data for any of them, so there will
be nothing to fit the multipliers to. The model has to derive them.

Other limits that a lesson meets at once: a fixed straight spine; symmetric cross-sections;
no prone, hands-and-knees or bridging; no pelvis, shoulder girdle, arms or legs; contact as
a stiffness multiplier on a whole flank.

## 2. Prerequisites (from the review; do these first)

1. **Make the forces mean something.** Replace one free force per coordinate with a few
   muscle groups of fixed sign. Section 5 below changes stiffness over time; that is
   meaningless while invented inward forces are absorbing stiffness errors.
2. **Settle how marker motion becomes volume** (the 62% against 36–41% seated abdomen
   question). Every new shape will reuse that conversion.
3. **Change the readout.** For lessons, report where the wall moves, by region, side and
   front or back, in millimetres. Compartment shares mislead as soon as a part is held
   (the 2026-11-10 review, private; section 3). Keep shares for comparing with OEP studies only.

## 3. Three timescales

| Layer | Timescale | What it computes | Status |
|---|---|---|---|
| **Breath** | seconds | One breath's motion about a fixed operating point: the existing linear virtual-work solve | exists (A2, sided) |
| **Position** | settles in seconds, held for minutes | The resting shape, pre-strains, pressures and contacts for a configuration | new |
| **Lesson** | minutes | Slow drift of tone and tissue state, step by step | new |

**Keep the breath layer linear.** A quiet breath moves the wall a few millimetres. The
nonlinearity that matters is in how the position sets the tangent stiffness, the Jacobians
and each muscle's effectiveness. So the breath solve stays as it is, and receives
`K(configuration, state)`, `J(configuration)` and `F(configuration, state)` from the layers
above. One breath costs milliseconds, so a whole lesson is a few hundred solves.

**The slow variables are frozen during a breath** and updated between breaths from
breath-averaged quantities (how far each region was strained, how much it moved). That
separation keeps the system simple and testable.

## 4. The position layer: configuration in, body out

### 4.1 Inputs

Extend the original plan's input vocabulary into one value type. Suggested fields:

- **Gravity**, as a unit vector in the body's frame. This replaces tilt and roll, and covers
  prone, hands-and-knees, inverted pelvis (bridging) and everything between.
- **Spine shape:** a few angles. Start with flexion/extension, side-bend and rotation, each
  for the lumbar and thoracic spine (six numbers). Add the neck only if a lesson needs it.
- **Pelvis tilt**, and **hip flexion** per side (knees toward the chest shortens the
  abdominal cavity).
- **Shoulder girdle and arm position** per side (an arm overhead changes the upper ribs).
- **Contacts:** a list of patches. Each has a region, a side, an angular sector, a height
  range and a kind: floor, chair, own hand, own thigh, a roller.
- **Holds:** tone on named regions (already in the plan).
- **Drive:** quiet, deep, mostly diaphragm, mostly ribs, plus cycle length.

Limbs, head and pelvis are **not simulated**. They enter as loads and constraints on the
trunk's coordinates.

### 4.2 Geometry on a curved centreline

Today the sections stack on a straight vertical spine. Generalise to sections perpendicular
to a curved centreline given by the spine angles, with left and right half-widths free to
differ. `SideLyingArc` is already a small version of this: it has the offset, the tilt, the
curvature and, most usefully, `lateralStrain` (how much each side's wall is lengthened or
shortened by the bend). Promote that idea from a drawing aid to the geometry itself.

Acceptance test for this refactor: the three existing postures, expressed as configurations,
reproduce their current outputs before any new physics is added.

### 4.3 Three general rules to replace the per-posture factors

**Rule A: a hydrostatic abdomen.** The abdominal contents behave like a liquid. Pressure
rises about 1 cmH2O for each centimetre of depth along gravity. That is large: a quiet
breath's whole abdominal pressure swing is about 1.5 cmH2O. So the direction of gravity
decides which part of the diaphragm is loaded, pushed headward and lengthened.

- This single rule should produce what `OperatingPoint`, `SidedOperatingPoint`,
  `dependentShare` and the lumped model's `dependentDiaphragmGain` each produce by hand:
  the back of the diaphragm working more supine, the floor-side hemidiaphragm working more
  lying on the side, and whatever happens prone or with the pelvis lifted.
- It needs a diaphragm in at least four patches (left/right × front/back) so it can respond
  to any gravity direction. The front-to-back `diaphragmTilt` and the two hemidiaphragms are
  the existing pieces.
- This is the "gravity proper" that the log deferred because the model was linear. It
  belongs in the position layer, which is where the nonlinearity now lives.

**Rule B: stiffness depends on distance from neutral.** The relaxed chest wall's
pressure–volume curve flattens away from its resting volume. A part moved away from its
neutral shape resists further motion more. The author's own account of side-lying is this rule
("deformed and away from the point of optimal elasticity"), and `DeformedSideStiffening`
is a one-off version of it.

- Give each breathing coordinate a stiffening law, `k = k0 · f(pre-strain)`, and let the
  configuration set the pre-strain: side-bend lengthens one flank and crowds the other;
  flexion closes the front and opens the back; rotation winds the ribs; an arm overhead
  lifts the upper ribs toward their inspiratory end.
- **Which way the breath then goes is an open question, not a given.** "Compression on one
  side pushes the breath to the other" is lesson lore. A crowded side might be stiff
  (nowhere to go) or might have the most room to open. The law must be able to express
  both, and the direction must come from a source or a measurement.
- The shape of `f` and its gain are unsourced today. Start with one shared law for all rib
  coordinates and one for the abdominal wall. Do not give each coordinate its own.

**Rule C: contacts are patches with a frame.** A contact acts on the outward motion of the
patch it touches, one-sided, with a stiffness for what it rests on (floor, mattress, hand).
The bed spring is the existing special case. Two things to carry over from the review:

- State the frame of every reported motion: relative to the spine, or to the room. They
  differ whenever the trunk rests on a part that breathes.
- Whether a contact lifts the trunk, deforms the tissue locally, or blocks the motion is a
  property of the contact that needs evidence. Do not assume lift (the 2026-11-10 review, private; section 1).

### 4.4 The settle solve

Given a configuration, solve once for the resting state: wall pre-strains, diaphragm
position per patch, end-expiratory lung volume, abdominal pressure field, which contacts
bear load. This is a small nonlinear static problem in the same coordinates the breath uses,
with nonlinear springs, the hydrostatic load and one-sided contacts. Then linearise about it
and hand the result to the breath layer.

### 4.5 The acceptance test that matters

**One parameter set, all sourced postures at once, no per-posture refit.** The calibration
targets already in the ledger:

- seated, 45° and supine shares and tidal volumes (Mendes, Sonpeayung);
- Takashima's markers in three postures, including the three sideways components the
  review found unused;
- the floor-side lung's share lying on the side (Amano, Grant: 51–62%);
- end-expiratory volume by posture (Lumb & Nunn; Amano, which also has prone).

Fit on some postures and predict the others, rotating. If the general rules cannot do this,
they will not be trustworthy in a lesson position, and that is worth knowing early. Prone
is a good untouched test because nothing in the model has been tuned toward it.

### 4.6 Worked example: lying on the back, knees bent and feet standing

The author's example (2026-11-10): "When lying down, I think the model assumes the legs are
long. If the knees are drawn to the ceiling, this drops the lower back and also fixes the
angle of the pelvis, so that the elasticity near the lower part of the abdomen is changed."

**Where the model stands today.** It has no legs and no pelvis. The supine body is whatever
Takashima's subjects were doing (the paper does not give the leg position; presumably legs
long), and the pelvis is a fixed edge at the bottom of the abdominal wall. So the leg
position is built in invisibly, and nothing can be adjusted for it.

**What the position changes.** Four separate things:

1. **Rest shape.** The hip flexors slacken, the pelvis rolls back and the lumbar curve
   flattens.
2. **Wall length.** Rolling the pelvis back brings the pubic bone toward the ribs, so the
   front abdominal wall is shorter and slacker, most of all low down. With the legs long it
   is drawn longer and tauter.
3. **Contact.** The low back rests on the floor, where before there was a gap.
4. **Anchoring.** How freely the pelvis can rock with the breath changes.

**What the model needs for it.**

- **Two inputs:** hip flexion per side, and whether the feet bear weight. They are not
  simulated. They set the items below.
- **Pelvis tilt and lumbar angle in the rest geometry**, derived from those inputs (part of
  4.2).
- **Wall stiffness that follows wall length:** Rule B applied along the abdominal wall. A
  slack wall is softer, a stretched one stiffer. No knee-specific rule.
- **An abdominal wall with an upper and a lower part.** Today the belly is one bulge, zero
  at the pelvis and at the costal margin, peaking in the middle (`bulge(z)`). It cannot
  express "the lower abdomen changed". Two zones, or one number that moves the bulge's peak
  up or down, is the smallest change that can.
- **A contact patch under the lumbar spine** (Rule C), on or off.
- **A stiffness on pelvic rocking,** set by the leg position, if the pelvis is allowed to
  move with the breath at all.

**Two things not to assume.**

- **Which way the pelvis is "fixed".** The author's sense is that knees-up fixes the pelvic
  angle. The opposite reading is also plausible: the pelvis is freer to rock with the feet
  standing (the pelvic clock is taught there), and long legs hold it tilted forward by
  their weight. Make it a parameter. Do not hard-code either.
- **Where the breath then goes.** A slacker lower wall suggests more motion low in the
  belly. A low back on the floor suggests less room behind. No measurement comparing the
  two positions is in the ledger, and every size here is unsourced. Label the result
  *derived* or *assumed* (section 7).

This is a good first case for the self-measurement in section 8: one person, legs long and
then knees up, with a marker or band high and low on the belly.

**The general pattern.** Any limb position reduces to four questions:

1. What does it do to the rest shape where the limb attaches?
2. Which stretch of wall does it lengthen or slacken?
3. What contact does it add or remove?
4. What does it anchor or free?

The same four cover:

- **an arm overhead:** lifts and pre-stretches the upper ribs on that side;
- **one knee bent:** this example, on one side only;
- **knees tilted to one side:** a twist of the pelvis against the ribs;
- **thighs drawn onto the belly:** different from feet standing. It adds a contact on the
  front of the abdomen and shortens the cavity, which pushes the diaphragm up (Rule A);
- **lying on the side with the knees bent:** the usual lesson position. Takashima's leg
  position there is unreported too.

Encode each as answers to the four questions, acting through Rules A–C. If a position seems
to need a rule of its own, treat that as a sign that one of the three is incomplete.

## 5. The lesson layer: properties that drift

"Elasticity could change over time" covers at least four different things. Keep them
separate, because they have different causes, time courses and evidence.

| Slow variable | What it is | Likely time course | Evidence to look for |
|---|---|---|---|
| **Tone** per region | Background muscle activity; raises stiffness and shifts the rest position | seconds to minutes; follows attention, effort and support | Druz & Sharp, Vellody (direction only, already in the ledger) |
| **History-dependence of muscle** (thixotropy) | Muscle held still gets stiffer; muscle just moved is looser; the rest position shifts toward where it was held | tens of seconds to minutes | Work on thixotropy of respiratory muscles and its effect on resting lung volume. I recall papers by Homma and Hagbarth around 2000. **From memory: verify before use.** |
| **Passive creep** | Connective tissue held at stretch slowly lengthens | minutes | General tissue mechanics; chest-wall-specific data unknown |
| **Lung state** | Lung compliance falls during shallow breathing and is restored by a deep breath or sigh | minutes; reset in one breath | Classic respiratory physiology. I recall Mead and Collier, and Ferris and Pollard, around 1959–60. **From memory: verify.** |

For Feldenkrais the first two are probably the ones that matter. the original plan already asks
whether tone, more than drive, is the main lever of "let the breath come".

**Form.** One or two state numbers per region, each following a first-order law toward a
target set by the current step:

- tone moves toward the step's target (supported and unattended → lower; held → higher);
- the rest position moves toward where the part has been held;
- stiffness falls in regions that have just moved a lot and rises in regions kept still.

Each law has a gain and a time constant. **None of them is sourced in size.** So:

- Treat every one as a named, switchable hypothesis, off by default, exactly as the
  expiratory mechanisms are now.
- The output of the lesson layer is a sensitivity statement: "if the flank's tone falls by a
  third over these five minutes, the supine breath afterwards moves this much more into the
  left lower ribs." It is not "this lesson does X".
- Do not fit these to the lesson's own claims. That would make the model agree with the
  lore by construction.

**The natural experiment is the lesson's own scan.** Lessons begin and end in a reference
position (lying on the back, noticing). Compute the breath in that position before, and
again after with the drifted state. The difference between them is the thing a student
reports, and the thing a measurement could check.

## 6. Input: a lesson as data

A lesson becomes a list of steps. Each step is a configuration (section 4.1) plus:

- duration, and how many repetitions of a movement;
- the movement, as a slow path between two configurations (the original plan: movement is a slow
  change of configuration, not dynamics);
- what is held and what is released;
- the drive mode;
- provenance: transcript anchors, and whether each field is stated, implied or inferred
  (three words: said in the lesson, implied by it, or inferred by whoever encodes it).

Hand-encode about ten steps of one real lesson first. Only then sketch a mapping from a
lesson-analysis pipeline's fields (activation and inhibition → holds and tone targets; ground
push → contacts; differentiation → the movement's path).
Encoding by hand first will show which configuration fields lessons really use. Expect to
cut the list in 4.1.

## 7. Output for a lesson

Per step:

- **Where the wall moves**, by region × side × front/back, in millimetres, plus each lung's
  share and the diaphragm's descent per patch.
- **The change** from the previous step and from the opening scan.
- **Why:** which rule accounts for the change. In a linear model this is cheap: switch
  gravity, contact, pre-strain and tone off one at a time and re-solve.
- **At fixed drive and at matched breath size**, side by side. They answer different
  questions (2026-11-09 review).
- **An evidence label** on each result:
  - *anchored*: the position is one with published data, and the model reproduces it;
  - *derived*: follows from the general rules in a position with no data;
  - *assumed*: depends on an unsourced size, with the range it was swept over.
- **A verdict against the lesson's own claim**, in an earlier review's words (private): "consistent
  under these assumptions", "not represented", or "contradicts this modelled case". Never
  true or false.

Keep the two rendering contracts apart, as now: anatomical motion, and experiential
emphasis. A lesson step often directs attention to a place where little moves. That is not
a model failure.

### 7.1 The shape of the blur: a felt container, not the skin outline

The author, 2026-11-10: the blurred figure's shape did not match the breath as felt, though
it was closer to the physical outline. Wanted: something round without corners, "maybe oval
with more weight toward the bottom, less weight given to the corners, especially the
shoulders", matching a felt image of what breath is, and not cropped: "the areas toward the
tips of the range are very important."

**The corners are mostly artefacts of the model, not anatomy.** The blur is drawn on the
skin outline, which has two artificial features:

- **Flat cuts.** The trunk stops at the iliac crests (z = 0) and at `top` (43 cm) with flat
  caps. The real container closes in a dome at each end: the lung apices at the root of the
  neck, and the pelvic bowl below.
- **Shoulder width.** The upper outline carries the shoulders, but the shoulder girdle sits
  outside the ribcage. The space that breathes is narrow at the top and widest low down.

The two cavities together are egg-shaped, heavier at the bottom, with no corners. So
the felt image is nearer the cavity than the display was. And the model is what crops: the
rounded ends called the tips are what the flat caps remove.

**Step 1 (anatomical): draw the cavity, closed at both ends.** A dome above and a bowl
below, in place of the silhouette. The model has no motion in those ends yet (the pelvic
floor was planned for a later version; the lung apices are in no plan), so at first they are carried by
their neighbours. Say so on the page. If the ends matter to the display, that is a reason
to model them.

**Step 2 (if the cavity is still not the wanted shape): treat it as a map projection.** A
smooth, reversible mapping from the body surface to an oval, as an oval world map does for
a globe: every place kept, every neighbour relation kept, the poles squeezed but present.
That gives exact meanings to what was asked for:

- **Not cropped:** every surface point has a place in the oval.
- **Less weight in the corners:** those regions are compressed in space, **not dimmed**. A
  brightness falloff toward the edges is the wrong tool; it would fade the tips.
- **More weight toward the bottom:** the lower regions get more room.

**What decides how much room a region gets.** Two principled choices:

- **By how much it breathes.** Display area in proportion to the region's share of the
  volume change in the posture's reference breath. The abdomen takes most of it in the
  current model, so a bottom-heavy oval follows from the model's state with nothing drawn
  by hand. (That share is itself in question: the 2026-11-10 review, private; section 2. The layout would move
  with it.)
- **By how it is felt.** Make the shape a few adjustable numbers (roundness, how low the
  widest point sits, how far the shoulders are compressed) and let the user tune them by
  eye. Record the settings. That is a description of one person's body image, and honest
  when labelled so.

Suggested order: build the first, then let the second correct it.

**An alternative layout to test against the oval:** radial. Breath as expansion from a
centre low in the belly, with the top and bottom as poles. The two axes are then how far
along the container a point lies, pole to pole, and how far round.

**Keep fixed.**

- The line views stay anatomical. The blur becomes, explicitly, the felt shape. This is the
  experiential contract the original plan names.
- The mapping is stated on the page and stays reversible, so the model still drives every
  pixel and light per area keeps a defined meaning.
- Shape and brightness are separate controls. Changing the container's shape must not
  change which regions are bright.
- The existing label problems in the blur (the 2026-11-10 review, private; section 8) are independent of this and
  still need fixing.

## 8. Evidence

The literature covers quiet breathing in a handful of clinical postures. It does not cover
side-bending, twisting, an arm overhead, knees to chest, or before-and-after a lesson. The
general rules can extrapolate, but nothing will check them.

**A decision for the author (since taken, `reference/SELF_MEASUREMENT_PLAN.md`):** the
original plan put "measuring the user's breath" out of scope. For this goal, a small
measurement of one's own breath is probably the only route to validation.
Options, cheapest first: two elastic bands (ribcage and abdomen); a few skin markers and a
fixed camera; a phone's depth camera pointed at the trunk. One person, a few positions, a
before-and-after scan. It would test Rule B's direction and the lesson layer's size, which
no paper will. It was the author's call.

Until then, every result outside the sourced postures should carry the *derived* or
*assumed* label visibly, in the viewer as well as the log.

## 9. Order of work

Each stage has a check that can fail.

1. **Prerequisites** (section 2).
2. **Configuration → body, no new physics.** Gravity vector, contact list, one generator.
   *Check:* the three current postures reproduce their current numbers.
3. **Hydrostatic abdomen and the settle solve; patchwise diaphragm.** Remove the
   posture-specific operating points. *Check:* one parameter set across seated, 45°, supine
   and side-lying; prone predicted, not fitted.
4. **Curved centreline, asymmetric sections, the stiffening law.** *Check:* seated side-bend
   and rotation give stable, symmetric-when-mirrored results; the direction question in
   Rule B is stated with whatever evidence was found.
5. **Lesson steps as data;** ten hand-encoded steps of the pilot lesson. *Check:* per-step
   output with labels; compare with the lesson's own relation labels (release, gauge, tracing, …) and record agreement,
   disagreement and "not represented".
6. **Slow state,** as switchable hypotheses, with the before-and-after scan. *Check:*
   sensitivity tables, not claims.
7. **The viewer plays a lesson:** a step list beside the breath, with the scan comparison.

Stop after stage 3 and review. If one parameter set cannot span the sourced postures, the
later stages should be rethought before they are built.

## 10. What not to do

- **No per-position fitted multipliers.** If a new position needs its own number, a rule is
  missing.
- **No finite-element trunk, and no simulated limbs.** Stay with a small set of coordinates.
- **No new configuration coordinate without a lesson step that needs it** and a rule
  (A, B or C) through which it acts.
- **No time dynamics inside the breath solve.** Slow variables change between breaths.
- **No slow-state law switched on by default** until something sizes it.
- **Do not let a lesson's claim become a calibration target.**
- **Do not start this before the prerequisites.** Generalising the current force
  calibration and volume conversion would multiply their problems across every position.
