import React from 'react';
import {AbsoluteFill, Audio, Easing, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame, random} from 'remotion';
import {FPS2, INTRO2, OUTRO2, PHOTO, PRODUCTS2, P2, sceneLen2, TOTAL2, VO_DELAY, vlen} from './data';
import {SHOP} from '../data';
import {GOLD, Logo, RED, RED_DARK} from '../parts';
import {Studio3D} from './Studio3D';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const HUDF = 'Rajdhani';
const TECH = 'Orbitron';

const sp = (frame: number, start: number, dur = 18) => interpolate(frame, [start, start + dur], [0, 1], {...clamp, easing: Easing.out(Easing.cubic)});

/* Grain + fuites de lumière (look cinéma) */
const FilmLook: React.FC<{accent: string}> = ({accent}) => {
  const frame = useCurrentFrame();
  const seed = Math.floor(random('g' + frame) * 1000);
  return (
    <>
      <AbsoluteFill style={{background: `radial-gradient(ellipse at ${30 + Math.sin(frame / 40) * 25}% ${20 + Math.cos(frame / 50) * 10}%, ${accent}40 0%, transparent 45%), radial-gradient(ellipse at 85% 90%, #ff8a3c33 0%, transparent 40%)`, mixBlendMode: 'screen'}} />
      <AbsoluteFill style={{boxShadow: 'inset 0 0 260px rgba(0,0,0,.85)'}} />
      <svg width="1080" height="1920" style={{position: 'absolute', inset: 0, opacity: 0.09, mixBlendMode: 'overlay'}}>
        <filter id={`n${seed}`}><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed={seed} /></filter>
        <rect width="100%" height="100%" filter={`url(#n${seed})`} />
      </svg>
    </>
  );
};

/* Interface de vol façon drone */
const HUD: React.FC<{p: P2; f: number; len: number}> = ({p, f, len}) => {
  const a = sp(f, 0, 14);
  const alt = (p.hud.alt + Math.sin(f / 25) * 1.5 + f * 0.02).toFixed(1);
  const spd = (p.hud.spd + Math.sin(f / 13) * 0.8).toFixed(1);
  const heading = (f * 0.6 + p.hud.alt * 3) % 360;
  const bat = Math.max(20, 92 - Math.floor(f / 40));
  const c = p.accent;
  const brackets = [[0, 0], [1, 0], [0, 1], [1, 1]] as const;
  return (
    <AbsoluteFill style={{opacity: a, fontFamily: HUDF, color: '#fff'}}>
      {brackets.map(([x, y], i) => (
        <div key={i} style={{position: 'absolute', [x ? 'right' : 'left']: 40, [y ? 'bottom' : 'top']: y ? 640 : 250, width: 90, height: 90, borderColor: c, borderStyle: 'solid', borderWidth: 0, [y ? 'borderBottomWidth' : 'borderTopWidth']: 4, [x ? 'borderRightWidth' : 'borderLeftWidth']: 4, filter: `drop-shadow(0 0 6px ${c})`}} />
      ))}
      {/* viseur central */}
      <svg width="1080" height="1920" style={{position: 'absolute', inset: 0}}>
        <g transform={`translate(540 ${p.coverY ? 760 : 900})`} stroke={c} fill="none" strokeWidth="3" style={{filter: `drop-shadow(0 0 6px ${c})`}} opacity="0.85">
          <circle r="70" strokeDasharray="30 14" transform={`rotate(${f * 2})`} />
          <circle r="110" strokeDasharray="4 18" opacity="0.6" transform={`rotate(${-f})`} />
          <line x1="-150" y1="0" x2="-85" y2="0" /><line x1="85" y1="0" x2="150" y2="0" />
          <line x1="0" y1="-150" x2="0" y2="-85" /><line x1="0" y1="85" x2="0" y2="150" />
          <circle r="5" fill={c} />
        </g>
      </svg>
      {/* compas */}
      <div style={{position: 'absolute', top: 200, left: 240, width: 600, height: 40, overflow: 'hidden', maskImage: 'linear-gradient(90deg,transparent,#000 20%,#000 80%,transparent)', WebkitMaskImage: 'linear-gradient(90deg,transparent,#000 20%,#000 80%,transparent)'}}>
        <div style={{position: 'absolute', left: 300 - heading * 6, top: 0, display: 'flex'}}>
          {Array.from({length: 120}).map((_, i) => {
            const deg = i * 6 - 180;
            const lbl = ({0: 'N', 90: 'E', 180: 'S', 270: 'O', [-90]: 'O', [-180]: 'S'} as Record<number, string>)[deg];
            return <div key={i} style={{width: 36, textAlign: 'center', font: `700 22px ${HUDF}`, color: lbl ? c : '#fff', opacity: lbl ? 1 : 0.6}}>{lbl ?? (deg % 30 === 0 ? '|' : '·')}</div>;
          })}
        </div>
      </div>
      {/* lectures gauche / droite */}
      <div style={{position: 'absolute', left: 50, top: 600, font: `700 28px ${HUDF}`, lineHeight: 1.35, textShadow: '0 0 8px #000'}}>
        <div style={{color: c}}>ALT</div><div style={{font: `700 54px ${TECH}`}}>{alt}<span style={{fontSize: 26}}> m</span></div>
        <div style={{color: c, marginTop: 14}}>VIT</div><div style={{font: `700 54px ${TECH}`}}>{spd}<span style={{fontSize: 26}}> m/s</span></div>
      </div>
      <div style={{position: 'absolute', right: 50, top: 600, textAlign: 'right', font: `700 28px ${HUDF}`, lineHeight: 1.35, textShadow: '0 0 8px #000'}}>
        <div style={{color: c}}>BATT</div><div style={{font: `700 54px ${TECH}`}}>{bat}%</div>
        <div style={{color: c, marginTop: 14}}>GPS</div><div style={{font: `700 40px ${TECH}`}}>●●●● 24</div>
      </div>
      <div style={{position: 'absolute', left: 50, top: 520, font: `700 30px ${TECH}`, color: '#ff3b3b', opacity: f % 30 < 18 ? 1 : 0.25}}>● REC</div>
      <div style={{position: 'absolute', right: 50, top: 520, font: `700 30px ${TECH}`}}>4K · 60</div>
    </AbsoluteFill>
  );
};

