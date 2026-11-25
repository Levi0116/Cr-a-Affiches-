import React from "react";
import { Sequence, staticFile } from "remotion";
import { Audio } from "@remotion/media";

export type NomSon =
  | "clic" | "ding" | "erreur" | "imprimante" | "notification" | "papier" | "pop"
  | "tampon" | "tiroir-caisse" | "whoosh-court" | "whoosh";

/** Effet sonore placé à une image donnée de la scène. */
export const Son: React.FC<{ nom: NomSon; a: number; volume?: number }> = ({ nom, a, volume = 0.7 }) => (
  <Sequence from={Math.max(0, Math.round(a))} durationInFrames={150} layout="none" name={`son ${nom}`}>
    <Audio src={staticFile(`audio/${nom}.wav`)} volume={volume} />
  </Sequence>
);
