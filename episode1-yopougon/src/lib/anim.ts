import { Easing, interpolate } from "remotion";
import lipsync from "../lipsync.json";

export const FPS = 30;
export const s = (sec: number) => Math.round(sec * FPS);

const C = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;
export const lerp = (f: number, i: number[], o: number[], ease?: (t: number) => number) =>
  interpolate(f, i, o, { ...C, easing: ease });
export const ease = Easing.bezier(0.45, 0, 0.2, 1);
export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);

// bruit pseudo-aléatoire lisse (caméra épaule, flicker)
const h = (n: number) => {
  const x = Math.sin(n * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};
export const noise = (t: number, seed = 0) => {
  const i = Math.floor(t);
  const f = t - i;
  const u = f * f * (3 - 2 * f);
  return (h(i + seed * 57) * (1 - u) + h(i + 1 + seed * 57) * u) * 2 - 1;
};
export const rnd = h;

// ouverture de bouche à partir de l'enveloppe audio d'une réplique
export type LineId = keyof typeof lipsync;
export const mouth = (frame: number, line: LineId, start: number) => {
  const env = (lipsync as Record<string, number[]>)[line];
  const i = frame - start;
  if (i < 0 || i >= env.length) return 0;
  const a = env[i];
  const b = env[Math.min(env.length - 1, i + 1)];
  return Math.max(0, (a + b) / 2 - 0.08) * 1.15;
};

// clignement d'yeux pseudo-aléatoire
export const blink = (frame: number, seed: number) => {
  const period = 90 + Math.floor(h(seed) * 70);
  const p = (frame + Math.floor(h(seed + 3) * 200)) % period;
  return p < 4;
};