/* Titre produit en haut (style motion design) */
const Header: React.FC<{p: P2; index: number; f: number}> = ({p, index, f}) => {
  const a = sp(f, 2, 16);
  const b = sp(f, 8, 16);
  return (
    <div style={{position: 'absolute', top: 40, left: 0, right: 0, padding: '0 44px', display: 'flex', alignItems: 'center', justifyContent: 'space-between'}}>
      <div style={{transform: `translateX(${(1 - a) * -600}px)`, opacity: a}}>
        <div style={{font: `700 26px ${TECH}`, color: p.accent, letterSpacing: 6}}>{String(index + 1).padStart(2, '0')}/{String(PRODUCTS2.length).padStart(2, '0')} · DJI</div>
        <div style={{font: `900 78px/1 ${TECH}`, color: '#fff', letterSpacing: 2, textShadow: `0 0 24px ${p.accent}88, 0 4px 0 rgba(0,0,0,.4)`, whiteSpace: 'nowrap'}}>{p.model}</div>
      </div>
      <div style={{transform: `translateX(${(1 - b) * 600}px)`, opacity: b}}><Logo scale={0.38} /></div>
    </div>
  );
};

/* Fiche technique dans un panneau en verre en bas */
const SpecPanel: React.FC<{p: P2; f: number; len: number}> = ({p, f, len}) => {
  const a = sp(f, 4, 16);
  const priceAt = Math.round(len * 0.55);
  const pr = interpolate(f, [priceAt, priceAt + 10], [0, 1], {...clamp, easing: Easing.out(Easing.back(2.2))});
  const shock = interpolate(f, [priceAt + 4, priceAt + 22], [0, 1], clamp);
  const shake = f >= priceAt + 4 && f < priceAt + 14 ? Math.sin(f * 7) * (priceAt + 14 - f) * 1.2 : 0;
  return (
    <div style={{position: 'absolute', left: 30, right: 30, bottom: 40, height: 590, transform: `translateY(${(1 - a) * 700}px) translateX(${shake}px)`}}>
      <div style={{position: 'absolute', inset: 0, borderRadius: 36, background: 'linear-gradient(180deg, rgba(8,12,20,.55), rgba(4,6,10,.88))', backdropFilter: 'blur(14px)', border: `2px solid ${p.accent}88`, boxShadow: `0 0 40px ${p.accent}44, inset 0 1px 0 rgba(255,255,255,.15)`}} />
      <div style={{position: 'absolute', left: 36, top: 26, right: 36, display: 'flex', flexDirection: 'column', gap: 14}}>
        {p.specs.map((s, i) => {
          const t = sp(f, 14 + i * 12, 14);
          const chars = Math.floor(interpolate(f, [16 + i * 12, 34 + i * 12], [0, s.v.length], clamp));
          return (
            <div key={i} style={{display: 'flex', alignItems: 'center', gap: 20, opacity: t, transform: `translateX(${(1 - t) * 80}px)`}}>
              <div style={{width: 14, height: 54, background: p.accent, boxShadow: `0 0 14px ${p.accent}`, transform: `scaleY(${t})`}} />
              <div style={{font: `700 26px ${TECH}`, color: p.accent, width: 240, letterSpacing: 2}}>{s.k}</div>
              <div style={{font: `700 46px ${HUDF}`, color: '#fff', whiteSpace: 'nowrap'}}>{s.v.slice(0, chars)}<span style={{opacity: chars < s.v.length && f % 10 < 5 ? 1 : 0, color: p.accent}}>▌</span></div>
            </div>
          );
        })}
      </div>
      {/* prix */}
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 30, display: 'flex', justifyContent: 'center'}}>
        <div style={{position: 'absolute', left: '50%', top: '50%', width: 300, height: 300, marginLeft: -150, marginTop: -150, borderRadius: '50%', border: `6px solid ${GOLD}`, transform: `scale(${shock * 4})`, opacity: (1 - shock) * 0.8}} />
        <div style={{display: 'flex', alignItems: 'baseline', gap: 18, padding: '18px 46px 22px', borderRadius: 26, background: `linear-gradient(180deg, #ff2a44 0%, ${RED} 45%, ${RED_DARK} 100%)`, border: `4px solid ${GOLD}`,
          boxShadow: `0 0 50px ${RED}aa, 0 20px 40px rgba(0,0,0,.6), inset 0 2px 0 rgba(255,255,255,.35)`, transform: `perspective(800px) rotateX(${(1 - pr) * 70}deg) scale(${0.3 + pr * 0.7})`, opacity: Math.min(1, pr * 3)}}>
          <div style={{font: `900 ${p.price.length > 8 ? 104 : 120}px/1 Montserrat`, letterSpacing: -4, background: 'linear-gradient(180deg,#fff 0%,#fff 55%,#ffd9a0 100%)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent', filter: 'drop-shadow(0 5px 0 rgba(0,0,0,.35))'}}>{p.price}</div>
          <div style={{font: `900 48px Montserrat`, color: GOLD}}>FCFA</div>
        </div>
      </div>
    </div>
  );
};

