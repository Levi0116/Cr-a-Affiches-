import React from "react";
import { AbsoluteFill, Series, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Audio } from "@remotion/media";
import { Caisse } from "./scenes/Caisse";
import { Concept } from "./scenes/Concept";
import { Fonctionnalites } from "./scenes/Fonctionnalites";
import { Intro } from "./scenes/Intro";
import { Outro } from "./scenes/Outro";
import { Patron } from "./scenes/Patron";
import { Probleme } from "./scenes/Probleme";
import { Resultats } from "./scenes/Resultats";
import { Serveuse } from "./scenes/Serveuse";
import { Stock } from "./scenes/Stock";
import { Son } from "./composants/Son";
import { C, DUREES, DUREE_TOTALE } from "./theme";

const ORDRE: { cle: keyof typeof DUREES; C: React.FC }[] = [
  { cle: "intro", C: Intro },
  { cle: "probleme", C: Probleme },
  { cle: "concept", C: Concept },
  { cle: "serveuse", C: Serveuse },
  { cle: "caisse", C: Caisse },
  { cle: "stock", C: Stock },
  { cle: "patron", C: Patron },
  { cle: "fonctionnalites", C: Fonctionnalites },
  { cle: "resultats", C: Resultats },
  { cle: "outro", C: Outro },
];

/** Début de chaque scène dans la vidéo complète. */
const DEBUTS = ORDRE.reduce<number[]>((acc, _, i) => [...acc, i === 0 ? 0 : acc[i - 1] + DUREES[ORDRE[i - 1].cle]], []);

/** Coupes masquées par un volet diagonal orange puis vert. */
const VOLETS = ["probleme", "concept", "serveuse", "fonctionnalites", "resultats", "outro"].map((c) => DEBUTS[ORDRE.findIndex((o) => o.cle === c)]);

const Volet: React.FC<{ f: number; coupe: number }> = ({ f, coupe }) => {
  if (f < coupe - 12 || f > coupe + 14) return null;
  const couche = (decalage: number, couleur: string) => {
    const x = interpolate(f, [coupe - 12 + decalage, coupe + 12 + decalage], [-3200, 2100], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2) });
    return <div style={{ position: "absolute", top: -200, left: x, width: 3000, height: 1480, background: couleur, transform: "skewX(-18deg)" }} />;
  };
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {couche(0, C.orange)}
      {couche(3, C.vert)}
    </AbsoluteFill>
  );
};

export const Presentation: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: C.nuit }}>
      <Series>
        {ORDRE.map(({ cle, C: Scene }) => (
          <Series.Sequence key={cle} durationInFrames={DUREES[cle]} name={cle}>
            <Scene />
          </Series.Sequence>
        ))}
      </Series>
      {VOLETS.map((v) => <Volet key={v} f={f} coupe={v} />)}
      {VOLETS.map((v) => <Son key={`s${v}`} nom="whoosh" a={v - 12} volume={0.4} />)}
      <Audio
        src={staticFile("audio/musique.wav")}
        volume={(fr) => interpolate(fr, [0, 15, DUREE_TOTALE - 60, DUREE_TOTALE], [0, 0.75, 0.75, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })}
      />
    </AbsoluteFill>
  );
};
