import React from "react";
import { AbsoluteFill, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";

const useV = () => {
  const { width, height } = useVideoConfig();
  return height > width;
};
import { Audio } from "@remotion/media";
import { Cam, Scene } from "./Scene";
import { Choix, Fissures, InsertHolster, InsertIndices, InsertJordans, TeleCU, Titre } from "./Overlays";
import { ease, easeOut, lerp } from "./lib/anim";
import lipsync from "./lipsync.json";
import { SFX, T, TOTAL, VOIX } from "./timeline";

// ------------------------------------------------------------------
// Découpage : chaque plan = intervalle [from, to) + caméra dans le monde
// ------------------------------------------------------------------
// vcx : centre horizontal propre au format vertical (TikTok)
type Shot = { from: number; to: number; cam: (f: number) => Cam; vcx?: (f: number) => number; focus?: "near" | "far"; hideGonmons?: boolean };
const clamp = (v: number, a: number, b: number) => Math.min(b, Math.max(a, v));
const microbesCx = (f: number) => clamp(lerp(f, [935, 1075], [2150, -300]) + 110, 380, 1650);

const HEAD = {
  yao: [335, 668],
  bravo: [548, 606],
  bravoPole: [1135, 482],
  blesse: [560, 672],
  g1: [560, 588],
  g2: [655, 606],
};

const SHOTS: Shot[] = [
  // SCÈNE 1
  { from: 0, to: 300, cam: (f) => ({ cx: lerp(f, [0, 300], [960, 1010]), cy: lerp(f, [0, 300], [540, 575]), w: lerp(f, [0, 300], [1920, 1680], ease) }), vcx: (f) => lerp(f, [0, 70, 200, 300], [1560, 1500, 900, 520], ease) },
  { from: 300, to: 510, cam: (f) => ({ cx: lerp(f, [300, 510], [470, 440]), cy: 690, w: lerp(f, [300, 510], [1120, 920], ease) }), vcx: () => 440 },
  { from: 510, to: 615, cam: (f) => ({ cx: HEAD.yao[0] + 20, cy: HEAD.yao[1] + 10, w: lerp(f, [510, 615], [460, 410]) }), focus: "near" },
  { from: 615, to: 800, cam: (f) => ({ cx: HEAD.bravo[0] - 10, cy: HEAD.bravo[1] + 14, w: lerp(f, [615, 800], [480, 420]) }), focus: "near" },
  { from: 800, to: 935, cam: (f) => ({ cx: lerp(f, T.bravoWalk, [600, 1080], ease), cy: lerp(f, T.bravoWalk, [690, 560], ease), w: lerp(f, [800, 935], [1000, 1250]) }) },
  // SCÈNE 2
  { from: 935, to: 1110, cam: (f) => ({ cx: lerp(f, [935, 1110], [1150, 860], ease), cy: 650, w: 1500, shake: 1.6 }), vcx: (f) => (f < 1040 ? microbesCx(f) : lerp(f, [1040, 1070], [microbesCx(1040), 1600], ease)) },
  { from: 1110, to: 1200, cam: (f) => ({ cx: lerp(f, [1110, 1200], [960, 900]), cy: lerp(f, [1110, 1200], [540, 580]), w: lerp(f, [1110, 1200], [1920, 1750]) }), vcx: () => 760 },
  { from: 1200, to: 1400, cam: (f) => ({ cx: lerp(f, [1200, 1390], [1250, 640], ease), cy: 700, w: lerp(f, [1200, 1400], [1150, 950]), shake: 2.2 }) },
  { from: 1400, to: 1660, cam: (f) => ({ cx: HEAD.blesse[0] - 20, cy: HEAD.blesse[1] + 20, w: lerp(f, [1400, 1660], [500, 400]), shake: 0.8 }), focus: "near" },
  { from: 1695, to: 1800, cam: (f) => ({ cx: 470, cy: 705, w: lerp(f, [1695, 1800], [950, 880]) }) },
  // SCÈNE 3
  { from: 1800, to: 1888, cam: (f) => ({ cx: 1000, cy: 600, w: 1920, shake: f > 1845 && f < 1865 ? 2 : 0.3 }), vcx: (f) => lerp(f, [1798, 1850], [1600, 1000], easeOut) },
  { from: 2040, to: 2112, cam: (f) => ({ cx: lerp(f, [2040, 2112], [1000, 820]), cy: 640, w: 1500 }), vcx: (f) => lerp(f, [2040, 2112], [900, 760]) },
  { from: 2112, to: 2160, cam: () => ({ cx: 690, cy: 680, w: 1050, shake: 2.4 }) },
  { from: 2205, to: 2330, cam: (f) => ({ cx: 470, cy: 650, w: lerp(f, [2205, 2330], [800, 700]), rot: -3 }) },
  { from: 2330, to: 2450, cam: (f) => ({ cx: HEAD.g1[0] - 10, cy: HEAD.g1[1] + 30, w: lerp(f, [2330, 2450], [470, 400]), rot: 3 }), focus: "near" },
  { from: 2450, to: 2525, cam: (f) => ({ cx: 340, cy: lerp(f, [2450, 2525], [745, 720]), w: 600 }), focus: "near" },
  { from: 2525, to: 2640, cam: (f) => ({ cx: HEAD.yao[0] + 15, cy: HEAD.yao[1] + 10, w: lerp(f, [2525, 2640], [430, 380]) }), focus: "near" },
  { from: 2690, to: 2810, cam: (f) => ({ cx: HEAD.g2[0], cy: HEAD.g2[1] + 25, w: lerp(f, [2690, 2810], [480, 420]), rot: -2 }), focus: "near" },
  { from: 2810, to: 2900, cam: (f) => ({ cx: lerp(f, [2810, 2900], [600, 560]), cy: 660, w: lerp(f, [2810, 2900], [950, 880]) }) },
  // SCÈNE 4 : jeu de regards
  { from: 2900, to: 2965, cam: (f) => ({ cx: 470, cy: 640, w: lerp(f, [2900, 2965], [760, 620], easeOut), shake: 1.5 }) },
  { from: 2965, to: 3030, cam: (f) => ({ cx: HEAD.bravoPole[0], cy: HEAD.bravoPole[1] + 8, w: lerp(f, [2965, 3030], [340, 290]) }), focus: "far" },
  { from: 3030, to: 3095, cam: (f) => ({ cx: 555, cy: 735, w: lerp(f, [3030, 3095], [360, 300]), shake: 0.6 }), focus: "near", hideGonmons: true },
  { from: 3095, to: 3168, cam: (f) => ({ cx: HEAD.yao[0] + 10, cy: HEAD.yao[1] + 6, w: lerp(f, [3095, 3168], [420, 270], ease) }), focus: "near" },
];

const FREEZE_CAM: Cam = { cx: HEAD.yao[0] + 10, cy: HEAD.yao[1] + 6, w: 270 };

// ------------------------------------------------------------------
// Sous-titres
// ------------------------------------------------------------------
const NOMS: Record<string, [string, string]> = {
  kpocle1: ["KPÔCLÉ", "#ff6fa8"],
  kpocle2: ["KPÔCLÉ 2", "#6fd0ff"],
  client: ["CLIENT BOURRÉ", "#c9b38a"],
  yao: ["YAO", "#ffd23f"],
  bravo: ["BRAVO", "#ff9f43"],
  microbe: ["MICROBE", "#ff4d4d"],
  blesse: ["LE DJO BLESSÉ", "#2ecc71"],
  tele: ["TÉLÉ", "#ff5252"],
  gonmon1: ["FAUX GONMON 1", "#a3b18a"],
  gonmon2: ["FAUX GONMON 2", "#9aa5b1"],
  narrateur: ["", "#fff"],
};
const TEXTES: Record<string, string[]> = {
  "00-kpocle1": ["Hé ! Tu vas payer ma bière ou bien ?", "Tu nous prends pour qui ?!"],
  "01-client": ["Laissez-moi… Moi je suis garçon…", "je vais payer demain…"],
  "02-kpocle2": ["Demain quoi ?", "Ton affaire là c'est pas sérieux oh !"],
  "03-yao": ["Vieux père, faut donner mes 100 francs avant de partir oh !"],
  "04-bravo": ["(rire) Hé mon petit, faut garder le silence !", "Tu me réclames 100 francs…", "Je vais en face chez la petite Chimène,", "je reviens régler ton affaire."],
  "05-microbe": ["Hé les djos, rentrez vos téléphones !", "Y a patrouille bizarre qui descend la rue là-bas !"],
  "06-blesse": ["Petit… faut me gbasser vite !", "Y a des djos qui me traquent. C'est des faux djos !", "S'ils demandent après moi,", "jure sur ta vie que tu n'as vu personne !"],
  "07-tele": ["Flash info : braquage à Angré 8è tranche.", "Les malfaiteurs sont en fuite."],
  "08-gonmon1": ["Hé le petit ! Tu es assis dans ton ghetto là, tu dors pas ?", "Tu as vu un djo courir en maillot de foot", "passer par ici tout de suite ?"],
  "09-yao": ["Chef, respect d'abord…", "Je mangeais mon pain oh."],
  "10-gonmon2": ["On t'a demandé si tu mangeais pain ?", "Réponds avant qu'on braque ton ghetto de gnata là", "et qu'on t'embarque !"],
  "11-narrateur": ["La famille, ouvrez bien vos yeux !", "Les microbes ont parlé, la tenue mousse pas droit,", "et Bravo regarde depuis le poteau.", "Tu es à la place de Yao, tu fais quoi ?", "Mets A ou B en commentaire et donne tes preuves !"],
};

type Cue = { from: number; to: number; who: string; text: string };
const CUES: Cue[] = VOIX.flatMap((v) => {
  const env = (lipsync as Record<string, number[]>)[v.id];
  const parts = TEXTES[v.id];
  const total = parts.reduce((a, p) => a + p.length, 0);
  let t = v.at;
  return parts.map((p) => {
    const d = (p.length / total) * env.length;
    const c = { from: Math.round(t), to: Math.round(t + d), who: v.id.split("-")[1], text: p };
    t += d;
    return c;
  });
});

export const SousTitres: React.FC = () => {
  const f = useCurrentFrame();
  const V = useV();
  const c = CUES.filter((q) => f >= q.from && f < q.to + 6).pop();
  if (!c) return null;
  const [nom, col] = NOMS[c.who];
  const narr = c.who === "narrateur";
  return (
    <div style={{ position: "absolute", left: 0, right: 0, ...(narr ? { top: V ? 390 : 170 } : { bottom: V ? 470 : 64 }), padding: V ? "0 50px" : 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
      {nom && <div style={{ fontFamily: "'Arial Black', Arial", fontSize: 26, color: col, letterSpacing: 3, textShadow: "0 2px 6px #000" }}>{nom}</div>}
      <div
        style={{
          fontFamily: "'Arial Black', Arial",
          fontSize: V ? 46 : narr ? 46 : 42,
          color: "#fff",
          textAlign: "center",
          maxWidth: V ? 960 : 1600,
          padding: "6px 22px",
          background: narr ? "rgba(0,0,0,0.0)" : "rgba(0,0,0,0.45)",
          borderRadius: 12,
          textShadow: "0 3px 0 #000, 0 0 12px #000",
          fontStyle: c.who === "blesse" ? "italic" : "normal",
        }}
      >
        {c.text}
      </div>
    </div>
  );
};

// ------------------------------------------------------------------
const Monde: React.FC = () => {
  const f = useCurrentFrame();
  const V = useV();
  const shot = SHOTS.find((s) => f >= s.from && f < s.to);
  if (!shot) return null;
  // petit flash de coupe au début de chaque plan
  const cut = f - shot.from;
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Scene frame={f} cam={V && shot.vcx ? { ...shot.cam(f), cx: shot.vcx(f) } : shot.cam(f)} focus={shot.focus} hideGonmons={shot.hideGonmons} vertical={V} />
      {cut < 3 && shot.from > 0 && <AbsoluteFill style={{ background: "#fff", opacity: 0.08 * (3 - cut) }} />}
    </AbsoluteFill>
  );
};

const Gel: React.FC = () => {
  const f = useCurrentFrame();
  const V = useV();
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <AbsoluteFill style={{ filter: `grayscale(${lerp(f, [0, 10], [0, 0.55])}) contrast(1.35) saturate(1.4) sepia(0.15)`, scale: lerp(f, [0, 10, 430], [1.08, 1, 0.96], easeOut) }}>
        <Scene frame={T.freeze - 1} cam={V ? { ...FREEZE_CAM, w: 420, cy: FREEZE_CAM.cy + 40 } : FREEZE_CAM} focus="near" vertical={V} />
      </AbsoluteFill>
      <svg width="100%" height="100%" style={{ position: "absolute", inset: 0, mixBlendMode: "multiply", opacity: 0.22 }}>
        <defs>
          <pattern id="trame2" width="12" height="12" patternUnits="userSpaceOnUse">
            <circle cx="6" cy="6" r="2.6" fill="#000" />
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#trame2)" />
      </svg>
      <AbsoluteFill style={{ border: "18px solid #fff", boxShadow: "inset 0 0 0 8px #000" }} />
      <Fissures />
      <AbsoluteFill style={{ background: "#fff", opacity: lerp(f, [0, 6], [0.9, 0]) }} />
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, transparent 40%, rgba(0,0,0,0.75) 100%)" }} />
      <Choix />
    </AbsoluteFill>
  );
};

