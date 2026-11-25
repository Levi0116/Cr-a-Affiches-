import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Ordinateur, Tablette, Telephone } from "../composants/Appareils";
import { FondNuit, Legende, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, entre, ressort } from "../theme";

const D = DUREES.concept;

/** Point lumineux qui parcourt une courbe de Bézier quadratique. */
const Impulsion: React.FC<{ f: number; p0: number[]; p1: number[]; p2: number[]; decalage: number; couleur: string }> = ({ f, p0, p1, p2, decalage, couleur }) => {
  const t = ((f + decalage) % 50) / 50;
  const x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0];
  const y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1];
  return <circle cx={x} cy={y} r={9} fill={couleur} opacity={Math.sin(t * Math.PI)} style={{ filter: `drop-shadow(0 0 10px ${couleur})` }} />;
};

export const Concept: React.FC = () => {
  const f = useCurrentFrame();
  const t1 = entre(f, 2, 18);
  const t1Sortie = interpolate(f, [118, 130], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const t2 = entre(f, 128, 18);
  const sortie = interpolate(f, [D - 10, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const sTab = ressort(f, 30, 13, 110);
  const sOrdi = ressort(f, 40, 13, 110);
  const sTel = ressort(f, 50, 13, 110);
  const liens = entre(f, 70, 30);
  const nuage = ressort(f, 62, 10, 140);

  // Points d'ancrage (px) : nuage et appareils.
  const N = [960, 300];
  const A = [[400, 470], [960, 420], [1610, 400]];
  const ctrl = [[560, 300], [960, 360], [1400, 300]];

  // Pastille hors ligne → synchronisé.
  const horsLigne = f >= 170 && f < 225;
  const pastille = ressort(f, 170, 12, 160);

  const appareil = (s: number, base: number): React.CSSProperties => ({
    transform: `translateY(${(1 - s) * 260 + Math.sin((f + base) / 30) * 6}px) scale(${0.8 + 0.2 * s})`, opacity: Math.min(1, s * 1.4),
  });

  return (
    <AbsoluteFill style={{ opacity: sortie }}>
      <FondNuit f={f} halo={C.libre} />

      {/* Titres */}
      <div style={{ position: "absolute", left: 0, right: 0, top: 96, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 104, color: "#fff", opacity: t1 * t1Sortie, transform: `translateY(${(1 - t1) * 40}px)` }}>
        Une <span style={{ color: C.orange }}>seule</span> plateforme.
      </div>
      {f >= 125 && (
        <div style={{ position: "absolute", left: 0, right: 0, top: 96, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 96, color: "#fff", opacity: t2, transform: `translateY(${(1 - t2) * 40}px)` }}>
          Trois écrans, <span style={{ color: C.orange }}>synchronisés en direct.</span>
        </div>
      )}

      {/* Liens nuage ↔ appareils */}
      <svg width="1920" height="1080" style={{ position: "absolute", inset: 0 }}>
        {A.map((a, i) => (
          <path key={i} d={`M${N[0]} ${N[1]} Q${ctrl[i][0]} ${ctrl[i][1]} ${a[0]} ${a[1]}`} stroke={C.creme} strokeOpacity={0.35} strokeWidth={4} strokeDasharray="14 12"
            fill="none" pathLength={1} style={{ strokeDashoffset: -f / 40 }} opacity={liens} />
        ))}
        {f > 90 && A.map((a, i) => (
          <React.Fragment key={i}>
            <Impulsion f={f} p0={N} p1={ctrl[i]} p2={a} decalage={i * 17} couleur={C.orange} />
            <Impulsion f={f} p0={a} p1={ctrl[i]} p2={N} decalage={i * 17 + 25} couleur={C.libre} />
          </React.Fragment>
        ))}
      </svg>

      {/* Nuage */}
      <div style={{ position: "absolute", left: N[0] - 80, top: N[1] - 80, width: 160, height: 160, borderRadius: "50%", background: `radial-gradient(circle, ${C.vertClair}, ${C.vert})`, border: `4px solid ${C.creme}55`, display: "flex", alignItems: "center", justifyContent: "center", transform: `scale(${nuage})`, boxShadow: `0 0 80px ${C.libre}88` }}>
        <Icone code={IC.sync} taille={90} couleur="#fff" style={{ transform: `rotate(${f * 2}deg)` }} />
      </div>

      {/* Appareils */}
      <div style={{ position: "absolute", left: 110, top: 470, ...appareil(sTab, 0) }}>
        <Tablette f={f} plans={[{ src: "salle", debut: 0 }]} largeur={600} style={{ position: "relative" }}>
          {f >= 170 && (
            <div style={{ position: "absolute", left: "50%", top: "6%", transform: `translateX(-50%) scale(${pastille})`, display: "flex", alignItems: "center", gap: 10, padding: "10px 22px", borderRadius: 999, background: horsLigne ? C.occupee : C.libre, color: "#fff", fontFamily: TEXTE, fontWeight: 700, fontSize: 24, whiteSpace: "nowrap", boxShadow: "0 10px 20px rgba(0,0,0,0.4)" }}>
              <Icone code={horsLigne ? IC.horsLigne : IC.ok} taille={28} couleur="#fff" />
              {horsLigne ? "Hors ligne – 2 en attente" : "Synchronisé"}
            </div>
          )}
        </Tablette>
      </div>
      <div style={{ position: "absolute", left: 640, top: 420, ...appareil(sOrdi, 20) }}>
        <Ordinateur f={f} plans={[{ src: "caisse", debut: 0 }]} largeur={660} style={{ position: "relative" }} />
      </div>
      <div style={{ position: "absolute", left: 1490, top: 400, ...appareil(sTel, 40) }}>
        <Telephone f={f} plans={[{ src: "telephone-tableau", debut: 0 }]} largeur={240} style={{ position: "relative" }} />
      </div>

      {/* Étiquettes */}
      {[
        { t: "Tablettes · serveuses", x: 410, d: 60 },
        { t: "Caisse", x: 970, d: 68 },
        { t: "Téléphone · patron", x: 1610, d: 76 },
      ].map((e) => (
        <div key={e.t} style={{ position: "absolute", left: e.x, top: 990, transform: `translateX(-50%) translateY(${(1 - entre(f, e.d, 16)) * 20}px)`, opacity: entre(f, e.d, 16) * (f > 160 ? interpolate(f, [160, 170], [1, 0], { extrapolateRight: "clamp" }) : 1), fontFamily: TEXTE, fontWeight: 700, fontSize: 44, color: C.creme, whiteSpace: "nowrap" }}>
          {e.t}
        </div>
      ))}
      <Legende f={f} debut={172} fin={D} texte="Même sans internet, le service continue." accent={["internet,"]} y={950} />
      <Vignette />

      <Son nom="whoosh-court" a={28} volume={0.4} />
      <Son nom="pop" a={32} volume={0.45} />
      <Son nom="pop" a={42} volume={0.45} />
      <Son nom="pop" a={52} volume={0.45} />
      <Son nom="ding" a={64} volume={0.35} />
      <Son nom="clic" a={170} volume={0.5} />
      <Son nom="ding" a={225} volume={0.45} />
    </AbsoluteFill>
  );
};
