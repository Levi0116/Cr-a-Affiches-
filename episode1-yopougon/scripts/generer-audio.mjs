// Génère les voix (ElevenLabs TTS, modèle eleven_v3) et les effets sonores.
// Usage : ELEVENLABS_API_KEY=... node scripts/generer-audio.mjs   (n'écrase pas les fichiers existants)
import { writeFileSync, existsSync } from "node:fs";

const KEY = process.env.ELEVENLABS_API_KEY ?? "proxy";
const V = {
  yao: "bIHbv24MWmeRgasZH58o", // Will
  bravo: "pqHfZKP75CvOlQylNhV4", // Bill
  blesse: "TX3LPaxmHKxFdv7VOQHJ", // Liam
  gonmon1: "pNInz6obpgDQGcFmaJgB", // Adam
  gonmon2: "N2lVS1w4EtoT3dr4eOWO", // Callum
  microbe: "IKne3meq5aSn9XLyUdCD", // Charlie
  kpocle1: "FGY2WhTYpPnrIDTdsKH5", // Laura
  kpocle2: "cgSgspJ2msm6clMCkdW9", // Jessica
  client: "CwhRBWXzGAHq8TQ4Fs17", // Roger
  tele: "onwK4e9ZLuTAKqWW03F9", // Daniel
  narrateur: "nPczCjzI2devNBz1zQrb", // Brian
};

export const LIGNES = [
  ["kpocle1", "[angry] [shouting] Hé ! Tu vas payer ma bière ou bien ? Tu nous prends pour qui ?!"],
  ["client", "[drunk] [slurring] Laissez-moi... Moi je suis garçon... je vais payer demain..."],
  ["kpocle2", "[shouting] Demain quoi ? Ton affaire là c'est pas sérieux oh !"],
  ["yao", "[casual] Vieux père, faut donner mes cent francs avant de partir oh !"],
  ["bravo", "[laughs] Hé mon petit, faut garder le silence ! Tu me réclames cent francs... [chuckles] Je vais en face chez la petite Chimène, je reviens régler ton affaire."],
  ["microbe", "[shouting] [out of breath] Hé les djos, rentrez vos téléphones ! Y a patrouille bizarre qui descend la rue là-bas !"],
  ["blesse", "[whispering] [panicked] Petit... faut me gbasser vite ! Y a des djos qui me traquent. C'est des faux djos ! S'ils demandent après moi, jure sur ta vie que tu n'as vu personne !"],
  ["tele", "[serious] Flash info. Braquage à Angré, huitième tranche. Les malfaiteurs sont en fuite."],
  ["gonmon1", "[aggressive] [loud] Hé le petit ! Tu es assis dans ton ghetto là, tu dors pas ? Tu as vu un djo courir en maillot de foot passer par ici tout de suite ?"],
  ["yao", "[calm] Chef, respect d'abord... [pause] Je mangeais mon pain oh."],
  ["gonmon2", "[cold] [menacing] On t'a demandé si tu mangeais pain ? Réponds avant qu'on braque ton ghetto de gnata là et qu'on t'embarque !"],
  ["narrateur", "[excited] La famille, ouvrez bien vos yeux ! Les microbes ont parlé, la tenue mousse pas droit, et Bravo regarde depuis le poteau. [dramatic] Tu es à la place de Yao, tu fais quoi ? Mets A ou B en commentaire et donne tes preuves !"],
];

const SFX = {
  ambiance: ["Night street ambience in an African city, distant crowd chatter, faint coumpa music from a bar far away, crickets, occasional distant moped", 22],
  neon: ["Flickering fluorescent neon tube buzzing and crackling, electrical hum bzzzt", 6],
  tension: ["Dark cinematic suspense drone with slow deep heartbeat pulse and low afro percussion, tense night thriller", 22],
  briquet: ["Zippo lighter flick and ignite, then a cigarette inhale", 2],
  couteau: ["Knife cutting crusty bread on newspaper", 3],
  course: ["Group of kids running fast barefoot on asphalt and sandals, passing by", 3],
  boitement: ["Limping uneven footsteps dragging on gravel with heavy pained breathing", 4],
  grille: ["Metal security gate shaken and forced open, loud rattling metal", 2],
  casiers: ["Plastic beer crates with glass bottles knocked over and clanking, body falling", 2],
  souffle: ["Panicked heavy breathing of a hidden injured man, trying to be quiet", 6],
  pneus: ["Car tires screeching to a sudden stop on asphalt, pickup truck engine idling", 4],
  coupure: ["TV music abruptly cut with static glitch, then breaking news alert jingle", 3],
  portiere: ["Two car doors slamming, heavy boots stepping on ground", 3],
  impact: ["Deep cinematic boom hit with reverb, dramatic reveal", 2],
  whoosh: ["Fast cinematic whoosh transition", 1],
  gel: ["Glass screen cracking and freezing, time stop effect, shatter freeze", 3],
  bip: ["Game show buttons blinking electronic pulse loop, suspenseful countdown ticks", 8],
};

async function post(url, body, out) {
  if (existsSync(out)) return console.log("existe déjà", out);
  const r = await fetch(url, { method: "POST", headers: { "xi-api-key": KEY, "Content-Type": "application/json", Accept: "audio/mpeg" }, body: JSON.stringify(body) });
  if (!r.ok) throw new Error(out + " " + r.status + " " + (await r.text()));
  writeFileSync(out, Buffer.from(await r.arrayBuffer()));
  console.log("ok", out);
}

const only = process.argv[2];
for (const [i, [who, text]] of LIGNES.entries()) {
  if (only && only !== "voix") break;
  await post(`https://api.elevenlabs.io/v1/text-to-speech/${V[who]}?output_format=mp3_44100_128`,
    { text, model_id: "eleven_v3", language_code: "fr", voice_settings: { stability: 0.5 } },
    `public/voix/${String(i).padStart(2, "0")}-${who}.mp3`);
}
for (const [name, [text, d]] of Object.entries(SFX)) {
  if (only && only !== "sfx") break;
  await post("https://api.elevenlabs.io/v1/sound-generation", { text, duration_seconds: d, prompt_influence: 0.5 }, `public/sfx/${name}.mp3`);
}
