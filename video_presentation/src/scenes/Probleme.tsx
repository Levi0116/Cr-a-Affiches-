import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Bulle, CanapeAssise, CanapeDos, EtagereBar, Puce, SalleMaquis, TableResto, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Personnage } from "../composants/Personnage";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, easeInOut, entre, ressort } from "../theme";

const D = DUREES.probleme;
/** Début de chaque station (la caméra glisse de l'une à l'autre en 18 images). */
const ST = [0, 113, 226, 329];
const RECAP = 410;

const hasard = (n: number) => {
  const x = Math.sin(n * 78.233 + 1.7) * 43758.5453;
  return x - Math.floor(x);
};

/** Feuilles de papier qui s'envolent. */
const Papiers: React.FC<{ f: number; x: number; y: number }> = ({ f, x, y }) => (
  <>
    {Array.from({ length: 9 }).map((_, i) => {
      const t = f - 10 - i * 7;
      if (t < 0) return null;
      const px = x + (hasard(i) - 0.3) * 520 * (t / 80) + Math.sin(t / 8 + i) * 30;
      const py = y - t * (3 + hasard(i + 9) * 3) + t * t * 0.012;
      return (
        <div key={i} style={{
          position: "absolute", left: px, top: py, width: 70, height: 90, background: "#FFFDF5", borderRadius: 6,
          transform: `rotate(${t * (hasard(i + 3) * 8 - 4)}deg)`, boxShadow: "0 10px 20px rgba(0,0,0,0.25)", opacity: interpolate(t, [60, 90], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
        }}>
          {[18, 32, 46, 60].map((ly) => <div key={ly} style={{ position: "absolute", left: 10, right: 10, top: ly, height: 3, background: "#9BB3D9" }} />)}
        </div>
      );
    })}
  </>
);

const PointsInterrogation: React.FC<{ f: number; debut: number; x: number; y: number; n?: number; couleur?: string }> = ({ f, debut, x, y, n = 5, couleur = C.erreur }) => (
  <>
    {Array.from({ length: n }).map((_, i) => {
      const s = ressort(f, debut + i * 6, 9, 150);
      return (
        <div key={i} style={{
          position: "absolute", left: x + (hasard(i + 40) - 0.5) * 460, top: y + (hasard(i + 60) - 0.5) * 240 + Math.sin((f + i * 20) / 12) * 10,
          fontFamily: TITRE, fontWeight: 800, fontSize: 70 + hasard(i) * 50, color: couleur, transform: `scale(${s}) rotate(${(hasard(i + 80) - 0.5) * 40}deg)`,
          textShadow: "0 10px 30px rgba(0,0,0,0.4)",
        }}>?</div>
      );
    })}
  </>
);

/** Salon du patron, la nuit. */
const Salon: React.FC<{ f: number }> = ({ f }) => (
  <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg,#14213D 0%,#1D2B4A 60%,#121A2E 100%)" }}>
    <div style={{ position: "absolute", left: 1100, top: 120, width: 620, height: 460, borderRadius: 16, background: "linear-gradient(180deg,#0A1630,#1B2F5C)", border: "18px solid #3B2A1E", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 420, top: 60, width: 110, height: 110, borderRadius: "50%", background: "#FFF3D6", boxShadow: "0 0 80px #FFF3D6AA" }} />
      {Array.from({ length: 30 }).map((_, i) => (
        <div key={i} style={{ position: "absolute", left: hasard(i) * 600, top: hasard(i + 30) * 260, width: 4, height: 4, borderRadius: 2, background: "#fff", opacity: 0.3 + 0.5 * Math.abs(Math.sin(f / 14 + i)) }} />
      ))}
      {Array.from({ length: 9 }).map((_, i) => (
        <div key={i} style={{ position: "absolute", left: i * 72, bottom: 0, width: 64, height: 80 + hasard(i + 5) * 180, background: "#0B1222" }}>
          {Array.from({ length: 6 }).map((__, j) => (
            <div key={j} style={{ position: "absolute", left: 12 + (j % 2) * 26, top: 16 + Math.floor(j / 2) * 34, width: 14, height: 16, background: hasard(i * 7 + j) > 0.5 ? "#FFC86B" : "#1B2640" }} />
          ))}
        </div>
      ))}
      <div style={{ position: "absolute", left: "50%", top: 0, bottom: 0, width: 18, marginLeft: -9, background: "#3B2A1E" }} />
    </div>
    {/* Lampe */}
    <div style={{ position: "absolute", left: 160, top: 0, width: 6, height: 220, background: "#222" }} />
    <div style={{ position: "absolute", left: 90, top: 210, width: 150, height: 90, borderRadius: "75px 75px 10px 10px", background: "#F55A0A" }} />
    <div style={{ position: "absolute", left: -100, top: 250, width: 540, height: 700, background: "radial-gradient(ellipse at 50% 0%, rgba(255,190,110,0.30), rgba(0,0,0,0) 65%)" }} />
    {/* Sol */}
    <div style={{ position: "absolute", left: 0, right: 0, top: 860, bottom: 0, background: "#0F1626" }} />
  </div>
);

export const Probleme: React.FC = () => {
  const f = useCurrentFrame();
  // Caméra : position x du monde (4 stations côte à côte).
  const cadres = [0, ST[1] - 18, ST[1], ST[2] - 18, ST[2], ST[3] - 18, ST[3]];
  const positions = [0, 0, 1, 1, 2, 2, 3];
  const station = interpolate(f, cadres, positions, { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut });
  const camX = -station * 1920;
  // Légère dérive (parallaxe) dans chaque station.
  const derive = Math.sin(f / 60) * 12;
  const recap = entre(f, RECAP, 20);
  const zoomRecap = 1 - recap * 0.08;
  const sortie = interpolate(f, [D - 12, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const loc = (i: number) => f - ST[i];

  return (
    <AbsoluteFill style={{ background: C.nuit, overflow: "hidden" }}>
      <AbsoluteFill style={{ transform: `scale(${zoomRecap})`, filter: `blur(${recap * 8}px)`, opacity: sortie }}>
        <div style={{ position: "absolute", left: camX + derive, top: 0, width: 1920 * 4, height: 1080 }}>
          {/* ---------------- Station 0 : la serveuse débordée */}
          <div style={{ position: "absolute", left: 0, top: 0, width: 1920, height: 1080, overflow: "hidden" }}>
            <SalleMaquis f={f} />
            <div style={{ position: "absolute", left: 1040, top: 380 }}>
              <Personnage type="client1" f={f} expression="sourire" parle={loc(0) > 8 && loc(0) < 60} brasD={[70 + Math.sin(f / 4) * 10, 50]} hauteur={640} regard={-1} graine={3} />
            </div>
            <div style={{ position: "absolute", left: 1380, top: 380 }}>
              <Personnage type="client2" f={f} expression="sourire" parle={loc(0) > 30 && loc(0) < 80} brasG={[40, 60]} hauteur={640} regard={-1} graine={4} />
            </div>
            <TableResto x={1000} y={760} largeur={760} />
            <div style={{ position: "absolute", left: 300, top: 240 }}>
              <Personnage type="fatou" f={f} expression="perplexe" tete={-6 + Math.sin(f / 10) * 3} brasD={[30, -115]} objetD="carnet" brasG={[25, -125]} objetG="stylo" hauteur={820} regard={1} />
            </div>
            <Papiers f={loc(0)} x={560} y={560} />
            <Bulle f={f} debut={14} x={1280} y={340} texte="Deux Flag, un poulet, un choukouya…" queue="bas" taille={42} />
            <Bulle f={f} debut={48} x={470} y={300} texte={<>Table 4… deux Flag<br />ou trois ?</>} queue="gauche" couleur={C.creme} taille={46} />
          </div>

          {/* ---------------- Station 1 : erreurs de calcul */}
          <div style={{ position: "absolute", left: 1920, top: 0, width: 1920, height: 1080, overflow: "hidden" }}>
            <SalleMaquis f={f} teinte={0.1} />
            <EtagereBar x={980} y={150} largeur={820} />
            <div style={{ position: "absolute", left: 1150, top: 300 }}>
              <Personnage type="koffi" f={f} expression={loc(1) > 50 ? "surpris" : "perplexe"} brasD={[25, -120]} brasG={[30, -100]} objetG="billets" hauteur={760} regard={-1} />
            </div>
            {/* Comptoir */}
            <div style={{ position: "absolute", left: 900, top: 700, width: 1020, height: 380, background: "linear-gradient(180deg,#7A4A26,#4A2C16)", borderTop: "22px solid #9C6434" }} />
            {/* Vieille calculatrice */}
            <div style={{ position: "absolute", left: 1080, top: 610, width: 170, height: 110, background: "#2B2B2B", borderRadius: 12, transform: "rotate(-6deg)" }}>
              <div style={{ margin: 12, height: 34, background: "#A9C49A", borderRadius: 4, fontFamily: TITRE, fontWeight: 800, fontSize: 26, textAlign: "right", padding: "2px 8px", color: "#1D2A18" }}>
                {loc(1) < 40 ? "5 400" : loc(1) < 70 ? "6 200" : "Err"}
              </div>
            </div>
            <div style={{ position: "absolute", left: 220, top: 260 }}>
              <Personnage type="client2" f={f} expression="fache" parle={loc(1) > 18 && loc(1) < 70} brasD={[60, 70 + Math.sin(f / 3) * 12]} hauteur={820} regard={1} graine={7} />
            </div>
            <Bulle f={f} debut={ST[1] + 16} x={460} y={240} texte={<>Ce n'est pas ce que<br />j'ai pris !</>} queue="gauche" taille={48} />
            {["5 400 F ?", "6 200 F ?", "4 800 F ?"].map((t, i) => {
              const s = ressort(f, ST[1] + 40 + i * 10, 10, 150);
              return (
                <div key={t} style={{ position: "absolute", left: 780 + i * 60, top: 330 + i * 110, fontFamily: TITRE, fontWeight: 800, fontSize: 60, color: C.erreur, transform: `scale(${s}) rotate(${(i - 1) * 8}deg)`, textShadow: "0 8px 24px rgba(0,0,0,0.5)" }}>
                  {t}
                </div>
              );
            })}
          </div>

          {/* ---------------- Station 2 : le stock qui disparaît */}
          <div style={{ position: "absolute", left: 3840, top: 0, width: 1920, height: 1080, overflow: "hidden" }}>
            <SalleMaquis f={f} teinte={0.25} />
            <div style={{ position: "absolute", left: 360, top: 220, transform: "scale(1.5)", transformOrigin: "0 0" }}>
              <EtagereBar x={0} y={0} largeur={800} masquees={(i) => {
                const ordre = [3, 9, 14, 6, 17, 1, 11, 20, 8];
                const k = ordre.indexOf(i);
                if (k < 0) return 1;
                return interpolate(loc(2), [10 + k * 7, 18 + k * 7], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
              }} />
            </div>
            <PointsInterrogation f={f} debut={ST[2] + 30} x={960} y={420} n={6} />
            <div style={{ position: "absolute", left: 0, right: 0, top: 860, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 96, color: "#fff", opacity: entre(f, ST[2] + 34, 14), textShadow: "0 10px 40px rgba(0,0,0,0.6)" }}>
              Où passe le stock ?
            </div>
          </div>

          {/* ---------------- Station 3 : le patron dans le flou */}
          <div style={{ position: "absolute", left: 5760, top: 0, width: 1920, height: 1080, overflow: "hidden" }}>
            <Salon f={f} />
            <CanapeDos x={160} y={560} largeur={860} />
            <div style={{ position: "absolute", left: 360, top: 250 }}>
              <Personnage type="patron" f={f} expression="triste" assis brasD={[20, -130]} objetD="telephone" brasG={[12, 10]} hauteur={780} regard={1} tete={4} />
            </div>
            <CanapeAssise x={160} y={770} largeur={860} />
            <Bulle f={f} debut={ST[3] + 14} x={760} y={290} texte={<>Combien on a vendu<br />ce soir ?</>} queue="gauche" taille={50} />
            <PointsInterrogation f={f} debut={ST[3] + 34} x={1350} y={720} n={4} couleur={C.creme} />
          </div>
        </div>
      </AbsoluteFill>

      {/* Pastilles des problèmes, une par station */}
      {f < RECAP && (
        <div style={{ position: "absolute", left: 0, right: 0, top: 930, display: "flex", justifyContent: "center" }}>
          {[
            { t: "Commandes oubliées", i: IC.ticket, d: 40 },
            { t: "Erreurs de calcul", i: IC.billets, d: ST[1] + 30 },
            { t: "Stock qui disparaît", i: IC.stock, d: ST[2] + 20 },
            { t: "Patron sans visibilité", i: IC.horsLigne, d: ST[3] + 26 },
          ].map((p, k) => {
            const actif = f >= p.d && (k === 3 || f < ST[k + 1] - 16);
            if (!actif) return null;
            return <Puce key={p.t} f={f} debut={p.d} texte={p.t} icone={p.i} couleur={C.erreur} taille={50} />;
          })}
        </div>
      )}

      {/* Récapitulatif */}
      {f >= RECAP && (
        <AbsoluteFill style={{ background: `rgba(11,21,16,${recap * 0.7})`, opacity: sortie }}>
          <div style={{ position: "absolute", left: 0, right: 0, top: 200, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 104, color: "#fff", opacity: recap, transform: `translateY(${(1 - recap) * 40}px)` }}>
            Le service devient <span style={{ color: C.orange }}>un casse-tête.</span>
          </div>
          <div style={{ position: "absolute", left: 210, right: 210, top: 470, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 40, justifyItems: "center" }}>
            {[
              { t: "Commandes oubliées", i: IC.ticket },
              { t: "Erreurs de calcul", i: IC.billets },
              { t: "Stock qui disparaît", i: IC.stock },
              { t: "Patron sans visibilité", i: IC.horsLigne },
            ].map((p, k) => <Puce key={p.t} f={f} debut={RECAP + 10 + k * 6} texte={p.t} icone={p.i} couleur={C.erreur} taille={52} sombre />)}
          </div>
          <div style={{ position: "absolute", left: 0, right: 0, top: 820, display: "flex", justifyContent: "center", gap: 16, opacity: entre(f, RECAP + 40, 14), fontFamily: TEXTE, fontWeight: 600, fontSize: 46, color: C.creme }}>
            <Icone code={IC.alerte} taille={52} couleur={C.orange} /> Et chaque soir, de l'argent qui se perd.
          </div>
        </AbsoluteFill>
      )}
      <Vignette />

      <Son nom="papier" a={12} volume={0.6} />
      <Son nom="erreur" a={40} volume={0.4} />
      <Son nom="whoosh-court" a={ST[1] - 18} volume={0.4} />
      <Son nom="erreur" a={ST[1] + 30} volume={0.4} />
      <Son nom="whoosh-court" a={ST[2] - 18} volume={0.4} />
      <Son nom="erreur" a={ST[2] + 20} volume={0.4} />
      <Son nom="whoosh-court" a={ST[3] - 18} volume={0.4} />
      <Son nom="erreur" a={ST[3] + 26} volume={0.4} />
      <Son nom="whoosh" a={RECAP - 4} volume={0.4} />
    </AbsoluteFill>
  );
};
