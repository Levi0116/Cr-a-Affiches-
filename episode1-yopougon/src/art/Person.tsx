import React from "react";

// Personnage 2D style webtoon (cell-shading, contours épais).
// Repère : origine aux pieds, y négatif vers le haut. Adulte ≈ 390 unités.

export type Top =
  | { kind: "tshirt"; color: string; text?: string }
  | { kind: "floral" }
  | { kind: "jersey"; torn?: boolean; blood?: boolean }
  | { kind: "camo" }
  | { kind: "vest" }
  | { kind: "dress"; color: string }
  | { kind: "foot"; color: string; color2: string; torn?: boolean };

export type Look = {
  skin: string;
  skinShade: string;
  hair: "shaved" | "short" | "wig" | "grey";
  wig?: string;
  moustache?: boolean;
  build?: number;
  female?: boolean;
  top: Top;
  bottom: "pants" | "shorts" | "jeanshort" | "camo" | "none" | "black";
  bottomColor?: string;
  shoes: "sandal" | "jordan" | "heels" | "barefoot" | "boot" | "samara" | "samaraBroken";
  apron?: boolean;
  towel?: boolean;
  watch?: "gold" | "silver";
  headphones?: boolean;
  holster?: boolean;
  sweat?: boolean;
  wound?: boolean;
  lipstick?: string;
  earrings?: boolean;
  belly?: number;
};

export type Pose = {
  lean?: number;
  head?: number;
  aL?: [number, number];
  aR?: [number, number];
  lL?: [number, number];
  lR?: [number, number];
  bob?: number;
  sit?: boolean;
  armsFront?: boolean;
};

export type Expr = "neutral" | "angry" | "panic" | "smile" | "calm" | "worried" | "focus";

export type PersonProps = {
  look: Look;
  pose?: Pose;
  x?: number;
  y?: number;
  scale?: number;
  flip?: boolean;
  talk?: number;
  blink?: boolean;
  gaze?: number; // -1..1 orientation du regard / visage
  expr?: Expr;
  holdR?: "cigarette" | "knife" | "bread" | "phone" | "none";
  holdL?: "cigarette" | "knife" | "bread" | "phone" | "none" | "bag";
  smoke?: number; // frame pour la fumée
  dim?: number; // assombrissement 0..1
};

const OUT = "#0b0a10";
const SW = 3.2;

const rad = (d: number) => (d * Math.PI) / 180;

// calcule épaule/coude/main pour un membre. side = +1 droite écran, -1 gauche
const limb = (jx: number, jy: number, side: number, a: number, b: number, L1: number, L2: number) => {
  const p1 = [jx + side * Math.sin(rad(a)) * L1, jy + Math.cos(rad(a)) * L1];
  const p2 = [p1[0] + side * Math.sin(rad(a + b)) * L2, p1[1] + Math.cos(rad(a + b)) * L2];
  return { p0: [jx, jy], p1, p2, end: a + b };
};

const Seg: React.FC<{ pts: number[][]; w: number; color: string; outline?: boolean }> = ({ pts, w, color, outline = true }) => {
  const d = `M${pts.map((p) => p.join(" ")).join(" L")}`;
  return (
    <>
      {outline && <path d={d} stroke={OUT} strokeWidth={w + SW * 2} fill="none" strokeLinecap="round" strokeLinejoin="round" />}
      <path d={d} stroke={color} strokeWidth={w} fill="none" strokeLinecap="round" strokeLinejoin="round" />
    </>
  );
};

const topFill = (t: Top) => {
  switch (t.kind) {
    case "tshirt":
      return t.color;
    case "floral":
      return "url(#floral)";
    case "jersey":
      return "#1f8a4c";
    case "camo":
      return "url(#camo)";
    case "vest":
      return "#1a1c20";
    case "dress":
      return t.color;
    case "foot":
      return t.color;
  }
};

