import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Doigt, Ordinateur, Paquet } from "../composants/Appareils";
import { Legende, SalleMaquis, TitreEtape, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Personnage } from "../composants/Personnage";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, milliers, ressort } from "../theme";

const D = DUREES.caisse;
const ARRIVEE = 30;
const ENCAISSER = 112;
const LOUPE = 140;
const VALIDER = 200;
const TAMPON = 210;
const TICKET = 228;
const TIROIR = 292;

/** Imprimante thermique et ticket qui sort. */
const Imprimante: React.FC<{ f: number }> = ({ f }) => {
  const sortie = interpolate(f, [TICKET, TICKET + 50], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const vibre = f > TICKET && f < TICKET + 50 ? Math.sin(f * 3) * 1.5 : 0;
  const lignes = [
    ["Restaurant Chez les Amani", "c"],
    ["FAC-2026-000001", "c"],
    ["2 × Castel 65 cl   1 400", "l"],
    ["1 × Poulet braisé  4 000", "l"],
    ["TOTAL           5 400 F", "b"],
    ["Reçu 6 000 · Rendu 600", "l"],
    ["Merci !", "c"],
  ];
  return (
    <div style={{ position: "absolute", left: 1150, top: 610, transform: `translateX(${vibre}px)` }}>
      {/* Ticket */}
      <div style={{ position: "absolute", left: 40, top: 30 - sortie * 300, width: 240, height: 310 * sortie + 10, overflow: "hidden", background: "#FFFDF7", boxShadow: "0 10px 30px rgba(0,0,0,0.3)", borderRadius: 4 }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: 0, padding: 16, fontFamily: "monospace", fontSize: 15, color: "#222", lineHeight: 1.7 }}>
          {lignes.map(([t, a], i) => (
            <div key={i} style={{ textAlign: a === "c" ? "center" : "left", fontWeight: a === "b" ? 800 : 500, borderTop: a === "b" ? "2px dashed #999" : undefined, fontSize: a === "b" ? 18 : 15 }}>{t}</div>
          ))}
        </div>
      </div>
      <div style={{ position: "relative", width: 320, height: 150, borderRadius: 26, background: "linear-gradient(180deg,#3A3F44,#1C1F22)", boxShadow: "0 30px 50px rgba(0,0,0,0.45)" }}>
        <div style={{ position: "absolute", left: 30, right: 30, top: 18, height: 14, borderRadius: 7, background: "#0D0F10" }} />
        <div style={{ position: "absolute", right: 30, bottom: 26, width: 18, height: 18, borderRadius: 9, background: f > TICKET && f < TICKET + 60 ? C.libre : "#555", boxShadow: f > TICKET && f < TICKET + 60 ? `0 0 14px ${C.libre}` : "none" }} />
        <div style={{ position: "absolute", left: 30, bottom: 22, fontFamily: TEXTE, fontWeight: 700, fontSize: 22, color: "#9AA0A6" }}>80 mm</div>
      </div>
    </div>
  );
};

