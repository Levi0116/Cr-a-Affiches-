import React from "react";

export type TypePersonnage = "fatou" | "koffi" | "patron" | "client1" | "client2";
export type Expression = "neutre" | "sourire" | "joie" | "triste" | "surpris" | "fache" | "perplexe";
export type Objet = "aucun" | "carnet" | "tablette" | "telephone" | "billets" | "stylo";

type Props = {
  type: TypePersonnage;
  f: number;
  expression?: Expression;
  /** La bouche bouge (dialogue). */
  parle?: boolean;
  /** Angles en degrés : bras (épaule) et avant-bras (coude), côté gauche de l'image puis droit. */
  brasG?: [number, number];
  brasD?: [number, number];
  objetD?: Objet;
  objetG?: Objet;
  /** Direction du regard, -1 (gauche) à 1 (droite). */
  regard?: number;
  /** Inclinaison de la tête en degrés. */
  tete?: number;
  /** Personnage assis (jambes repliées masquées). */
  assis?: boolean;
  hauteur?: number;
  style?: React.CSSProperties;
  graine?: number;
};

const LOOKS: Record<TypePersonnage, {
  peau: string; peauOmbre: string; haut: string; hautOmbre: string; bas: string; chaussures: string;
}> = {
  fatou: { peau: "#8A5A36", peauOmbre: "#734628", haut: "#FFF3D6", hautOmbre: "#EBD9B4", bas: "#2B2B2B", chaussures: "#3A2418" },
  koffi: { peau: "#6B4226", peauOmbre: "#55331C", haut: "#1F6B3A", hautOmbre: "#16522C", bas: "#2A3340", chaussures: "#1B1B1B" },
  patron: { peau: "#5C3A21", peauOmbre: "#472C18", haut: "#F7ECD6", hautOmbre: "#E2D2B2", bas: "#3B2F25", chaussures: "#24170F" },
  client1: { peau: "#9C6A43", peauOmbre: "#84552F", haut: "#2563EB", hautOmbre: "#1D4FC0", bas: "#2F3A4A", chaussures: "#1F1F1F" },
  client2: { peau: "#7A4A2A", peauOmbre: "#633B20", haut: "#B83280", hautOmbre: "#962767", bas: "#3A2A3A", chaussures: "#2A1A12" },
};

/** Motif « wax » pour le foulard de Fatou et la chemise du client 2. */
const Wax: React.FC<{ id: string; fond: string; a: string; b: string }> = ({ id, fond, a, b }) => (
  <pattern id={id} width="28" height="28" patternUnits="userSpaceOnUse" patternTransform="rotate(20)">
    <rect width="28" height="28" fill={fond} />
    <circle cx="14" cy="14" r="7" fill="none" stroke={a} strokeWidth="3.5" />
    <circle cx="14" cy="14" r="2.5" fill={b} />
    <circle cx="0" cy="0" r="3" fill={b} />
    <circle cx="28" cy="28" r="3" fill={b} />
  </pattern>
);

