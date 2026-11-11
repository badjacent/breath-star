# Literature pass 1 (2026-11-09)

What the model can be checked against, and how far each source was read.
Numbers in `compartments.json` come only from rows marked **table read**.

## Read levels

- **table read**: the numbers were taken from the paper's own tables (the
  full text was open).
- **abstract read**: the abstract was read, but not the full text. The
  qualitative claim can be used, but there are no numbers.
- **citation only**: the citation was checked, but neither the abstract nor
  the text was read. Nothing in the model rests on it yet.

## Sources

### Compartment shares by posture

**Mendes LPS, Vieira DSR, Gabriel LS, et al., Parreira VF (2020).** Influence
of posture, sex, and age on breathing pattern and chest wall motion in healthy
subjects. *Braz J Phys Ther* 24:240–248. doi:10.1016/j.bjpt.2019.02.007,
PMC7253877. — **table read** (Table 2, Table 3).

The 83 participants were healthy adults: 31 men and 52 women, aged 21–85.
They were measured by OEP (optoelectronic plethysmography) seated, at 45°,
and supine. The paper gives each compartment's share of tidal volume as mean
(SD):

| | Men seated | Men 45° | Men supine | Women seated | Women 45° | Women supine |
|---|---|---|---|---|---|---|
| Upper (pulmonary) ribcage % | 37.4 (8.4) | 31.0 (10.6) | 19.5 (9.9) | 43.0 (11.4) | 39.7 (14.3) | 23.0 (10.5) |
| Lower (abdominal) ribcage % | 21.9 (5.8) | 14.3 (3.9) | 11.5 (4.4) | 19.5 (5.4) | 13.1 (5.0) | 11.9 (4.6) |
| Abdomen % | 40.8 (10.5) | 55.4 (13.3) | 69.8 (13.4) | 37.4 (12.2) | 46.5 (15.9) | 65.4 (13.3) |
| Chest-wall tidal volume (L) | 0.84 (0.45) | 0.59 (0.26) | 0.58 (0.28) | 0.53 (0.23) | 0.44 (0.16) | 0.41 (0.16) |
| Breathing rate (bpm) | 15.7 | 15.7 | 16.2 | 16.7 | 16.9 | 17.4 |

The regression in Table 3 gives these effects:

- Going from seated to supine adds +28.3 points to the abdomen's share,
  −19.1 to the upper ribcage's and −8.8 to the lower ribcage's.
- Each year of age adds +0.29 points to the abdomen's share and takes −0.20
  from the upper ribcage's.

Posture has the largest effect of any variable, which suits the model:
gravity is a first-class input.

**Method details that matter:**

- The 45° posture is given only as "45° of trunk inclination"; there are no
  backrest details.
- OEP used **89 markers seated, but 52 inclined and supine**. With the back
  on a support, the reclined volumes come from the front surface, with the
  back treated as fixed.
- The postures came in a **fixed order** (seated, 45°, supine); they were
  not randomized.

**Romei M, Mauro AL, D'Angelo MG, et al., Aliverti A (2010).** Effects of
gender and posture on thoraco-abdominal kinematics during quiet breathing in
healthy adults. *Respir Physiol Neurobiol* 172:184–191.
doi:10.1016/j.resp.2010.05.018. — **abstract read.**

The 34 adults were measured in five postures, from seated (with and without
a back support) to supine. As the trunk tilts back, ribcage displacement,
tidal volume and ventilation fall progressively, and the abdomen's share
rises progressively. A back support while seated changes the breathing
pattern. In this sample, the posture effect on the abdomen was significant
only in women, which differs from Mendes. **The full text is closed**
(checked 2026-11-09). OpenAlex and Semantic Scholar list it as closed; the
Milan repository has a restricted PDF with a "request a copy" form; the
Politecnico di Milano record has no file. It needs a library login, a
purchase, or a request to the authors. Mendes (open) says Romei reported the
ribcage only as one compartment.

**Sonpeayung R, Tantisuwat A, Janwantanakul P, Thaveeratitham P (2019).**
Total and compartmental chest wall volumes, lung function, and respiratory
muscle strength in individuals with abdominal obesity: effects of body
positions. *J Obes* 2019:9539846. doi:10.1155/2019/9539846, PMC6942872. —
**figure read.** The means are printed on the plots in Figures 2 and 3. The
error bars can't be read as numbers, and the text doesn't say whether they
are SD or SE.

The study covers 20 healthy lean men aged 27, plus an obese group, which
isn't used here. Each was measured by OEP over 5 minutes of quiet breathing
in four positions: sitting upright without a backrest; sitting upright with
padding at shoulder level; Fowler's (45° on a bed, knees slightly bent); and
supine. For the controls:

| | Sit, no support | Sit, back support | Fowler's 45° | Supine |
|---|---|---|---|---|
| Ribcage % | 63.6 | 64.8 | 52.1 | 37.5 |
| Abdomen % | 36.4 | 38.9* | 47.9 | 62.5 |
| Ribcage L | 0.35 | 0.33 | 0.23 | 0.14 |
| Abdomen L | 0.19 | 0.19 | 0.20 | 0.38 |

\* The back-support labels sum to 103.7%; every other position sums to
100%, so one of the two is probably misprinted.

What it shows:

- **A back support barely matters when the trunk is upright.** This is the
  comparison Romei was wanted for.
- **45° sits about 44% of the way from sitting to supine** in abdominal
  share, close to Mendes's men (50%).
- **The abdomen's volume hardly changes until the body is flat**
  (0.19–0.20 L, then 0.38 L). All the change before that is in the ribcage.
- **Total volume is lowest at 45°** (0.43 L) and about equal sitting
  (0.54 L) and supine (0.52 L). That disagrees with Mendes, where volume
  falls steadily to supine.

### Side-lying

**Nozoe M, Mase K, Takashima S, et al. (2014).** Measurements of chest wall
volume variation during tidal breathing in the supine and lateral positions
in healthy subjects. *Respir Physiol Neurobiol* 193:38–42.
doi:10.1016/j.resp.2013.12.016. — **abstract read.**

The 18 healthy subjects were measured by OEP supine and in right and left
side-lying. Supine, there is no left/right difference between compartments.
Side-lying, the chest-wall volume change is **lower on the dependent (lower)
side**, because the lower ribcage and abdomen move less there. The full text
has the per-side volumes and is the next thing to get.

**Takashima S, Nozoe M, Mase K, et al. (2017).** Effects of posture on
chest-wall configuration and motion during tidal breathing in normal men.
*J Phys Ther Sci* 29:29–34. doi:10.1589/jpts.29.29. — **table read** (open
access).

The 15 healthy men were measured by OEP supine, in right side-lying (resting
on the floor) and sitting. Tidal volume was 0.52, 0.51 and 0.56 L, with no
posture effect.

- At end-expiration, side-lying narrows the lower ribcage from side to side:
  282.8 mm, against 325.1 mm supine and 323.5 mm sitting. It narrows the
  abdomen too: 271.5, 310.6 and 312.0 mm. (Corrected 2026-11-09 from the
  page image. The first pass read the abdomen row as the lower ribcage.)
  The full Table 2 is in `anatomy.json`.
- Table 3 gives the mean tidal displacement of marker groups in mm. On the
  upper (left) side in right side-lying, the lower ribcage moves sideways by
  **1.70 ± 0.58**, against 0.41 supine and 0.96 sitting. That is the largest
  sideways motion in the study.
- The front of the abdomen moves 5.55 front-to-back supine, 5.23 side-lying
  and 4.79 sitting. That makes it the largest single motion in every
  posture.
- Sitting has the largest up-down and front-back motion of the ribcage: the
  front of the lower ribcage moves 2.58 up-down and 2.81 front-back.

These are the magnitudes a surface view, such as the cutaway or Breath Star,
should show.

**Kaneko K, Milic-Emili J, Dolovich MB, Dawson A, Bates DV (1966).** Regional
distribution of ventilation and perfusion as a function of body position.
*J Appl Physiol* 21:767–777. doi:10.1152/jappl.1966.21.3.767. — **citation
only** (the abstract was seen only through a search summary).