export const Caisse: React.FC = () => {
  const f = useCurrentFrame();
  const notif = ressort(f, ARRIVEE, 10, 170);
  const loupe = ressort(f, LOUPE, 12, 150);
  const loupeSortie = interpolate(f, [VALIDER - 14, VALIDER - 4], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const tampon = ressort(f, TAMPON, 9, 240);
  const camera = interpolate(f, [0, D], [1.0, 1.04]);
  const sortie = interpolate(f, [D - 12, D], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ overflow: "hidden", opacity: sortie }}>
      <AbsoluteFill style={{ transform: `scale(${camera})` }}>
        <SalleMaquis f={f} teinte={0.2} />
        <div style={{ position: "absolute", left: 1420, top: 300 }}>
          <Personnage type="koffi" f={f} expression={f > TIROIR ? "joie" : f > TAMPON ? "sourire" : "neutre"} hauteur={760} regard={-1}
            brasG={f > TIROIR ? [150, 25] : [25, -115]} brasD={[12, 10]} graine={9} />
        </div>
        {/* Comptoir */}
        <div style={{ position: "absolute", left: 0, top: 760, width: 1920, height: 320, background: "linear-gradient(180deg,#7A4A26,#4A2C16)", borderTop: "22px solid #9C6434" }} />
        <Imprimante f={f} />
        <div style={{ position: "absolute", left: 120, top: 330 }}>
          <Ordinateur f={f} largeur={900} style={{ position: "relative" }}
            plans={[
              { src: "caisse", debut: 0 },
              { src: "encaissement", debut: ENCAISSER },
            ]}
            dessus={
              <>
                {f >= ARRIVEE && f < ENCAISSER + 10 && (
                  <div style={{ position: "absolute", left: "1%", top: "17.5%", width: "25.5%", height: "57%", borderRadius: 14, border: `5px solid ${C.orange}`, transform: `scale(${0.9 + notif * 0.1})`, opacity: notif * (0.6 + 0.4 * Math.sin(f / 4)), boxShadow: `0 0 30px ${C.orange}` }} />
                )}
                {f >= ARRIVEE && f < ENCAISSER && (
                  <div style={{ position: "absolute", right: "2%", top: "4%", transform: `scale(${notif})`, transformOrigin: "100% 0", display: "flex", alignItems: "center", gap: 12, padding: "12px 22px", borderRadius: 18, background: C.vert, color: "#fff", fontFamily: TEXTE, fontWeight: 700, fontSize: 26, boxShadow: "0 16px 40px rgba(0,0,0,0.4)" }}>
                    <Icone code={IC.cloche} taille={32} couleur={C.accentLumiere} /> Nouvelle commande · Table 11
                  </div>
                )}
                <Doigt f={f} apparition={74} disparition={VALIDER + 6} taille={110} points={[
                  { f: 104, x: 82, y: 23 },
                  { f: VALIDER, x: 70.4, y: 67.3 },
                ]} />
                {/* Loupe sur la monnaie à rendre */}
                {f >= LOUPE && f < VALIDER && (
                  <div style={{
                    position: "absolute", left: "12%", top: "36%", width: "52%", padding: "16px 26px", whiteSpace: "nowrap", borderRadius: 20, background: "#E9F7EF", border: `4px solid ${C.libre}`,
                    display: "flex", alignItems: "center", justifyContent: "space-between", transform: `scale(${1 + loupe * 0.35}) translateY(${-loupe * 30}px)`,
                    opacity: Math.min(1, loupe) * loupeSortie, boxShadow: "0 30px 60px rgba(0,0,0,0.35)",
                  }}>
                    <span style={{ fontFamily: TEXTE, fontWeight: 700, fontSize: 24, color: "#0B6B47" }}>Monnaie à rendre</span>
                    <span style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 50, color: "#0B6B47" }}>600 F</span>
                  </div>
                )}
                {/* Tampon PAYÉE */}
                {f >= TAMPON && (
                  <div style={{
                    position: "absolute", left: "50%", top: "45%", transform: `translate(-50%,-50%) rotate(-14deg) scale(${2.2 - tampon * 1.2})`, opacity: Math.min(1, tampon * 1.5),
                    padding: "14px 46px", border: `10px solid ${C.libre}`, borderRadius: 24, color: C.libre, fontFamily: TITRE, fontWeight: 800, fontSize: 120, letterSpacing: 10,
                    background: "rgba(255,255,255,0.85)", boxShadow: "0 20px 40px rgba(0,0,0,0.2)",
                  }}>PAYÉE</div>
                )}
              </>
            }
          />
        </div>
      </AbsoluteFill>
      <Paquet f={f} debut={-12} duree={40} de={[-120, 420]} a={[260, 520]} icone={<Icone code={IC.ticket} taille={56} couleur="#fff" />} />

      {/* Compteur de caisse */}
      {f >= TIROIR - 6 && (
        <div style={{ position: "absolute", left: 1110, top: 150, padding: "18px 30px", borderRadius: 24, background: "rgba(11,21,16,0.9)", border: `3px solid ${C.libre}`, transform: `scale(${ressort(f, TIROIR - 6, 11, 160)})`, fontFamily: TEXTE, fontWeight: 700, fontSize: 30, color: C.creme }}>
          Encaissé ce soir
          <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 64, color: "#fff" }}>
            {milliers(Math.round(interpolate(f, [TIROIR, TIROIR + 24], [2400, 7800], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }) / 100) * 100)} F
          </div>
        </div>
      )}

      <TitreEtape f={f} numero={2} titre="La caisse encaisse sans erreur" fin={TIROIR - 8} />
      <Legende f={f} debut={ENCAISSER + 6} fin={D - 6} texte="Monnaie calculée, facture numérotée, ticket imprimé." accent={["calculée,", "numérotée,", "imprimé."]} y={950} />
      <Vignette />

      <Son nom="notification" a={ARRIVEE} volume={0.6} />
      <Son nom="clic" a={104} />
      <Son nom="whoosh-court" a={ENCAISSER} volume={0.3} />
      <Son nom="pop" a={LOUPE} volume={0.5} />
      <Son nom="clic" a={VALIDER} />
      <Son nom="tampon" a={TAMPON} volume={0.8} />
      <Son nom="imprimante" a={TICKET} volume={0.55} />
      <Son nom="tiroir-caisse" a={TIROIR} volume={0.7} />
    </AbsoluteFill>
  );
};
