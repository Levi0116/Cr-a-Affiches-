import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { FondNuit, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, TITRE, entre, ressort } from "../theme";

const D = DUREES.fonctionnalites;

const CARTES = [
  { t: "Plan de salle en direct", i: IC.table, c: C.libre },
  { t: "Commande en 3 touches", i: IC.doigt, c: C.orange },
  { t: "Factures numérotées", i: IC.ticket, c: C.addition },
  { t: "Encaissement et monnaie", i: IC.billets, c: C.libre },
  { t: "Partage d'addition", i: IC.partage, c: C.occupee },
  { t: "Ardoises clients", i: IC.ardoise, c: C.addition },
  { t: "Stock automatique", i: IC.stock, c: C.orange },
  { t: "Alertes et validations", i: IC.cloche, c: C.occupee },
  { t: "Rapports Excel et PDF", i: IC.rapports, c: C.libre },
  { t: "Fonctionne hors ligne", i: IC.horsLigne, c: C.orange },
];

const MUR = ["rapports", "validations", "qr", "facture", "comptage", "stock", "tableau-de-bord", "caisse"];

export const Fonctionnalites: React.FC = () => {
  const f = useCurrentFrame();
  const titre = entre(f, 4, 18);
  const sortie = interpolate(f, [D - 20, D], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  // Projecteur qui passe sur chaque carte.
  const projecteur = interpolate(f, [170, 330], [-1, 10], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <FondNuit f={f} motif={false} />
      {/* Mur de captures en perspective */}
      <div style={{ position: "absolute", left: -400, top: -300, width: 2800, height: 1800, transform: "perspective(1800px) rotateX(28deg) rotateZ(-12deg)", opacity: 0.16 }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 640px)", gap: 40, transform: `translateY(${-f * 1.2}px)` }}>
          {[...MUR, ...MUR, ...MUR].map((m, i) => (
            <Img key={i} src={staticFile(`ecrans/${m}.png`)} style={{ width: 640, height: 400, objectFit: "cover", borderRadius: 18 }} />
          ))}
        </div>
      </div>
      <AbsoluteFill style={{ background: "radial-gradient(ellipse 70% 60% at 50% 55%, rgba(11,21,16,0.3), rgba(11,21,16,0.9))" }} />

      <AbsoluteFill style={{ transform: `scale(${1 + sortie * 0.1})`, opacity: 1 - sortie }}>
        <div style={{ position: "absolute", left: 0, right: 0, top: 100, textAlign: "center", opacity: titre, transform: `translateY(${(1 - titre) * 40}px)` }}>
          <div style={{ fontFamily: TEXTE, fontWeight: 700, fontSize: 34, letterSpacing: 8, color: C.orangeClair, textTransform: "uppercase" }}>Fonctionnalités</div>
          <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 96, color: "#fff" }}>Tout ce qu'il faut pour le service</div>
        </div>

        <div style={{ position: "absolute", left: 110, right: 110, top: 340, display: "grid", gridTemplateColumns: "repeat(5, 1fr)", gap: 26 }}>
          {CARTES.map((c, i) => {
            const d = 26 + i * 9;
            const s = ressort(f, d, 12, 130);
            const lumiere = Math.max(0, 1 - Math.abs(projecteur - i) / 1.2);
            const flotte = Math.sin((f + i * 13) / 26) * 5;
            return (
              <div key={c.t} style={{
                height: 290, borderRadius: 32, padding: "34px 28px", background: `linear-gradient(160deg, rgba(255,255,255,${0.1 + lumiere * 0.08}), rgba(255,255,255,0.03))`,
                border: `2px solid ${lumiere > 0.1 ? c.c : "rgba(255,226,174,0.16)"}`, boxShadow: lumiere > 0.1 ? `0 0 ${50 * lumiere}px ${c.c}88` : "0 20px 40px rgba(0,0,0,0.3)",
                transform: `translateY(${(1 - s) * 140 + flotte - lumiere * 14}px) scale(${0.85 + 0.15 * Math.min(1, s)})`, opacity: Math.min(1, s * 1.5),
                display: "flex", flexDirection: "column", justifyContent: "space-between",
              }}>
                <div style={{ width: 100, height: 100, borderRadius: 28, background: c.c, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: `0 14px 30px ${c.c}66` }}>
                  <Icone code={c.i} taille={60} couleur="#fff" />
                </div>
                <div style={{ fontFamily: TITRE, fontWeight: 800, fontSize: 38, lineHeight: 1.12, color: "#fff" }}>{c.t}</div>
              </div>
            );
          })}
        </div>
      </AbsoluteFill>
      <Vignette />

      {CARTES.map((_, i) => (i % 2 === 0 ? <Son key={i} nom="pop" a={26 + i * 9} volume={0.35} /> : null))}
      <Son nom="whoosh" a={170} volume={0.3} />
    </AbsoluteFill>
  );
};
