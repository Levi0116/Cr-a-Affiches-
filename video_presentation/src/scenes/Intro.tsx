import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { FondNuit, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, easeInOut, entre, ressort } from "../theme";

const D = DUREES.intro;

export const Intro: React.FC = () => {
  const f = useCurrentFrame();
  const anneau = ressort(f, 4, 14, 90);
  const logo = ressort(f, 14, 10, 120);
  // Le logo monte vers le haut pour laisser place au titre.
  const monte = interpolate(f, [100, 135], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut });
  const tailleLogo = interpolate(monte, [0, 1], [400, 250]);
  const yLogo = interpolate(monte, [0, 1], [540, 300]);
  const sortie = interpolate(f, [D - 26, D], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut });
  const balayage = interpolate(f, [40, 80], [-120, 220], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  const titre = "Votre restaurant, piloté en temps réel".split(" ");
  const piliers = [
    { t: "Commandes", i: IC.doigt },
    { t: "Caisse", i: IC.billets },
    { t: "Stock", i: IC.stock },
    { t: "Contrôle", i: IC.bouclier },
  ];

  return (
    <AbsoluteFill style={{ transform: `scale(${1 + sortie * 0.25})`, opacity: 1 - sortie * 0.9, filter: `blur(${sortie * 12}px)` }}>
      <FondNuit f={f} />
      {/* Anneaux lumineux */}
      {[0, 1, 2].map((i) => {
        const a = ressort(f, 4 + i * 6, 16, 70);
        return (
          <div key={i} style={{
            position: "absolute", left: 960, top: yLogo, width: tailleLogo * (1.25 + i * 0.35), height: tailleLogo * (1.25 + i * 0.35),
            transform: `translate(-50%,-50%) scale(${a})`, borderRadius: "50%", border: `${3 - i}px solid ${i === 0 ? C.orange : C.creme}`,
            opacity: (0.6 - i * 0.18) * anneau,
          }} />
        );
      })}
      {/* Logo */}
      <div style={{
        position: "absolute", left: 960, top: yLogo, width: tailleLogo, height: tailleLogo, borderRadius: "50%", overflow: "hidden",
        transform: `translate(-50%,-50%) scale(${logo}) rotate(${(1 - logo) * -25}deg)`,
        boxShadow: `0 0 0 8px ${C.creme}, 0 0 90px ${C.orange}AA, 0 30px 80px rgba(0,0,0,0.6)`, background: "#fff",
      }}>
        <Img src={staticFile("logo_amani.png")} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        <div style={{ position: "absolute", top: 0, bottom: 0, left: `${balayage}%`, width: "40%", background: "linear-gradient(100deg, rgba(255,255,255,0) 0%, rgba(255,255,255,0.55) 50%, rgba(255,255,255,0) 100%)" }} />
      </div>

      {/* Titre */}
      <div style={{ position: "absolute", left: 100, right: 100, top: 480, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 104, color: "#fff", lineHeight: 1.08 }}>
        {titre.map((m, i) => {
          const e = entre(f, 125 + i * 4, 18);
          const estAccent = i >= 4;
          return (
            <span key={i} style={{ display: "inline-block", marginRight: "0.25em", opacity: e, transform: `translateY(${(1 - e) * 50}px) rotate(${(1 - e) * 6}deg)`, color: estAccent ? C.orange : "#fff" }}>{m}</span>
          );
        })}
      </div>

      {/* Piliers */}
      <div style={{ position: "absolute", left: 0, right: 0, top: 760, display: "flex", justifyContent: "center", gap: 28 }}>
        {piliers.map((p, i) => {
          const s = ressort(f, 165 + i * 7, 12, 160);
          return (
            <div key={p.t} style={{
              display: "flex", alignItems: "center", gap: 16, padding: "18px 34px 18px 22px", borderRadius: 999,
              background: "rgba(255,243,214,0.08)", border: "2px solid rgba(255,226,174,0.25)", transform: `scale(${s})`, opacity: Math.min(1, s),
              fontFamily: TEXTE, fontWeight: 700, fontSize: 46, color: C.creme,
            }}>
              <Icone code={p.i} taille={50} couleur={C.orange} />
              {p.t}
            </div>
          );
        })}
      </div>
      <Vignette />

      <Son nom="whoosh" a={2} volume={0.55} />
      <Son nom="pop" a={16} volume={0.6} />
      <Son nom="whoosh-court" a={102} volume={0.45} />
      {[0, 1, 2, 3].map((i) => <Son key={i} nom="clic" a={165 + i * 7} volume={0.35} />)}
    </AbsoluteFill>
  );
};
