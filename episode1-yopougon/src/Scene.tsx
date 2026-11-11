import React from "react";
import { Defs } from "./art/Defs";
import { Person, Pose } from "./art/Person";
import * as C from "./art/cast";
import { Camion, Casiers, Ciel, DepotFond, FaceOpposee, FAR, Grille, NEAR, PickUp, Poteau, Route, Siege, Trottoir } from "./art/Decor";
import { blink, ease, easeOut, lerp, mouth, noise } from "./lib/anim";
import { L, T } from "./timeline";

export type Cam = { cx: number; cy: number; w: number; shake?: number; rot?: number };

// Format vertical (TikTok) : vue deux fois plus étroite, hauteur 16:9 inversée, bornée au décor
export const verticalView = (cam: Cam) => {
  const w = cam.w * 0.5;
  const h = Math.min((w * 16) / 9, 1440);
  const w2 = (h * 9) / 16;
  const cy = Math.min(Math.max(cam.cy, -190 + h / 2), 1270 - h / 2);
  return { w: w2, h, cx: cam.cx, cy };
};

const walk = (ph: number, amp = 22, arm = 18): Pose => ({
  lL: [Math.sin(ph) * amp, Math.max(0, -Math.sin(ph)) * 28],
  lR: [-Math.sin(ph) * amp, Math.max(0, Math.sin(ph)) * 28],
  aL: [8 - Math.sin(ph) * arm, 10],
  aR: [8 + Math.sin(ph) * arm, 10],
  bob: -Math.abs(Math.cos(ph)) * 5,
});
const run = (ph: number): Pose => ({ ...walk(ph, 38, 45), lean: -10, aL: [10 - Math.sin(ph) * 50, -60], aR: [10 + Math.sin(ph) * 50, -60], bob: -Math.abs(Math.cos(ph)) * 10 });
const gest = (f: number, k: number, on: boolean): Pose =>
  on ? { aL: [30 + 25 * Math.sin(f / 5 + k), 40 + 30 * Math.sin(f / 7)], aR: [50 + 30 * Math.sin(f / 6 + k * 2), 60 + 40 * Math.cos(f / 4)] } : { aL: [10, 5], aR: [14, 8] };

const talkAny = (f: number) => (id: Parameters<typeof mouth>[1], at: number) => mouth(f, id, at);