/* Passage vidéo : clips plein écran, étalonnage, poussée caméra */
const Footage: React.FC<{p: P2; len: number}> = ({p, len}) => {
  const f = useCurrentFrame();
  const per = Math.ceil(len / p.clips.length);
  const zoom = interpolate(f, [0, len], [1.0, 1.12]);
  return (
    <AbsoluteFill style={{overflow: 'hidden'}}>
      {p.clips.map((c, i) => (
        <Sequence key={c} from={i * per} durationInFrames={i === p.clips.length - 1 ? len - i * per : per} layout="none">
          <AbsoluteFill style={{transform: `scale(${zoom})`}}>
            <OffthreadVideo src={staticFile(`dji2/clips/${c}`)} muted style={{width: '100%', height: '100%', objectFit: 'cover', filter: 'contrast(1.12) saturate(1.18) brightness(.98)'}} />
          </AbsoluteFill>
        </Sequence>
      ))}
      {/* étalonnage teal & orange */}
      <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(0,60,90,.35) 0%, rgba(0,0,0,0) 40%, rgba(255,120,40,.12) 75%, rgba(0,0,0,.55) 100%)', mixBlendMode: 'soft-light'}} />
      <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(0,0,0,.65) 0%, rgba(0,0,0,0) 22%, rgba(0,0,0,0) 55%, rgba(0,0,0,.6) 100%)'}} />
      {/* flash de coupe entre deux plans */}
      {p.clips.slice(1).map((_, i) => {
        const at = (i + 1) * per;
        const o = interpolate(f, [at - 3, at, at + 6], [0, 0.85, 0], clamp);
        return <AbsoluteFill key={i} style={{background: '#fff', opacity: o}} />;
      })}
    </AbsoluteFill>
  );
};

