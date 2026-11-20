import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { EtagereBar, Legende, SalleMaquis, TitreEtape, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, entre, ressort } from "../theme";

const D = DUREES.stock;
const RETRAITS = [34, 50, 66];
const ALERTE = 112;

export const Stock: React.FC = () => {
  const f = useCurrentFrame();
  const carte = ressort(f, 14, 13, 120);
  const nb = 46 - RETRAITS.filter((r) => f >= r + 6).length;
  const jauge = interpolate(f, [RETRAITS[0], RETRAITS[2] + 12], [46 / 60, 43 / 60], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const alerte = ressort(f, ALERTE, 11, 150);
  const secousse = f > ALERTE && f < ALERTE + 30 ? Math.sin((f - ALERTE) * 1.4) * 14 * (1 - (f - ALERTE) / 30) : 0;
  const sortie = interpolate(f, [D - 12, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ overflow: "hidden", opacity: sortie }}>
      <SalleMaquis f={f} teinte={0.35} />
      {/* Étagère : trois bouteilles de la première rangée partent */}
      <div style={{ position: "absolute", left: 110, top: 380, transform: "scale(1.15)", transformOrigin: "0 0" }}>
        <EtagereBar x={0} y={0} largeur={720} masquees={(i) => {
          const k = [0, 1, 2].indexOf(i);
          if (k < 0) return 1;
          return interpolate(f, [RETRAITS[k], RETRAITS[k] + 10], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
        }} />
      </div>
      {RETRAITS.map((r, k) => {
        if (f < r) return null;
        const t = f - r;
        return (
          <div key={k} style={{ position: "absolute", left: 160 + k * 74, top: 380 - t * 2.4, fontFamily: TITRE, fontWeight: 800, fontSize: 60, color: C.orange, opacity: interpolate(t, [0, 6, 26, 34], [0, 1, 1, 0], { extrapolateRight: "clamp" }), textShadow: "0 6px 20px rgba(0,0,0,0.5)" }}>−1</div>
        );
      })}

      {/* Carte article */}
      <div style={{
        position: "absolute", left: 1010, top: 360, width: 800, padding: 44, borderRadius: 40, background: "#FFFDF7",
        boxShadow: "0 40px 90px rgba(0,0,0,0.45)", transform: `translateY(${(1 - carte) * 120}px) scale(${0.9 + 0.1 * carte})`, opacity: Math.min(1, carte * 1.5),
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: 24 }}>
          <div style={{ width: 96, height: 96, borderRadius: 26, background: "#E3F4EA", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Icone code={IC.bar} taille={60} couleur={C.libre} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 56, color: C.texte }}>Flag 65 cl</div>
            <div style={{ fontFamily: TEXTE, fontWeight: 600, fontSize: 32, color: C.libre }}>En stock · seuil 12</div>
          </div>
          <div style={{ textAlign: "right" }}>
            <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 120, color: C.texte, lineHeight: 1, transform: `scale(${RETRAITS.some((r) => f >= r + 6 && f < r + 14) ? 1.12 : 1})` }}>{nb}</div>
            <div style={{ fontFamily: TEXTE, fontWeight: 600, fontSize: 28, color: "#6B7A70" }}>bouteilles</div>
          </div>
        </div>
        <div style={{ marginTop: 34, height: 22, borderRadius: 11, background: "#E8E2D4", overflow: "hidden" }}>
          <div style={{ width: `${jauge * 100}%`, height: "100%", borderRadius: 11, background: `linear-gradient(90deg, ${C.libre}, #34D399)` }} />
        </div>
        <div style={{ marginTop: 20, fontFamily: TEXTE, fontWeight: 600, fontSize: 30, color: "#6B7A70", opacity: entre(f, RETRAITS[0], 10) }}>
          Table 11 · 2 Flag servies <span style={{ color: C.orange }}>→ retirées du stock</span>
        </div>
      </div>

      {/* Alerte stock bas */}
      {f >= ALERTE && (
        <div style={{
          position: "absolute", left: 1010, top: 130, width: 800, display: "flex", alignItems: "center", gap: 26, padding: "26px 34px", borderRadius: 30,
          background: C.vert, border: `3px solid ${C.occupee}`, boxShadow: `0 30px 70px rgba(0,0,0,0.5), 0 0 50px ${C.occupee}66`,
          transform: `translateY(${(1 - alerte) * -200}px)`, opacity: Math.min(1, alerte * 1.4),
        }}>
          <div style={{ width: 90, height: 90, borderRadius: "50%", background: C.occupee, display: "flex", alignItems: "center", justifyContent: "center", transform: `rotate(${secousse}deg)` }}>
            <Icone code={IC.cloche} taille={56} couleur="#fff" />
          </div>
          <div>
            <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 44, color: "#fff" }}>Stock bas : Guinness</div>
            <div style={{ fontFamily: TEXTE, fontWeight: 600, fontSize: 32, color: C.accentLumiere }}>Reste 3 bouteilles · patron prévenu</div>
          </div>
        </div>
      )}

      <TitreEtape f={f} numero={3} titre="Le stock se met à jour tout seul" fin={ALERTE - 4} />
      <Legende f={f} debut={24} fin={D - 6} texte="Chaque vente retire les bouteilles du stock, automatiquement." accent={["automatiquement."]} y={950} />
      <Vignette />

      {RETRAITS.map((r) => <Son key={r} nom="pop" a={r} volume={0.45} />)}
      <Son nom="notification" a={ALERTE} volume={0.65} />
    </AbsoluteFill>
  );
};