const sleeveColor = (t: Top) => {
  switch (t.kind) {
    case "floral":
      return "url(#floral)";
    case "camo":
      return "url(#camo)";
    case "vest":
      return "#2a2d33";
    case "jersey":
      return "#1f8a4c";
    case "tshirt":
      return t.color;
    case "foot":
      return t.color;
    case "dress":
      return null;
  }
};

export const Person: React.FC<PersonProps> = ({
  look,
  pose = {},
  x = 0,
  y = 0,
  scale = 1,
  flip = false,
  talk = 0,
  blink = false,
  gaze = 0,
  expr = "neutral",
  holdR = "none",
  holdL = "none",
  smoke = 0,
  dim = 0,
}) => {
  const b = look.build ?? 1;
  const f = look.female;
  const sw = (f ? 31 : 41) * b;
  const ww = (f ? 21 : 31) * b + (look.belly ?? 0);
  const hw = (f ? 34 : 31) * b;
  const sit = pose.sit;
  const bob = pose.bob ?? 0;
  const hipY = (sit ? -108 : -170) + bob;
  const lift = hipY + 170; // décalage vertical du buste

  const sY = -298 + lift;
  const legW = 22 * b;
  const armW = 17 * b;

  // jambes
  const lL = pose.lL ?? [4, 0];
  const lR = pose.lR ?? [4, 0];
  const legL = sit ? limb(-hw * 0.55, hipY, -1, 52 + lL[0], -52 + lL[1], 56, 76) : limb(-hw * 0.55, hipY, -1, lL[0], lL[1], 86, 80);
  const legR = sit ? limb(hw * 0.55, hipY, 1, 52 + lR[0], -52 + lR[1], 56, 76) : limb(hw * 0.55, hipY, 1, lR[0], lR[1], 86, 80);

  // bras
  const aL = pose.aL ?? [8, 6];
  const aR = pose.aR ?? [8, 6];
  const armL = limb(-sw + 6, sY + 8, -1, aL[0], aL[1], 70, 64);
  const armR = limb(sw - 6, sY + 8, 1, aR[0], aR[1], 70, 64);

  const pantsColor =
    look.bottom === "camo" ? "url(#camo)" : look.bottom === "jeanshort" ? "url(#denim)" : look.bottom === "black" ? "#16171b" : look.bottomColor ?? "#2b2f3a";

  const Shoe: React.FC<{ p: number[]; side: number }> = ({ p, side }) => {
    const [px, py] = p;
    const sx = px + side * 7;
    if (look.shoes === "jordan")
      return (
        <g>
          <path d={`M${sx - 18} ${py + 6} q0 -22 10 -24 h14 q8 6 12 18 q4 6 0 10 h-36z`} fill="#f7f7f2" stroke={OUT} strokeWidth={SW} />
          <path d={`M${sx - 18} ${py + 6} h36`} stroke="#c9c9c2" strokeWidth={4} />
          <path d={`M${sx - 10} ${py - 6} q10 4 22 -2`} stroke="#d8d8d0" strokeWidth={2} fill="none" />
          <circle cx={sx - 4} cy={py - 12} r={2} fill="#ffffff" />
        </g>
      );
    if (look.shoes === "boot")
      return <path d={`M${sx - 16} ${py + 6} v-20 h20 q14 8 14 20z`} fill="#141416" stroke={OUT} strokeWidth={SW} />;
    if (look.shoes === "heels")
      return (
        <g>
          <path d={`M${sx - 10} ${py - 6} q14 -4 22 6 l-2 6 h-16z`} fill={look.lipstick ?? "#c2185b"} stroke={OUT} strokeWidth={2.5} />
          <path d={`M${sx - 9} ${py} v8`} stroke={OUT} strokeWidth={3} />
        </g>
      );
    if (look.shoes === "barefoot")
      return <ellipse cx={sx} cy={py + 2} rx={13} ry={6} fill={look.skin} stroke={OUT} strokeWidth={SW} />;
    // tapettes / samaras
    const broken = look.shoes === "samaraBroken";
    return (
      <g>
        <ellipse cx={sx} cy={py + 4} rx={17} ry={5.5} fill={broken ? "#6b4b2b" : "#2e6bd1"} stroke={OUT} strokeWidth={SW} />
        <ellipse cx={sx} cy={py} rx={12} ry={5.5} fill={look.skin} stroke={OUT} strokeWidth={2.4} />
        {broken ? (
          <path d={`M${sx - 8} ${py - 2} l6 -5 M${sx + 6} ${py - 3} l4 5`} stroke="#3a2a18" strokeWidth={3} />
        ) : (
          <path d={`M${sx - 8} ${py - 2} q8 -8 16 0`} stroke="#2e6bd1" strokeWidth={3} fill="none" />
        )}
      </g>
    );
  };

  const legPath = (l: ReturnType<typeof limb>) => [l.p0, l.p1, l.p2];
  const thigh = (l: ReturnType<typeof limb>, k: number) => [l.p0, [l.p0[0] + (l.p1[0] - l.p0[0]) * k, l.p0[1] + (l.p1[1] - l.p0[1]) * k]];

  const Leg: React.FC<{ l: ReturnType<typeof limb>; side: number }> = ({ l, side }) => (
    <g>
      <Seg pts={legPath(l)} w={legW * 0.82} color={look.skin} />
      {(look.bottom === "pants" || look.bottom === "camo" || look.bottom === "black") && <Seg pts={legPath(l)} w={legW * 1.08} color={pantsColor} />}
      {(look.bottom === "shorts" || look.bottom === "jeanshort") && <Seg pts={thigh(l, 1.05)} w={legW * 1.2} color={pantsColor} />}
      <Shoe p={l.p2} side={side} />
    </g>
  );

  const Hand: React.FC<{ p: number[]; hold: string; side: number }> = ({ p, hold, side }) => (
    <g>
      {hold === "knife" && (
        <g transform={`translate(${p[0]} ${p[1]}) rotate(${side * -30})`}>
          <rect x={-3} y={-34} width={6} height={30} rx={2} fill="#d5dbe0" stroke={OUT} strokeWidth={2} />
          <rect x={-4} y={-6} width={8} height={14} rx={2} fill="#4a2c1a" stroke={OUT} strokeWidth={2} />
        </g>
      )}
      {hold === "phone" && <rect x={p[0] - 9} y={p[1] - 22} width={18} height={30} rx={3} fill="#9fd4ff" stroke={OUT} strokeWidth={2.5} />}
      {hold === "bag" && (
        <g>
          <path d={`M${p[0] - 4} ${p[1]} v18`} stroke="#5b4a2a" strokeWidth={3} />
          <rect x={p[0] - 16} y={p[1] + 8} width={22} height={14} fill="#efe8d4" stroke={OUT} strokeWidth={1.2} transform={`rotate(-12 ${p[0]} ${p[1] + 14})`} />
          <rect x={p[0] - 24} y={p[1] + 16} width={44} height={36} rx={6} fill="#8a7650" stroke={OUT} strokeWidth={SW} />
          <circle cx={p[0] + 2} cy={p[1] + 13} r={3.2} fill="none" stroke="#c62828" strokeWidth={1.4} />
        </g>
      )}
      <circle cx={p[0]} cy={p[1]} r={9.5 * b} fill={look.skin} stroke={OUT} strokeWidth={SW} />
      {hold === "bread" && (
        <g transform={`translate(${p[0] + side * 4} ${p[1] - 8}) rotate(${side * 10})`}>
          <path d="M-30 0 q30 -16 60 0 q-30 14 -60 0z" fill="#d89a4c" stroke={OUT} strokeWidth={2.5} />
          <path d="M-14 -4 l4 6 M0 -6 l4 6 M14 -4 l4 6" stroke="#9a5f24" strokeWidth={2} />
          <path d="M-26 2 q26 10 52 0" stroke="#7b3b22" strokeWidth={4} fill="none" />
        </g>
      )}
      {hold === "cigarette" && (
        <g>
          <path d={`M${p[0]} ${p[1] - 4} l${side * 18} -6`} stroke="#f4efe6" strokeWidth={4} strokeLinecap="round" />
          <circle cx={p[0] + side * 19} cy={p[1] - 10} r={2.6} fill="#ff6a1a" />
        </g>
      )}
    </g>
  );

  const Arm: React.FC<{ a: ReturnType<typeof limb>; hold: string; side: number }> = ({ a, hold, side }) => {
    const sc = sleeveColor(look.top);
    const longSleeve = look.top.kind === "camo";
    return (
      <g>
        <Seg pts={[a.p0, a.p1, a.p2]} w={armW} color={look.skin} />
        {sc && <Seg pts={longSleeve ? [a.p0, a.p1, [a.p1[0] + (a.p2[0] - a.p1[0]) * 0.8, a.p1[1] + (a.p2[1] - a.p1[1]) * 0.8]] : [a.p0, [a.p0[0] + (a.p1[0] - a.p0[0]) * 0.55, a.p0[1] + (a.p1[1] - a.p0[1]) * 0.55]]} w={armW * 1.5} color={sc} />}
        {look.watch && side === -1 && (
          <circle cx={a.p1[0] + (a.p2[0] - a.p1[0]) * 0.82} cy={a.p1[1] + (a.p2[1] - a.p1[1]) * 0.82} r={7} fill={look.watch === "gold" ? "#f2c230" : "#c9d1d8"} stroke={OUT} strokeWidth={2.4} />
        )}
        <Hand p={a.p2} hold={hold} side={side} />
      </g>
    );
  };

  // buste
  const torso = `M${-sw} ${sY} Q${-sw - 5} ${sY + 48} ${-ww} ${hipY - 35} L${-hw} ${hipY + 2} L${hw} ${hipY + 2} L${ww} ${hipY - 35} Q${sw + 5} ${sY + 48} ${sw} ${sY} Q0 ${sY - 9} ${-sw} ${sY}Z`;

  const t = look.top;
  const TopDetail = () => {
    if (t.kind === "floral")
      return (
        <g>
          <path d={`M-12 ${sY - 2} L0 ${sY + 70} L12 ${sY - 2} Z`} fill="#f2f2ee" stroke={OUT} strokeWidth={2} />
          <path d={`M-12 ${sY - 2} L-4 ${hipY} M12 ${sY - 2} L4 ${hipY}`} stroke={OUT} strokeWidth={2} />
          <path d={`M-4 ${sY + 70} L-4 ${hipY} L4 ${hipY} L4 ${sY + 70}z`} fill="#f2f2ee" />
        </g>
      );
    if (t.kind === "jersey")
      return (
        <g>
          <path d={`M${-sw + 2} ${sY + 40} L${sw - 2} ${sY + 14} L${sw} ${sY + 40} L${-sw + 4} ${sY + 66} Z`} fill="#f47c20" />
          <path d={`M-12 ${sY - 3} q12 14 24 0`} stroke="#f2f2ee" strokeWidth={5} fill="none" />
          <text x={-8} y={sY + 102} fontSize={22} fontWeight={900} fill="#f2f2ee" fontFamily="Arial Black, Arial">10</text>
          {t.torn && (
            <path d={`M${sw - 14} ${sY + 70} l-10 12 l8 4 l-12 16 l14 -6 l-4 14 l10 -26z`} fill={look.skin} stroke={OUT} strokeWidth={2} />
          )}
          {t.blood && (
            <g fill="#6d0a0a" opacity={0.9}>
              <path d={`M${-ww + 4} ${sY + 80} q10 -10 20 2 q6 16 -6 24 q-4 18 -10 0 q-10 -6 -4 -26z`} />
              <circle cx={sw - 20} cy={sY + 112} r={5} />
              <circle cx={-6} cy={sY + 128} r={3.5} />
            </g>
          )}
        </g>
      );
    if (t.kind === "vest")
      return (
        <g>
          <path d={`M-14 ${sY - 2} q14 12 28 0`} fill="#2a2d33" stroke={OUT} strokeWidth={2} />
          {[-1, 1].map((k) => (
            <g key={k}>
              <rect x={k > 0 ? 4 : -28} y={sY + 38} width={24} height={20} rx={3} fill="#24262b" stroke={OUT} strokeWidth={2} />
              <rect x={k > 0 ? 4 : -28} y={sY + 64} width={24} height={20} rx={3} fill="#24262b" stroke={OUT} strokeWidth={2} />
            </g>
          ))}
          <path d={`M-20 ${sY + 6} v${hipY - sY - 20} M20 ${sY + 6} v${hipY - sY - 20}`} stroke="#0e0f12" strokeWidth={3} />
        </g>
      );
    if (t.kind === "camo")
      return <path d={`M-12 ${sY - 2} L0 ${sY + 22} L12 ${sY - 2}`} fill="#262b1e" stroke={OUT} strokeWidth={2} />;
    if (t.kind === "tshirt")
      return (
        <g>
          <path d={`M-13 ${sY - 3} q13 12 26 0`} stroke="#1b1b1f" strokeWidth={4} fill="none" />
          {t.text && (
            <text x={0} y={sY + 32} textAnchor="middle" fontSize={15} fontWeight={800} fill="#bdbdb4" opacity={0.75} fontFamily="Arial Black, Arial" letterSpacing={1}>
              {t.text}
            </text>
          )}
        </g>
      );
    if (t.kind === "foot")
      return (
        <g>
          <rect x={-sw + 4} y={sY + 30} width={(sw - 4) * 2} height={14} fill={t.color2} />
          {t.torn && <path d={`M${-ww + 6} ${hipY - 30} l8 -14 l6 10 l6 -16 l6 22z`} fill={look.skin} stroke={OUT} strokeWidth={2} />}
        </g>
      );
    return null;
  };

  return (
    <g transform={`translate(${x} ${y}) scale(${flip ? -scale : scale} ${scale})`}>
      {/* ombre au sol */}
      <ellipse cx={0} cy={2} rx={sit ? 70 : 55} ry={9} fill="#000" opacity={0.45} />
      <g transform={`rotate(${pose.lean ?? 0} 0 ${hipY})`}>
        {!sit && (
          <>
            <Leg l={legL} side={-1} />
            <Leg l={legR} side={1} />
          </>
        )}
        {sit && (
          <>
            <Leg l={legL} side={-1} />
            <Leg l={legR} side={1} />
          </>
        )}
        {!pose.armsFront && (
          <>
            <Arm a={armL} hold={holdL} side={-1} />
            <Arm a={armR} hold={holdR} side={1} />
          </>
        )}
        {/* bassin */}
        {look.bottom !== "none" && t.kind !== "dress" && (
          <path d={`M${-hw - 2} ${hipY - 14} h${hw * 2 + 4} l2 22 h${-hw * 2 - 8}z`} fill={pantsColor} stroke={OUT} strokeWidth={SW} />
        )}
        {/* cou */}
        <rect x={-10 * b} y={sY - 26} width={20 * b} height={32} fill={look.skinShade} stroke={OUT} strokeWidth={SW} />
        {/* robe */}
        {t.kind === "dress" && (
          <path d={`M${-hw} ${hipY - 30} Q${-hw - 8} ${hipY + 20} ${-hw + 2} ${hipY + 66} L${hw - 2} ${hipY + 66} Q${hw + 8} ${hipY + 20} ${hw} ${hipY - 30}Z`} fill={t.color} stroke={OUT} strokeWidth={SW} />
        )}
        <path d={torso} fill={topFill(t)} stroke={OUT} strokeWidth={SW} strokeLinejoin="round" />
        {t.kind === "dress" && <path d={`M${-sw + 6} ${sY} q${sw - 6} 26 ${(sw - 6) * 2} 0`} fill={look.skin} stroke={OUT} strokeWidth={2.2} />}
        {/* ombrage cell */}
        <path d={`M${sw - 2} ${sY + 4} Q${sw + 4} ${sY + 48} ${ww} ${hipY - 35} L${hw} ${hipY} L${hw - 16} ${hipY} Q${ww - 6} ${sY + 60} ${sw - 16} ${sY + 4}Z`} fill="#000" opacity={0.25} />
        <TopDetail />
        {look.apron && (
          <g>
            <path d={`M-8 ${sY - 4} L-22 ${sY + 40} M8 ${sY - 4} L22 ${sY + 40}`} stroke="#8a7a5c" strokeWidth={3.5} />
            <path d={`M-26 ${sY + 40} h52 l4 ${hipY - sY + 30} h-60z`} fill="#a8946a" stroke={OUT} strokeWidth={SW} />
            <path d={`M-14 ${hipY - 6} h28 v16 h-28z`} fill="#94815a" stroke={OUT} strokeWidth={2} />
            <path d={`M-20 ${sY + 80} q10 6 18 -2 M6 ${hipY + 10} q8 4 14 -2`} stroke="#6e6044" strokeWidth={2} fill="none" />
          </g>
        )}
        {look.towel && (
          <path d={`M${sw - 30} ${sY - 6} q24 -4 32 8 l-4 62 l-14 2 l-2 -50 q-6 -6 -14 -6z`} fill="#e6e1d3" stroke={OUT} strokeWidth={2.6} />
        )}
        {look.holster && (
          <g>
            <rect x={-hw - 2} y={hipY - 18} width={hw * 2 + 4} height={9} fill="#2a1d12" stroke={OUT} strokeWidth={2} />
            <path d={`M${hw - 4} ${hipY - 12} h22 l-2 44 h-18z`} fill="#4a2e18" stroke={OUT} strokeWidth={SW} />
            <path d={`M${hw - 2} ${hipY - 10} l18 -10`} stroke="#4a2e18" strokeWidth={5} />
            <ellipse cx={hw + 7} cy={hipY - 10} rx={8} ry={3} fill="#0b0805" />
          </g>
        )}
        {pose.armsFront && (
          <>
            <Arm a={armL} hold={holdL} side={-1} />
            <Arm a={armR} hold={holdR} side={1} />
          </>
        )}
        <Head look={look} y={sY - 20} tilt={pose.head ?? 0} talk={talk} blink={blink} gaze={gaze} expr={expr} />
        {holdR === "cigarette" && smoke > 0 && <Smoke x={armR.p2[0] + 19} y={armR.p2[1] - 12} frame={smoke} />}
      </g>
      {dim > 0 && <path d={torso} fill="#000" opacity={0} />}
    </g>
  );
};

