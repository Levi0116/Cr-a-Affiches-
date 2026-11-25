import React from "react";
import { AbsoluteFill, Img, interpolate, staticFile } from "remotion";
import { C, ressort } from "../theme";

/** Images d'écran successives avec fondu enchaîné. */
/** zoom : images clés (frames → échelles) autour du point x %, y %. */
export type Plan = { src: string; debut: number; zoom?: { f: number[]; s: number[]; x: number; y: number } };

const Ecran: React.FC<{ f: number; plans: Plan[]; children?: React.ReactNode; rayon: number }> = ({ f, plans, children, rayon }) => (
  <div style={{ position: "absolute", inset: 0, overflow: "hidden", borderRadius: rayon, background: "#0B1510" }}>
    {plans.map((p, i) => {
      const suivant = plans[i + 1];
      const entree = i === 0 ? 1 : interpolate(f, [p.debut, p.debut + 8], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
      const visible = !suivant || f < suivant.debut + 8;
      if (!visible || f < p.debut - 1) return null;
      // zoom : [début, fin, échelle, x%, y%] — zoom progressif vers un point.
      let transform = "none";
      let origin = "50% 50%";
      if (p.zoom) {
        const sc = interpolate(f, p.zoom.f, p.zoom.s, {
          extrapolateLeft: "clamp", extrapolateRight: "clamp",
          easing: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
        });
        transform = `scale(${sc})`;
        origin = `${p.zoom.x}% ${p.zoom.y}%`;
      }
      return (
        <Img key={p.src + i} src={staticFile(`ecrans/${p.src}.png`)}
          style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", opacity: entree, transform, transformOrigin: origin }} />
      );
    })}
    {children}
    {/* Reflet de la vitre */}
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(115deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 32%)", pointerEvents: "none" }} />
  </div>
);

type PropsAppareil = {
  f: number;
  plans: Plan[];
  largeur: number;
  style?: React.CSSProperties;
  children?: React.ReactNode;
  /** Éléments posés sur l'écran sans être rognés (main, bulles). */
  dessus?: React.ReactNode;
};

export const Tablette: React.FC<PropsAppareil> = ({ f, plans, largeur, style, children, dessus }) => {
  const b = largeur * 0.028;
  const h = (largeur - 2 * b) / 1.6 + 2 * b;
  return (
    <div style={{
      position: "absolute", width: largeur, height: h, borderRadius: b * 1.8, background: "linear-gradient(145deg,#2A302C,#0D100E)",
      boxShadow: "0 50px 90px rgba(0,0,0,0.45), 0 0 0 2px #3A413C inset", ...style,
    }}>
      <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b }}>
        <Ecran f={f} plans={plans} rayon={b * 0.6}>{children}</Ecran>
      </div>
      <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b, zIndex: 5 }}>{dessus}</div>
      <div style={{ position: "absolute", left: b * 0.38, top: "50%", width: b * 0.3, height: b * 0.3, borderRadius: "50%", background: "#1C2A22", transform: "translateY(-50%)" }} />
    </div>
  );
};

export const Ordinateur: React.FC<PropsAppareil> = ({ f, plans, largeur, style, children, dessus }) => {
  const b = largeur * 0.022;
  const hEcran = (largeur - 2 * b) / 1.6 + 2 * b;
  return (
    <div style={{ position: "absolute", width: largeur, height: hEcran + largeur * 0.06, ...style }}>
      <div style={{
        position: "absolute", left: 0, top: 0, width: largeur, height: hEcran, borderRadius: b * 1.4,
        background: "linear-gradient(180deg,#26292B,#111314)", boxShadow: "0 40px 80px rgba(0,0,0,0.4)",
      }}>
        <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b }}>
          <Ecran f={f} plans={plans} rayon={b * 0.3}>{children}</Ecran>
        </div>
        <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b, zIndex: 5 }}>{dessus}</div>
      </div>
      <div style={{
        position: "absolute", left: -largeur * 0.07, top: hEcran - 2, width: largeur * 1.14, height: largeur * 0.035,
        background: "linear-gradient(180deg,#D9DCDF,#9EA3A8)", borderRadius: `4px 4px ${largeur * 0.03}px ${largeur * 0.03}px`,
        boxShadow: "0 30px 50px rgba(0,0,0,0.35)",
      }}>
        <div style={{ position: "absolute", left: "42%", width: "16%", top: 0, height: "38%", background: "#8C9196", borderRadius: "0 0 8px 8px" }} />
      </div>
    </div>
  );
};

export const Telephone: React.FC<PropsAppareil> = ({ f, plans, largeur, style, children, dessus }) => {
  const b = largeur * 0.045;
  const h = (largeur - 2 * b) / (780 / 1688) + 2 * b;
  return (
    <div style={{
      position: "absolute", width: largeur, height: h, borderRadius: largeur * 0.16, background: "linear-gradient(145deg,#2E3431,#0C0F0D)",
      boxShadow: "0 40px 80px rgba(0,0,0,0.45), 0 0 0 2px #444B46 inset", ...style,
    }}>
      <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b }}>
        <Ecran f={f} plans={plans} rayon={largeur * 0.12}>{children}</Ecran>
      </div>
      <div style={{ position: "absolute", left: b, top: b, right: b, bottom: b, zIndex: 5 }}>{dessus}</div>
      <div style={{ position: "absolute", left: "50%", top: b * 1.8, width: largeur * 0.26, height: largeur * 0.07, borderRadius: 99, background: "#050605", transform: "translateX(-50%)" }} />
    </div>
  );
};

