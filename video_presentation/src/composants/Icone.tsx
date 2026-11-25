import React from "react";
import { ICONES } from "../theme";

/** Icône Material (police Flutter embarquée). */
export const Icone: React.FC<{ code: number; taille?: number; couleur?: string; style?: React.CSSProperties }> = ({
  code,
  taille = 48,
  couleur = "currentColor",
  style,
}) => (
  <span
    style={{
      fontFamily: ICONES,
      fontSize: taille,
      lineHeight: 1,
      color: couleur,
      display: "inline-block",
      width: taille,
      height: taille,
      textAlign: "center",
      ...style,
    }}
  >
    {String.fromCodePoint(code)}
  </span>
);