const Objet: React.FC<{ objet: Objet }> = ({ objet }) => {
  switch (objet) {
    case "carnet":
      return (
        <g transform="translate(-26,-10) rotate(-8)">
          <rect x="0" y="0" width="56" height="72" rx="5" fill="#FFFDF5" stroke="#C9B48A" strokeWidth="2" />
          {[16, 28, 40, 52].map((y) => (
            <line key={y} x1="8" x2="48" y1={y} y2={y} stroke="#9BB3D9" strokeWidth="2" />
          ))}
          <rect x="0" y="0" width="56" height="9" rx="4" fill="#E5484D" />
        </g>
      );
    case "tablette":
      return (
        <g transform="translate(-50,-32) rotate(-6)">
          <rect x="0" y="0" width="100" height="70" rx="9" fill="#151A17" />
          <rect x="6" y="6" width="88" height="58" rx="4" fill="#0F5132" />
          <rect x="12" y="12" width="22" height="20" rx="3" fill="#059669" />
          <rect x="39" y="12" width="22" height="20" rx="3" fill="#D97706" />
          <rect x="66" y="12" width="22" height="20" rx="3" fill="#059669" />
          <rect x="12" y="37" width="22" height="20" rx="3" fill="#2563EB" />
          <rect x="39" y="37" width="22" height="20" rx="3" fill="#059669" />
          <rect x="66" y="37" width="22" height="20" rx="3" fill="#D97706" />
        </g>
      );
    case "telephone":
      return (
        <g transform="translate(-18,-44) rotate(-4)">
          <rect x="0" y="0" width="38" height="74" rx="7" fill="#151A17" />
          <rect x="3" y="5" width="32" height="64" rx="4" fill="#FBF6EC" />
          <rect x="6" y="12" width="26" height="16" rx="3" fill="#0B3A1C" />
          <rect x="6" y="32" width="26" height="8" rx="2" fill="#E7DCC6" />
          <rect x="6" y="44" width="26" height="8" rx="2" fill="#E7DCC6" />
        </g>
      );
    case "billets":
      return (
        <g transform="translate(-30,-20) rotate(-12)">
          <rect x="0" y="6" width="64" height="32" rx="3" fill="#6BA368" stroke="#3F7A3C" strokeWidth="2" />
          <rect x="6" y="0" width="64" height="32" rx="3" fill="#C98B4B" stroke="#8F5F2C" strokeWidth="2" />
          <circle cx="38" cy="16" r="8" fill="none" stroke="#8F5F2C" strokeWidth="2" />
        </g>
      );
    case "stylo":
      return <rect x="-4" y="-40" width="8" height="54" rx="3" fill="#2563EB" transform="rotate(25)" />;
    default:
      return null;
  }
};

/** Bras en deux segments ; `cote` = -1 (gauche de l'image) ou 1 (droite). */
const Bras: React.FC<{
  x: number; y: number; angles: [number, number]; cote: number; manche: string; mancheOmbre: string; peau: string; objet: Objet;
  manchesLongues: boolean;
}> = ({ x, y, angles, cote, manche, mancheOmbre, peau, objet, manchesLongues }) => {
  const [epaule, coude] = angles;
  return (
    <g transform={`translate(${x} ${y}) rotate(${-epaule * cote})`}>
      <rect x="-21" y="-12" width="42" height="122" rx="21" fill={manche} />
      <rect x={cote > 0 ? 6 : -21} y="-6" width="15" height="110" rx="8" fill={mancheOmbre} opacity="0.6" />
      <g transform={`translate(0 100) rotate(${-coude * cote})`}>
        <rect x="-17" y="-8" width="34" height="108" rx="17" fill={manchesLongues ? manche : peau} />
        {manchesLongues && <rect x="-17" y="78" width="34" height="22" rx="10" fill={peau} />}
        <g transform="translate(0 104)">
          <ellipse cx="0" cy="0" rx="19" ry="21" fill={peau} />
          <g transform={`rotate(${(epaule + coude) * cote})`}>
            <Objet objet={objet} />
          </g>
          {objet !== "aucun" && <ellipse cx={-cote * 6} cy="4" rx="12" ry="9" fill={peau} />}
        </g>
      </g>
    </g>
  );
};

/** Pseudo-hasard déterministe. */
const hasard = (n: number) => {
  const x = Math.sin(n * 12.9898) * 43758.5453;
  return x - Math.floor(x);
};

/**
 * Personnage illustré (vectoriel) : respiration, clignement des yeux,
 * bouche qui parle, bras articulés, objet tenu en main.
 * Boîte : 400 × 800, pieds en bas.
 */