export const Scene: React.FC<{ frame: number; cam: Cam; focus?: "near" | "far"; hideGonmons?: boolean; vertical?: boolean }> = ({ frame: f, cam, focus, hideGonmons, vertical }) => {
  const m = talkAny(f);

  // ---------- éclairage ----------
  const neon = f % 53 < 2 || (f > 1110 && f < 1200 && f % 23 < 3) || (f > 3000 && f % 31 < 2) ? 0.2 : 0.92 + 0.08 * noise(f / 2, 1);
  const gyro = f >= T.gyro ? 1 : 0;
  const ph = Math.floor(f / 5) % 2;
  const tv = f >= T.tvFlash ? "flash" : "clip";

  // ---------- pick-up ----------
  const pickX = f < T.pickup[0] ? 2600 : lerp(f, T.pickup, [2400, 1080], easeOut);
  const pickBounce = f > T.pickup[1] && f < T.pickup[1] + 20 ? Math.sin((f - T.pickup[1]) / 2.5) * 4 * (1 - (f - T.pickup[1]) / 20) : 0;

  // ---------- grille ----------
  const gateOpen = f < T.gateForce[0] ? 0 : f < 1400 ? lerp(f, [1325, 1345, 1380, 1420], [0, 1, 1, 0.35], ease) : f < T.gatePush[0] ? 0.35 : lerp(f, [2112, 2124], [0.35, 1], easeOut);
  const gateShake = (f >= 1318 && f < 1345 ? Math.sin(f * 2.2) * 6 : 0) + (f >= 2112 && f < 2135 ? Math.sin(f * 2.6) * 10 : 0);
  const crateShake = f >= 1380 && f < 1395 ? Math.sin(f * 3) * 5 : 0;

  // ---------- Yao ----------
  const cutting = (f > 300 && f < 505) || (f > 1700 && f < 1795);
  const wiping = f > 2450 && f < 2560;
  const yaoPose: Pose = wiping
    ? { sit: true, armsFront: true, aL: [5, -38], aR: [5, -38 + 10 * Math.sin(f / 3)] }
    : { sit: true, armsFront: true, aL: [24, -60], aR: [20, cutting ? -70 + 14 * Math.sin(f / 2.6) : -70], head: f > 2900 ? -3 : 0 };
  const yaoTalk = m("03-yao", L.yao1) + m("09-yao", L.yao2);
  const yaoGaze = f > 515 && f < 960 ? 0.75 : f > 2100 ? 0.7 : f > 1395 && f < 1700 ? 0.6 : cutting ? -0.1 : 0.2;
  const yaoExpr = f > 2100 ? "focus" : f > 1395 && f < 1700 ? "worried" : f > 515 && f < 610 ? "smile" : "calm";

  // ---------- Bravo ----------
  const bw = T.bravoWalk;
  const bX = f < bw[0] ? 560 : lerp(f, bw, [560, 1135], ease);
  const bY = f < bw[0] ? NEAR : lerp(f, bw, [NEAR, FAR], ease);
  const bS = f < bw[0] ? 1 : lerp(f, bw, [1, 0.74], ease);
  const bWalking = f >= bw[0] && f < bw[1];
  const lighting = f > 395 && f < 440;
  const puff = f > 440 && (f - 440) % 150 < 40;
  const bravoPose: Pose = bWalking
    ? { ...walk(f / 3.2), aR: [20, -110] }
    : f >= bw[1]
      ? { aL: [30, -100], aR: puff ? [10, -150] : [25, -80], lean: -5, lL: [6, 0], lR: [-4, 0] }
      : lighting
        ? { aL: [10, -150], aR: [10, -150], armsFront: true }
        : { aL: [34, -95], aR: puff ? [10, -150] : [25, -80] };
  const bravoTalk = m("04-bravo", L.bravo);
  const bravoProps = { look: C.BRAVO, x: bX, y: bY, scale: bS, flip: f < 1950 ? f < bw[0] || f >= bw[1] : true, pose: bravoPose, talk: bravoTalk, blink: blink(f, 2), gaze: f >= bw[0] && f < bw[1] ? -0.4 : 0.6, expr: (f > 2900 ? "focus" : bravoTalk > 0 || (f > L.bravo && f < 930) ? "smile" : "neutral") as "focus" | "smile" | "neutral", holdR: (f > 425 ? "cigarette" : "none") as "cigarette" | "none", smoke: f > 430 ? f : 0 };
  // pendant la traversée il se retourne vers Yao (flip false = regarde à droite)
  if (bWalking) bravoProps.flip = false;

  // ---------- kpôclés & client ----------
  const ex = T.kpocleExit;
  const exiting = f >= ex[0];
  const kOff = exiting ? lerp(f, ex, [0, 620], ease) : 0;
  const k1Talk = m("00-kpocle1", L.kp1);
  const k2Talk = m("02-kpocle2", L.kp2);
  const cTalk = m("01-client", L.client);
  const kPose = (k: number, on: boolean): Pose => (exiting ? walk(f / 2.8 + k) : gest(f, k, on));

  // ---------- Jo ----------
  const joPose: Pose = { sit: true, armsFront: true, aR: [-10, -150], aL: [-5, -140], head: Math.sin(f / 7) * 5 };

  // ---------- microbes ----------
  const mi = T.microbes;
  const microbesOn = f >= mi[0] - 5 && f < mi[1] + 5;
  const miX = lerp(f, mi, [2150, -300]);
  const miTalk = m("05-microbe", L.microbe);

  // ---------- blessé ----------
  let blX = 1600;
  let blY = NEAR;
  let blPose: Pose = {};
  let blFlip = true;
  let blSit = false;
  let blVisible = f >= T.blesseIn[0];
  if (f < T.blesseIn[1]) {
    blX = lerp(f, T.blesseIn, [1500, 800]);
    const p = f / 4;
    blPose = { ...walk(p, 20, 10), lean: -6 + Math.sin(p) * 6, aR: [-20, -100], bob: -Math.abs(Math.cos(p)) * 10 + (Math.sin(p) > 0 ? 6 : 0) };
  } else if (f < T.gateForce[1]) {
    blX = 800;
    blPose = { aL: [80, -10 + Math.sin(f) * 8], aR: [70, -20], lean: -12, lL: [18, 0], lR: [-10, 0] };
  } else if (f < T.blesseHide[1]) {
    blX = lerp(f, T.blesseHide, [790, 560]);
    blPose = f < 1380 ? { ...walk(f / 3.5, 20, 10), aR: [-20, -100], lean: -8 } : { sit: true, lean: lerp(f, [1380, 1392], [-30, 0]) };
    blSit = f >= 1380;
  } else {
    blX = 560;
    blSit = true;
    const hide = f < 1660 ? 0 : f < 3020 ? lerp(f, [1660, 1680], [0, 92], ease) : lerp(f, [3020, 3040], [92, 64], ease);
    blY = NEAR + hide + Math.sin(f / 4) * 1.5;
    blPose = { sit: true, armsFront: true, aL: [-10, -80], aR: [-10, -60], head: -4 };
  }
  if (blSit) blPose = { ...blPose, sit: true };
  const blTalk = m("06-blesse", L.blesse);
  if (f >= T.gateForce[0]) blFlip = true;

  // ---------- faux gonmons ----------
  const go = T.gonmonsOut;
  const gOn = f >= go[0];
  const g1X = f < go[1] ? lerp(f, go, [930, 800]) : f < 2200 ? lerp(f, [2135, 2195], [800, 560], ease) : f < T.g1Step[0] ? 560 : lerp(f, T.g1Step, [560, 505], easeOut);
  const g2X = f < go[1] ? lerp(f, go, [1040, 890]) : lerp(f, [2140, 2200], [890, 655], ease);
  const g1Walking = (f >= go[0] && f < go[1]) || (f >= 2135 && f < 2195) || (f >= T.g1Step[0] && f < T.g1Step[1]);
  const g2Walking = (f >= go[0] && f < go[1]) || (f >= 2140 && f < 2200);
  const g1Talk = m("08-gonmon1", L.g1);
  const g2Talk = m("10-gonmon2", L.g2);
  const pushing = f >= T.gatePush[0] && f < T.gatePush[1];
  const g1Pose: Pose = g1Walking ? walk(f / 3) : pushing ? { aR: [80, -10], aL: [70, 0], lean: -10 } : g1Talk > 0.02 || (f > L.g1 && f < 2450) ? { aR: [78, -25 + 8 * Math.sin(f / 6)], aL: [20, -100], lean: -4 } : f > 2900 ? { aR: [60, -20], aL: [20, -100], lean: -8 } : { aL: [20, -100], aR: [22, -100] };
  const g2Pose: Pose = g2Walking ? walk(f / 3.2) : g2Talk > 0.02 || (f > L.g2 && f < 2900) ? { aR: [20, -35], aL: [50, 40 + 20 * Math.sin(f / 7)], lean: -3 } : { aR: [20, -35], aL: [14, -90] };

  // ---------- caméra ----------
  const sh = cam.shake ?? 0;
  const vv = vertical ? verticalView(cam) : { w: cam.w, h: (cam.w * 9) / 16, cx: cam.cx, cy: cam.cy };
  const w = vv.w;
  const h = vv.h;
  const vx = vv.cx - w / 2 + noise(f / 9, 11) * sh * cam.w * 0.01;
  const vy = vv.cy - h / 2 + noise(f / 8, 23) * sh * cam.w * 0.01;

  const blurFar = focus === "near" ? "url(#flou4)" : undefined;
  const blurNear = focus === "far" ? "url(#flou4)" : undefined;

  return (
    <svg viewBox={`${vx} ${vy} ${w} ${h}`} width="100%" height="100%" style={{ position: "absolute", inset: 0, rotate: `${(cam.rot ?? 0) + noise(f / 15, 5) * sh * 0.15}deg`, scale: cam.rot ? 1.08 : 1 }} preserveAspectRatio="xMidYMid slice">
      <Defs />
      {/* ===== PLAN LOINTAIN ===== */}
      <g filter={blurFar}>
        <Ciel frame={f} />
        <FaceOpposee frame={f} />
        <Poteau />
        <Camion frame={f} />
        <Person look={C.JO} x={900} y={470} scale={0.74} pose={joPose} holdR="phone" blink={blink(f, 9)} gaze={0.2} expr="smile" />
        <circle cx={905} cy={300} r={60} fill="url(#lumTel)" opacity={0.35} style={{ mixBlendMode: "screen" }} />
        {kOff < 600 && (
          <>
            <Person look={C.KPOCLE1} x={1440 + kOff} y={FAR} scale={0.74} flip={exiting} pose={kPose(0, k1Talk > 0.03)} talk={k1Talk} blink={blink(f, 4)} gaze={exiting ? 0.3 : 0.6} expr={exiting ? "worried" : "angry"} />
            <Person look={C.CLIENT} x={1560 + kOff * 1.05} y={FAR} scale={0.74} flip={!exiting} pose={exiting ? walk(f / 3) : { ...gest(f, 3, cTalk > 0.03), lean: Math.sin(f / 18) * 7 }} talk={cTalk} blink={f % 40 < 14} gaze={0.4} expr="neutral" />
            <Person look={C.KPOCLE2} x={1680 + kOff * 0.95} y={FAR} scale={0.74} flip={!exiting} pose={kPose(1, k2Talk > 0.03)} talk={k2Talk} blink={blink(f, 5)} gaze={exiting ? -0.3 : 0.6} expr={exiting ? "worried" : "angry"} />
          </>
        )}
        {f >= bw[1] && <Person {...bravoProps} />}
      </g>
      {/* ===== ROUTE ===== */}
      <g filter={blurFar}>
        <Route frame={f} gyro={gyro} flash={ph} />
        {bWalking && <Person {...bravoProps} />}
        {microbesOn &&
          C.MICROBES.map((look, i) => (
            <Person key={i} look={look} x={miX + i * 110 + Math.sin(i * 3) * 20} y={925 + i * 8} scale={0.82} flip pose={run(f / 2.2 + i * 1.7)} talk={i === 0 ? miTalk : 0} gaze={i === 0 ? 0.9 : 0.3} expr={i === 0 ? "panic" : "worried"} blink={false} />
          ))}
        <PickUp x={pickX} frame={f} gyro={gyro} bounce={pickBounce} />
      </g>
      {/* ===== DÉPÔT (PREMIER PLAN) ===== */}
      <g filter={blurNear}>
        <Trottoir />
        <DepotFond frame={f} neon={neon} tv={tv} />
        {blVisible && f >= T.blesseHide[0] && (
          <Person look={C.BLESSE} x={blX} y={blY} flip={blFlip} pose={blPose} talk={blTalk} blink={blink(f, 7)} gaze={f > 1395 ? 0.9 : -0.6} expr="panic" holdL={f > 1345 ? "bag" : "none"} />
        )}
        <Casiers x={470} y={NEAR} rows={5} cols={3} shake={crateShake} />
        <Siege x={330} />
        <Person look={C.YAO} x={330} y={NEAR} pose={yaoPose} talk={yaoTalk} blink={blink(f, 1)} gaze={yaoGaze} expr={yaoExpr} holdL={wiping ? "none" : "bread"} holdR={wiping ? "none" : "knife"} />
        {f < bw[0] && <Person {...bravoProps} />}
        {blVisible && f < T.blesseHide[0] && <Person look={C.BLESSE} x={blX} y={blY} flip={blFlip} pose={blPose} blink={blink(f, 7)} gaze={Math.sin(f / 20) > 0.6 ? -0.9 : 0.8} expr="panic" holdL="bag" />}
        {gOn && !hideGonmons && (
          <>
            <Person look={C.GONMON2} x={g2X} y={NEAR} flip pose={g2Pose} talk={g2Talk} blink={blink(f, 12)} gaze={0.6} expr="angry" />
            <Person look={C.GONMON1} x={g1X} y={NEAR} scale={1.04} flip pose={g1Pose} talk={g1Talk} blink={blink(f, 13)} gaze={0.7} expr="angry" />
          </>
        )}
        <Grille open={gateOpen} shake={gateShake} />
      </g>
      {/* ===== LUMIÈRES ===== */}
      <rect x={-500} y={-300} width={2920} height={1700} fill="#1b2456" opacity={0.32} style={{ mixBlendMode: "multiply" }} />
      <ellipse cx={340} cy={560} rx={560} ry={470} fill="url(#lumJaune)" opacity={0.5 * neon} style={{ mixBlendMode: "screen" }} />
      <ellipse cx={1640} cy={600} rx={520} ry={300} fill="url(#lumRouge)" opacity={0.35} style={{ mixBlendMode: "screen" }} />
      {gyro > 0 && (
        <>
          <ellipse cx={ph ? pickX - 400 : pickX + 300} cy={700} rx={900} ry={600} fill={ph ? "url(#lumRouge)" : "url(#lumBleue)"} opacity={0.45} style={{ mixBlendMode: "screen" }} />
          <rect x={-500} y={-300} width={2920} height={1700} fill={ph ? "#ff1030" : "#1040ff"} opacity={0.08} style={{ mixBlendMode: "screen" }} />
        </>
      )}
    </svg>
  );
};