The 8 subjects were studied with xenon-133 supine, prone and side-lying. The
summary says ventilation is greater in dependent zones in every posture, and
the authors put it down to the gradient in pleural pressure. Read the paper
before relying on this. It is the classic statement, and it is often
repeated.

**Krayer S, Rehder K, Vettermann J, Didier EP, Ritman EL (1989).** Position
and motion of the human diaphragm during anesthesia-paralysis.
*Anesthesiology* 70:891–898. doi:10.1097/00000542-198906000-00002. —
**abstract read.**

The 6 volunteers were imaged by 3-D CT. During spontaneous breathing, the
dependent regions of the diaphragm moved more than the nondependent ones in
4 of 6 subjects. **The back of the diaphragm moved more than the front in 5
of 6, whatever the body position.** Supine, the volume the diaphragm
displaced was about the tidal volume.

**Froese AB, Bryan AC (1974).** Effects of anesthesia and paralysis on
diaphragmatic mechanics in man. *Anesthesiology* 41:242–255.
doi:10.1097/00000542-197409000-00006. — **citation only.** This is the
classic source for the dependent part of the diaphragm moving most in
spontaneous breathing.

### The diaphragm and the compartments

**Aliverti A, Ghidoli G, Dellacà RL, Pedotti A, Macklem PT (2003).** Chest
wall kinematic determinants of diaphragm length by optoelectronic
plethysmography and ultrasonography. *J Appl Physiol* 94:621–630.
doi:10.1152/japplphysiol.00329.2002. — **abstract read.**

The 4 men were measured in quiet breathing and exercise. The up-down motion
of the edge of the zone of apposition (where the diaphragm lies against the
ribcage) is explained 89–96% by the abdomen's volume change; the ribcage
compartments add less than 1%. That supports the plan's simplification that
the abdomen's displacement stands in for the diaphragm's descent.

### Methods (for the vocabulary, not for numbers)

**Konno K, Mead J (1967).** Measurement of the separate volume changes of rib
cage and abdomen during breathing. *J Appl Physiol* 22:407–422.
doi:10.1152/jappl.1967.22.3.407. — **citation only.** This is the source of
the two-compartment model. A search summary says the abdomen supplied about
half or more of tidal volume, standing and supine, in 6 subjects. That is not
verified, and it is higher than Mendes's seated figure, so read the paper
before using it.

**Cala SJ, Kenyon CM, Ferrigno G, et al. (1996).** Chest wall and lung
volume estimation by optical reflectance motion analysis. *J Appl Physiol*
81:2680–2689. doi:10.1152/jappl.1996.81.6.2680. — **abstract read.** This
is the OEP method: 86 markers. The volume it measures matches spirometry
(r ≈ 0.996 in tidal breathing). So a compartment's volume is close to the
air it moves.

**Wade OL (1954).** Movements of the thoracic cage and diaphragm in
respiration. *J Physiol* 124:193–212. doi:10.1113/jphysiol.1954.sp005099. —
**citation only.** This is the source for the pump-handle and bucket-handle
rib motion.

**Mead J (1979).** Functional significance of the area of apposition of
diaphragm to rib cage. *Am Rev Respir Dis* 119(2 Pt 2):31–32. — **citation
only.**

## What this means for the plan

1. **M0 has a real target.** The model must reproduce Mendes's seated→supine
   shift: the abdomen's share goes from roughly 40% to 65–70%, and the
   tidal volume falls modestly. The per-sex columns give two parameter sets.
2. **Surface motion and lung ventilation differ, and the model needs both.**
   Side-lying, the *wall* moves less on the dependent side (Nozoe, Takashima),
   while the dependent *lung* is said to ventilate more (Kaneko; still to be
   verified). The two fit if the dependent wall is pinned by the floor while
   the dependent part of the diaphragm (Krayer, Froese–Bryan) does the work.
   That is the contact constraint and the piston of the plan's mechanics
   section. **This is the side-lying test:** a model that only moves walls
   will fail it.
3. **Posterior breathing has a basis.** In Krayer, the back of the diaphragm
   moves more than the front regardless of position. That fits a front/back
   split of the diaphragm (v1.5) better than one of the abdominal wall.
4. **Display scale.** Takashima's mm values (abdomen about 5 mm front-to-back,
   ribcage 1–3 mm) set the true proportions. Any view that exaggerates them
   should do so by one documented factor.

## Not found yet (still unsourced)

- **Abdominal binding or holding in healthy people, measured by
  compartment.** Exercise studies (McGill; Frontiers in Physiology 2017 and
  2018) report lower operating lung volumes and better diaphragm efficiency,
  but no compartment shares. The expected shift to the ribcage is an
  inference for now.
- **A hand on one side of the ribs.** I found nothing; it may need its own
  measurement.
- **Normal ribcage–abdomen phase.** One paper gives 0–20° for healthy quiet
  breathing, but that comes from a search summary and is not verified. The
  2017 thoracoabdominal-asynchrony paper (PMC5540557) and the healthy-control
  thresholds in the ALS study are the leads.
- **Flexion with exhale and extension with inhale.** I found no direct
  measurement.
- **Vellody et al.** (magnetometry: supine, side-lying, sitting), cited by
  Takashima. The citation is not yet resolved.

## Next reads, in order

1. Nozoe 2014, full text: the per-side compartment volumes in side-lying.
2. Romei 2010, full text: the five-angle gradient. It is closed, so it
   needs a library or the authors. Sonpeayung 2019 already answers the
   back-support question.
3. Konno and Mead 1967, and Kaneko 1966 (journals.physiology.org blocks
   automated fetches; get them through a library or by hand).
4. Thoracoabdominal phase in healthy adults (PMC5540557).

---

# Literature pass 2: anatomy (2026-11-09)

For the A-series, which models what moves. Numbers are in `anatomy.json`.

**Wilson TA, Rehder K, Krayer S, Hoffman EA, Whitney CG, Rodarte JR
(1987).** Geometry and respiratory displacement of human ribs. *J Appl
Physiol* 62:1872–1877. doi:10.1152/jappl.1987.62.5.1872. — **abstract
read.**

Two supine, relaxed men were imaged by CT, holding their breath at resting
lung volume (FRC) and at full lungs (TLC).

- From FRC to TLC, each rib's plane rotates about an axis passing near the
  spine.
- **Pump-handle and bucket-handle components:** rib 3 rotates 11° and 13°;
  both fall with rib number, to 7° and 10° at rib 7.
- **The rotation axes lie about 35° from the midplane** for ribs 3–7.
- Each rib's arc radius grows slightly, a small rotation out of the rib's
  plane.

This is the core kinematics for A1's rib bands. The rib radii, plane
orientations and the per-rib table are in the closed full text. Caveat: the
rotations span FRC to TLC (the inspiratory capacity, about 3 L). Tidal
breathing uses a fraction of that, and the linear scaling is an
assumption.

**Gauthier AP, Verbanck S, Estenne M, Segebarth C, Macklem PT, Paiva M
(1994).** Three-dimensional reconstruction of the in vivo human diaphragm
shape at different lung volumes. *J Appl Physiol* 76:495–506.
doi:10.1152/jappl.1994.76.2.495. — **abstract read.**

Four men, supine and relaxed, were imaged by MRI at four lung volumes.

- The diaphragm's shape changes front-to-back, but hardly at all
  side-to-side.
- The zone of apposition depends mostly on the diaphragm shortening, and
  less on the lower ribcage widening.
- It behaves as a **"widening piston"** better than a piston in a
  cylinder.
- The muscular surface falls linearly, by about 41%, from residual volume
  to TLC.
- Much of the muscle lies against the lungs: tension in the dome acts
  radially, and in the zone of apposition along the body axis.

