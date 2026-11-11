import React from "react";
import { AbsoluteFill, Freeze, Sequence, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Audio } from "@remotion/media";
import { Visuels } from "./Episode1";
import { easeOut, lerp, noise } from "./lib/anim";
import lipsync from "./lipsync.json";
import { SFX, T, TOTAL, VOIX } from "./timeline";

// ------------------------------------------------------------------
// Version « rétention » : accroche choc (flash-forward) + retour en arrière,
// passages lents coupés, compteur d'indices et teasers.
// Le film d'origine est rejoué via un remappage du temps (montage).
// ------------------------------------------------------------------

type Clip = { src: [number, number] };
const HOOK: Clip[] = [
  { src: [2767, 2812] }, // faux gonmon 2 qui menace (synchro avec la voix, coupée à 72)
  { src: [3036, 3080] }, // l'œil du blessé caché
  { src: [3118, 3162] }, // Yao qui hésite
];
const HOOK_LEN = HOOK.reduce((a, c) => a + c.src[1] - c.src[0], 0);
const REWIND = 26;
const STORY: Clip[] = [
  { src: [28, 130] },
  { src: [400, 1110] },
  { src: [1140, 1700] },
  { src: [1740, TOTAL] },
];
const STORY_START = HOOK_LEN + REWIND;
const STORY_LEN = STORY.reduce((a, c) => a + c.src[1] - c.src[0], 0);
export const TOTAL_V2 = STORY_START + STORY_LEN;

// position de chaque clip de l'histoire sur la sortie
const PLACED = (() => {
  let o = STORY_START;
  return STORY.map((c) => {
    const p = { ...c, out: o };
    o += c.src[1] - c.src[0];
    return p;
  });
})();
const outToSrc = (f: number) => {
  for (const c of PLACED) if (f >= c.out && f < c.out + c.src[1] - c.src[0]) return c.src[0] + f - c.out;
  return TOTAL - 1;
};
const srcToOut = (t: number) => {
  for (const c of PLACED) if (t >= c.src[0] && t < c.src[1]) return c.out + t - c.src[0];
  const next = PLACED.find((c) => c.src[0] >= t);
  return next ? next.out : TOTAL_V2;
};

// ------------------------------------------------------------------
const useV = () => {
  const { width, height } = useVideoConfig();
  return height > width;
};
const FONT = "'Arial Black', 'Arial', sans-serif";

// Badge permanent : rappelle le défi sans jamais montrer les indices
const Badge: React.FC<{ src: number }> = ({ src }) => {
  const V = useV();
  if (src >= T.freeze) return null;
  return (
    <div style={{ position: "absolute", top: V ? 250 : 40, right: V ? 40 : 50, padding: "12px 24px", borderRadius: 999, background: "rgba(0,0,0,0.65)", border: "4px solid #ffd23f", color: "#ffd23f", fontFamily: FONT, fontSize: V ? 36 : 32 }}>
      🔍 5 INDICES CACHÉS
    </div>
  );
};

// ------------------------------------------------------------------
// Accroche (0 → ~3,4 s) puis rembobinage
// ------------------------------------------------------------------
const Accroche: React.FC = () => {
  const f = useCurrentFrame();
  const V = useV();
  let src = HOOK[0].src[0];
  let o = 0;
  for (const c of HOOK) {
    const l = c.src[1] - c.src[0];
    if (f < o + l) {
      src = c.src[0] + f - o;
      break;
    }
    o += l;
  }
  const cap = f < 85 ? "« Réponds avant qu'on braque ton ghetto de gnata là… »" : "« …et qu'on t'embarque ! »";
  return (
    <AbsoluteFill>
      <Freeze frame={src}>
        <Visuels intro={false} sousTitres={false} cache />
      </Freeze>
      {(f === 45 || f === 46 || f === 89 || f === 90) && <AbsoluteFill style={{ background: "#fff", opacity: 0.35 }} />}
      <AbsoluteFill style={{ background: "#d50000", mixBlendMode: "multiply", opacity: 0.06 + 0.06 * Math.abs(Math.sin(f / 3)) }} />
      <div style={{ position: "absolute", top: V ? 250 : 40, left: 40, right: 40, textAlign: "center" }}>
        <div style={{ display: "inline-block", background: "#d50000", color: "#fff", fontFamily: FONT, fontSize: V ? 64 : 56, padding: "8px 26px", lineHeight: 1.15, rotate: "-2deg" }}>
          1 BLESSÉ CACHÉ.
          <br />2 « POLICIERS ».
        </div>
        <div style={{ marginTop: 20, color: "#ffd23f", fontFamily: FONT, fontSize: V ? 58 : 48, lineHeight: 1.1, textShadow: "0 4px 0 #000, 0 0 20px #000", scale: lerp(f, [6, 14], [0, 1], easeOut) }}>
          5 INDICES SONT CACHÉS
          <br />
          DANS LA VIDÉO 👀 TU LES VOIS ?
        </div>
      </div>
      <div style={{ position: "absolute", bottom: V ? 470 : 70, left: 50, right: 50, textAlign: "center", fontFamily: FONT, fontSize: V ? 44 : 42, color: "#fff", textShadow: "0 3px 0 #000, 0 0 12px #000" }}>
        <div style={{ fontSize: 26, color: "#9aa5b1", letterSpacing: 3 }}>FAUX GONMON 2</div>
        {cap}
      </div>
    </AbsoluteFill>
  );
};

