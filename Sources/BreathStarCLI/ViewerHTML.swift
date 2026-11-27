// The viewer page. `/*DATA*/null` is replaced by the JSON from viewerData().
let viewerHTML = #"""
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Breath Star Viewer</title>
<style>
  :root {
    --bg: #fbfaf7; --panel: #ffffff; --ink: #222; --muted: #666; --line: #e3dfd8; --rest: #9a9a9a;
    --wall: #c0603a; --rib: #b08d6e; --dome: #3a7cc0; --spine: #8a7f72; --vec: #7a6a9a; --ghost: #5a8fc0;
    --lung: #333; --accent: #3a7cc0;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #1b1a18; --panel: #24221f; --ink: #eee; --muted: #aaa; --line: #3a3733; --rest: #777;
      --wall: #e07a52; --rib: #c9a483; --dome: #6aa6e0; --spine: #a99c8c; --vec: #a896c8; --ghost: #7fb0e0;
      --lung: #ddd; --accent: #6aa6e0;
    }
  }
  * { box-sizing: border-box; }
  body { margin: 0; background: var(--bg); color: var(--ink); font: 14px/1.45 -apple-system, Helvetica, sans-serif; }
  main { max-width: 1120px; margin: 0 auto; padding: 18px 16px 40px; }
  h1 { font-size: 19px; margin: 0 0 2px; }
  .sub { color: var(--muted); margin: 0 0 14px; }
  .controls { display: flex; flex-wrap: wrap; gap: 10px 18px; align-items: center; background: var(--panel);
              border: 1px solid var(--line); border-radius: 8px; padding: 10px 12px; margin-bottom: 12px; }
  .controls label { display: inline-flex; align-items: center; gap: 6px; color: var(--muted); }
  .controls select, .controls button { font: inherit; color: var(--ink); background: var(--bg); border: 1px solid var(--line);
              border-radius: 6px; padding: 4px 8px; }
  button.play { min-width: 76px; font-weight: 600; }
  input[type=range] { accent-color: var(--accent); }
  #scrub { width: 100%; margin: 4px 0 0; }
  .scrubrow { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; padding: 8px 12px; margin-bottom: 12px; }
  .readout { display: flex; flex-wrap: wrap; gap: 6px 20px; color: var(--muted); font-variant-numeric: tabular-nums; }
  .readout b { color: var(--ink); font-weight: 600; }
  .stage { background: var(--panel); border: 1px solid var(--line); border-radius: 8px; overflow: hidden; }
  svg { display: block; width: 100%; height: auto; }
  .note { color: var(--muted); font-size: 12.5px; margin-top: 10px; }
  .legend { display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 12.5px; color: var(--muted); margin: 8px 2px 0; }
  .sw { display: inline-block; width: 18px; height: 3px; vertical-align: middle; margin-right: 5px; border-radius: 2px; }