**Miyao H, Abe T, Otsuka H, Tomita T (1990).** [Change in the zone of
apposition of the human diaphragm associated with ventilatory movement.]
*Nihon Kyobu Shikkan Gakkai Zasshi* 28:1462–1470 (in Japanese). — **abstract
read.**

24 healthy subjects were studied by ultrasound of the upper edge of the zone
of apposition.

- Its movement is **linear with volume**.
- Over a supine vital-capacity manoeuvre it travels 103.0 ± 15.6 (left
  anterior), 106.6 ± 17.2 (right anterior), 108.5 ± 18.2 (left posterior)
  and **114.8 ± 16.3 mm** (right posterior axillary line).
- The right posterior travel is largest.
- Inspiratory travel is larger supine than sitting.

**Boussuges A, Gole Y, Blanc P (2009).** Diaphragmatic motion studied by
M-mode ultrasonography: methods, reproducibility, and normal values.
*Chest* 135:391–400. doi:10.1378/chest.08-1541. — **abstract read.**

210 healthy adults (150 men and 60 women) were scanned at the posterior
diaphragm, on both sides. **The lower limits of excursion in quiet
breathing are about 1.0 cm for men and 0.9 cm for women.** The means, which
are in the full text, are not yet read. Men's excursions are larger than
women's.

**Takashima 2017, Table 2** (table read, from the page image): end-expiratory
diameters in mm, which set A1's cross-section sizes.

**Still needed:** a source for the abdominal wall's displacement
distribution; the rib lengths and arc radii (Wilson's full text, or
anthropometry); and **the insertional versus appositional action** of the
diaphragm in humans (De Troyer). A review (private) cites Wilson and De Troyer
2013, a canine study; it shows the two components separate, but its
coefficients are not human.


---

# Literature pass 3: A2's emergent patterns (2026-11-09)

The A2 what-ifs switch muscles off in a healthy seated body. These sources
describe the corresponding patterns in patients. They are used for
**directions only**: patients differ from the model in more than their
muscles (chest-wall stiffness, posture, tone).

**Estenne M, De Troyer A (1985).** Relationship between respiratory muscle
electromyogram and rib cage motion in tetraplegia. *Am Rev Respir Dis*
132:53–59. doi:10.1164/arrd.1985.132.1.53. — **abstract read.**

- 20 tetraplegic patients, breathing at rest, seated (magnetometers and
  EMG).
- The lower ribcage expanded more than the upper, and more in its
  transverse than its AP diameter.
- The upper ribcage moved paradoxically inward in 11 of 20 patients, and in
  7 of 8 of those with spastic or silent scalenes.
- Supine, with the scalene, intercostal and abdominal muscles denervated,
  the transverse diameter still increased, but the lower ribcage's AP
  diameter decreased in 7 of 8.

**Mortola JP, Sant'Ambrogio G (1978).** Motion of the rib cage and the
abdomen in tetraplegic patients. *Clin Sci Mol Med* 54:25–32.
doi:10.1042/cs0540025. — **abstract read.** Supine, the ribcage moves
paradoxically inward. Seated, the lower ribcage's paradox disappears, and
the upper's is reduced but present. Their conclusion: what the diaphragm
does to the ribcage depends on posture, dome configuration and ribcage
geometry.

**Urmey W, Loring S, Mead J, et al. (1986).** Upper and lower rib cage
deformation during breathing in quadriplegics. *J Appl Physiol*
60:618–622. doi:10.1152/jappl.1986.60.2.618. — **abstract read.** 6
quadriplegics. The ribcage AP diameter decreases with inspiration, the
upper ribcage distorts most, and abdominal compression reduces the
distortion. They attribute that to a larger area of apposition.

**De Troyer A, Estenne M, Vincken W (1986).** Rib cage motion and muscle use
in high tetraplegics. *Am Rev Respir Dis* 133:1115–1119.
doi:10.1164/arrd.1986.133.6.1115. — **abstract read.** 2 patients breathing
with neck muscles only, with no diaphragm. The sternum moves cranially, the
upper ribcage AP expands, and the lateral walls of the lower ribcage move
paradoxically inward.

**Higenbottam T, Allen D, Loh L, Clark TJ (1977).** Abdominal wall movement
in normals and patients with hemidiaphragmatic and bilateral diaphragmatic
palsy. *Thorax* 32:589–595. PMC470795. — **summary read** (the full text
is page images).

- In bilateral palsy, the front abdominal wall moves *inward* on
  inspiration; most clearly lying down, and more with larger breaths.
- It moves outward in normal subjects and in hemidiaphragm palsy.

**Loring SH, Mead J (1982).** Action of the diaphragm on the rib cage
inferred from a force-balance analysis. *J Appl Physiol* 53:756–760.
doi:10.1152/jappl.1982.53.3.756. — **abstract read.** The diaphragm
expands the ribcage by pulling cephalad at its insertions on the lower ribs
(insertional) and by raising abdominal pressure against its zone of
apposition (appositional). The appositional part is largest at low lung
volumes. **A2 has only the appositional part.**

**McCool FD, Tzelepis GE (2012).** Dysfunction of the diaphragm. *N Engl J
Med* 366:932–942. doi:10.1056/NEJMra1007236. — **citation only** (secondary
summaries seen): paradoxical abdominal motion is a sign of bilateral
paralysis, and the vital capacity falls 30–50% supine.

**Not found:** normal transdiaphragmatic and oesophageal pressure swings in
quiet seated breathing in healthy adults. A2's 4.5 cmH2O
transdiaphragmatic (4.9 active) and −2.8 cmH2O pleural follow from textbook
compliances. They are unchecked.

**Estenne M, Heilporn A, Delhez L, Yernault JC, De Troyer A (1983).** Chest
wall stiffness in patients with chronic respiratory muscle weakness. *Am Rev
Respir Dis* 128:1002–1007. doi:10.1164/arrd.1983.128.6.1002. — **abstract
read.**

- Measured with the weighted-spirometer technique, with every muscle
  relaxed, as EMG confirmed.
- Relaxed chest-wall compliance was **0.162 ± 0.012 L/cmH2O in 16
  patients**, against **0.248 ± 0.013 in 20 healthy controls**.
- The ratio, ×1.53, is used for chronic patients in A2.
- The healthy value also bounds the textbook passive compliance:
  ribcage 0.11 + abdomen 0.09 = 0.20.

**Druz WS, Sharp JT (1981).** Activity of respiratory muscles in upright and
recumbent humans. *J Appl Physiol* 51:1552–1561.
doi:10.1152/jappl.1981.51.6.1552. — **abstract read.** 9 healthy subjects.
Upright postures show more phasic *and tonic* scalene,
sternocleidomastoid and parasternal activity, more phasic diaphragm
activity, and tonic oblique activity when standing. More rib motion upright
comes from rib-muscle activation plus a stiffened abdomen.

**Tanaka K, Takahashi Y, Nakamura A, Moro H (2026).** Intercostal
transdiaphragmatic port insertion… *Am Surg* (online).
doi:10.1177/00031348261499855. — **abstract read.** **CORRECTED
2026-11-09** (a review, private). What the abstract actually says, paraphrased: to avoid
the lung, ports may enter the 7th intercostal space only in front of the
anterior axillary line, the 8th only in front of the midaxillary line, and
the 9th anywhere "within the zone of apposition".

- So the lung is *absent* in front at the lower levels, and reaches lower
  at the sides and back. That fits the classical lung edge: about the 6th
  rib midclavicular, the 8th midaxillary, the 10th posteriorly.
- My first reading was reversed. It does **not** support "the front of the
  lower ribcage faces the pleura and lung"; it suggests the opposite.
- It is a surgical-access source in any case. It doesn't measure a pressure
  map during breathing.


---

# Literature pass 4: gravity and tone (2026-11-09)

**Ibañez J, Raurich JM (1982).** Normal values of functional residual
capacity in the sitting and supine positions. *Intensive Care Med*.
doi:10.1007/bf01725734. — **abstract read.** 100 healthy adults (helium
dilution). FRC *always* decreased from sitting to supine. Magnitudes are in
the full text, not read.