const Grain: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <svg width="100%" height="100%" style={{ position: "absolute", inset: 0, opacity: 0.07, mixBlendMode: "overlay", pointerEvents: "none" }}>
      <filter id="grain">
        <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves={2} seed={f % 12} />
      </filter>
      <rect width="100%" height="100%" filter="url(#grain)" />
    </svg>
  );
};

// Toute l'image (sans le son) ; intro = carton titre + fondu d'ouverture
export const Visuels: React.FC<{ intro?: boolean; sousTitres?: boolean }> = ({ intro = true, sousTitres = true }) => (
    <AbsoluteFill style={{ background: "#000" }}>
      <Monde />
      <Sequence from={1660} durationInFrames={35} name="Insert indices">
        <InsertIndices />
      </Sequence>
      <Sequence from={1888} durationInFrames={152} name="Télé flash info">
        <TeleCU />
      </Sequence>
      <Sequence from={2160} durationInFrames={45} name="Insert Jordan">
        <InsertJordans />
      </Sequence>
      <Sequence from={2640} durationInFrames={50} name="Insert holster">
        <InsertHolster />
      </Sequence>
      <Sequence from={T.freeze} durationInFrames={TOTAL - T.freeze} name="Arrêt sur image">
        <Gel />
      </Sequence>
      {/* vignette permanente */}
      <AbsoluteFill style={{ background: "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.6) 100%)", pointerEvents: "none" }} />
      <Grain />
      {intro && (
        <Sequence durationInFrames={120} name="Titre">
          <Titre />
        </Sequence>
      )}
      {sousTitres && <SousTitres />}
      {intro && (
        <Sequence durationInFrames={20}>
          <FonduNoir />
        </Sequence>
      )}
    </AbsoluteFill>
);

