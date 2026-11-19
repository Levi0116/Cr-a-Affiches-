import React from "react";
import { AbsoluteFill, interpolate, useCurrentFrame } from "remotion";
import { Doigt, Paquet, Tablette } from "../composants/Appareils";
import { Bulle, Legende, SalleMaquis, TableResto, TitreEtape, Vignette } from "../composants/Decor";
import { Icone } from "../composants/Icone";
import { Personnage } from "../composants/Personnage";
import { Son } from "../composants/Son";
import { C, DUREES, IC, TEXTE, ressort } from "../theme";

const D = DUREES.serveuse;
const T_TABLE = 118;
const T_PLUS = 178;
const T_GRILL = 204;
const T_VALIDER = 246;
const ENVOYE = 254;

export const Serveuse: React.FC = () => {
  const f = useCurrentFrame();
  const sTab = ressort(f, 40, 14, 100);
  const envoye = ressort(f, ENVOYE, 11, 170);
  // Légère poussée de caméra sur la tablette.
  const zoom = interpolate(f, [60, D], [1, 1.05], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const sortieTab = interpolate(f, [D - 40, D - 10], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      <SalleMaquis f={f} teinte={0.3} />
      {/* Clients attablés */}
      <div style={{ position: "absolute", left: 300, top: 470 }}>
        <Personnage type="client1" f={f} expression="sourire" parle={f > 22 && f < 100} brasD={[55, 60]} hauteur={560} regard={-1} graine={5} assis />
      </div>
      <div style={{ position: "absolute", left: 540, top: 470 }}>
        <Personnage type="client2" f={f} expression="sourire" hauteur={560} regard={-1} graine={6} assis />
      </div>
      <TableResto x={270} y={800} largeur={600} />
      <div style={{ position: "absolute", left: 20, top: 330 }}>
        <Personnage type="fatou" f={f} expression={f > ENVOYE ? "joie" : "sourire"} brasD={[25, -118]} objetD="tablette" hauteur={780} regard={1} />
      </div>
      <Bulle f={f} debut={24} fin={130} x={560} y={480} texte={<>Deux Flag, un poulet braisé<br />et un choukouya !</>} queue="bas" taille={40} />

      {/* Tablette agrandie */}
      <div style={{
        position: "absolute", left: 900, top: 300, transform: `translateX(${(1 - sTab) * 900 + sortieTab * 80}px) rotate(${(1 - sTab) * 8}deg) scale(${zoom})`,
        transformOrigin: "50% 50%", opacity: Math.min(1, sTab * 1.5),
      }}>
        <Tablette
          f={f}
          largeur={920}
          style={{ position: "relative" }}
          plans={[
            { src: "salle", debut: 0 },
            { src: "commande", debut: T_TABLE + 10 },
            { src: "commande-envoyee", debut: ENVOYE },
          ]}
          dessus={
            <>
              <Doigt f={f} apparition={86} disparition={D - 50} taille={130} points={[
                { f: T_TABLE, x: 9.4, y: 88.5 },
                { f: T_PLUS, x: 95.5, y: 34.7 },
                { f: T_GRILL, x: 20.5, y: 40 },
                { f: T_VALIDER, x: 83.3, y: 93 },
              ]} />
              {f >= ENVOYE && (
                <div style={{
                  position: "absolute", left: "50%", top: "40%", transform: `translate(-50%,-50%) scale(${envoye})`, display: "flex", alignItems: "center", gap: 18,
                  padding: "24px 42px", borderRadius: 999, background: C.libre, color: "#fff", fontFamily: TEXTE, fontWeight: 800, fontSize: 46,
                  boxShadow: `0 20px 60px rgba(0,0,0,0.5), 0 0 60px ${C.libre}`, whiteSpace: "nowrap", opacity: interpolate(f, [D - 50, D - 40], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" }),
                }}>
                  <Icone code={IC.ok} taille={56} couleur="#fff" /> Envoyé en caisse
                </div>
              )}
            </>
          }
        />
      </div>

      <Paquet f={f} debut={D - 46} duree={40} de={[1360, 560]} a={[2050, 420]} icone={<Icone code={IC.ticket} taille={56} couleur="#fff" />} />

      <TitreEtape f={f} numero={1} titre="La serveuse prend la commande" fin={D} />
      <Legende f={f} debut={140} fin={D - 6} texte="3 touches, et la commande part directement en caisse." accent={["3", "caisse."]} y={950} />
      <Vignette />

      <Son nom="whoosh-court" a={40} volume={0.4} />
      <Son nom="clic" a={T_TABLE} />
      <Son nom="whoosh-court" a={T_TABLE + 8} volume={0.25} />
      <Son nom="pop" a={T_PLUS} volume={0.6} />
      <Son nom="pop" a={T_GRILL} volume={0.6} />
      <Son nom="clic" a={T_VALIDER} />
      <Son nom="ding" a={ENVOYE} volume={0.6} />
      <Son nom="whoosh" a={D - 46} volume={0.45} />
    </AbsoluteFill>
  );
};