**Smith J, Bellemare F (1987).** Effect of lung volume on in vivo
contraction characteristics of human diaphragm. *J Appl Physiol*
62:1893–. doi:10.1152/jappl.1987.62.5.1893. — **abstract read.**

- 6 men. Twitch Pdi was **49.1 ± 9.1 cmH2O at RV against 19.6 ± 6.0 at
  TLC**.
- The fall was almost all in pleural pressure, with little change in
  gastric pressure. At TLC the diaphragm ceases to act as an inspiratory
  muscle.
- Used for length–tension: about 15.6% per litre, scaled by a 4.53 L VC.

**Boyle KGPJM et al. (2026).** The effect of body position on responses to
rapid bilateral anterolateral magnetic phrenic nerve stimulation in healthy
humans (PosiStim). *Respiration*. doi:10.1159/000551452, PMC13268612. —
**abstract read.**

- 17 healthy subjects. Stimulated Pdi and tidal volume were highest
  semirecumbent: +2.5 cmH2O against supine and +0.5 against sitting.
- So supine Pdi is not simply higher at a longer diaphragm length; the
  abdominal load matters.

**Muller N, Volgyesi G, Becker L, Bryan MH, Bryan AC (1979).**
Diaphragmatic muscle tone. *J Appl Physiol* 47:279–.
doi:10.1152/jappl.1979.47.2.279. — **abstract read.** The human diaphragm
has tonic activity at end expiration. It falls in REM sleep and under
anaesthesia and rises with abdominal loading. No mechanical size is given.

**Vellody VP, Nassery M, Balasaraswathi K, Goldberg NB, Sharp JT (1978).**
Compliances of human rib cage and diaphragm-abdomen pathways in relaxed
versus paralyzed states. *Am Rev Respir Dis* 118:479–491.
doi:10.1164/arrd.1978.118.3.479. — **abstract read.**

- 11 normal subjects (magnetometers), awake "relaxed" against
  anaesthetised-paralysed.
- **The ribcage component of compliance was greater paralysed in 9/11:
  awake ribs are stiffened by muscle activity**, which is tone.
- The diaphragm–abdomen component was greater awake in 8/11.
- Magnitudes are in the full text, not read.

**Deschamps C, Rodarte JR, Wilson TA (1988).** Coupling between rib cage and
abdominal compartments of the relaxed chest wall. *J Appl Physiol*
65:2265–. doi:10.1152/jappl.1988.65.5.2265. — **abstract read.** Seated,
relaxed: the ribcage–abdomen cross-compliance is small and positive, 0.01–
0.02 L/cmH2O. Not in A2, which has no passive cross-coupling except the
sternal arch.

**Westbrook et al. (1973)**, *J Appl Physiol* 34:81–86 — citation only.
**D'Angelo et al. (1991)**, *J Appl Physiol* 70:2602 (anaesthetised-paralysed
chest-wall mechanics, supine) — abstract seen, no compliance numbers in it.

# Literature pass 5: the back (2026-11-09)

- **De Groote A, Wantier M, Chéron G, Estenne M, Paiva M (1997).**
  Chest wall motion during tidal breathing. *J Appl Physiol* 83:1531–1537.
  Optoelectronic, 36 markers front, side and back; 5 healthy seated men.
  The ribcage moves cranially, ventrally and slightly laterally; the
  dorsal surface is displaced ventrally, which spinal flexion does not
  account for. **Used:** the sign check for the back markers; the case
  against spine extension in seated quiet breathing. No per-marker
  magnitudes taken.
- **Kaneko H, Horie J (2012)** and **Handley (2026):** searched for back
  data; none usable (front and side markers only, or no quiet-breath
  posterior numbers).

Still missing: posterior marker magnitudes for quiet breathing (OEP
posterior groups; Gómez-Recio 2024's supplement), and any back data in
standing.

## Pass 5, continued: the posterior diaphragm

- **Krayer S, Rehder K, Vettermann J, Didier EP, Ritman EL (1989).**
  Position and motion of the human diaphragm during anesthesia-paralysis.
  *Anesthesiology* 70:891–898. High-speed 3-D CT, 6 subjects. Dorsal
  motion exceeded ventral in 5 of 6, regardless of posture.
- **Gierada DS et al. (1995).** Diaphragmatic motion: fast
  gradient-recalled-echo MR imaging in healthy subjects. *Radiology*
  194:879–884. 10 volunteers, near-vital-capacity breaths; excursion rises
  front → middle → back (dome 4.4 cm right, 4.2 left).
- **Takazakura R et al. (2004).** Diaphragmatic motion in the sitting and
  supine positions: healthy subject study using a vertically open MRI
  system. *J Magn Reson Imaging* 19:605–609. 10 men; supine > sitting at
  most points; the back-minus-front difference larger supine. Numbers not
  obtained (full text unavailable).
- **Kolář P et al. (2009).** Analysis of diaphragm movement during tidal
  breathing and during its activation while breath holding using MRI
  synchronized with spirometry. *Physiol Res* 58:383–392. 16 adults
  (10 F), supine, tidal: apex 27.3 ± 10.2 mm, posterior costophrenic angle
  39 ± 17.6 mm. **Used:** the supine tilt (ratio 1.43).

## Pass 5, continued: rib geometry and rib motion direction

- **Jordanoglou J (1969).** Rib movement in health, kyphoscoliosis, and
  ankylosing spondylitis. *Thorax* 24:407–414 (open access, PMC472003;
  read from the page scans). 10 healthy adults (8 M, 20–33 y), supine,
  tidal breathing; a mechanical angular-linear displacement indicator on
  points of ribs 2–9 (parasternal, mid-clavicular, anterior axillary,
  mid-axillary). The vectors along a rib are parallel; the motion is up,
  out and forward, read as rotation about the rib-neck axis. Table I
  (forward/out/up): rib 4 0.77/0.20/0.60; rib 5 0.83/0.26/0.47; rib 6
  0.85/0.26/0.45; rib 7 0.76/0.35/0.52; rib 8 0.83/0.29/0.46; rib 9
  0.79/0.38/0.47; S 1.0–1.55 cm. **Used:** an independent direction
  check (`breathstar jordanoglou`), not fitted.
- **Wilson TA et al. (1987).** Geometry and respiratory displacement of
  human ribs. *J Appl Physiol* 62:1872–1877. Full text not obtained (403).
- **Weaver AA, Schoell SL, Stitzel JD (2014).** Morphometric analysis of
  variation in the ribs with age and sex. *J Anat* 225:246–261. Rib
  orientation as Euler angles relative to an atlas rib; no absolute
  lateral-drop measure.
- **Dansereau J, Stokes IAF (1988).** Measurements of the
  three-dimensional shape of the rib cage. *J Biomech* 21:893–901. Not
  obtained.

## Pass 6: side-lying, how it is measured (2026-11-09)

- **Room frame.** Takashima 2017 (and OEP generally) report marker
  displacement in the laboratory frame. Lying on the side on a floor, the
  dependent flank can't move into the floor. If the dependent side widens,
  the whole trunk is lifted away from it, so every marker on the upper side
  moves outward by that lift *plus* its own widening. Lifting the trunk's
  weight is a constant load, not a spring, so it doesn't resist the
  widening. The pelvis also rests on the floor and doesn't lift, so the
  trunk pivots: the lift fades from the ribcage to the iliac crests. This
  reasoning is the model's (`observeSided(restingOn:)`), not a source's.
  It explains Takashima's largest sideways motion (upper side lower
  ribcage 1.70 ± 0.58 mm, against 0.41 supine) without extra muscle on
  that side.
- **Nozoe 2014** and **Kaneko 1966** (entries above) remain the per-side
  sources. Nozoe's per-side volumes need the full text. Kaneko's
  dependent-lung ventilation is still citation-only and is not a test
  target until read.

## Pass 6: timing