export const Episode1: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Visuels />
      {/* ===== AUDIO ===== */}
      <Audio src={staticFile("sfx/ambiance.mp3")} loop volume={(f) => (f < 1888 ? 0.45 : f < T.freeze ? 0.18 : 0.08)} />
      <Sequence from={1110} durationInFrames={T.freeze - 1110} name="Tension">
        <Audio src={staticFile("sfx/tension.mp3")} loop volume={(f) => lerp(f, [0, 60], [0, 0.55])} />
      </Sequence>
      <Sequence from={T.freeze} name="Tension finale">
        <Audio src={staticFile("sfx/tension.mp3")} loop volume={0.3} />
      </Sequence>
      {SFX.map((x, i) => (
        <Sequence key={i} from={x.at} durationInFrames={x.dur} name={`sfx ${x.f}`}>
          <Audio src={staticFile(`sfx/${x.f}.mp3`)} volume={x.vol} loop={x.loop} />
        </Sequence>
      ))}
      {VOIX.map((v) => (
        <Sequence key={v.id} from={v.at} name={`voix ${v.id}`}>
          <Audio src={staticFile(v.file)} volume={v.vol} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};

const FonduNoir: React.FC = () => {
  const f = useCurrentFrame();
  return <AbsoluteFill style={{ background: "#000", opacity: lerp(f, [0, 20], [1, 0]) }} />;
};