export const Smoke: React.FC<{ x: number; y: number; frame: number }> = ({ x, y, frame }) => (
  <g opacity={0.5}>
    {[0, 1, 2, 3].map((i) => {
      const p = ((frame + i * 18) % 72) / 72;
      return <circle key={i} cx={x + Math.sin(p * 6 + i) * 8} cy={y - p * 70} r={3 + p * 10} fill="#c8c8d0" opacity={1 - p} />;
    })}
  </g>
);

export const Head: React.FC<{ look: Look; y: number; tilt: number; talk: number; blink: boolean; gaze: number; expr: Expr }> = ({ look, y, tilt, talk, blink, gaze, expr }) => {
  const lx = gaze * 7;
  const cy = -36;
  const f = look.female;
  const eyeRy = expr === "panic" ? 6.4 : expr === "focus" || expr === "angry" ? 3.8 : 5;
  const browIn = expr === "angry" ? 5 : expr === "panic" || expr === "worried" ? -5 : expr === "focus" ? 2 : 0;
  const mo = Math.min(1, talk);
  return (
    <g transform={`translate(0 ${y}) rotate(${tilt} 0 0) scale(1.14)`}>
      {/* perruque (arrière) */}
      {look.hair === "wig" && <path d={`M-40 ${cy - 10} Q-44 ${cy - 52} 0 ${cy - 52} Q44 ${cy - 52} 40 ${cy - 10} L44 ${cy + 40} Q30 ${cy + 46} 24 ${cy + 30} L-24 ${cy + 30} Q-30 ${cy + 46} -44 ${cy + 40}Z`} fill={look.wig} stroke={OUT} strokeWidth={SW} />}
      {/* oreilles */}
      <ellipse cx={-31} cy={cy + 2} rx={7} ry={10} fill={look.skinShade} stroke={OUT} strokeWidth={SW} />
      <ellipse cx={31} cy={cy + 2} rx={7} ry={10} fill={look.skinShade} stroke={OUT} strokeWidth={SW} />
      {look.earrings && (
        <>
          <circle cx={-32} cy={cy + 16} r={5} fill="none" stroke="#f2c230" strokeWidth={2.4} />
          <circle cx={32} cy={cy + 16} r={5} fill="none" stroke="#f2c230" strokeWidth={2.4} />
        </>
      )}
      {/* visage */}
      <path d={`M-30 ${cy - 8} Q-31 ${cy - 42} 0 ${cy - 42} Q31 ${cy - 42} 30 ${cy - 8} Q30 ${cy + 24} 14 ${cy + 36} Q0 ${cy + 42} -14 ${cy + 36} Q-30 ${cy + 24} -30 ${cy - 8}Z`} fill={look.skin} stroke={OUT} strokeWidth={SW} />
      {/* ombre cell du visage */}
      <path d={`M${12 + lx} ${cy - 40} Q31 ${cy - 40} 30 ${cy - 8} Q30 ${cy + 24} 14 ${cy + 36} Q8 ${cy + 39} 4 ${cy + 40} Q22 ${cy + 14} ${12 + lx} ${cy - 40}Z`} fill={look.skinShade} opacity={0.85} />
      {/* cheveux */}
      {(look.hair === "shaved" || look.hair === "short" || look.hair === "grey") && (
        <path d={`M-30 ${cy - 10} Q-32 ${cy - 44} 0 ${cy - 45} Q32 ${cy - 44} 30 ${cy - 10} Q28 ${cy - 28} 20 ${cy - 30} Q0 ${cy - 34} -20 ${cy - 30} Q-28 ${cy - 28} -30 ${cy - 10}Z`} fill={look.hair === "shaved" ? "#2a221e" : "#141012"} opacity={look.hair === "shaved" ? 0.55 : 1} stroke={look.hair === "shaved" ? "none" : OUT} strokeWidth={2} />
      )}
      {look.hair === "grey" && (
        <>
          <path d={`M-30 ${cy - 10} q2 -10 6 -14`} stroke="#a8a8a8" strokeWidth={5} />
          <path d={`M30 ${cy - 10} q-2 -10 -6 -14`} stroke="#a8a8a8" strokeWidth={5} />
        </>
      )}
      {look.hair === "wig" && <path d={`M-32 ${cy - 6} Q-30 ${cy - 46} 0 ${cy - 46} Q30 ${cy - 46} 32 ${cy - 6} Q20 ${cy - 30} 4 ${cy - 26} Q-16 ${cy - 34} -32 ${cy - 6}Z`} fill={look.wig} stroke={OUT} strokeWidth={2.4} />}
      {/* sourcils */}
      {[-1, 1].map((k) => (
        <path key={k} d={`M${k * 6 + lx} ${cy - 13 + browIn} L${k * 19 + lx} ${cy - 15 - browIn * 0.2}`} stroke="#120c0c" strokeWidth={4.2} strokeLinecap="round" />
      ))}
      {/* yeux */}
      {[-1, 1].map((k) =>
        blink ? (
          <path key={k} d={`M${k * 12 + lx - 7} ${cy - 3} q7 4 14 0`} stroke={OUT} strokeWidth={3} fill="none" />
        ) : (
          <g key={k}>
            <ellipse cx={k * 12 + lx} cy={cy - 3} rx={7} ry={eyeRy} fill="#f4efe6" stroke={OUT} strokeWidth={2.4} />
            <circle cx={k * 12 + lx * 1.35} cy={cy - 3} r={3.6} fill="#2a160c" />
            <circle cx={k * 12 + lx * 1.35 + 1.2} cy={cy - 4.5} r={1.2} fill="#fff" />
            <path d={`M${k * 12 + lx - 8} ${cy - 3 - eyeRy + 0.5} q8 -3 16 0`} stroke={OUT} strokeWidth={3.2} fill="none" />
            {f && <path d={`M${k * 12 + lx + k * 7} ${cy - 6} l${k * 5} -3`} stroke={OUT} strokeWidth={2} />}
          </g>
        ),
      )}
      {/* nez */}
      <path d={`M${lx * 1.3 - 8} ${cy + 13} q3 -5 3 -12 M${lx * 1.3 - 9} ${cy + 13} q9 6 18 0`} stroke={OUT} strokeWidth={2.4} fill="none" strokeLinecap="round" />
      <ellipse cx={lx * 1.3 - 4} cy={cy + 13} rx={2.4} ry={1.6} fill="#1a0c08" />
      <ellipse cx={lx * 1.3 + 4} cy={cy + 13} rx={2.4} ry={1.6} fill="#1a0c08" />
      {/* bouche */}
      {mo > 0.04 ? (
        <g>
          <ellipse cx={lx} cy={cy + 25 + mo * 2} rx={9 + mo * 2} ry={2 + mo * 8} fill="#3a0c0e" stroke={look.lipstick ?? "#5a2a24"} strokeWidth={3.4} />
          <rect x={lx - 6} y={cy + 23.5 - mo * 4 + mo * 2} width={12} height={3} fill="#f4efe6" />
        </g>
      ) : (
        <path
          d={
            expr === "smile"
              ? `M${lx - 10} ${cy + 23} q10 8 20 0`
              : expr === "angry" || expr === "focus"
                ? `M${lx - 9} ${cy + 26} q9 -4 18 0`
                : expr === "panic" || expr === "worried"
                  ? `M${lx - 8} ${cy + 27} q8 -6 16 0`
                  : `M${lx - 9} ${cy + 25} q9 2 18 0`
          }
          stroke={look.lipstick ?? "#3a1612"}
          strokeWidth={look.lipstick ? 4.4 : 3}
          fill="none"
          strokeLinecap="round"
        />
      )}
      {look.moustache && <path d={`M${lx - 13} ${cy + 20} q6 -5 13 -2 q7 -3 13 2`} stroke="#141012" strokeWidth={3.4} fill="none" strokeLinecap="round" />}
      {look.sweat && (
        <g fill="#cfe8ff" stroke={OUT} strokeWidth={1.2}>
          <path d={`M-24 ${cy - 22} q-4 8 0 10 q4 -2 0 -10z`} />
          <path d={`M25 ${cy - 6} q-4 8 0 10 q4 -2 0 -10z`} />
          <path d={`M-18 ${cy + 4} q-3 6 0 8 q3 -2 0 -8z`} />
        </g>
      )}
      {look.wound && (
        <g>
          <path d={`M10 ${cy - 24} l12 -4`} stroke="#8a0d0d" strokeWidth={3} />
          <path d={`M16 ${cy - 26} q2 14 -2 22`} stroke="#8a0d0d" strokeWidth={2.4} fill="none" />
        </g>
      )}
      {look.headphones && (
        <g>
          <path d={`M-36 ${cy - 2} Q-38 ${cy - 58} 0 ${cy - 58} Q38 ${cy - 58} 36 ${cy - 2}`} stroke="#18191d" strokeWidth={9} fill="none" />
          <rect x={-46} y={cy - 16} width={18} height={32} rx={8} fill="#c62828" stroke={OUT} strokeWidth={SW} />
          <rect x={28} y={cy - 16} width={18} height={32} rx={8} fill="#c62828" stroke={OUT} strokeWidth={SW} />
        </g>
      )}
    </g>
  );
};
