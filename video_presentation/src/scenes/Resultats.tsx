import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Puce } from "../composants/Decor";
import { Personnage } from "../composants/Personnage";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, entre, milliers, ressort } from "../theme";

const D = DUREES.resultats;

const hasard = (n: number) => {
  const x = Math.sin(n * 33.71 + 4.1) * 43758.5453;
  return x - Math.floor(x);
};

const Confettis: React.FC<{ f: number }> = ({ f }) => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    {Array.from({ length: 60 }).map((_, i) => {
      const t = f - 20 - hasard(i) * 40;
      if (t < 0) return null;
      const couleurs = [C.orange, C.libre, C.occupee, C.vert, C.addition];
      return (
        <div key={i} style={{
          position: "absolute", left: hasard(i + 7) * 1920 + Math.sin(t / 10 + i) * 40, top: -40 + t * (4 + hasard(i + 3) * 4),
          width: 14 + hasard(i + 1) * 12, height: 8 + hasard(i + 2) * 10, background: couleurs[i % couleurs.length],
          transform: `rotate(${t * (6 + hasard(i) * 10)}deg)`, opacity: 0.9, borderRadius: 2,
        }} />
      );
    })}
  </AbsoluteFill>
);

const Statistique: React.FC<{ f: number; debut: number; valeur: (t: number) => string; texte: string; couleur: string }> = ({ f, debut, valeur, texte, couleur }) => {
  const s = ressort(f, debut, 12, 120);
  const t = interpolate(f, [debut + 4, debut + 40], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: (x) => 1 - Math.pow(1 - x, 3) });
  return (
    <div style={{
      width: 520, height: 300, borderRadius: 36, background: "#FFFFFF", padding: "34px 40px", boxShadow: "0 30px 70px rgba(11,58,28,0.18)",
      borderTop: `10px solid ${couleur}`, transform: `translateY(${(1 - s) * 120}px)`, opacity: Math.min(1, s * 1.5),
    }}>
      <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 104, lineHeight: 1, color: couleur, whiteSpace: "nowrap" }}>{valeur(t)}</div>
      <div style={{ fontFamily: TEXTE, fontWeight: 600, fontSize: 36, lineHeight: 1.2, color: C.texte, marginTop: 18 }}>{texte}</div>
    </div>
  );
};

export const Resultats: React.FC = () => {
  const f = useCurrentFrame();
  const titre = entre(f, 2, 18);
  const sortie = interpolate(f, [D - 12, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const saut = (d: number) => Math.max(0, Math.sin(Math.max(0, f - d) / 7)) * (f > d ? 16 : 0);

  return (
    <AbsoluteFill style={{ background: `radial-gradient(ellipse 90% 80% at 50% 30%, #FFF8E8, ${C.creme} 60%, ${C.cremeFonce})`, overflow: "hidden", opacity: sortie }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: 90, textAlign: "center", opacity: titre, transform: `translateY(${(1 - titre) * 40}px)` }}>
        <span style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 100, color: C.vert }}>Les résultats </span>
        <span style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 100, color: C.orange }}>dès le premier soir</span>
      </div>

      <div style={{ position: "absolute", left: 120, right: 120, top: 260, display: "flex", justifyContent: "space-between" }}>
        <Statistique f={f} debut={18} couleur={C.libre} valeur={(t) => `${Math.round(t * 100)} %`} texte="des factures calculées automatiquement" />
        <Statistique f={f} debut={28} couleur={C.orange} valeur={(t) => `${milliers(Math.round((1 - t) * 15) * 100)} F`} texte="d'écart à la clôture lors de la soirée test*" />
        <Statistique f={f} debut={38} couleur={C.addition} valeur={(t) => (t < 1 ? `${Math.round(t * 24)} h` : "24 h/24")} texte="de suivi à distance pour le patron" />
      </div>

      {/* L'équipe, enfin sereine */}
      <div style={{ position: "absolute", left: 30, top: 600 + 0 }}>
        <div style={{ position: "absolute", left: 0, top: -saut(70) }}>
          <Personnage type="fatou" f={f} expression="joie" brasD={[150, 20]} brasG={[20, 10]} hauteur={640} graine={11} />
        </div>
        <div style={{ position: "absolute", left: 230, top: -saut(80) }}>
          <Personnage type="koffi" f={f} expression="joie" brasG={[150, 20]} brasD={[150, 20]} hauteur={640} graine={12} />
        </div>
        <div style={{ position: "absolute", left: 460, top: -saut(90) }}>
          <Personnage type="patron" f={f} expression="joie" brasD={[30, -120]} objetD="telephone" brasG={[150, 20]} hauteur={640} graine={13} />
        </div>
      </div>

      <div style={{ position: "absolute", left: 900, top: 640, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 28 }}>
        {[
          { t: "Moins d'erreurs", i: IC.ok, c: C.libre },
          { t: "Service plus rapide", i: IC.eclair, c: C.orange },
          { t: "Stock maîtrisé", i: IC.stock, c: C.occupee },
          { t: "Patron serein", i: IC.bouclier, c: C.addition },
        ].map((p, k) => <Puce key={p.t} f={f} debut={100 + k * 12} texte={p.t} icone={p.i} couleur={p.c} taille={40} />)}
      </div>
      <div style={{ position: "absolute", left: 900, top: 930, fontFamily: TEXTE, fontWeight: 500, fontSize: 28, color: "#5B6B60", opacity: entre(f, 150, 14) }}>
        * Soirée simulée : 3 tablettes, environ 100 commandes.
      </div>
      <Confettis f={f} />

      <Son nom="ding" a={20} volume={0.5} />
      <Son nom="ding" a={30} volume={0.4} />
      <Son nom="ding" a={40} volume={0.4} />
      {[0, 1, 2, 3].map((k) => <Son key={k} nom="pop" a={100 + k * 12} volume={0.4} />)}
    </AbsoluteFill>
  );
};