/** Main qui appuie : se déplace de point en point (en % de l'écran) et tape. */
export const Doigt: React.FC<{
  f: number;
  points: { f: number; x: number; y: number }[];
  apparition: number;
  disparition?: number;
  taille?: number;
}> = ({ f, points, apparition, disparition = 99999, taille = 150 }) => {
  if (f < apparition || f > disparition + 15) return null;
  const opacite = interpolate(f, [apparition, apparition + 10, disparition, disparition + 12], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  // Position : chaque point est atteint 6 images avant son tap.
  const xs = points.map((p) => p.x);
  const ys = points.map((p) => p.y);
  const fs = points.map((p) => p.f - 6);
  const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
  const pos = (arr: number[]) => {
    if (points.length === 1) return arr[0];
    const cadres: number[] = [];
    const vals: number[] = [];
    fs.forEach((fr, i) => {
      const depart = i === 0 ? fr - 1 : Math.max(fs[i - 1] + 8, fr - 18);
      if (i > 0) { cadres.push(depart); vals.push(arr[i - 1]); }
      cadres.push(fr); vals.push(arr[i]);
    });
    return interpolate(f, cadres, vals, { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: ease });
  };
  const x = pos(xs);
  const y = pos(ys);
  let appui = 0;
  let onde: { r: number; o: number } | null = null;
  for (const p of points) {
    const d = f - p.f;
    if (d >= -4 && d <= 6) appui = Math.max(appui, 1 - Math.abs(d - 0) / 5);
    if (d >= 0 && d < 22) onde = { r: interpolate(d, [0, 22], [10, 90]), o: interpolate(d, [0, 22], [0.7, 0]) };
  }
  return (
    <>
      {onde && (
        <div style={{
          position: "absolute", left: `${x}%`, top: `${y}%`, width: onde.r * 2, height: onde.r * 2, marginLeft: -onde.r, marginTop: -onde.r,
          borderRadius: "50%", border: `5px solid rgba(255,255,255,${onde.o})`, background: `rgba(245,90,10,${onde.o * 0.35})`,
        }} />
      )}
      <svg viewBox="0 0 100 130" style={{
        position: "absolute", left: `${x}%`, top: `${y}%`, width: taille, height: taille * 1.3, opacity: opacite,
        transform: `translate(-24%, -6%) scale(${1 - appui * 0.12}) rotate(-12deg)`, transformOrigin: "24% 6%",
        filter: "drop-shadow(0 18px 18px rgba(0,0,0,0.35))", overflow: "visible",
      }}>
        <path d="M18 8 Q24 0 30 8 L30 58 L36 56 Q40 46 46 54 L48 60 Q54 52 60 60 L62 66 Q68 60 74 68 L76 98 Q76 124 50 126 L34 126 Q20 122 14 104 L4 76 Q2 66 10 66 Q16 66 18 76 Z"
          fill="#8A5A36" stroke="#5C3A21" strokeWidth="2.5" />
        <path d="M20 10 Q24 5 28 10 L28 20 L20 20 Z" fill="#C79A78" opacity="0.8" />
        <path d="M20 112 L72 112 L74 130 L22 130 Z" fill="#0B3A1C" />
      </svg>
    </>
  );
};

/** Paquet de données lumineux qui vole d'un point à un autre (en px). */
export const Paquet: React.FC<{ f: number; debut: number; duree: number; de: [number, number]; a: [number, number]; couleur?: string; icone?: React.ReactNode; hauteurArc?: number }> = ({
  f, debut, duree, de, a, couleur = C.orange, icone, hauteurArc = 220,
}) => {
  if (f < debut || f > debut + duree + 10) return null;
  const t = interpolate(f, [debut, debut + duree], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: (x) => (x < 0.5 ? 2 * x * x : 1 - Math.pow(-2 * x + 2, 2) / 2) });
  const x = de[0] + (a[0] - de[0]) * t;
  const y = de[1] + (a[1] - de[1]) * t - Math.sin(t * Math.PI) * hauteurArc;
  const fin = interpolate(f, [debut + duree, debut + duree + 10], [1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  const s = ressort(f, debut, 10, 180) * (0.6 + fin * 0.4);
  const trainee = [0.06, 0.12, 0.18, 0.24].map((dt) => {
    const tt = Math.max(0, t - dt);
    return [de[0] + (a[0] - de[0]) * tt, de[1] + (a[1] - de[1]) * tt - Math.sin(tt * Math.PI) * hauteurArc];
  });
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {trainee.map(([tx, ty], i) => (
        <div key={i} style={{
          position: "absolute", left: tx - 14 + i * 2, top: ty - 14 + i * 2, width: 28 - i * 4, height: 28 - i * 4, borderRadius: "50%",
          background: couleur, opacity: (0.45 - i * 0.1) * fin * (t > 0.02 ? 1 : 0), filter: "blur(2px)",
        }} />
      ))}
      <div style={{
        position: "absolute", left: x - 48, top: y - 48, width: 96, height: 96, borderRadius: 30, background: couleur,
        transform: `scale(${s})`, opacity: fin, display: "flex", alignItems: "center", justifyContent: "center",
        boxShadow: `0 0 60px ${couleur}, 0 0 0 6px rgba(255,255,255,0.25) inset`,
      }}>{icone}</div>
    </AbsoluteFill>
  );
};