export const Personnage: React.FC<Props> = ({
  type, f, expression = "neutre", parle = false, brasG = [8, 12], brasD = [8, 12],
  objetD = "aucun", objetG = "aucun", regard = 0, tete = 0, assis = false, hauteur = 600, style, graine = 1,
}) => {
  const L = LOOKS[type];
  const id = `${type}-${graine}`;
  const souffle = Math.sin((f + graine * 17) / 22);
  const respiration = 1 + souffle * 0.012;
  // Clignement : deux ou trois fois toutes les ~3 s.
  const cycle = 95 + Math.floor(hasard(graine) * 40);
  const t = (f + graine * 31) % cycle;
  const clin = t < 4 ? Math.abs(t - 2) / 2 : 1;
  const ouverture = parle ? Math.max(0, Math.sin(f * 0.9) * 0.5 + Math.sin(f * 1.7) * 0.5) : 0;
  const rx = regard * 6;
  const hautTete = Math.sin((f + graine * 17) / 22 + 0.6) * 2;

  const sourcils = (() => {
    switch (expression) {
      case "fache": return { g: "M154 178 L188 190", d: "M246 178 L212 190" };
      case "triste": return { g: "M156 190 L188 180", d: "M244 190 L212 180" };
      case "surpris": return { g: "M154 172 Q171 162 188 172", d: "M212 172 Q229 162 246 172" };
      case "perplexe": return { g: "M154 178 Q171 170 188 180", d: "M212 172 Q229 164 246 170" };
      default: return { g: "M154 182 Q171 175 188 182", d: "M212 182 Q229 175 246 182" };
    }
  })();

  const bouche = (() => {
    if (parle && ouverture > 0.08) {
      return <ellipse cx="200" cy="252" rx={13 - ouverture * 3} ry={3 + ouverture * 9} fill="#3A1A12" />;
    }
    switch (expression) {
      case "joie":
        return (
          <g>
            <path d="M176 244 Q200 274 224 244 Z" fill="#3A1A12" />
            <path d="M180 246 Q200 254 220 246 L218 250 Q200 256 182 250 Z" fill="#FFFFFF" />
          </g>
        );
      case "sourire": return <path d="M181 247 Q200 262 219 247" stroke="#3A1A12" strokeWidth="5" fill="none" strokeLinecap="round" />;
      case "triste": return <path d="M184 258 Q200 246 216 258" stroke="#3A1A12" strokeWidth="5" fill="none" strokeLinecap="round" />;
      case "surpris": return <ellipse cx="200" cy="254" rx="9" ry="12" fill="#3A1A12" />;
      case "fache": return <path d="M184 254 Q200 248 216 254" stroke="#3A1A12" strokeWidth="5" fill="none" strokeLinecap="round" />;
      case "perplexe": return <path d="M184 254 Q196 250 206 254 T218 250" stroke="#3A1A12" strokeWidth="5" fill="none" strokeLinecap="round" />;
      default: return <path d="M186 250 Q200 256 214 250" stroke="#3A1A12" strokeWidth="5" fill="none" strokeLinecap="round" />;
    }
  })();

  const manchesLongues = type === "patron" || type === "client2";

  return (
    <svg viewBox="0 0 400 800" style={{ height: hauteur, width: hauteur / 2, overflow: "visible", ...style }}>
      <defs>
        <Wax id={`wax-${id}`} fond="#F55A0A" a="#FFE2AE" b="#0B3A1C" />
        <Wax id={`wax2-${id}`} fond="#B83280" a="#FFD27A" b="#5B1240" />
        <radialGradient id={`ombre-${id}`}>
          <stop offset="0" stopColor="#000" stopOpacity="0.35" />
          <stop offset="1" stopColor="#000" stopOpacity="0" />
        </radialGradient>
      </defs>

      {/* Ombre portée */}
      {!assis && <ellipse cx="200" cy="782" rx="120" ry="16" fill={`url(#ombre-${id})`} />}

      {/* Jambes */}
      {!assis && (
        <g>
          {type === "fatou" ? (
            <path d="M138 520 L262 520 L276 748 L124 748 Z" fill={`url(#wax-${id})`} />
          ) : (
            <>
              <rect x="146" y="520" width="50" height="236" rx="18" fill={L.bas} />
              <rect x="204" y="520" width="50" height="236" rx="18" fill={L.bas} />
            </>
          )}
          {type === "fatou" && (
            <>
              <rect x="160" y="740" width="26" height="22" fill={L.peau} />
              <rect x="214" y="740" width="26" height="22" fill={L.peau} />
            </>
          )}
          <ellipse cx="168" cy="768" rx="36" ry="14" fill={L.chaussures} />
          <ellipse cx="232" cy="768" rx="36" ry="14" fill={L.chaussures} />
        </g>
      )}

      <g transform={`translate(200 540) scale(1 ${respiration}) translate(-200 -540)`}>
        {/* Buste */}
        <path
          d="M128 300 Q200 284 272 300 Q296 310 292 350 L280 545 Q200 560 120 545 L108 350 Q104 310 128 300 Z"
          fill={type === "client2" ? `url(#wax2-${id})` : L.haut}
        />
        <path d="M250 304 Q290 312 290 352 L280 545 Q262 549 246 551 Z" fill={L.hautOmbre} opacity="0.55" />

        {/* Détails de tenue */}
        {type === "fatou" && (
          <g>
            <path d="M150 360 L250 360 L262 552 Q200 562 138 552 Z" fill="#0B3A1C" />
            <path d="M150 360 L250 360" stroke="#0B3A1C" strokeWidth="6" />
            <rect x="174" y="430" width="52" height="38" rx="8" fill="#1F6B3A" />
            <text x="200" y="520" textAnchor="middle" fontFamily="PlusJakarta" fontWeight="800" fontSize="22" fill="#FFE2AE">AMANI</text>
            <path d="M170 300 L200 336 L230 300" fill={L.peau} />
          </g>
        )}
        {type === "koffi" && (
          <g>
            <path d="M172 298 L200 340 L228 298 Z" fill={L.peau} />
            <path d="M166 296 L200 318 L186 340 Z M234 296 L200 318 L214 340 Z" fill="#16522C" />
            <circle cx="200" cy="360" r="5" fill="#FFE2AE" />
            <circle cx="200" cy="390" r="5" fill="#FFE2AE" />
            <rect x="226" y="372" width="40" height="30" rx="6" fill="#F55A0A" />
            <text x="246" y="393" textAnchor="middle" fontFamily="PlusJakarta" fontWeight="800" fontSize="16" fill="#fff">K</text>
          </g>
        )}
        {type === "patron" && (
          <g>
            <path d="M176 296 L200 330 L224 296 Z" fill={L.peau} />
            <path d="M200 330 L200 545" stroke="#D9C49E" strokeWidth="3" />
            {[360, 400, 440, 480].map((y) => <circle key={y} cx="208" cy={y} r="4" fill="#B79C6E" />)}
            <path d="M120 330 L160 300 L176 296 L170 545 L120 545 Z" fill="#0B3A1C" opacity="0.92" />
            <path d="M280 330 L240 300 L224 296 L230 545 L280 545 Z" fill="#0B3A1C" opacity="0.92" />
            <rect x="244" y="350" width="24" height="5" rx="2" fill="#FFE2AE" />
          </g>
        )}
        {type === "client1" && <path d="M176 296 L200 326 L224 296 Z" fill={L.peau} />}

        {/* Bras gauche de l'image */}
        <Bras x={128} y={318} angles={brasG} cote={-1} manche={type === "client2" ? `url(#wax2-${id})` : L.haut}
          mancheOmbre={L.hautOmbre} peau={L.peau} objet={objetG} manchesLongues={manchesLongues} />

        {/* Cou */}
        <rect x="178" y="262" width="44" height="44" rx="12" fill={L.peauOmbre} />

        {/* Tête */}
        <g transform={`translate(0 ${hautTete}) rotate(${tete} 200 290)`}>
          {/* Cheveux arrière */}
          {type === "client2" && <ellipse cx="200" cy="215" rx="88" ry="92" fill="#1B120C" />}

          <ellipse cx="128" cy="222" rx="13" ry="18" fill={L.peauOmbre} />
          <ellipse cx="272" cy="222" rx="13" ry="18" fill={L.peauOmbre} />
          <ellipse cx="200" cy="212" rx="72" ry="82" fill={L.peau} />
          <path d="M248 160 Q276 210 252 272 Q236 290 210 294 Q262 250 248 160 Z" fill={L.peauOmbre} opacity="0.5" />

          {/* Coiffures */}
          {type === "fatou" && (
            <g>
              <path d="M124 196 Q118 110 200 104 Q284 108 278 196 Q262 150 200 148 Q140 150 124 196 Z" fill={`url(#wax-${id})`} />
              <path d="M134 160 Q160 70 236 82 Q300 96 292 150 Q270 112 214 112 Q160 116 134 160 Z" fill={`url(#wax-${id})`} />
              <path d="M228 86 Q290 50 300 104 Q290 132 262 116 Q250 96 228 86 Z" fill={`url(#wax-${id})`} />
              <path d="M124 196 Q140 152 200 148 Q262 150 278 196" stroke="#C24104" strokeWidth="5" fill="none" />
              <circle cx="132" cy="246" r="7" fill="#FFC23D" />
              <circle cx="268" cy="246" r="7" fill="#FFC23D" />
            </g>
          )}
          {type === "koffi" && (
            <path d="M128 196 Q120 122 200 122 Q282 122 272 196 Q268 160 248 152 Q200 140 152 152 Q132 162 128 196 Z" fill="#14100D" />
          )}
          {type === "patron" && (
            <g>
              <path d="M130 186 Q130 130 200 128 Q270 130 270 186 Q262 156 200 152 Q138 156 130 186 Z" fill="#1B1714" />
              <path d="M140 232 Q146 300 200 304 Q254 300 260 232 Q252 262 236 270 Q200 262 164 270 Q148 262 140 232 Z" fill="#1B1714" />
              <path d="M178 262 Q200 256 222 262 Q200 270 178 262 Z" fill="#1B1714" />
              <path d="M132 200 Q200 214 268 200" stroke="#2A2420" strokeWidth="0" fill="none" />
            </g>
          )}
          {type === "client1" && (
            <g>
              <path d="M130 190 Q126 128 200 124 Q276 128 270 190 Q258 154 200 150 Q144 154 130 190 Z" fill="#20160F" />
              <rect x="118" y="132" width="164" height="30" rx="14" fill="#F55A0A" />
              <path d="M270 150 Q320 150 322 166 L270 166 Z" fill="#D94A04" />
            </g>
          )}
          {type === "client2" && (
            <g>
              <path d="M126 196 Q118 116 200 112 Q282 116 274 196 Q252 146 200 146 Q148 146 126 196 Z" fill="#1B120C" />
              {[150, 175, 200, 225, 250].map((x) => <path key={x} d={`M${x} 118 L${x - 4} 150`} stroke="#3A2A20" strokeWidth="4" />)}
              <circle cx="132" cy="248" r="8" fill="#FFD27A" />
              <circle cx="268" cy="248" r="8" fill="#FFD27A" />
            </g>
          )}

          {/* Sourcils */}
          <path d={sourcils.g} stroke="#1B120C" strokeWidth="6" strokeLinecap="round" fill="none" />
          <path d={sourcils.d} stroke="#1B120C" strokeWidth="6" strokeLinecap="round" fill="none" />

          {/* Yeux */}
          {[172, 228].map((cx) => (
            <g key={cx} transform={`translate(${cx} 210) scale(1 ${clin}) translate(${-cx} -210)`}>
              <ellipse cx={cx} cy="210" rx="13" ry={expression === "surpris" ? 16 : 13} fill="#FFFFFF" />
              <circle cx={cx + rx} cy="212" r="8" fill="#2A1A10" />
              <circle cx={cx + rx + 3} cy="208" r="2.6" fill="#FFFFFF" />
            </g>
          ))}
          {/* Nez */}
          <path d="M194 222 Q190 238 196 240 Q204 242 210 238" stroke={L.peauOmbre} strokeWidth="5" fill="none" strokeLinecap="round" />
          {/* Joues */}
          {(expression === "joie" || expression === "sourire") && (
            <>
              <ellipse cx="156" cy="240" rx="13" ry="8" fill="#E86A5A" opacity="0.3" />
              <ellipse cx="244" cy="240" rx="13" ry="8" fill="#E86A5A" opacity="0.3" />
            </>
          )}
          {bouche}
          {type === "patron" && !parle && expression !== "joie" && (
            <path d="M178 244 Q200 238 222 244" stroke="#1B1714" strokeWidth="7" fill="none" strokeLinecap="round" />
          )}
        </g>

        {/* Bras avant (droite de l'image) */}
        <Bras x={272} y={318} angles={brasD} cote={1} manche={type === "client2" ? `url(#wax2-${id})` : L.haut}
          mancheOmbre={L.hautOmbre} peau={L.peau} objet={objetD} manchesLongues={manchesLongues} />
      </g>
    </svg>
  );
};
