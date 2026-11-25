import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";
import path from "node:path";
const [,, projet, sortie, ...frames] = process.argv;
const serveUrl = await bundle({ entryPoint: path.join(projet, "src/index.ts"), webpackOverride: (c) => c, publicDir: path.join(projet, "public"), rspack: true });
const browserExecutable = "/opt/pw-browsers/chromium_headless_shell-1243/chrome-headless-shell-linux64/chrome-headless-shell";
const composition = await selectComposition({ serveUrl, id: "Presentation", browserExecutable });
for (const fr of frames) {
  await renderStill({ composition, serveUrl, frame: Number(fr), output: path.join(sortie, `f${fr}.jpg`), imageFormat: "jpeg", jpegQuality: 70, scale: 0.5, browserExecutable });
  console.log("ok", fr);
}
