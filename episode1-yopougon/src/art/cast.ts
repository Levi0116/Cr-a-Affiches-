import type { Look } from "./Person";

const peau = (n: number) => [["#7a4a2e", "#5c3420"], ["#6b3f26", "#4e2c1a"], ["#8a5634", "#683d24"], ["#5a3420", "#40241a"], ["#9a6440", "#7a4a2e"]][n];

export const YAO: Look = { skin: peau(0)[0], skinShade: peau(0)[1], hair: "short", build: 0.88, top: { kind: "tshirt", color: "#26262b", text: "ABIDJAN" }, bottom: "pants", bottomColor: "#3b3f48", shoes: "samara", apron: true, towel: true };
export const BRAVO: Look = { skin: peau(3)[0], skinShade: peau(3)[1], hair: "grey", moustache: true, build: 1.12, belly: 8, top: { kind: "floral" }, bottom: "pants", bottomColor: "#4a3f35", shoes: "sandal", watch: "silver" };
export const BLESSE: Look = { skin: peau(1)[0], skinShade: peau(1)[1], hair: "shaved", build: 1, top: { kind: "jersey", torn: true, blood: true }, bottom: "black", shoes: "samaraBroken", watch: "gold", sweat: true, wound: true };
export const GONMON1: Look = { skin: peau(3)[0], skinShade: peau(3)[1], hair: "shaved", build: 1.25, top: { kind: "camo" }, bottom: "camo", shoes: "jordan" };
export const GONMON2: Look = { skin: peau(2)[0], skinShade: peau(2)[1], hair: "shaved", build: 1.15, belly: 6, top: { kind: "vest" }, bottom: "black", shoes: "boot", holster: true };
export const KPOCLE1: Look = { skin: peau(4)[0], skinShade: peau(4)[1], hair: "wig", wig: "#d6336c", female: true, build: 1, top: { kind: "dress", color: "#ffd23f" }, bottom: "none", shoes: "heels", lipstick: "#d81b60", earrings: true };
export const KPOCLE2: Look = { skin: peau(2)[0], skinShade: peau(2)[1], hair: "wig", wig: "#3fb6ff", female: true, build: 1.05, top: { kind: "dress", color: "#e8452c" }, bottom: "none", shoes: "heels", lipstick: "#8e1b3c", earrings: true };
export const CLIENT: Look = { skin: peau(1)[0], skinShade: peau(1)[1], hair: "short", build: 1.05, belly: 10, top: { kind: "tshirt", color: "#7a6a52" }, bottom: "pants", bottomColor: "#2f3440", shoes: "sandal" };
export const JO: Look = { skin: peau(3)[0], skinShade: peau(3)[1], hair: "shaved", build: 1.3, top: { kind: "tshirt", color: "#3a5a3a" }, bottom: "shorts", bottomColor: "#444", shoes: "sandal", headphones: true };
export const MICROBES: Look[] = [
  { skin: peau(0)[0], skinShade: peau(0)[1], hair: "shaved", build: 0.75, top: { kind: "foot", color: "#c62828", color2: "#fff", torn: true }, bottom: "jeanshort", shoes: "barefoot" },
  { skin: peau(3)[0], skinShade: peau(3)[1], hair: "shaved", build: 0.72, top: { kind: "foot", color: "#ffd23f", color2: "#1b5e20", torn: true }, bottom: "jeanshort", shoes: "samara" },
  { skin: peau(1)[0], skinShade: peau(1)[1], hair: "shaved", build: 0.74, top: { kind: "foot", color: "#1565c0", color2: "#fff", torn: true }, bottom: "jeanshort", shoes: "barefoot" },
];