const Rembobinage: React.FC = () => {
  const f = useCurrentFrame();
  const V = useV();
  const src = Math.round(lerp(f, [0, REWIND], [3162, STORY[0].src[0]], (t) => t * t));
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{ filter: `blur(${2 + noise(f, 2) * 2}px) saturate(0.4) contrast(1.3)`, translate: `${noise(f * 3, 4) * 30}px 0` }}>
        <Freeze frame={src}>
          <Visuels intro={false} sousTitres={false} cache />
        </Freeze>
      </AbsoluteFill>
      {Array.from({ length: 6 }).map((_, i) => (
        <div key={i} style={{ position: "absolute", left: 0, right: 0, top: `${(i * 17 + f * 7) % 100}%`, height: 14 + (i % 3) * 10, background: "rgba(255,255,255,0.18)" }} />
      ))}
      <AbsoluteFill style={{ justifyContent: "center", alignItems: "center" }}>
        <div style={{ fontFamily: FONT, fontSize: V ? 72 : 80, color: "#fff", textShadow: "0 5px 0 #000, 0 0 30px #000", textAlign: "center", lineHeight: 1.1 }}>
          ⏪ 2 MINUTES
          <br />
          PLUS TÔT…
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

// ------------------------------------------------------------------
const Histoire: React.FC = () => {
  const f = useCurrentFrame();
  const src = outToSrc(f + STORY_START);
  const cutIn = PLACED.some((c) => c.out - STORY_START === f || c.out - STORY_START + 1 === f);
  return (
    <AbsoluteFill>
      <Freeze frame={src}>
        <Visuels intro={false} cache />
      </Freeze>
      {cutIn && <AbsoluteFill style={{ background: "#fff", opacity: 0.12 }} />}
      <Badge src={src} />
      {src < 130 && (
        <div style={{ position: "absolute", left: 50, top: "58%", fontFamily: "monospace", fontSize: 40, color: "#e8d27a", textShadow: "0 0 10px #000" }}>YOPOUGON • 01H30</div>
      )}
    </AbsoluteFill>
  );
};

// ---- son remappé : chaque son source est découpé selon les clips du montage ----
type Son = { file: string; at: number; dur: number; vol: number; loop?: boolean };
const DUREES: Record<string, number> = { ambiance: 661, neon: 181, tension: 661, briquet: 61, couteau: 91, course: 91, boitement: 121, grille: 61, casiers: 61, souffle: 181, pneus: 121, coupure: 91, portiere: 91, impact: 61, whoosh: 31, gel: 91, bip: 241 };
const SONS: Son[] = [
  ...VOIX.map((v) => ({ file: v.file, at: v.at, dur: (lipsync as Record<string, number[]>)[v.id].length, vol: v.id === "07-tele" ? 0.22 : v.vol })),
  ...SFX.map((x) => ({ file: `sfx/${x.f}.mp3`, at: x.at, dur: x.dur ?? DUREES[x.f], vol: x.vol, loop: x.loop })),
];

const SonRemappe: React.FC<{ s: Son }> = ({ s }) => (
  <>
    {PLACED.map((c, i) => {
      const a = Math.max(c.src[0], s.at);
      const b = Math.min(c.src[1], s.at + s.dur);
      if (b <= a) return null;
      const trim = a - s.at;
      return (
        <Sequence key={i} from={c.out + a - c.src[0]} durationInFrames={b - a} name={s.file}>
          <Audio src={staticFile(s.file)} volume={s.vol} loop={s.loop} trimBefore={s.loop ? undefined : trim} />
        </Sequence>
      );
    })}
  </>
);

export const EpisodeV2: React.FC = () => {
  return (
    <AbsoluteFill style={{ background: "#000" }}>
      <Sequence durationInFrames={HOOK_LEN} name="Accroche">
        <Accroche />
      </Sequence>
      <Sequence from={HOOK_LEN} durationInFrames={REWIND} name="Rembobinage">
        <Rembobinage />
      </Sequence>
      <Sequence from={STORY_START} name="Histoire">
        <Histoire />
      </Sequence>

      {/* ===== SON ===== */}
      <Sequence durationInFrames={HOOK_LEN + 6} name="Accroche son">
        <Audio src={staticFile("sfx/choc.mp3")} volume={1} />
        <Audio src={staticFile("voix/10-gonmon2.mp3")} trimBefore={72} volume={1.1} />
        <Audio src={staticFile("sfx/souffle.mp3")} volume={0.6} />
        <Audio src={staticFile("sfx/tension.mp3")} volume={0.6} />
      </Sequence>
      <Sequence from={HOOK_LEN - 4} durationInFrames={REWIND + 6} name="Rembobinage son">
        <Audio src={staticFile("sfx/rembobinage.mp3")} volume={0.9} />
      </Sequence>
      <Sequence from={STORY_START} name="Ambiance">
        <Audio src={staticFile("sfx/ambiance.mp3")} loop volume={(f) => {
          const s = outToSrc(f + STORY_START);
          return s < 1888 ? 0.45 : s < T.freeze ? 0.18 : 0.08;
        }} />
      </Sequence>
      <Sequence from={srcToOut(1140)} durationInFrames={srcToOut(T.freeze) - srcToOut(1140)} name="Tension">
        <Audio src={staticFile("sfx/tension.mp3")} loop volume={(f) => lerp(f, [0, 60], [0, 0.55])} />
      </Sequence>
      <Sequence from={srcToOut(T.freeze)} name="Tension finale">
        <Audio src={staticFile("sfx/tension.mp3")} loop volume={0.3} />
      </Sequence>
      {SONS.map((s, i) => (
        <SonRemappe key={i} s={s} />
      ))}
    </AbsoluteFill>
  );
};