- **Single motor units of human inspiratory muscles in quiet breathing.**
  *Proceedings of the Australian Physiological Society* 33:35P (abstract;
  authors not recorded here; the Gandevia/Butler group's work). 5 seated
  subjects, 260 units. Recruitment after inspiratory flow onset (ms; % of
  Ti): diaphragm 377 ± 62 (21.7 ± 3.3); scalenes 421 ± 73 (21.0 ± 3.4);
  parasternal intercostal 666 ± 50 (31.6 ± 2.4); dorsal external
  intercostal 3rd space 637 ± 61 (30.4 ± 2.2), 5th space 1119 ± 129
  (41.7 ± 3.8). **Used:** `MuscleTiming` (onset order and size).
- **Priori R, Aliverti A, Albuquerque AL, et al. (2013).** The effect of
  posture on asynchronous chest wall movement in COPD. *J Appl Physiol*
  114:1066–1075. OEP, seated and supine. Controls showed no compartmental
  asynchrony (values not obtained). **Used:** the synchrony check.
- Motion-capture compartment phase angles in healthy subjects, −5.05° to
  +3.86° (*Sci Rep* 2021; s41598-021-01033-8; read only as a search
  summary).
- **Abe T, Kusuhara N, Yoshimura N, Tomita T, Easton PA (1996).**
  Differential respiratory activity of four abdominal muscles in humans.
  *J Appl Physiol* 80:1379–1389 (abstract). In resting breathing:
  transversus abdominis most active, obliques intermediate, rectus least.
  No size taken. **Used:** the expiratory abdominal mechanism (off by
  default).
- **Post-inspiratory diaphragm activity:** in all healthy volunteers (Am
  J Respir Crit Care Med 2024, 209:881, letter). Rib-cage inspiratory
  muscles active through expiration in quiet breathing (J Appl Physiol
  1997, 83:1256). No time constant found.

# Literature pass 7: standing versus sitting (2026-11-09)

Why: the model's only upright posture is seated. What would standing need,
and what is known? (Prompted by the side-lying session's summary.)

## Compartment shares: weak and partly conflicting

- **Verschakelen JA, Demedts MG (1995).** Normal thoracoabdominal motions:
  influence of sex, age, posture, and breath size. *Am J Respir Crit Care
  Med* 151:399–405 (abstract). Respiratory inductive plethysmography (RIP)
  in 120 healthy people aged 10–60+. Posture effect p < 0.001 in quiet
  breathing: ribcage predominance greatest standing, least supine; sex and
  age matter only for vital-capacity breaths. Gómez-Recio 2024 cites it as
  finding no significant standing-vs-sitting difference, so the
  significance is presumably overall, driven by supine. Pairwise numbers
  are in the full text.
- **Konno K, Mead J (1967).** Measurement of the separate volume changes
  of rib cage and abdomen during breathing. *J Appl Physiol* 22:407–422
  (abstract). 6 subjects, standing and supine, AP diameters: the abdomen
  takes about half or more of the tidal volume in both postures. This
  pulls the other way from Verschakelen (old method, few subjects).
- **Gómez-Recio M, Bastir M, LoMauro A, Aliverti A, Beyer B (2024).**
  Three-dimensional geometric morphometric shape analysis of chest wall
  kinematics in different breathing conditions. *R Soc Open Sci*
  11:240548 (full text, open). 27 young men (14 sitting on a cycle
  ergometer, 13 standing), 89 markers, two different capture systems.
  Quiet breathing:
  - sitting: mainly anteroposterior change, slightly greater at the
    abdomen;
  - standing: greater upper chest variation (cranial and ventral), and
    greater AP change of the whole torso, especially thoracic;
  - a minor thoracic spine extension on inspiration;
  - sitting is more flexed, with the shoulder girdle constrained.
  Numbers are only in supplementary tables S1–S7 (not obtained). The
  posture groups were analysed separately, with no direct comparison.
- Mendes 2020 (which the model already uses) has no standing condition.
- **Summary:** standing is probably a little more ribcage-dominant than
  sitting, but not reliably different in quiet breathing.

## Mechanism: tonic, not phasic, abdominal activity standing

- **Druz WS, Sharp JT (1981).** Activity of respiratory muscles in upright
  and recumbent humans. *J Appl Physiol* 51:1552–1561 (abstract).
  - Upright: more phasic and tonic scalene, sternocleidomastoid and
    parasternal activity.
  - The diaphragm: more phasic, not tonic.
  - The external oblique: more **tonic (not phasic)** activity standing
    only.
  - Inspiratory gastric pressure change relative to oesophageal is larger
    upright: a stiffer abdomen.
  - Their conclusion: more ribcage motion upright from more rib-muscle and
    diaphragm drive, with a stiffened abdomen moving the ribcage more
    effectively.
- **Phasic expiratory abdominals in quiet standing:** not established.
  - De Troyer 1990 (seated): transversus expiratory activity only with
    raised drive (hypercapnia, loads).
  - A Korean EMG study: internal oblique and transversus more active
    standing than sitting, but during forced manoeuvres.
  - Abe 1996: transversus the most active abdominal muscle at rest
    (posture-dependent).
- **For the model:** standing = seated + a tonically stiffer abdominal
  wall, + perhaps more rib drive. Not the phasic expiratory abdominal
  pressure, which healthy synchrony already bounds to about 0.2 cmH2O
  seated.

## Lung volume and geometry

- **Attali et al. (2024).** *Arch Bronconeumol* (abstract or table only).
  In healthy adults, standing and sitting lung volumes are comparable. The
  FRC change from supine is −0.79 L sitting and −0.86 L standing (my
  inference: standing ~0.07 L lower; check the full table). An older J
  Clin Invest table (1950s, garbled extract) suggests standing higher.
  **Reading:** the operating point is about the same as seated.
- **Standing trunk dimensions:** none found (Takashima has seated, supine
  and side-lying only).
- **Standing marker motion:** none found with numbers. Gómez-Recio's
  supplement is the best candidate.

## Pass 7, continued: Gómez-Recio 2024's supplement, read

Figshare collection 10.6084/m9.figshare.c.7321776 (via PMC). It holds
supplementary tables ST1–ST7 (rsos240548_si_006.docx), captions, three
figures and a video. **No compartment volumes, marker displacements or
spine angles.** The tables are geometric-morphometric statistics:
- **ST2, centroid size (CS) in quiet breathing, median end expiration →
  end inspiration:** sitting 1833.5 → 1846.7; standing 1954.1 → 1965.6.
  Standing is larger overall: different subjects and systems.
- **ST3, "functional size" in quiet breathing:** sitting 13.0, standing
  16.5. Relative to CS that's about 0.71% sitting and 0.85% standing:
  slightly more size change standing. Tidal volumes aren't reported, so
  this can't be read as more breath.
- **ST1, ST5–ST7:** shape principal-component scores. They separate the
  postures but aren't anatomical quantities.

**For the model:** nothing to size spine extension or standing shares
with. The video (figshare 26212359) shows the mean shape warps and could
be read for direction only. Standing still needs Verschakelen 1995's or
Konno & Mead 1967's full text, or another standing marker or OEP dataset.

# Literature pass 8: side-lying, per lung (2026-11-09)

Gathered by the read-only research session. The full notes, with the
tables, are in the shared notes folder (`sources-asymmetry-standing.md`).
The entries the model uses:

- **Amano M et al. (2024).** *Cureus* 16:e75900, PMC11737910. **Table
  read.** 13 healthy adults, breath-hold CT at natural inspiration and
  expiration, supine, prone and both sides.
  - Derived tidal split: dependent lung **62% right side down, 56% left
    side down**.
  - End-expiration against supine: upper lung **+700 mL**, dependent lung
    −85 to −145 mL.
  - The breaths are probably deeper than tidal (supine Δ 926 mL).
- **Grant CA et al. (2011).** *Crit Care* 15:R37, PMC3222074. **Figure
  read.** 10 healthy adults, EIT at nipple level: dependent share 59% right
  side down, 51% left side down.
- **Amis TC, Jones HA, Hughes JMB (1984).** *Respir Physiol* 56:145. **Table
  read.** Krypton, tidal. Upper/lower V̇/VA is 0.39–0.49; volume differences
  alone can't explain the split.
- **Chevrolet JC et al. (1979).** *Respir Physiol* 38:313. **Abstract
  read.** 4 subjects. Upper/lower ventilation per volume: 0.55 natural,
  0.42 abdominal, **0.99 with intercostal and accessory muscles**: the
  dependent lung's advantage comes from the diaphragm.
- **Roussos CS, Martin RR, Engel LA (1977).** *J Appl Physiol* 43:32.
  **Abstract read.** Diaphragm contraction shrinks the dependent and
  non-dependent volume difference (19.7 → 3.9 %TLC).
- **Lumb AB, Nunn JF (1991).** *Anesth Analg* 73:422. **Abstract read.**
  FRC lateral is +350 mL above supine and −450 below sitting (sitting −
  supine 806). Ribcage share 70% sitting, 32–36% in any horizontal
  posture.
- **Yamaguti WPS et al. (2007).** *J Bras Pneumol* 33. **Text read.** 7
  women, ultrasound, right hemidiaphragm, probably deep breaths: 51.3 mm
  dependent vs 45.9 mm upper (×1.12).
- **Still not read:** Kaneko 1966 and Nozoe 2014 (full text), Froese &
  Bryan 1974. No quantitative dome-height source for awake quiet breathing
  side-lying.

## Pass 8, continued: the spine lying on the side

- **Leilnahari K, Fatouraee N, Khodalotfi M, Sadeghein MA, Kashani YA
  (2011).** Spine alignment in men during lateral sleep position:
  experimental study and modeling. *BioMed Eng OnLine* 10:103,
  PMC3265433. **Text read (via summary of the full text).** 25 men,
  optical tracking of 12 spinous processes (C7–L5), lying on the side.
  - Frontal-plane bend at T11 (the "π-P8 angle"): **firm 8.9°**, soft
    12.66°, custom-made 4.10°.
  - On a firm surface "only shoulder and pelvis receive good support"; the
    spine bends down in the lumbar area.
  - **Used:** the side-lying arc's sag, ≈1.9 cm (two straight segments
    C7–T11–L5 over ~49 cm).
  - No per-region mm, and no floor condition.
- **Takashima S (2017), thesis, Kobe University** (the full text of
  Takashima et al. 2017; da.lib.kobe-u.ac.jp/da/kernel/D1006900). **Text
  read.**
  - Side-lying posture: on the floor, with the upper arm propped on a
    cushion on the greater trochanter.
  - The right (dependent) side is called the **weight-bearing side**. Its
    abdominal rib cage and abdomen are narrowed side to side.
  - The asymmetry is attributed to "local pressure on the chest wall due to
    the floor surface", plus a mediastinal shift and abdominal organs
    shifting with gravity.
  - **Used:** the dependent lower ribcage touches the floor. That supports
    the room-frame lift and the bed spring.

## Pass 8, continued: the mediastinum

- **Hubmayr RD, Margulies SS (1992).** Effects of unilateral hyperinflation
  on the interpulmonary distribution of pleural pressure. *J Appl Physiol*
  73:1650–1654. **Abstract read.** Recumbent dogs and baboons; pleural
  pressure from each lung's volume and elastic properties, and from rib
  capsules, during single-lung inflation.
  - The other side receives a fraction of the inflated side's pleural
    pressure change: **0.7 ± 0.1 in dogs, 0.5 ± 0.1 in baboons**.
  - Preventing sternal displacement or venting the diaphragm to the air
    didn't change it. The midline structures and the lungs resist
    displacement.
  - **Used:** sets the model's mediastinal compliance (primate 0.5).

## Pass 8, continued: the shoulder on the upper ribcage (searched, not found)

**Wanted:** how much the shoulder loads or holds the dependent upper ribcage
lying on the side, to size `side-lying` section 10's shoulder constraint.
- **Interface-pressure studies** in lateral positions map the shoulder or
  armpit and the greater trochanter, on mattresses or surgical cushions,
  not on a floor. Examples: a 2016 physiology abstract (peak moves from the
  sacrum to the trochanter at 30°); Zhang et al. 2021, *BMC Musculoskelet
  Disord* (surgical chest cushions, axilla and iliac spine). They give no
  load fraction for the upper ribcage.
- **A side-sleeper pillow patent** (US 8065766) reports pressure maps where
  relieving the shoulder shifts load onto the upper rib cage. That's
  consistent with the shoulder taking load otherwise, but it's a patent,
  with no numbers used.
- **Anaesthesia textbooks** state qualitatively that the dependent chest
  wall is "constrained by the table" lying on the side.
- **Nothing quantitative** on dependent upper-rib excursion or shoulder
  loading of the ribs during quiet breathing. The shoulder constraint stays
  an untested lead (not adopted).

## Pass 9: pressing on the chest (holds anchor), 2026-11-10

- **Kouyama Y, Nozoe M, Matsushita K, Takashima S, Mase K, Wada T, Uchiyama Y, Domen K (2016).**
  背臥位における呼吸介助が局所換気運動に及ぼす影響 (Effects of chest wall compression on regional
  chest wall motion in healthy male subjects). *Physical Therapy Japan* 43(5):368–374 (full text
  read, J-STAGE).
  - **Design:** 7 healthy men (33 ± 7 y), supine, quiet breathing; OEP with 62 markers
    (compartments Vrcp, Vrca, Vab); oesophageal and gastric balloons.
  - **The manoeuvre:** 呼吸介助, a physiotherapist's expiratory assist, with the hands pressing the
    chest from the start of expiration until just before inspiration. "Upper" = both hands below
    the clavicles, front; "lower" = slightly below the nipples, from the front to the sides of the
    lower ribcage. As strong as is comfortable. Two minutes each, in random order.
  - **Table 2 (ΔV per breath, L, mean ± SD):**

    | | quiet | upper press | lower press |
    | --- | --- | --- | --- |
    | Vcw | 0.50 ± 0.06 | 1.58 ± 0.28 | 1.40 ± 0.34 |
    | Vrcp | 0.07 ± 0.03 | 0.81 ± 0.14 | −0.14 ± 0.09 |
    | Vrca | 0.09 ± 0.03 | 0.43 ± 0.11 | 0.90 ± 0.20 |
    | Vab | 0.33 ± 0.06 | 0.34 ± 0.17 | 0.64 ± 0.26 |

    Under the lower press ΔVrcp is negative in all 7: the upper ribcage EXPANDS during expiration.
  - **Table 4 (cmH2O):**
    - end-expiratory Pga: 2.99 ± 4.18, 8.71 ± 5.94, 15.55 ± 8.09;
    - end-expiratory Pes: 2.38, 8.91, 8.30.
  - Table 3 has end-inspiratory and end-expiratory compartment volumes.
  - **The authors' mechanism (Fig. 4b):** the lower press raises Pga, which pushes the diaphragm up
    and raises Pes, and the upper ribcage expands.
  - **Used:** `breathstar kouyama` (anchor test; not fitted except the press's size, set to the
    Pga rise).

# Literature pass 10: inspiratory drive by posture (2026-11-10)

Checking the stage-3 prediction (quiet tidal held; drive needed ×0.91 at 45°, ×0.84 supine,
×0.88 side, ×1.23 face down, one scale on every muscle).

- **Wakode S, Salkar P, Thakare A, Hulke S, Malhotra V, Jiwne R.** Neural respiratory drive by
  parasternal sEMG (2nd intercostal space) in three positions, healthy adults 18–50. *J
  Musculoskelet Neuronal Interact* 25(1) (ismni.org/jmni/article/25/74). **Abstract read.** Men
  standing 5.11, sitting 4.91, supine 4.40; women 7.44, 6.75, 6.44 (EMGpara%max or NRDI, the
  excerpt doesn't say which); all positions differ (P < 0.001). Supine/sitting: **0.90 men,
  0.95 women.** n not given in the excerpt.
- **(PMID 30650399, 2019)** "The influence of posture on parasternal intercostal muscle activity in
  healthy young adults." **Seen through a search summary only** (PubMed page blocked). 51 adults:
  no significant difference in raw EMGpara, EMGpara%max, NRDI or tidal volume seated → reclined
  → supine; raw and normalised values agree less well supine.
- **Druz WS, Sharp JT (1981)**, "Activity of respiratory muscles in upright and recumbent humans"
  (*J Appl Physiol*). **Citation and search summary only.** 9 normal subjects: more phasic and
  tonic scalene, sternocleidomastoid and parasternal activity upright than supine.
- **Upside-down posture (Flinders; citation and summary only):** crural diaphragm EMG unchanged
  against standing, scalene EMG about halved, ribcage share down, transdiaphragmatic pressure
  swing doubled.
- **Prone:** a search summary mentioned a small study (young women) finding less motor-unit
  activation prone than supine. **Source not identified**; not used.

**For the model.** The direction of the supine prediction has support for the rib muscles
(Wakode 0.90–0.95, Druz & Sharp), none for the diaphragm (unchanged when inverted), and one
null result (n = 51). The model scales every muscle by one factor; the evidence suggests posture
mostly changes the rib muscles' drive. Size: the model's 0.84 is below Wakode's 0.90–0.95.
Face down (×1.23): untested; one unidentified report points the other way.

# Literature pass 11: the spine's shape and breathing (2026-11-10)

For stage 4's direction question (does a crowded side stiffen, sending the breath away, or open?).
Search summaries and abstracts only; nothing here was read in full.

- **Acute side-bend:** no study found that measures regional chest-wall motion or ventilation in
  a voluntary lateral flexion. An OEP symmetry protocol in healthy adults is registered
  (NCT06774118), no results yet.
- **Sitting-posture study, 7 healthy adults** (core.ac.uk 15090717, title "Changes in sitting
  posture induce multiplanar changes in chest wall shape and motion with breathing"; authors not
  confirmed): volume matched by dead space (1.5 VT). Rotation **decreased** lateral-diameter
  motion at the axilla (p < 0.0007); thoracolumbar extension **increased** it at the 9th rib;
  slump increased AP motion at T1 and the axilla. Lateral flexion was tested? Not visible.
- **Claus, Hides & Moseley 2015** (Applied Ergonomics; abstract only, via a search
  summary): 10-minute sitting flexes the lumbar region 24° and the thoracolumbar region 12° from
  standing; a "corrected" sitting posture restores the thoracolumbar angle (−2° vs −1° standing),
  and a lordotic lumbar angle was rarely adopted. Used for where a seated arch happens (stage 4).
- **Hazaki K, Okada K** (World Physiotherapy congress abstract): rib cage expansion **4.2 ± 1.5 cm
  upright vs 3.6 ± 1.1 slumped**; attributed to limited rib elevation with the thoracic spine
  flexed; diaphragm excursion also smaller.
- **Shōbo & Kakizaki** (search summary): hunched sitting lowered tidal volume and thoracic
  asymmetry.
- **Scoliosis (chronic, structural):** most often the **concave (crowded) lung** ventilates worse
  (scintigraphy 1997; kyphoscoliosis), but a 1981 xenon study found the convex side restricted and
  1972/xenon studies found no consistent difference.

**For the model.** Directions: slump → less ribcage (law ✓, rib gain fitted to 0.857); rotation →
less axilla motion (✓); extension → more 9th-rib motion (✗: the law gives less); side-bend →
breath to the open side (law's default sign, consistent with scoliosis's majority and lesson
lore, not measured acutely).

# Literature pass 12: compartment volumes from Takashima's lab (2026-11-10)

For the open question of the seated share (is it, read from Takashima's markers through this geometry,
right as volume?).

- **Takashima 2017, full text (PMC5300799) checked:** no compartment volumes in any posture. Table 2
  is diameters, Table 3 mean marker coordinates; only whole tidal volume (0.52/0.51/0.56 L). The
  thesis is the same study. **Closed: there is nothing more to get from this paper.**
- **Kouyama 2016** (same lab, already read; pass 3): supine quiet breathing, OEP, 7 men: Vrcp
  0.07 ± 0.03, Vrca 0.09 ± 0.03, Vab 0.33 ± 0.06 of Vcw 0.50 L → **14/18/66%**. The lab's only
  published compartment volumes found.
- **Nozoe 2014** (same lab): supine and side-lying compartment volumes, full text paywalled
  (ScienceDirect S1569904813004138; PubMed 24418356). No sitting.
- **No sitting compartment volumes from this lab** were found (two extended searches). Sitting OEP
  volumes in healthy men: Mendes 2020 (37.4/21.9/40.8%) and Romei 2010 (abstract only).

**What the volumes say.** Upper/lower ribcage ratio:

| | seated | supine |
|---|---|---|
| Mendes men (OEP) | 1.7 | 1.7 |
| Kouyama (OEP, same lab as Takashima) | – | 0.8 |
| Takashima markers through the model's geometry | – | 3.0 |
| Model (stage 3 default) | 2.6 | 2.7 |

Supine abdomen: model 65.7, Kouyama 66, Mendes 69.8; whole ribcage: model 34.3, Kouyama 32,
Mendes 31.0, Lumb & Nunn 32–36. So both OEP sources agree with the model on the belly and the
whole ribcage and disagree on the split inside the ribcage: the model's lower ribcage is too small
(seated 12 vs 22; supine 9 vs 11.5–18) and its upper too large, in every posture. That is the
marker-to-volume conversion's fingerprint (the fixed-sign fit made the lower band ~×2 stiffer and
its muscle group silent), not a posture rule.

# Literature pass 13: leg position and the lumbar curve, lying on the back (2026-11-11)

For `Legs` (adaptation notes §4.6). Search summaries only; no full text read.

- **Supine MRI, legs flexed vs straightened** (spondylolisthesis, 100 patients; PubMed 25715663,
  Eur J Radiol 2015): lumbar lordosis ~51.7° flexed vs ~57.4° straightened (≈ 5.7°).
- **Standing radiograph vs supine MRI with straight legs** (ScienceDirect S0161475406003083): median
  difference 3°; legs straight reproduces standing lordosis.
- **Stenosis, extended legs + lumbar pillow** (PubMed 40799618) and a positioning study
  (ResearchGate 333480299): legs extended ≈ 97% of standing lordosis.
- **Supine vs standing radiographs (2025, PMC12084752 table):** pelvic tilt ~14° supine vs ~21°
  standing, lordosis ~50° in both.
- Not found: hook-lying with the feet standing (hips ~60°), or any breathing measure by leg position.

**Used:** `Legs.lumbarFlexion` (0.15 × hip flexion) gives 4.5–6° at a cushion's hip angle, inside
the 3–6° reported. The slope beyond that, the bulge peak and the contact are still assumed.

# Literature pass 14: 45° and face down by OEP (2026-11-11)

- **LoMauro A, De Luca D, Scarpazza P, Aliverti A (2024).** In vivo measurement of tidal volume
  during non-invasive respiratory support by continuous-flow helmet CPAP. *Ann Biomed Eng*
  52(9):2546–2555. doi:10.1007/s10439-024-03545-6, PMC11329575. **Full text read through a
  summary; Table 1's posture columns were assigned by inference** (the text confirms the
  direction). 28 healthy volunteers (14 women), OEP, semi-recumbent 45° then prone on a reclining
  bed; prone with 47 markers from C7 to the gluteal line (the back only). Quiet breathing without
  PEEP (ZEEP), median (Q1–Q3):
  - abdominal share of the breath: **45° 52.0% (41.7–59.4); prone 42.5% (38.7–46.5)**;
  - tidal volume 0.45 vs 0.39 L; minute ventilation 7.00 vs 6.09 L/min.
  - The authors: "the bed and the pelvis bones limit the expansion of the abdomen" prone (a
    presumption). No cushion details.