</style>
</head>
<body>
<main>
  <h1>Breath Star: one breath, scrubbable</h1>
  <p class="sub">A2's own simulated breath (not a prescribed animation). Motion is magnified by scaling each point's
     displacement from the resting shape; volumes in the trace are true scale.</p>

  <div class="controls">
    <span style="color:var(--muted)">Posture, case and playback are above the blur figure below.</span>
    <label>Magnify <input type="range" id="mag" min="1" max="12" step="0.5" value="4"> <span id="magv">×4</span></label>
    <label><input type="checkbox" id="rest" checked> rest outline</label>
    <label><input type="checkbox" id="vectors" checked> back-rib vectors</label>
    <label><input type="checkbox" id="ghosts"> alternative model variants</label>
    <label><input type="checkbox" id="lift"> trunk lift off the floor (hypothesis; fails the front markers)</label>
    <label><input type="checkbox" id="floor" checked> floor (lying on the side)</label>
  </div>

  <div class="scrubrow">
    <input type="range" id="scrub" min="0" max="1000" value="0" aria-label="Position in the breath">
    <div class="readout">
      <span>t <b id="rt">0.00</b> s of <span id="rp"></span></span>
      <span id="rphase"></span>
      <span>lung <b id="rl"></b> L</span>
      <span>upper <b id="ru"></b></span>
      <span>lower <b id="rlo"></b></span>
      <span>abdomen <b id="ra"></b></span>
      <span>signed shares of the breath <b id="rs"></b></span>
    </div>
  </div>

  <div class="stage"><svg id="body" viewBox="0 0 1080 540" role="img" aria-label="Trunk seen from the side, front and back"></svg></div>
  <div class="legend">
    <span><i class="sw" style="background:var(--wall)"></i>body wall</span>
    <span><i class="sw" style="background:var(--rib)"></i>ribs</span>
    <span><i class="sw" style="background:var(--dome)"></i>diaphragm (schematic dome; its descent is the model's)</span>
    <span><i class="sw" style="background:var(--spine)"></i>spine (fixed)</span>
    <span><i class="sw" style="background:var(--vec)"></i>back-rib motion, ×4 more</span>
    <span><i class="sw" style="background:var(--ghost);opacity:.6"></i>alternative model variants</span>
  </div>
  <div class="stage" style="margin-top:12px"><svg id="trace" viewBox="0 0 1080 190" role="img" aria-label="Volume change over the breath"></svg></div>
  <h2 style="font-size:16px;margin:22px 0 4px">Blur (prototype)</h2>
  <p class="sub" style="margin-bottom:8px">The same breath as light on a front-facing figure. Light is the skin's outward
     motion, blurred along the body surface (never across gaps), weighted by the area each point stands for, so light per
     area means motion per area. Front half on top; back half beneath, softer and wider; inside, the diaphragm.</p>
  <div class="controls">
    <label>Posture <select id="posture"></select></label>
    <label>Case <select id="case"></select></label>
    <button class="play" id="play">Pause</button>
    <label title="1× plays the breath at half its real pace (one breath every 7.5 s); the times shown are the model's">Speed <select id="speed"><option value="0.25">¼×</option><option value="0.5">½×</option><option value="1" selected>1× (half real time)</option><option value="2">real time</option></select></label>
    <label title="made-up variation, not the model: each breath's breathing in and breathing out are stretched or squeezed by their own random amount, and a random pause follows breathing out. 0 = every breath the same. The shape of each breath is unchanged; only its pace.">Timing variation <input type="range" id="tvar" min="0" max="0.4" step="0.05" value="0"> <span id="tvarv">off</span></label>
    <span id="tbreath" style="color:var(--muted);font-size:12px"></span>
  </div>
  <div class="controls lessonbar" id="lessonbar" hidden>
    <button id="lprev" title="previous step">◀</button>
    <button id="lnext" title="next step">▶</button>
    <div id="linfo" style="flex:1 1 420px;min-width:0"></div>
  </div>
  <div class="controls">
    <label>Light from <select id="bchan"><option value="d">fullness (how far out)</option><option value="v">wall speed (how fast the skin moves)</option><optgroup label="what can be felt (not for Seated)"><option value="stretch">stretch (the wall's area strain)</option><option value="push">push (the tissue's elastic force)</option><option value="effort">effort (the muscles' force)</option><option value="floor">floor (pressure on the support)</option></optgroup></select></label>
    <label title="stretch, push and floor: add the posture's resting load (the weight's settle from weightless, the spine's bend or the side-lying arc, the trunk's weight on the floor) to the breath's"><input type="checkbox" id="brestload"> add the resting load</label>
    <label>Blur width <select id="bw"><option value="2">2 cm</option><option value="4" selected>4 cm</option><option value="8">8 cm</option></select></label>
    <label>Contrast <input type="range" id="bgamma" min="0.3" max="1.2" step="0.05" value="0.6"> <span id="bgv">γ 0.60</span></label>
    <label><input type="checkbox" id="bback" checked> back layer</label>
    <label><input type="checkbox" id="binside"> diaphragm</label>
    <label><input type="checkbox" id="bsil"> silhouette</label>
    <label><input type="checkbox" id="bspine" checked> spine</label>
    <label>Shape <select id="bshape"><option value="body">body outline</option><option value="oval" selected>felt container (oval)</option><option value="radial">radial (from the low belly)</option></select></label>
    <label class="radialc">centre height <input type="range" id="bcentre" min="0" max="16" step="1" value="10"></label>
    <label class="ovalc">room by breath <input type="range" id="broom" min="0" max="1" step="0.05" value="1"></label>
    <label class="ovalc eggc">wider low <input type="range" id="begg" min="0" max="0.5" step="0.05" value="0"></label>
    <label class="ovalc">height/width <input type="range" id="baspect" min="0.9" max="1.8" step="0.05" value="1"></label>
    <label title="a wide blur of the whole light, mixed in: it softens the light and lets it spill past the edge (Breath Star's wash)">glow width <input type="range" id="bglow" min="0" max="14" step="0.5" value="9"> <span id="bglowv">9.0 cm</span></label>
    <label>glow mix <input type="range" id="bgmix" min="0" max="1" step="0.05" value="0.6"></label>
    <button id="bstar" title="round container, no egg, glow 9 cm at 0.6, no outline">Breath Star look</button>
    <button id="bmine" title="the earlier settings: oval 1.25, wider low 0.1, no glow, outline on">earlier settings</button>
    <label><input type="checkbox" id="bunc"> soften where unsure</label>
    <button id="bpop" title="opens the blur alone in its own window, to put on another display; this window's controls drive it. Double-click it for full screen.">Show in its own window</button>
    <label title="a made-up pattern, not the model: a band of motion that travels round the trunk once per breath, to see how each shape shows travel (blur only; the line view keeps the case)">Test wave <select id="bwave"><option value="off">off (the model)</option><option value="up">up the trunk</option><option value="updown">up, then back down</option><option value="side">side to side</option></select></label>
  </div>
  <div class="controls">
    <label title="a second blur beside the first, at the same point in the breath and on the same brightness scale (the first posture's reference breath)">Compare with <select id="cposture"></select></label>
    <label>case <select id="ccase"></select></label>
    <label title="the second blur shows this case minus the comparison, point by point, scaled so the largest difference over the breath is full brightness: orange where the first moves further out (or less in), blue where the comparison does"><input type="checkbox" id="cdelta"> show the difference instead</label>
  </div>
  <div class="stage" style="background:#0d0f14"><canvas id="blur" width="840" height="920" style="display:block;width:100%;max-width:420px;margin:0 auto"></canvas></div>
  <p class="note">Blue-white: outward. Violet: inward. With "fullness" that means the wall is inward of where it rests at
     the end of breathing out (in a healthy breath, only a paradox does that). With "wall speed" violet also shows the
     wall moving in during ordinary breathing out. Brightness follows a compressive curve (γ), a blur and a soft tone
     map, all fixed by the posture's reference breath: brighter means more motion, and a weaker case looks weaker, but
     brightness ratios are not motion ratios. "Soften where unsure" widens the light where 12 variants of the model,
     with its assumed numbers and the marker means redrawn, disagree (seated only); the variants leave out the
     structural choices, so this understates the uncertainty. "Test wave" replaces the model's light with a made-up
     band that travels round the trunk once per breath, to compare how the shapes show travel; it is not a prediction. <b>What can be felt</b> (not for Seated, whose model is A2): the body senses no volume; it senses stretch, tension, effort and touch. <i>Stretch</i>: the wall's area strain (blue-white lengthened, violet shortened). <i>Push</i>: the tissue's own elastic force (passive springs, the costal arch and sternum, the bend's stiffening), turned into a surface pressure by virtual work. <i>Effort</i>: the muscles' force, the breath's drive plus what held regions resist; the model's holds are stiffnesses, so a hold costs effort only when the breath pushes on it. <i>Floor</i>: pressure on the contact patches. "Add the resting load" adds the posture's own: the weight's settle (from weightless), the spine's bend or, lying on the side, the rest arc (Leilnahari 2011; the mechanics don't use it yet), and the trunk's weight on the floor (35 kg, ASSUMED). With "diaphragm" on, push and effort light the domes by the diaphragm's force. The springs are linear: real tissue stiffens as it stretches, which this can't show. The breath changes the floor's pressure by a few cmH2O against about 110 from the trunk's weight, so with the resting load the floor barely flickers. <b>Compare with</b> puts a second blur beside the first, at the same point in the breath and lit on the first posture's reference scale, so a weaker breath looks weaker; the popup window shows both. "Show the difference instead" replaces the second blur with the first minus the comparison, point by point on the same surface grid, drawn on the first posture's shape: orange where the first is further out (or less far in), blue where the comparison is. It is scaled so the largest difference over the whole breath is full brightness, so it shows where the two differ, not how large the difference is next to the breath itself. Cases are matched to the same breath size, so the difference is where the breath goes, not how much of it there is. Trunk only: the model has no head or limbs.
     <b>Felt container:</b> the trunk surface mapped smoothly onto an oval, nothing cropped; the iliac crests and the top
     of the ribcage become its poles (the pelvic bowl and the lung apices are not modelled, so the poles are carried by
     their neighbours). "Room by breath" gives each height space by how much it moves in the reference breath; light is
     scaled by the map's stretch, so brightness still means motion per area. <b>Radial</b> (an alternative to compare): the breath as expansion from a centre low in the belly (centre height in cm above the iliac crests), the pelvis and the top of the ribcage as the poles; each height row becomes an arc whose ring area follows its room, across the row becomes the angle round it. Below about 6 cm the trunk barely moves, so a low centre leaves the lower half dark. Lying on the side, the oval shows the light
     without the posture's arc or the floor.</p>

  <p class="note">Playback: 1× is half the breath's real pace (one breath every 7.5 s); "real time" plays it as modelled (16 breaths a minute). The felt container's defaults are the Breath Star look the user chose on 2026-11-10 (round, room fully by breath, a 9 cm glow at 0.6, no outline); "earlier settings" restores the oval chosen before (height/width 1.25, wider low 0.1, outline, no glow). Space plays or pauses; ← → step one frame. Alternative model variants (seated reference only): 12 variants with the
     assumed numbers and the marker means redrawn, refitted and recalibrated (<code>breathstar uncertainty</code>),
     at the reference breath's current fraction of its peak, on the reference's resting shape. Where they spread, the
     motion depends on those assumptions; where they agree, it is robust to them, though not to the structural choices
     the variants leave out (the stiffness basis, one force per coordinate). Lying on the side: the trunk lift is a
     hypothesis, off by default. Generated by <code>breathstar viewer</code>.</p>
</main>

<script id="data" type="application/json">/*DATA*/null</script>
<script>
"use strict";
const D = JSON.parse(document.getElementById("data").textContent);
const NUM = /-?\d+\.\d+/g;
const K = 9;                                   // px per cm
const VIEW = { side: { x: 90, y: 480, sx: 1 }, front: { x: 560, y: 480, sx: 1 }, back: { x: 880, y: 480, sx: -1 } };
const VECTOR_GAIN = 4;
const PLAYBACK = 0.5;   // 1× = half real time, the user's preferred pace (2026-11-10)
const $ = id => document.getElementById(id);
const NS = "http://www.w3.org/2000/svg";

function compile(d) { return { parts: d.split(NUM), rest: (d.match(NUM) || []).map(Number) }; }
// Lesson steps (stage 7) share their geometry with the posture of the same gravity.
for (const p of D.postures) if (p.geometryFrom) {
  const g = D.postures.find(q => q.id === p.geometryFrom);
  p.layers = g.layers; p.surface = g.surface; p.landmarks = g.landmarks; p.diaphragm = g.diaphragm;
}
for (const p of D.postures) for (const l of p.layers) if (!l.tpl) l.tpl = compile(l.d);
for (const g of D.ghosts) for (const k in g) g[k].tpl = compile(g[k].d);

// Lying on the floor (posture.lying): front-view points are carried onto the spine's sideways arc
// (shifted and turned with it) and lifted away from the floor by the breath (room frame); the front
// view is drawn lying down, head to the right, floor below. LY holds the current frame's q and
// magnification (the lift is a displacement, so it is magnified like the rest).
let LY = null;
const LV = { x: 470, y: 255 };
function lyingAt(z) {
  const L = posture.lying, zs = L.z;
  let i = Math.floor((z - zs[0]) / 0.5); i = Math.max(0, Math.min(zs.length - 2, i));
  const a = Math.max(0, Math.min(1, (z - zs[i]) / 0.5)), lerp = arr => arr[i] + a * (arr[i + 1] - arr[i]);
  let lift = 0;
  // The trunk lift is a hypothesis Takashima's front markers argue against (critique 3, section 1): off by default.
  const liftOn = $("lift").checked;
  if (LY && liftOn) for (let c = 0; c < LY.q.length; c++) if (LY.q[c]) lift += LY.q[c] * lerp(L.liftBasis[c]);
  return { x: lerp(L.x), tilt: lerp(L.tilt), lift: LY && liftOn ? LY.mag * lift : 0 };
}
function onArc(x, z) { const s = lyingAt(z); return [s.x + s.lift + x * Math.cos(s.tilt), z - x * Math.sin(s.tilt)]; }
// A bent spine, upright (posture.bend: stage 4): each section carried onto the spine's sideways curve.
function bendAt(z) {
  const B = posture.bend, zs = B.z;
  let i = Math.floor((z - zs[0]) / 0.5); i = Math.max(0, Math.min(zs.length - 2, i));
  const a = Math.max(0, Math.min(1, (z - zs[i]) / 0.5));
  return { x: B.x[i] + a * (B.x[i + 1] - B.x[i]), tilt: B.tilt[i] + a * (B.tilt[i + 1] - B.tilt[i]) };
}
function onBend(x, z) { const s = bendAt(z); return [s.x + x * Math.cos(s.tilt), z - x * Math.sin(s.tilt)]; }

function draw(tpl, view, values) {
  const v = VIEW[view], lying = posture.lying && view !== "side";
  let s = tpl.parts[0];
  for (let j = 0; j + 1 < values.length; j += 2) {
    let a = values[j], b = values[j + 1], px, py;
    if (lying) { [a, b] = onArc(a, b); px = LV.x + b * K; py = LV.y - a * K; }
    else if (posture.bend && view !== "side") { [a, b] = onBend(a, b); px = v.x + v.sx * a * K; py = v.y - b * K; }
    else { px = v.x + v.sx * a * K; py = v.y - b * K; }
    s += px.toFixed(1) + tpl.parts[j + 1] + py.toFixed(1) + tpl.parts[j + 2];
  }
  return s;
}

let posture = D.postures[0], kase = posture.cases[0];
let t = 0, playing = true, last = null;

function el(tag, attrs, parent) {
  const e = document.createElementNS(NS, tag);
  for (const k in attrs) e.setAttribute(k, attrs[k]);
  (parent || $("body")).appendChild(e);
  return e;
}

// Static scaffold: view titles, landmark lines; then one path per layer (rest + moving).
const paths = {};
function scaffold() {
  const svg = $("body");
  svg.innerHTML = "";
  const L = posture.lying;
  const titles = L
    ? [["Side (seen from above: the left side)", 90], ["Front, lying on the right side (head to the right, floor below)", 480]]
    : [["Side (left side facing you, front to the right)", 90], ["Front (facing the person)", 450], ["Back (seen from behind)", 790]];
  for (const [txt, x] of titles) el("text", { x, y: 520, fill: "var(--ink)", "font-weight": 600, "font-size": 13 }).textContent = txt;
  for (const [name, z] of Object.entries(posture.landmarks)) {
    const y = VIEW.side.y - z * K;
    el("line", { x1: 70, x2: L ? 410 : 1060, y1: y, y2: y, stroke: "var(--line)", "stroke-width": 1 });
    el("text", { x: 66, y: y + 4, fill: "var(--muted)", "font-size": 10.5, "text-anchor": "end" }).textContent = name;
  }
  if (L) {
    // The floor, at the trunk's lowest resting point; the spine's arc is drawn each frame.
    const fy = LV.y - L.floor * K, x0 = LV.x + L.z[0] * K, x1 = LV.x + L.z[L.z.length - 1] * K;
    const floorG = el("g", { id: "floorg" });
    el("line", { x1: x0 - 30, x2: x1 + 30, y1: fy, y2: fy, stroke: "var(--muted)", "stroke-width": 2 }, floorG);
    for (let x = x0 - 30; x < x1 + 30; x += 14) el("line", { x1: x, x2: x - 8, y1: fy, y2: fy + 8, stroke: "var(--muted)", "stroke-width": 1 }, floorG);
    el("text", { x: x0 - 30, y: fy + 24, fill: "var(--muted)", "font-size": 11 }, floorG).textContent =
      `floor: the lower ribcage bears weight on it (Takashima's thesis); the pelvis, via the greater trochanter (not modelled), rests on it too · spine sag ${(L.sagCm * 10).toFixed(0)} mm (Leilnahari 2011, firm surface)`;
    el("text", { x: x1 - 10, y: LV.y - 150, fill: "var(--muted)", "font-size": 11, "text-anchor": "end" }).textContent = "head →";
    // What the model can't explain (side-lying session, critique 3 fixes): Takashima's largest side-lying motion.
    el("text", { x: x0 - 30, y: LV.y - 170, fill: "var(--muted)", "font-size": 11 }).textContent =
      "Unexplained: the upper side's lower ribs move 1.70 mm sideways (Takashima); the model gives about 0.5 without the lift, and the lift fails the front markers.";
    paths.spine = el("path", { fill: "none", stroke: "var(--spine)", "stroke-width": 4, "stroke-linecap": "round" });
  } else {
    paths.spine = null;
    // The midline (front) and the spine (back): straight, or along the bent spine's curve (stage 4).
    const spineLine = v => "M" + Array.from({ length: 87 }, (_, i) => i * 0.5).filter(z => z <= posture.landmarks["top of ribcage"])
      .map(z => { const x = posture.bend ? bendAt(z).x : 0; return (v.x + v.sx * x * K).toFixed(1) + "," + (v.y - z * K).toFixed(1); }).join(" L");
    el("path", { d: spineLine(VIEW.front), fill: "none", stroke: "var(--spine)", "stroke-dasharray": "2 4" });
    el("path", { d: spineLine(VIEW.back), fill: "none", stroke: "var(--spine)", "stroke-width": 4, "stroke-linecap": "round" });
  }
  const ghostG = el("g", { id: "ghostg" });
  paths.ghosts = D.ghosts.map(g => Object.keys(g).map(k => ({ g: g[k], p: el("path", { fill: "none", stroke: "var(--ghost)", "stroke-width": 1, "stroke-opacity": 0.4 }, ghostG) })));
  const restG = el("g", { id: "restg" });
  paths.layers = posture.layers.map(l => {
    const color = l.key.endsWith("spine") ? "var(--spine)" : l.key.includes("rib") ? "var(--rib)"
      : l.key.includes("dome") ? "var(--dome)" : l.key.endsWith("vectors") ? "var(--vec)" : "var(--wall)";
    const width = l.key.endsWith("spine") ? 6 : l.key.includes("rib") ? 1.8 : l.key.endsWith("vectors") ? 2.2 : 2.5;
    const hidden = L && l.view === "back";
    const rest = l.key.endsWith("vectors") || hidden ? null
      : el("path", { d: draw(l.tpl, l.view, l.tpl.rest), fill: "none", stroke: "var(--rest)", "stroke-width": 1.2, "stroke-dasharray": "4 3" }, restG);
    const p = el("path", { fill: "none", stroke: color, "stroke-width": width, "stroke-linejoin": "round", "stroke-linecap": "round" });
    return { l, p, rest };
  });
  traceScaffold();
}

function frameQ(f) {
  const n = kase.q.length, i = Math.floor(f) % n, j = (i + 1) % n, a = f - Math.floor(f);
  return { q: kase.q[i].map((v, c) => v + a * (kase.q[j][c] - v)),
           lerp: key => kase[key][i] + a * (kase[key][j] - kase[key][i]) };
}

function render() {
  const mag = +$("mag").value;
  const f = t / D.period * kase.q.length;
  const { q, lerp } = frameQ(f);
  LY = posture.lying ? { q, mag } : null;
  if (paths.spine) {
    const L = posture.lying;
    paths.spine.setAttribute("d", "M" + L.z.filter(z => z >= 0 && z <= posture.landmarks["top of ribcage"])
      .map(z => { const sp = lyingAt(z); return (LV.x + z * K).toFixed(1) + "," + (LV.y - (sp.x + sp.lift) * K).toFixed(1); }).join(" L"));
  }
  for (const { l, p } of paths.layers) {
    if (posture.lying && l.view === "back") { p.setAttribute("d", ""); continue; }
    if (l.key.endsWith("vectors") && !$("vectors").checked) { p.setAttribute("d", ""); continue; }
    const gain = mag * (l.key.endsWith("vectors") ? VECTOR_GAIN : 1);
    const vals = l.tpl.rest.map((r, j) => {
      let d = 0;
      for (let c = 0; c < q.length; c++) d += q[c] * l.basis[c][j];
      return r + gain * d;
    });
    p.setAttribute("d", draw(l.tpl, l.view, vals));
  }
  const showGhosts = $("ghosts").checked && posture.id === "seated" && kase.id === "reference";
  const peak = Math.max(...kase.lung), frac = Math.max(0, lerp("lung") / peak);
  for (const set of paths.ghosts) for (const { g, p } of set) {
    p.setAttribute("d", showGhosts ? draw(g.tpl, g.view, g.tpl.rest.map((r, j) => r + mag * frac * g.delta[j])) : "");
  }
  $("restg").style.display = $("rest").checked ? "" : "none";
  if ($("floorg")) $("floorg").style.display = $("floor").checked ? "" : "none";
  $("floor").disabled = !posture.lying;
  $("lift").disabled = !posture.lying;
  // Readouts.
  const tin = D.inspiration;
  $("rt").textContent = t.toFixed(2);
  $("rp").textContent = D.period.toFixed(2) + " s";
  // Air direction from the lung's own change; the drive separately (air keeps flowing in briefly
  // after the drive stops, so the two can differ).
  const dl = frameQ(f + 0.5).lerp("lung") - frameQ(f - 0.5 + kase.q.length).lerp("lung");
  $("rphase").innerHTML = (Math.abs(dl) < 1e-4 ? "<b>turning</b>" : dl > 0 ? "<b>air in</b>" : "<b>air out</b>")
    + (t < tin ? " · muscles driving" : " · drive off (passive recoil)");
  const L = k => (lerp(k) * 1000).toFixed(0) + " mL";
  $("rl").textContent = lerp("lung").toFixed(3);
  $("ru").textContent = L("upper"); $("rlo").textContent = L("lower"); $("ra").textContent = L("abdomen");
  // Shares of a tiny breath are meaningless (they divide by nearly zero): show the size instead.
  $("rs").textContent = (kase.tidal < 0.05
      ? `breath too small to split (${(kase.tidal * 1000).toFixed(0)} mL)`
      : kase.shares.map(s => (s * 100).toFixed(0) + "%").join(" / ") + " (tidal " + kase.tidal.toFixed(2) + " L)")
    + " · " + (kase.sizing || "");
  $("scrub").value = Math.round(t / D.period * 1000);
  traceCursor();
  if (typeof renderBlur === "function") { renderBlur(f, mag); mirrorBlur(); }
  $("bunc").disabled = !posture.surface.uncertainty;
}

// Trace panel.
const TR = { x0: 70, w: 840, y0: 20, h: 140 };
function traceScaffold() {
  const svg = $("trace");
  svg.innerHTML = "";
  const series = [["lung", "var(--lung)", "lung (total)"], ["upper", "var(--wall)", "upper ribcage"], ["lower", "var(--rib)", "lower ribcage"], ["abdomen", "var(--dome)", "abdomen"]];
  const all = series.flatMap(s => kase[s[0]]);
  const vmax = Math.max(0.001, ...all), vmin = Math.min(0, ...all);
  const px = tt => TR.x0 + tt / D.period * TR.w, py = v => TR.y0 + TR.h - (v - vmin) / (vmax - vmin) * TR.h;
  el("line", { x1: TR.x0, x2: TR.x0 + TR.w, y1: py(0), y2: py(0), stroke: "var(--line)" }, svg);
  el("line", { x1: px(D.inspiration), x2: px(D.inspiration), y1: TR.y0, y2: TR.y0 + TR.h, stroke: "var(--line)", "stroke-dasharray": "3 3" }, svg);
  el("text", { x: px(D.inspiration) + 4, y: TR.y0 + TR.h - 4, fill: "var(--muted)", "font-size": 11 }, svg).textContent = "drive ends";
  series.forEach(([k, color, label], i) => {
    const pts = kase.t.map((tt, j) => px(tt).toFixed(1) + "," + py(kase[k][j]).toFixed(1));
    pts.push(px(D.period).toFixed(1) + "," + py(kase[k][0]).toFixed(1));
    el("polyline", { points: pts.join(" "), fill: "none", stroke: color, "stroke-width": 2 }, svg);
    el("text", { x: TR.x0 + TR.w + 14, y: TR.y0 + 14 + i * 18, fill: color, "font-size": 12 }, svg).textContent = label;
  });
  el("text", { x: TR.x0, y: TR.y0 + TR.h + 22, fill: "var(--muted)", "font-size": 11 }, svg).textContent =
    "volume change, litres, true scale: 0 to " + vmax.toFixed(2) + " L; click or drag to scrub";
  paths.cursor = el("line", { y1: TR.y0, y2: TR.y0 + TR.h, stroke: "var(--ink)", "stroke-width": 1.2 }, svg);
  const seek = e => {
    const r = svg.getBoundingClientRect(), x = (e.clientX - r.left) / r.width * 1080;
    t = Math.min(D.period * 0.999, Math.max(0, (x - TR.x0) / TR.w * D.period));
    setPlaying(false); render();
  };
  svg.onpointerdown = e => { seek(e); svg.onpointermove = seek; };
  window.onpointerup = () => { svg.onpointermove = null; };
}
function traceCursor() {
  const x = TR.x0 + t / D.period * TR.w;
  paths.cursor.setAttribute("x1", x); paths.cursor.setAttribute("x2", x);
}

function setPlaying(p) { playing = p; $("play").textContent = p ? "Pause" : "Play"; last = null; }
// Timing variation (a user setting, made up, not the model): per breath, breathing in and breathing
// out are each stretched by a log-normal factor exp(v·N(0,1)), and a pause of up to v × the model's
// breath length (uniform) follows breathing out, held at rest. v = 0: every breath the same.
let fIn = 1, fEx = 1, pause = 0;
function gauss() { let u = 0, w = 0; while (!u) u = Math.random(); while (!w) w = Math.random(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * w); }
function drawBreath() {
  const v = +$("tvar").value, tin = D.inspiration;
  fIn = Math.exp(v * gauss()); fEx = Math.exp(v * gauss());
  pause = v * Math.random() * D.period;
  const len = tin * fIn + (D.period - tin) * fEx + pause;
  $("tbreath").textContent = v ? `this breath ${len.toFixed(1)} s (in ${(tin * fIn).toFixed(1)}, out ${((D.period - tin) * fEx).toFixed(1)}, pause ${pause.toFixed(1)})` : "";
}
$("tvar").oninput = () => { const v = +$("tvar").value; $("tvarv").textContent = v ? "±" + Math.round(v * 100) + "%" : "off"; drawBreath(); };
function advance(dt) {
  if (!+$("tvar").value) { t = (t + dt) % D.period; return; }
  while (dt > 0) {
    if (pause > 0) { const used = Math.min(pause, dt); pause -= used; dt -= used; t = 0; continue; }
    const inBreathIn = t < D.inspiration, f = inBreathIn ? fIn : fEx;
    const edge = inBreathIn ? D.inspiration : D.period, need = (edge - t) * f;
    if (dt < need) { t += dt / f; return; }
    dt -= need; t = edge;
    if (!inBreathIn) { t = 0; drawBreath(); }
  }
}
function tick(now) {
  if (playing) {
    // The user's preferred pace (2026-11-10): 1× plays at half real time; "real time" is 2×.
    if (last !== null) advance((now - last) / 1000 * PLAYBACK * +$("speed").value);
    last = now;
    render();
  }
  requestAnimationFrame(tick);
}

function fillCases() {
  $("case").innerHTML = posture.cases.map(c => `<option value="${c.id}">${c.label}</option>`).join("");
  $("ghosts").disabled = posture.id !== "seated";
}
{
  // Postures, then the lesson's steps in their own group.
  const plain = D.postures.filter(p => !p.group), groups = [...new Set(D.postures.filter(p => p.group).map(p => p.group))];
  $("posture").innerHTML = plain.map(p => `<option value="${p.id}">${p.label}</option>`).join("")
    + groups.map(g => `<optgroup label="${g}">` + D.postures.filter(p => p.group === g).map(p => `<option value="${p.id}">${p.label}</option>`).join("") + "</optgroup>").join("");
}
function lessonPanel() {
  const L = posture.lesson;
  $("lessonbar").hidden = !L;
  if (!L) return;
  const esc = t => String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;");
  $("linfo").innerHTML = `<b>Step ${L.index} of ${L.total}: ${esc(L.label)}</b> · ${L.minutes} min (assumed) · ${esc(L.source)}<br>`
    + `<span style="color:var(--muted)">${esc(L.configuration)} · ${esc(L.provenance)} · drive ×${L.drive.toFixed(2)}</span><br>`
    + `relation: ${esc(L.relation)}<br>verdict: ${esc(L.verdict)}` + (L.note ? `<br><span style="color:var(--muted)">note: ${esc(L.note)}</span>` : "");
  $("lprev").disabled = L.index === 1; $("lnext").disabled = L.index === L.total;
}
$("posture").onchange = () => {
  const id = kase.id;
  posture = D.postures.find(p => p.id === $("posture").value);
  fillCases();
  kase = posture.cases.find(c => c.id === id) || posture.cases[0];
  $("case").value = kase.id;
  lessonPanel();
  scaffold(); render();
};
function lessonStep(d) {
  const steps = D.postures.filter(p => p.group === posture.group), i = steps.indexOf(posture) + d;
  if (i < 0 || i >= steps.length) return;
  $("posture").value = steps[i].id; $("posture").onchange();
}
$("lprev").onclick = () => lessonStep(-1);
$("lnext").onclick = () => lessonStep(1);
$("case").onchange = () => { kase = posture.cases.find(c => c.id === $("case").value); traceScaffold(); render(); };
$("play").onclick = () => setPlaying(!playing);
$("scrub").oninput = () => { t = $("scrub").value / 1000 * D.period * 0.999; setPlaying(false); render(); };
$("mag").oninput = () => { $("magv").textContent = "×" + $("mag").value; render(); };
for (const id of ["rest", "vectors", "ghosts", "speed", "floor", "lift"]) $(id).onchange = render;
document.addEventListener("keydown", e => {
  if (e.target.tagName === "SELECT") return;
  const step = D.period / kase.q.length;
  if (e.key === " ") { e.preventDefault(); setPlaying(!playing); }
  else if (e.key === "ArrowRight") { setPlaying(false); t = (t + step) % D.period; render(); }
  else if (e.key === "ArrowLeft") { setPlaying(false); t = (t - step + D.period) % D.period; render(); }
});
// ---- Blur panel ----
const BC = $("blur"), bx = BC.getContext("2d");
// The view leaves room around the figure (as Breath Star's does), so a glow can spread past its edge
// and a round container fits: 13 canvas px per cm, ±32 cm wide, the trunk's middle at the centre.
const BK = 13, BCX = 420, BCY = 772;                // canvas px per cm (2× its CSS size)
// Light is accumulated in a floating-point buffer (0.5 cm cells) and tone-mapped with a soft curve,
// 1 − exp(−E·light), whose exposure E is fixed by the posture's reference breath at its peak: no
// hard clipping, and cases stay comparable.
const CELL = 0.5, GW = 128, GH = 136, X0 = -32, ZTOP = 58;
const acc = [new Float32Array(GW * GH), new Float32Array(GW * GH), new Float32Array(GW * GH)];
const off = document.createElement("canvas"); off.width = GW; off.height = GH;
const offx = off.getContext("2d"), img = offx.createImageData(GW, GH);
const COL = { out: [0.45, 0.72, 1.0], back: [0.12, 0.28, 1.0], in: [0.85, 0.25, 1.0], dia: [0.15, 0.95, 0.70] };
const BG = [13, 15, 20];
const DCOL = { pos: [1.0, 0.55, 0.18], neg: [0.25, 0.65, 1.0] };   // difference: more here / more in the comparison
// ---- Shape: body outline, or the felt container (docs/LESSON_ADAPTATION.md §7.1) ----
// The felt container is a smooth, reversible map from the trunk surface's front projection (x, z) to an
// egg-shaped oval: every point keeps a place (the flat cuts at the iliac crests and the top of the ribcage
// become the poles, squeezed but present), neighbours stay neighbours. Height h = z/top goes to the oval's
// vertical coordinate v through g(h) = (1 − w)·h + w·C(h), C the cumulative share of the posture's reference
// breath (motion × area) below h: each height gets room by how much it breathes, mixed with even spacing by
// w. Width: x / (rest half-width at z) × the oval's half-width at v. Each point's light is scaled by the
// map's area change, so light per display area still means motion per body area: squeezed corners are
// packed, not dimmed.
const shapeCache = {};
function shapeOf() {
  const kind = $("bshape").value;
  if (kind !== "oval" && kind !== "radial") return null;
  const surf = posture.surface, top = posture.landmarks["top of ribcage"];
  const key = posture.id + "|" + kind + "|" + $("broom").value + "|" + $("begg").value + "|" + $("baspect").value + "|" + $("bcentre").value;
  if (shapeCache[key]) return shapeCache[key];
  // Rest half-width per height row (the widest projected point), and the reference breath's motion per row.
  const rows = new Map();
  for (let j = 0; j < surf.x.length; j++) {
    const z = surf.z[j], r = rows.get(z) || { hw: 0, m: 0 };
    r.hw = Math.max(r.hw, Math.abs(surf.x[j])); rows.set(z, r);
  }
  const ref = posture.cases.find(c => c.id === "reference");
  const iPeak = ref.lung.indexOf(Math.max(...ref.lung)), B = surf.bases["4"], q = ref.q[iPeak];
  for (let j = 0; j < surf.x.length; j++) {
    let v = 0; for (let c = 0; c < q.length; c++) v += q[c] * B[c][j];
    rows.get(surf.z[j]).m += Math.abs(v) * surf.projArea[j];
  }
  const zs = [...rows.keys()].sort((a, b) => a - b), hw = zs.map(z => rows.get(z).hw), m = zs.map(z => rows.get(z).m);
  const total = m.reduce((a, b) => a + b, 0) || 1, cum = [];
  let acc0 = 0; for (const v of m) { acc0 += v; cum.push(acc0 / total); }
  const w = +$("broom").value, egg = +$("begg").value, aspect = +$("baspect").value, Hd = 46;
  function interp(arr, z) {
    if (z <= zs[0]) return arr[0];
    if (z >= zs[zs.length - 1]) return arr[arr.length - 1];
    let i = 0; while (zs[i + 1] < z) i++;
    const a = (z - zs[i]) / (zs[i + 1] - zs[i]); return arr[i] + a * (arr[i + 1] - arr[i]);
  }
  function map(x, z) {
    const zc = Math.max(0, Math.min(top, z)), h = zc / top;
    const g = (1 - w) * h + w * interp(cum, zc);
    const v = -0.985 + 1.97 * g;   // the poles nearly closed: the flat cuts squeezed, still present
    const W = (Hd / 2) / aspect * Math.sqrt(Math.max(0, 1 - v * v)) * (1 - egg * v) / (1 + egg * 0.3);
    return [x / Math.max(1, interp(hw, zc)) * W, 1 + (v + 1) / 2 * Hd + (z - zc)];
  }
  function areaScale(x, z) {   // display area per body area at (x, z)
    const [, z0] = map(0, z - 0.5), [, z1] = map(0, z + 0.5), [xw] = map(1, z);
    return Math.max(0.05, (z1 - z0) * xw);
  }
  if (kind === "oval") return (shapeCache[key] = { map, areaScale });
  // Radial (docs/LESSON_ADAPTATION.md §7.1, "an alternative layout to test against the oval"): the breath
  // as expansion from a centre low in the belly, the pelvis and the top of the ribcage as the poles.
  // A row's distance from the centre is how far along the trunk it lies (the same room-by-breath
  // spacing g as the oval), above the centre into the upper half-disc, below into the lower; across
  // the row (x over its rest half-width) becomes the angle round the arc; the radius goes with the square
// root of the spacing, so each row's ring area (not its radius) follows its room. Light is scaled by the map's
  // local area change (numerical Jacobian), so brightness still means motion per body area.
  const R = Hd / 2, zc0 = 1 + R;
  const gOf = z => { const zc = Math.max(0, Math.min(top, z)), h = zc / top; return (1 - w) * h + w * interp(cum, zc); };
  const g0 = gOf(+$("bcentre").value);
  function rmap(x, z) {
    const zc = Math.max(0, Math.min(top, z)), g = gOf(zc), up = g >= g0;
    // Area, not radius, follows the spacing: a ring's area goes with r·dr, so r = R·√(share) gives each
    // row display area in proportion to its room (with "room by breath", its share of the breath).
    const r = R * Math.sqrt(Math.max(0, up ? (g - g0) / Math.max(1e-6, 1 - g0) : (g0 - g) / Math.max(1e-6, g0)));
    const u = Math.max(-1, Math.min(1, x / Math.max(1, interp(hw, zc))));
    const th = u * Math.PI / 2;
    return [r * Math.sin(th) / aspect, zc0 + (up ? 1 : -1) * r * Math.cos(th)];
  }
  function rArea(x, z) {
    const e = 0.5, [ax, az] = rmap(x - e, z), [bx, bz] = rmap(x + e, z), [cx, cz] = rmap(x, z - e), [dx, dz] = rmap(x, z + e);
    return Math.max(0.05, Math.abs((bx - ax) * (dz - cz) - (bz - az) * (dx - cx)) / (4 * e * e));
  }
  return (shapeCache[key] = { map: rmap, areaScale: rArea });
}
function toDisplay(x, z) {
  const sh = shapeOf();
  if (sh) return sh.map(x, z);
  return posture.lying ? onArc(x, z) : posture.bend ? onBend(x, z) : [x, z];
}
function splat(xcm, zcm, sigma, w, col) {
  if (w <= 0) return;
  const cx = (xcm - X0) / CELL, cz = (ZTOP - zcm) / CELL, sc = sigma / CELL, R = Math.ceil(3 * sc);
  const norm = w / (2 * Math.PI * sc * sc);
  for (let dz = -R; dz <= R; dz++) {
    const iz = Math.round(cz) + dz; if (iz < 0 || iz >= GH) continue;
    for (let dxx = -R; dxx <= R; dxx++) {
      const ix = Math.round(cx) + dxx; if (ix < 0 || ix >= GW) continue;
      const ddx = ix - cx, ddz = iz - cz, g = norm * Math.exp(-(ddx * ddx + ddz * ddz) / (2 * sc * sc));
      const k = iz * GW + ix;
      acc[0][k] += g * col[0]; acc[1][k] += g * col[1]; acc[2][k] += g * col[2];
    }
  }
}
const refCache = {};
function blurValues(surf, B, q) {
  const n = surf.x.length, v = new Float64Array(n);
  for (let c = 0; c < q.length; c++) { const qc = q[c]; if (!qc) continue; const b = B[c]; for (let j = 0; j < n; j++) v[j] += qc * b[j]; }
  return v;
}
// The test wave: a made-up band of outward motion (Gaussian, 4 cm wide) that travels once per breath,
// up the trunk from the pelvis to the top of the ribcage, up and back, or across from one side to the
// other. Its peak is the reference breath's largest motion, so it is lit on the same scale.
// It is not the model: it shows how each shape draws a travelling pattern.
let inRef = false;
function waveValues(surf, f, peak) {
  const kind = $("bwave").value, ph = f / kase.q.length, top = posture.landmarks["top of ribcage"];
  const n = surf.x.length, v = new Float64Array(n), s = 4;
  let along, c;
  if (kind === "side") { along = j => surf.x[j]; c = -16 + 32 * ph; }
  else { along = j => surf.z[j]; c = kind === "updown" ? top * (1 - Math.abs(2 * ph - 1)) : top * ph; }
  for (let j = 0; j < n; j++) { const d = along(j) - c; v[j] = peak * Math.exp(-d * d / (2 * s * s)); }
  return v;
}
function qAt(f) { return frameQ(((f % kase.q.length) + kase.q.length) % kase.q.length).q; }
// What can be felt (Felt.swift): per-frame arrays from the case, interpolated like q.
function rowAt(arr, f) {
  const n = arr.length, g = ((f % n) + n) % n, i = Math.floor(g) % n, j = (i + 1) % n, a = g - Math.floor(g);
  return arr[i].map((v, c) => v + a * (arr[j][c] - v));
}
// A generalised force per coordinate as a surface pressure (cmH2O): f_c · b_c / Σ b_c²·a, the
// diaphragm's left out (it has no wall: it goes to the domes).
function forceField(surf, B, F) {
  const n = surf.x.length, v = new Float64Array(n);
  for (let c = 0; c < F.length; c++) { const N = surf.norm[c]; if (!N || !F[c]) continue; const k = F[c] / N, b = B[c]; for (let j = 0; j < n; j++) v[j] += k * b[j]; }
  return v;
}
const patchCache = {};
function patchOf(surf) {
  const key = posture.id + "|" + kase.id;
  if (patchCache[key]) return patchCache[key];
  const n = surf.x.length, idx = new Int16Array(n).fill(-1);
  (kase.patches || []).forEach((p, k) => {
    for (let j = 0; j < n; j++) if (surf.side[j] === p.side && surf.z[j] >= p.z[0] && surf.z[j] <= p.z[1] && surf.psi[j] >= p.psi[0] && surf.psi[j] <= p.psi[1]) idx[j] = k;
  });
  return (patchCache[key] = idx);
}
function feltValues(surf, f, chan) {
  const n = surf.x.length, rest = $("brestload").checked, w = $("bw").value;
  if (!kase.elastic || !surf.strain) return new Float64Array(n);
  if (chan === "stretch") {
    const S = surf.strain[w], v = blurValues(surf, S, qAt(f));
    if (rest) {
      const r = blurValues(surf, S, kase.restQ), x = kase.restStrain;
      for (let j = 0; j < n; j++) v[j] += r[j] + (x ? x[j] : 0);
    }
    return v;
  }
  if (chan === "push" || chan === "effort") {
    const F = rowAt(chan === "push" ? kase.elastic : kase.effort, f);
    if (rest && chan === "push") for (let c = 0; c < F.length; c++) F[c] += kase.restElastic[c];
    return forceField(surf, surf.bases[w], F);
  }
  // floor
  const P = rowAt(kase.floor, f), idx = patchOf(surf), v = new Float64Array(n);
  for (let j = 0; j < n; j++) if (idx[j] >= 0) v[j] = P[idx[j]] + (rest ? kase.patches[idx[j]].rest : 0);
  return v;
}
// The domes' value: the coordinate (fullness), or for push and effort the diaphragm's force as a
// pressure (force over the volume it moves), on the surface's scale.
function domeValue(f, chan, i) {
  if (chan === "push" || chan === "effort") {
    if (!kase.elastic) return 0;
    let F = rowAt(chan === "push" ? kase.elastic : kase.effort, f)[i];
    if (chan === "push" && $("brestload").checked) F += kase.restElastic[i];
    return F / Math.abs(posture.own[i] || 1);
  }
  return qAt(f)[i];
}
const FELT = new Set(["stretch", "push", "effort", "floor"]);
function channel(surf, B, f, chan) {
  if (FELT.has(chan)) return feltValues(surf, f, chan);
  if (chan === "d") return blurValues(surf, B, qAt(f));
  const a = blurValues(surf, B, qAt(f + 0.5)), b = blurValues(surf, B, qAt(f - 0.5));
  const dt = D.period / kase.q.length;
  for (let j = 0; j < a.length; j++) a[j] = (a[j] - b[j]) / dt;
  return a;
}
// Accumulate one frame's light; returns the brightest cell's total.
function accumulate(f, mag, width, chan, gamma, ref, over) {
  for (const a of acc) a.fill(0);
  const surf = posture.surface, wave = !inRef && !over && $("bwave").value !== "off";
  const vals = over ? over(f) : wave ? waveValues(surf, f, ref.m) : channel(surf, surf.bases[width], f, chan);
  const unc = $("bunc").checked && surf.uncertainty;
  const n = surf.x.length;
  const one = (j, back) => {
    const L = Math.pow(Math.abs(vals[j]) / ref.m, gamma);
    // Screen spread wide enough to close the gaps between neighbouring points (projected spacing).
    let sigma = Math.max(back ? 2.0 : 1.0, 0.75 * surf.projArea[j]) * (back ? 1.6 : 1);
    if (unc) sigma *= 1 + 1.5 * Math.min(1, surf.uncertainty[j]);
    const [px, pz] = toDisplay(surf.x[j], surf.z[j]);
    const sh = shapeOf(), J = sh ? sh.areaScale(surf.x[j], surf.z[j]) : 1;
    splat(px, pz, sigma * Math.sqrt(J), L * surf.projArea[j] * J * (back ? 0.6 : 1), over ? (vals[j] < 0 ? DCOL.neg : DCOL.pos) : vals[j] < 0 ? COL.in : back ? COL.back : COL.out);
  };
  if ($("bback").checked) for (let j = 0; j < n; j++) if (surf.back[j]) one(j, true);
  for (let j = 0; j < n; j++) if (!surf.back[j]) one(j, false);
  if ($("binside").checked && !wave && !over && chan !== "stretch" && chan !== "floor") {
    // Each hemidiaphragm's descent: A2 has one coordinate for both; the sided model one per side
    // (posture.diaphragm lists the indices: [both] or [left, right]). Push and effort: its force.
    const q = qAt(f), idx = posture.diaphragm || [6], share = surf.diaphragmBackShare, felt = FELT.has(chan);
    for (const sx of [-1, 1]) {
      const i = idx.length > 1 ? (sx > 0 ? idx[0] : idx[1]) : idx[0];
      const d = q[i], dv = felt ? Math.abs(domeValue(f, chan, i)) : Math.max(0, d);
      const dL = Math.pow(dv / (felt ? ref.m : ref.dmax), gamma), zDome = posture.landmarks["xiphoid"] - 1.5 - d * mag;
      const [dx, dz] = toDisplay(sx * 7, zDome);
      splat(dx, dz, 4.5, 60 * dL * share, COL.dia);
      splat(dx, dz, 3.0, 60 * dL * (1 - share), COL.dia);
    }
  }
  glow();
  let m = 0; for (let k = 0; k < GW * GH; k++) m = Math.max(m, acc[0][k], acc[1][k], acc[2][k]);
  return m;
}
// Glow past the edge (Breath Star's wash): a wide Gaussian of the whole light field, mixed in. The blur
// conserves light, so brightness still means motion; it only softens and spills it, over the edge too.
const glowTmp = new Float32Array(GW * GH);
function glow() {
  const width = +$("bglow").value, mix = +$("bgmix").value;
  if (width <= 0 || mix <= 0) return;
  const sc = width / CELL, R = Math.ceil(3 * sc), ker = [];
  let sum = 0; for (let i = -R; i <= R; i++) { const g = Math.exp(-i * i / (2 * sc * sc)); ker.push(g); sum += g; }
  for (let i = 0; i < ker.length; i++) ker[i] /= sum;
  for (const a of acc) {
    for (let z = 0; z < GH; z++) for (let x = 0; x < GW; x++) {   // along x
      let v = 0; for (let i = -R; i <= R; i++) { const xx = x + i; if (xx >= 0 && xx < GW) v += ker[i + R] * a[z * GW + xx]; }
      glowTmp[z * GW + x] = v;
    }
    for (let x = 0; x < GW; x++) for (let z = 0; z < GH; z++) {   // along z, mixed back in
      let v = 0; for (let i = -R; i <= R; i++) { const zz = z + i; if (zz >= 0 && zz < GH) v += ker[i + R] * glowTmp[zz * GW + x]; }
      a[z * GW + x] = (1 - mix) * a[z * GW + x] + mix * v;
    }
  }
}
// Reference scales: the largest |value| over the posture's reference breath (per width and channel),
// its diaphragm peak, and the exposure that maps its brightest frame's brightest cell to 0.85.
function refScale(width, chan, gamma, mag) {
  const key = [posture.id, width, chan, gamma, $("bback").checked, $("binside").checked, $("brestload").checked,
               $("bshape").value, $("broom").value, $("begg").value, $("baspect").value, $("bcentre").value, $("bglow").value, $("bgmix").value].join("|");
  if (refCache[key]) return refCache[key];
  const keep = kase; kase = posture.cases.find(c => c.id === "reference"); inRef = true;
  const B = posture.surface.bases[width];
  let m = 1e-9, peakF = 0, peakV = -1;
  for (let f = 0; f < kase.q.length; f++) {
    for (const x of channel(posture.surface, B, f, chan)) m = Math.max(m, Math.abs(x));
    if (kase.lung[f] > peakV) { peakV = kase.lung[f]; peakF = f; }
  }
  let dmax = 1e-9; for (const q of kase.q) for (const i of (posture.diaphragm || [6])) dmax = Math.max(dmax, Math.abs(q[i]));
  const r = { m, dmax, E: 1 };
  let brightest = 1e-9;
  for (let f = 0; f < kase.q.length; f += 2) brightest = Math.max(brightest, accumulate(f, mag, width, chan, gamma, r));
  r.E = -Math.log(0.15) / brightest;
  kase = keep; inRef = false;
  return (refCache[key] = r);
}
// Comparison (side by side): the second panel is another posture and case at the same point in the
// breath, lit on the first posture's reference scale; or the difference, first minus comparison, point
// by point (both on the same 1548-point surface grid, each through its own posture's basis), drawn on the
// first posture's shape and scaled so the largest difference over the breath is full brightness.
function withCompare(fn) {
  const keepP = posture, keepK = kase;
  posture = D.postures.find(p => p.id === $("cposture").value);
  kase = posture.cases.find(c => c.id === $("ccase").value) || posture.cases[0];
  try { return fn(); } finally { posture = keepP; kase = keepK; }
}
function deltaVals(width, chan) {
  return f => {
    const a = channel(posture.surface, posture.surface.bases[width], f, chan);
    const b = withCompare(() => channel(posture.surface, posture.surface.bases[width], f, chan));
    for (let j = 0; j < a.length; j++) a[j] -= b[j];
    return a;
  };
}
const deltaCache = {};
function deltaScale(width, chan, gamma, mag, over) {
  const key = [posture.id, kase.id, $("cposture").value, $("ccase").value, width, chan, gamma, $("bback").checked, $("brestload").checked,
               $("bshape").value, $("broom").value, $("begg").value, $("baspect").value, $("bcentre").value, $("bglow").value, $("bgmix").value].join("|");
  if (deltaCache[key]) return deltaCache[key];
  let m = 1e-12;
  for (let f = 0; f < kase.q.length; f++) for (const x of over(f)) m = Math.max(m, Math.abs(x));
  const r = { m, E: 1 };
  let brightest = 1e-12;
  for (let f = 0; f < kase.q.length; f += 2) brightest = Math.max(brightest, accumulate(f, mag, width, chan, gamma, r, over));
  r.E = -Math.log(0.15) / brightest;
  return (deltaCache[key] = r);
}
function renderBlur(f, mag) {
  const width = $("bw").value, chan = $("bchan").value, gamma = +$("bgamma").value;
  const ref = refScale(width, chan, gamma, mag);
  const two = $("cposture").value !== "none";
  if (BC.width !== (two ? 1680 : 840)) { BC.width = two ? 1680 : 840; BC.style.maxWidth = two ? "840px" : "420px"; }
  bx.fillStyle = "#0d0f14"; bx.fillRect(0, 0, BC.width, BC.height);
  const name = () => posture.label + " · " + kase.label;
  accumulate(f, mag, width, chan, gamma, ref);
  blurPanel(f, mag, 420, ref, two ? name() : null);
  if (!two) return;
  if ($("cdelta").checked) {
    const over = deltaVals(width, chan), dref = deltaScale(width, chan, gamma, mag, over);
    const tiny = dref.m < 1e-3 * ref.m;
    if (!tiny) accumulate(f, mag, width, chan, gamma, dref, over); else for (const a of acc) a.fill(0);
    const other = withCompare(name);
    blurPanel(f, mag, 1260, dref, tiny ? "no difference: the same breath" : "difference: orange = more in the first, blue = more in " + other);
  } else {
    withCompare(() => { accumulate(f, mag, width, chan, gamma, ref); blurPanel(f, mag, 1260, ref, name()); });
  }
}
function blurPanel(f, mag, BCX, ref, label) {
  const d = img.data;
  for (let k = 0; k < GW * GH; k++) {
    for (let c = 0; c < 3; c++) d[4 * k + c] = BG[c] + (255 - BG[c]) * (1 - Math.exp(-ref.E * acc[c][k]));
    d[4 * k + 3] = 255;
  }
  offx.putImageData(img, 0, 0);
  bx.imageSmoothingEnabled = true; bx.imageSmoothingQuality = "high";
  bx.drawImage(off, BCX + X0 * BK, BCY - ZTOP * BK, GW * CELL * BK, GH * CELL * BK);
  if ($("bsil").checked) {
    const l = posture.layers.find(l => l.key === "front.outline");
    const { q } = frameQ(f);
    const vals2 = l.tpl.rest.map((r, j) => { let dd = 0; for (let c = 0; c < q.length; c++) dd += q[c] * l.basis[c][j]; return r + mag * dd; });
    let sstr = l.tpl.parts[0];
    for (let j = 0; j + 1 < vals2.length; j += 2) {
      const [xa, za] = toDisplay(vals2[j], vals2[j + 1]);
      sstr += (BCX + xa * BK).toFixed(1) + l.tpl.parts[j + 1] + (BCY - za * BK).toFixed(1) + l.tpl.parts[j + 2];
    }
    bx.strokeStyle = "rgba(220,230,255,0.28)"; bx.lineWidth = 2; bx.stroke(new Path2D(sstr));
  }
  if ($("bspine").checked) {
    // The spine, behind the trunk: the fixed midline sitting and lying on the back; lying on the
    // side, its sideways arc plus the breath's lift (as in the line view).
    const top = posture.landmarks["top of ribcage"], pts = [];
    for (let z = 0; z <= top + 1e-9; z += 0.5) {
      const x = posture.lying && !shapeOf() ? (() => { const sp = lyingAt(z); return sp.x + sp.lift; })()
              : posture.bend && !shapeOf() ? bendAt(z).x : 0;
      const [X, Z] = shapeOf() ? shapeOf().map(0, z) : [x, z];
      pts.push((BCX + X * BK).toFixed(1) + "," + (BCY - Z * BK).toFixed(1));
    }
    bx.strokeStyle = "rgba(200,185,160,0.55)"; bx.lineWidth = 5; bx.lineCap = "round";
    bx.stroke(new Path2D("M" + pts.join(" L")));
  }
  if (posture.lying && $("floor").checked && !shapeOf()) {
    // The floor, on the dependent (right) side: the person's right is on the viewer's left here.
    const fx = BCX + posture.lying.floor * BK;
    bx.strokeStyle = "rgba(200,200,210,0.5)"; bx.lineWidth = 2; bx.setLineDash([10, 8]);
    bx.beginPath(); bx.moveTo(fx, BCY - 46 * BK); bx.lineTo(fx, BCY + 2 * BK); bx.stroke(); bx.setLineDash([]);
    bx.fillStyle = "rgba(200,200,210,0.6)"; bx.font = "22px -apple-system, Helvetica, sans-serif"; bx.fillText("floor", fx + 6, BCY + 14);
  }
  if (label) {
    bx.fillStyle = "rgba(220,225,235,0.75)"; bx.font = "24px -apple-system, Helvetica, sans-serif"; bx.textAlign = "center";
    bx.fillText(label, BCX, 40, 800); bx.textAlign = "start";
  }
}
// The blur in its own window, for a second display: a bare page with one canvas, scaled to fit,
// that this window copies each frame into. Double-click it to go full screen.
let popWin = null, popCtx = null;
function mirrorBlur() {
  if (!popCtx) return;
  if (popWin.closed) { popWin = popCtx = null; $("bpop").textContent = "Show in its own window"; return; }
  if (popCtx.canvas.width !== BC.width) popCtx.canvas.width = BC.width;
  popCtx.drawImage(BC, 0, 0);
}
$("bpop").onclick = () => {
  if (popWin && !popWin.closed) { popWin.focus(); return; }
  popWin = window.open("", "breathstar-blur", "popup,width=900,height=960");
  if (!popWin) { alert("The browser blocked the window: allow pop-ups for this page."); return; }
  const d = popWin.document;
  d.open();
  d.write(`<!doctype html><title>Breath Star blur</title><style>html,body{margin:0;height:100%;background:#0d0f14;overflow:hidden}
canvas{display:block;width:100vw;height:100vh;object-fit:contain}body.idle{cursor:none}</style>
<canvas id="c" width="${BC.width}" height="${BC.height}"></canvas>
<script>
document.addEventListener("dblclick", () => document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen());
let t; document.addEventListener("mousemove", () => { document.body.classList.remove("idle"); clearTimeout(t); t = setTimeout(() => document.body.classList.add("idle"), 2000); });
<\/script>`);
  d.close();
  popCtx = d.getElementById("c").getContext("2d");
  $("bpop").textContent = "Bring its window forward";
  render();
};
$("bgamma").oninput = () => { $("bgv").textContent = "γ " + (+$("bgamma").value).toFixed(2); render(); };
// Exposure depends on magnification only through the dome's drawn height; recompute when it changes.
$("mag").addEventListener("input", () => { for (const k in refCache) delete refCache[k]; });
for (const id of ["bchan", "bw", "bback", "binside", "bsil", "bspine", "bunc", "bwave", "brestload"]) $(id).onchange = render;
// Shape changes move the light, so the exposure is recomputed; the oval's sliders only show with it.
function shapeChanged() {
  for (const k in refCache) delete refCache[k];
  for (const e of document.querySelectorAll(".ovalc")) e.style.display = $("bshape").value !== "body" ? "" : "none";
  for (const e of document.querySelectorAll(".radialc")) e.style.display = $("bshape").value === "radial" ? "" : "none";
  for (const e of document.querySelectorAll(".eggc")) e.style.display = $("bshape").value === "oval" ? "" : "none";
  render();
}
for (const id of ["bshape", "broom", "begg", "baspect", "bcentre"]) $(id).addEventListener("input", shapeChanged);
function glowChanged() {
  $("bglowv").textContent = +$("bglow").value > 0 ? (+$("bglow").value).toFixed(1) + " cm" : "off";
  for (const k in refCache) delete refCache[k];
  render();
}
for (const id of ["bglow", "bgmix"]) $(id).addEventListener("input", glowChanged);
function preset(v) {
  for (const [id, val] of Object.entries(v)) { const e = $(id); if (e.type === "checkbox") e.checked = val; else e.value = val; }
  $("bglowv").textContent = +$("bglow").value > 0 ? (+$("bglow").value).toFixed(1) + " cm" : "off";
  shapeChanged();
}
$("bstar").onclick = () => preset({ bshape: "oval", baspect: 1, begg: 0, bglow: 9, bgmix: 0.6, bsil: false });
$("bmine").onclick = () => preset({ bshape: "oval", broom: 1, baspect: 1.25, begg: 0.1, bglow: 0, bgmix: 0.6, bsil: true });
$("bshape").onchange = shapeChanged;
for (const e of document.querySelectorAll(".ovalc")) e.style.display = $("bshape").value !== "body" ? "" : "none";
  for (const e of document.querySelectorAll(".radialc")) e.style.display = $("bshape").value === "radial" ? "" : "none";
  for (const e of document.querySelectorAll(".eggc")) e.style.display = $("bshape").value === "oval" ? "" : "none";

// Comparison pickers: the postures that have their own surface (lesson steps share theirs), and their cases.
$("cposture").innerHTML = '<option value="none">nothing (one blur)</option>'
  + D.postures.filter(p => !p.group).map(p => `<option value="${p.id}">${p.label}</option>`).join("");
$("cposture").value = "supine";
function fillCompareCases() {
  const p = D.postures.find(p => p.id === $("cposture").value);
  $("ccase").innerHTML = p ? p.cases.map(c => `<option value="${c.id}">${c.label}</option>`).join("") : "";
  $("ccase").disabled = $("cdelta").disabled = !p;
}
fillCompareCases();
$("cposture").onchange = () => { fillCompareCases(); render(); };
for (const id of ["ccase", "cdelta"]) $(id).onchange = render;

fillCases(); scaffold(); render();
requestAnimationFrame(tick);
</script>
</body>
</html>
"""#
