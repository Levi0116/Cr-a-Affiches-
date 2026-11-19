import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Doigt, Tablette, Telephone } from "../composants/Appareils";
import { CanapeAssise, CanapeDos, Legende, Particules, TitreEtape, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Personnage } from "../composants/Personnage";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, easeInOut, ressort } from "../theme";

const D = DUREES.patron;
const NOTIF = 40;
const VALIDER = 132;
const TABLEAU = 176;

export const Patron: React.FC = () => {
  const f = useCurrentFrame();
  const notif = ressort(f, NOTIF, 12, 150);
  const notifSortie = interpolate(f, [100, 112], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const valide = ressort(f, VALIDER + 4, 11, 170);
  const versGauche = interpolate(f, [TABLEAU - 10, TABLEAU + 20], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: easeInOut });
  const tab = ressort(f, TABLEAU, 14, 100);
  const sortie = interpolate(f, [D - 12, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ overflow: "hidden", opacity: sortie }}>
      {/* Salon de nuit, plus apaisé qu'au début */}
      <AbsoluteFill style={{ background: "linear-gradient(180deg,#14213D 0%,#1D2B4A 60%,#121A2E 100%)" }} />
      <div style={{ position: "absolute", left: -200, top: 120, width: 1100, height: 900, background: "radial-gradient(ellipse at 40% 30%, rgba(255,190,110,0.28), rgba(0,0,0,0) 65%)" }} />
      <Particules f={f} n={16} />
      <CanapeDos x={-60} y={620} largeur={820} />
      <div style={{ position: "absolute", left: 40, top: 330 }}>
        <Personnage type="patron" f={f} expression={f > VALIDER + 4 ? "joie" : f > NOTIF ? "neutre" : "sourire"} assis hauteur={760}
          brasD={[22, -128]} objetD="telephone" brasG={[12, 8]} regard={1} tete={f > VALIDER ? -3 : 3} />
      </div>
      <CanapeAssise x={-60} y={835} largeur={820} />
      <div style={{ position: "absolute", left: 1500, top: 230, padding: "12px 24px", borderRadius: 999, background: "rgba(255,243,214,0.12)", fontFamily: TEXTE, fontWeight: 700, fontSize: 30, color: C.creme, display: "flex", gap: 10, alignItems: "center" }}>
        <Icone code={IC.horloge} taille={34} couleur={C.orange} /> 21 h 40 · à la maison
      </div>

      {/* Téléphone agrandi */}
      <div style={{ position: "absolute", left: interpolate(versGauche, [0, 1], [880, 640]), top: 300, transform: `scale(${interpolate(versGauche, [0, 1], [1, 0.86])})`, transformOrigin: "50% 0" }}>
        <Telephone f={f} largeur={300} style={{ position: "relative" }}
          plans={[{ src: "telephone-validations", debut: 0 }]}
          dessus={
            <>
              <Doigt f={f} apparition={96} disparition={VALIDER + 10} taille={110} points={[{ f: VALIDER, x: 62.3, y: 38.9 }]} />
              {f >= VALIDER + 4 && (
                <div style={{ position: "absolute", left: "5%", right: "5%", top: "20%", height: "25%", borderRadius: 22, background: "rgba(5,150,105,0.94)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 6, transform: `scale(${valide})`, color: "#fff", fontFamily: TEXTE, fontWeight: 800, fontSize: 30 }}>
                  <Icone code={IC.ok} taille={64} couleur="#fff" />
                  Validé
                </div>
              )}
            </>
          }
        />
      </div>
      {/* Notification qui tombe */}
      {f >= NOTIF && f < 114 && (
        <div style={{
          position: "absolute", left: 1220, top: 300, width: 560, padding: "24px 28px", borderRadius: 28, background: "rgba(255,253,247,0.97)",
          boxShadow: "0 30px 70px rgba(0,0,0,0.5)", transform: `translateY(${(1 - notif) * -260}px)`, opacity: Math.min(1, notif * 1.4) * notifSortie,
          display: "flex", gap: 20, alignItems: "center",
        }}>
          <div style={{ width: 80, height: 80, borderRadius: 22, background: C.orange, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
            <Icone code={IC.cloche} taille={48} couleur="#fff" />
          </div>
          <div>
            <div style={{ fontFamily: TEXTE, fontWeight: 800, fontSize: 34, color: C.texte }}>Demande d'annulation</div>
            <div style={{ fontFamily: TEXTE, fontWeight: 600, fontSize: 28, color: "#5B6B60" }}>Awa · 3 Guinness · table 5</div>
          </div>
        </div>
      )}

      {/* Tableau de bord */}
      {f >= TABLEAU - 2 && (
        <div style={{ position: "absolute", left: 1000, top: 330, transform: `translateX(${(1 - tab) * 1000}px) rotate(${(1 - tab) * 6}deg)`, opacity: Math.min(1, tab * 1.5) }}>
          <Tablette f={f} largeur={820} style={{ position: "relative" }}
            plans={[{ src: "tableau-de-bord", debut: 0, zoom: { f: [TABLEAU + 40, TABLEAU + 80, D - 30, D], s: [1, 1.9, 1.9, 1.9], x: 34, y: 22 } }]}
          />
        </div>
      )}
      {f >= TABLEAU + 84 && (
        <div style={{ position: "absolute", left: 1000, top: 230, padding: "14px 28px", borderRadius: 999, background: C.libre, color: "#fff", fontFamily: TEXTE, fontWeight: 800, fontSize: 34, transform: `scale(${ressort(f, TABLEAU + 84, 11, 170)})`, display: "flex", gap: 12, alignItems: "center", boxShadow: `0 0 40px ${C.libre}88` }}>
          <Icone code={IC.hausse} taille={40} couleur="#fff" /> Ventes du soir, en direct
        </div>
      )}

      <TitreEtape f={f} numero={4} titre="Le patron suit tout, à distance" fin={TABLEAU + 70} />
      <Legende f={f} debut={TABLEAU + 10} fin={D - 6} texte="Il valide, contrôle et suit ses ventes, où qu'il soit." accent={["valide,", "contrôle", "suit"]} y={950} />
      <Vignette />

      <Son nom="notification" a={NOTIF} volume={0.65} />
      <Son nom="clic" a={VALIDER} />
      <Son nom="ding" a={VALIDER + 4} volume={0.6} />
      <Son nom="whoosh" a={TABLEAU - 6} volume={0.45} />
    </AbsoluteFill>
  );
};