**For the model.** 45°: 52.2% (the linear postural factor; squared 55.9%), on the median. Prone:
73.6%, far above. This replaces Lumb & Nunn's "any horizontal posture" band as the prone target.

- **Weight through the girdles vs the trunk, lying (2026-11-11, for face down's anchoring):** one
  search; found only whole-body or peak interface pressures (Pickenbrock et al. 2017 BMC Nursing,
  supine and side-lying, n = 4; Stern et al. 2024 BioMed Eng OnLine, 19 postures incl. prone, n =
  10, maps not segment shares). No per-segment weight fractions. Not used.

# Literature pass 15: checking what was recalled (2026-11-11)

Three numbers in the code were marked "recalled, not read".

- **Elliott AR, Prisk GK, Guy HJB, West JB (1994).** Lung volumes during sustained microgravity on
  Spacelab SLS-1. *J Appl Physiol* 77(4):2005–2014. Abstract via a summary: 4 subjects, 9 days.
  FRC ~15% (~0.5 L) below standing in microgravity, 32% below standing supine; residual volume −18%
  in microgravity, unchanged supine. **Confirms** the settle's seated → weightless −0.42 L in size.
- **White AA, Panjabi MM** (1978 review in *Spine*; *Clinical Biomechanics of the Spine*, 1990).
  Thoracic flexion–extension per level, from a secondary reproduction: T1–T5 4°, T6 5°, T7–T9 6°,
  T10 9°, T11–T12 12° (sum ≈ 76°); lumbar L1–L2 12° (a 2015 PMC table, PMC4360610). **Confirms** the
  flexion share (≈ 0.49 vs 0.5 used). Lateral bending and axial rotation, from secondary
  reproductions of their table (a Frontiers in Pediatrics 2023 review; a chiropractic biomechanics
  handout): ~6° per side per thoracic and lumbar segment, 3° at L5–S1 (lumbar share ≈ 0.27–0.3 vs
  0.3 used); axial rotation 1–2° per lumbar segment, 8–9° upper thoracic (share ≈ 0.1 vs 0.12
  used). **Confirmed** in size; the original table was not read.
- **Homma I, Hagbarth KE (2000).** Thixotropy of rib cage respiratory muscles in normal subjects.
  *J Appl Physiol* 89(5):1753–1758. Abstract: 12 healthy, inductance plethysmography; after
  conditioning manoeuvres the end-expiratory ribcage position shifts (significant for two of three
  manoeuvre types).
- **Lima INDF, Sarmento A, Goes MC, … LoMauro A, Reid WD, Aliverti A, Fregonezi GADF (2019).**
  After-effects of thixotropic maneuvers on chest wall and compartmental operational volumes of
  healthy subjects using OEP. *Front Physiol* 10:1376. Read through a summary. 28 healthy; maximal
  5 s inspiratory or expiratory efforts against a closed shutter at TLC or RV, three in a row.
  After inspiratory efforts the end-inspiratory volume rose ~0.28 L (upper and lower ribcage, not
  the abdomen) for 3–5 breaths; after expiratory efforts from RV the end-expiratory volume fell
  ~0.2 L (upper ribcage and abdomen). Timing and flow unchanged.
- **Lakie M, Campbell KS (2019).** Muscle thixotropy: where are we now? (review). Limb muscle
  stiffens while still and loosens with movement.

**For the model.** Slow-state H2 (use loosens, stillness stiffens, τ 5 min) has support in
direction only: the respiratory evidence is an after-effect on operating volume lasting breaths,
after maximal efforts, not a stiffness change over minutes after gentle movement. H2 stays a
labelled hypothesis, off by default.

- **Tone factors (held ×5, light ×1.5, softened ×0.7), 2026-11-11:** searched for OEP or inductance
  plethysmography during abdominal bracing, drawing-in or hollowing, and with an abdominal binder,
  in healthy adults; none found (two extended searches). Abdominal-muscle elastography at rest and
  contracted was not found in reach either (pass 14). The factors stay assumed.

- **Higenbottam T, et al. (1977).** Abdominal wall movement in normals and patients with
  hemidiaphragmatic and bilateral diaphragmatic palsy. *Thorax* 32:589–595. doi:10.1136/thx.32.5.589.
  Abstract via a summary: magnetometers; with bilateral palsy the front abdominal wall moves inward
  on inspiration, more with larger breaths, **best seen recumbent**. **Kreitzer et al. (1978)** (case
  report, summary): inward abdominal motion supine, none at the bedside upright. Used:
  `PatientTests.bellyParadoxLyingDown` (front-wall AP motion).

# Literature pass 16: arm position (2026-11-11)

- **Kruapanich C, et al. (2021–22).** The effect of unsupported arm elevations on regional chest
  wall volumes and thoracoabdominal asynchrony in patients with COPD. *Physiother Theory Pract*
  38(11). doi:10.1080/09593985.2021.1882018. Abstract via summaries: 21 COPD and matched healthy
  subjects, OEP. In both groups the upper ribcage's tidal volume (VRCp) and asynchrony changed with
  unsupported arm elevation against rest. Healthy: VRCp lower in scaption (0.14 ± 0.07 L) and
  abduction (0.15 ± 0.06) than in flexion (0.18 ± 0.07). **The resting value was not reachable**
  (full text closed).
- **Arm positioning alters lung volumes in subjects with COPD and healthy subjects** (ResearchGate
  10736034; body plethysmography, via a summary): arm elevation lowers vital capacity ~180 mL and
  FRC ~120 mL.

**For the model.** Arms are not built: the direction is sourced (holding the arms up takes motion
from the upper ribcage, more sideways than forward, and lowers FRC slightly), the size is not.
Needed: Kruapanich's resting VRCp (full text), or a supported-arm (lying, arm overhead) dataset,
which is the common lesson case.

# Literature pass 17: weight per body region lying (2026-11-11)

- **Gao Y, Zhang J, Zou C, et al. (2024).** A method for calculating vector forces at the
  human–mattress interface during sleeping positions using image registration. *Sci Rep*
  14:15238, PMC11220148. 5 healthy adults, supine and lateral. Per-region resultant forces (head,
  chest, waist, hips, legs) were computed but **not reported**; only whole-body vertical force (≈ 99%
  of body weight).
- **Verhaert V, et al. (2011).** Ergonomics in bed design. *Ergonomics*, doi:10.1080/00140139.2010.538725.
  Reports the fraction of body pressure in eight transverse bed sectors (per a review table).
  **Full text not reachable**; the likeliest source of per-region load shares.
- **Segment masses (a human–bed modelling paper, 71 kg group):** pelvis ≈ 18.3 kg (26%), shoulders
  ≈ 12.1 kg (17%), chest ≈ 10.3 kg (15%), waist ≈ 9.4 kg (13%). Masses, not support loads.

**For the model.** The anchoring fraction (`contactAnchoring`) still has no source. Needed: Verhaert
2011's sector fractions, or another per-region load map, face down and side-lying.

# Literature pass 18: respiratory muscle activity face down (2026-11-11)

- **Motor units involvement in diaphragm and intercostal muscles during supine and prone posture …
  in healthy young female adults.** *Indian J Physiol Pharmacol* (ijpp.com). Summary only: 30
  healthy young women, surface EMG; diaphragm and intercostal RMS and %MVC **lower prone than
  supine** (significant). (The "small study in young women" of pass 10, now identified.)
- **Prone dogs (anaesthetised)** (J Appl Physiol, PubMed 8365978): parasternal inspiratory EMG and
  shortening **+30–35%** prone. Animal, anaesthetised: not used.
- Still no human prone comparison of scalene or parasternal EMG against sitting.

**For the model.** Face down's upper rib muscles are, if anything, less active than supine, so the
upper ribs' postural loss applies face down too (`uprightUpperDrive` as it stands). The route that
fixed face down by removing that loss (`breathstar prone`: free lift + no loss → 44%) is
contradicted; face down needs a mechanical answer (with a free lift and the loss: 59.8%).
