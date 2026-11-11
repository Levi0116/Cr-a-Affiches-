// Calcule l'enveloppe RMS par image (30 fps) de chaque voix -> src/lipsync.json
import { execFileSync } from "node:child_process";
import { readdirSync, writeFileSync } from "node:fs";
const out = {};
for (const f of readdirSync("public/voix").filter((x) => x.endsWith(".mp3")).sort()) {
  const raw = execFileSync("ffmpeg", ["-v", "error", "-i", `public/voix/${f}`, "-ac", "1", "-ar", "8000", "-f", "s16le", "-"], { maxBuffer: 1e8 });
  const s = new Int16Array(raw.buffer, raw.byteOffset, raw.length / 2);
  const per = 8000 / 30, env = [];
  for (let i = 0; i < s.length; i += per) {
    let a = 0, n = 0;
    for (let j = Math.floor(i); j < Math.min(s.length, i + per); j++) { a += s[j] * s[j]; n++; }
    env.push(Math.sqrt(a / Math.max(1, n)) / 32768);
  }
  const mx = Math.max(...env) || 1;
  out[f.replace(".mp3", "")] = env.map((v) => Math.round(Math.min(1, v / (mx * 0.6)) * 100) / 100);
}
writeFileSync("src/lipsync.json", JSON.stringify(out));
console.log(Object.fromEntries(Object.entries(out).map(([k, v]) => [k, v.length])));
