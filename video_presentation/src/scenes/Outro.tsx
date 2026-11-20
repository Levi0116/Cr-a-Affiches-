import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { FondNuit, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, entre, ressort } from "../theme";

const D = DUREES.outro;

export const Outro: React.FC = () => {
  const f = useCurrentFrame();
  const logo = ressort(f, 6, 11, 110);
  const nom = entre(f, 30, 20);
  const ligne = entre(f, 52, 22);
  const tel = ressort(f, 80, 12, 140);
  const slogan = entre(f, 120, 22);
  const noir = interpolate(f, [D - 40, D - 4], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill>
      <FondNuit f={f} />
      <div style={{
        position: "absolute", left: 960, top: 270, width: 300, height: 300, borderRadius: "50%", overflow: "hidden", background: "#fff",
        transform: `translate(-50%,-50%) scale(${logo})`, boxShadow: `0 0 0 8px ${C.creme}, 0 0 100px ${C.orange}99`,
      }}>
        <Img src={staticFile("logo_amani.png")} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 450, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 104, color: "#fff", opacity: nom, transform: `translateY(${(1 - nom) * 40}px)`, letterSpacing: (1 - nom) * 20 }}>
        Restaurant Chez les Amani
      </div>
      <div style={{ position: "absolute", left: "50%", top: 590, width: 700 * ligne, height: 6, marginLeft: -350 * ligne, borderRadius: 3, background: `linear-gradient(90deg, ${C.orange}, ${C.accentLumiere})` }} />
      <div style={{ position: "absolute", left: 0, right: 0, top: 620, textAlign: "center", fontFamily: TEXTE, fontWeight: 600, fontSize: 46, color: C.creme, opacity: ligne }}>
        Commandes · Caisse · Stock · Contrôle
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 730, display: "flex", justifyContent: "center" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 20, padding: "20px 44px", borderRadius: 999, background: C.orange, transform: `scale(${tel})`, boxShadow: `0 20px 60px ${C.orange}77`, fontFamily: TITRE, fontWeight: 800, fontSize: 56, color: "#fff" }}>
          <Icone code={IC.telephone} taille={58} couleur="#fff" /> +226 65 91 11 76
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 870, textAlign: "center", fontFamily: TITRE, fontWeight: 800, fontSize: 64, color: C.accentLumiere, opacity: slogan, transform: `translateY(${(1 - slogan) * 30}px)` }}>
        Prêt pour le service.
      </div>
      <Vignette />
      <AbsoluteFill style={{ background: "#000", opacity: noir }} />

      <Son nom="pop" a={8} volume={0.55} />
      <Son nom="whoosh-court" a={30} volume={0.35} />
      <Son nom="ding" a={82} volume={0.5} />
    </AbsoluteFill>
  );
};