/* Scène produit complète */
const ProductScene: React.FC<{p: P2; index: number; len: number}> = ({p, index, len}) => {
  const f = useCurrentFrame();
  const vf = f - PHOTO;
  const toVideo = interpolate(f, [PHOTO - 6, PHOTO, PHOTO + 10], [0, 1, 0], clamp);
  const burst = interpolate(f, [PHOTO - 8, PHOTO + 8], [1, 1.25], clamp);
  const glitch = (f >= PHOTO - 4 && f <= PHOTO + 4) || f >= len - 6;
  const outBlur = interpolate(f, [len - 8, len], [0, 30], clamp);
  return (
    <AbsoluteFill style={{background: '#000', overflow: 'hidden'}}>
      {/* 1. présentation photo en 3D */}
      <Sequence durationInFrames={PHOTO + 6} layout="none">
        <AbsoluteFill style={{transform: `scale(${f > PHOTO - 8 ? burst : 1})`, filter: f > PHOTO - 8 ? `blur(${(burst - 1) * 40}px)` : undefined}}>
          <Studio3D frame={f} len={PHOTO + 6} accent={p.accent} mode="product" title={p.model} photo={p.photo} cutout={p.cutout} />
        </AbsoluteFill>
        <PhotoOverlay p={p} index={index} f={f} />
      </Sequence>
      {/* 2. vidéo + HUD */}
      <Sequence from={PHOTO} durationInFrames={len - PHOTO} layout="none">
        <AbsoluteFill style={{filter: outBlur ? `blur(${outBlur}px)` : undefined, transform: `translateX(${-outBlur * 12}px)`}}>
          <Footage p={p} len={len - PHOTO} />
          {p.coverY ? (
            <div style={{position: 'absolute', left: 0, right: 0, top: p.coverY, height: 130, background: `linear-gradient(90deg, rgba(4,6,10,.92), rgba(4,6,10,.8), rgba(4,6,10,.92))`, borderTop: `2px solid ${p.accent}`, borderBottom: `2px solid ${p.accent}`, overflow: 'hidden', display: 'flex', alignItems: 'center'}}>
              <div style={{whiteSpace: 'nowrap', font: `800 64px ${TECH}`, color: '#fff', transform: `translateX(${-((vf * 6) % 1400)}px)`, letterSpacing: 4}}>
                {`DJI ${p.model} · ZEYNAB STORE · `.repeat(6)}
              </div>
            </div>
          ) : null}
          <HUD p={p} f={vf} len={len - PHOTO} />
          <Header p={p} index={index} f={vf} />
          <SpecPanel p={p} f={vf} len={len - PHOTO} />
          <FilmLook accent={p.accent} />
        </AbsoluteFill>
      </Sequence>
      {/* flash + aberration chromatique aux transitions */}
      <AbsoluteFill style={{background: '#fff', opacity: toVideo, mixBlendMode: 'screen'}} />
      {glitch ? <Glitch accent={p.accent} f={f} /> : null}
    </AbsoluteFill>
  );
};

const Glitch: React.FC<{accent: string; f: number}> = ({accent, f}) => (
  <AbsoluteFill style={{pointerEvents: 'none'}}>
    {Array.from({length: 7}).map((_, i) => {
      const y = random(`gy${f}-${i}`) * 1920;
      const h = 10 + random(`gh${f}-${i}`) * 60;
      return <div key={i} style={{position: 'absolute', left: 0, right: 0, top: y, height: h, background: i % 2 ? accent : '#fff', opacity: 0.35, transform: `translateX(${(random(`gx${f}-${i}`) - 0.5) * 300}px)`, mixBlendMode: 'difference'}} />;
    })}
  </AbsoluteFill>
);

const PhotoOverlay: React.FC<{p: P2; index: number; f: number}> = ({p, index, f}) => {
  const a = sp(f, 10, 16);
  return (
    <>
      <div style={{position: 'absolute', top: 60, left: 0, right: 0, textAlign: 'center', opacity: a, transform: `translateY(${(1 - a) * -40}px)`}}>
        <div style={{display: 'inline-block', font: `700 28px ${TECH}`, color: '#04060b', background: p.accent, padding: '8px 26px', borderRadius: 40, letterSpacing: 6, boxShadow: `0 0 30px ${p.accent}`}}>{String(index + 1).padStart(2, '0')} · DJI</div>
      </div>
      {p.badge ? (
        <div style={{position: 'absolute', right: 50, top: 1270, padding: '12px 28px', background: `linear-gradient(180deg,#ff3b55,${RED})`, color: '#fff', font: `900 34px Montserrat`, borderRadius: 14, border: `3px solid ${GOLD}`, transform: `rotate(-6deg) scale(${sp(f, 24, 12)})`, boxShadow: '0 10px 30px rgba(0,0,0,.6)'}}>{p.badge}</div>
      ) : null}
      <div style={{position: 'absolute', bottom: 120, left: 0, right: 0, textAlign: 'center', opacity: sp(f, 20, 16)}}>
        <div style={{font: `600 34px ${HUDF}`, color: '#cfd8e6', letterSpacing: 10}}>DISPONIBLE CHEZ</div>
        <div style={{font: `900 60px Montserrat`, color: '#fff', letterSpacing: 3, textShadow: `0 0 30px ${p.accent}66`}}>ZEYNAB STORE</div>
      </div>
    </>
  );
};

/* ---------------- INTRO ---------------- */
const Intro2: React.FC = () => {
  const f = useCurrentFrame();
  const logo = sp(f, 72, 20);
  const sub = sp(f, 95, 20);
  const out = interpolate(f, [INTRO2 - 10, INTRO2], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: '#000', opacity: out}}>
      <Studio3D frame={f} len={INTRO2} accent="#38d9ff" mode="intro" title="LA FLOTTE DJI" />
      <div style={{position: 'absolute', top: 120, left: 0, right: 0, display: 'flex', justifyContent: 'center', opacity: logo, transform: `scale(${0.6 + logo * 0.5})`}}><Logo scale={1.2} /></div>
      <div style={{position: 'absolute', bottom: 210, left: 0, right: 0, textAlign: 'center', opacity: sub, transform: `translateY(${(1 - sub) * 50}px)`}}>
        <div style={{font: `700 40px ${TECH}`, color: '#38d9ff', letterSpacing: 10}}>PRENEZ DE LA HAUTEUR</div>
        <div style={{font: `600 34px ${HUDF}`, color: '#fff', letterSpacing: 6, marginTop: 10}}>8 DRONES · PRIX CHOC · LIVRAISON</div>
      </div>
      <AbsoluteFill style={{background: '#fff', opacity: interpolate(f, [68, 72, 84], [0, 0.9, 0], clamp)}} />
    </AbsoluteFill>
  );
};

/* ---------------- OUTRO ---------------- */
const Outro2: React.FC = () => {
  const f = useCurrentFrame();
  const recap = interpolate(f, [150, 165], [1, 0], clamp);
  const info = sp(f, 162, 18);
  const end = interpolate(f, [OUTRO2 - 12, OUTRO2], [1, 0], clamp);
  const items = [
    {icon: '📞', k: 'CONTACT / WHATSAPP', v: SHOP.contact, big: true},
    {icon: '📍', k: 'SIÈGE', v: SHOP.siege},
    {icon: '🏬', k: 'MAGASINS ANNEXES', v: SHOP.annexes.join(' • ')},
    {icon: '🚚', k: 'SERVICES', v: SHOP.services.join(' • ')},
  ];
  return (
    <AbsoluteFill style={{background: '#000', opacity: end}}>
      <Studio3D frame={f} len={OUTRO2} accent={GOLD} mode="outro" />
      <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(0,0,0,.2), rgba(0,0,0,.55) 40%, rgba(0,0,0,.75))'}} />
      <div style={{position: 'absolute', top: 70, left: 0, right: 0, display: 'flex', justifyContent: 'center', opacity: sp(f, 0, 16)}}><Logo scale={1.1} /></div>
      <div style={{position: 'absolute', top: 390, left: 0, right: 0, textAlign: 'center'}}>
        <div style={{font: `700 34px ${TECH}`, color: GOLD, letterSpacing: 8}}>DISPONIBLES CHEZ</div>
        <div style={{font: `900 96px Montserrat`, color: '#fff', textShadow: `0 0 40px ${GOLD}66`}}>ZEYNAB STORE</div>
      </div>
      <div style={{position: 'absolute', left: 44, right: 44, top: 600, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, opacity: recap}}>
        {PRODUCTS2.map((p, i) => {
          const t = sp(f, 8 + i * 5, 14);
          return (
            <div key={p.id} style={{padding: '18px 22px', borderRadius: 22, background: 'rgba(6,10,18,.72)', border: `2px solid ${p.accent}`, boxShadow: `0 0 24px ${p.accent}44`, transform: `perspective(900px) rotateY(${(1 - t) * (i % 2 ? -90 : 90)}deg)`, opacity: t}}>
              <div style={{font: `700 22px ${TECH}`, color: p.accent, letterSpacing: 3}}>DJI</div>
              <div style={{font: `800 40px ${HUDF}`, color: '#fff', lineHeight: 1}}>{p.model}</div>
              <div style={{font: `900 42px Montserrat`, color: GOLD, marginTop: 6}}>{p.price} <span style={{fontSize: 24}}>FCFA</span></div>
            </div>
          );
        })}
      </div>
      <div style={{position: 'absolute', left: 56, right: 56, top: 640, display: 'flex', flexDirection: 'column', gap: 22, opacity: info}}>
        {items.map((it, i) => {
          const t = sp(f, 166 + i * 8, 16);
          return (
            <div key={i} style={{display: 'flex', alignItems: 'center', gap: 24, padding: '20px 26px', background: 'rgba(6,10,18,.75)', borderRadius: 24, border: `2px solid ${GOLD}aa`, boxShadow: `0 0 30px ${GOLD}22`, transform: `translateX(${(1 - t) * 1200}px)`}}>
              <div style={{width: 88, height: 88, flex: 'none', borderRadius: '50%', background: 'radial-gradient(circle at 35% 30%,#fff3c4,#e6b850 50%,#a8761d)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 46}}>{it.icon}</div>
              <div>
                <div style={{font: `700 24px ${TECH}`, color: GOLD, letterSpacing: 3}}>{it.k}</div>
                <div style={{font: it.big ? `900 74px/1.05 Montserrat` : `700 38px/1.2 ${HUDF}`, color: '#fff'}}>{it.v}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{position: 'absolute', bottom: 80, left: 0, right: 0, textAlign: 'center', font: `800 42px ${TECH}`, color: '#fff', letterSpacing: 4, opacity: info}}>
        COMMANDEZ <span style={{color: GOLD}}>MAINTENANT</span>
      </div>
    </AbsoluteFill>
  );
};

export const DJI2Video: React.FC = () => {
  let at = INTRO2;
  const scenes = PRODUCTS2.map((p, i) => {
    const len = sceneLen2(p);
    const priceAt = PHOTO + Math.round((len - PHOTO) * 0.55);
    const el = (
      <Sequence key={p.id} from={at} durationInFrames={len}>
        <ProductScene p={p} index={i} len={len} />
        <Sequence from={VO_DELAY}><Audio src={staticFile(`dji2/vo/${p.id}.mp3`)} /></Sequence>
        <Audio src={staticFile('dji2/whoosh.mp3')} volume={0.6} />
        <Sequence from={PHOTO - 10}><Audio src={staticFile('dji2/whoosh.mp3')} volume={0.45} /></Sequence>
        <Sequence from={priceAt + 3}><Audio src={staticFile('dji2/impact.mp3')} volume={0.55} /></Sequence>
      </Sequence>
    );
    at += len;
    return el;
  });
  return (
    <AbsoluteFill style={{background: '#000'}}>
      <Audio src={staticFile('dji2/music.m4a')} volume={(fr) => interpolate(fr, [0, TOTAL2 - 40, TOTAL2], [0.3, 0.3, 0], clamp)} />
      <Sequence durationInFrames={INTRO2}>
        <Intro2 />
        <Audio src={staticFile('dji2/riser.mp3')} volume={0.5} />
        <Sequence from={66}><Audio src={staticFile('dji2/impact.mp3')} volume={0.7} /></Sequence>
        <Sequence from={45}><Audio src={staticFile('dji2/vo/intro.mp3')} /></Sequence>
      </Sequence>
      {scenes}
      <Sequence from={at} durationInFrames={OUTRO2}>
        <Outro2 />
        <Sequence from={VO_DELAY}><Audio src={staticFile('dji2/vo/outro.mp3')} /></Sequence>
      </Sequence>
    </AbsoluteFill>
  );
};
