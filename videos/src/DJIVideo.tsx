import React from 'react';
import {AbsoluteFill, Audio, Easing, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame} from 'remotion';
import {D_FPS, D_INTRO, D_OUTRO, D_TOTAL, DRONES, Drone, sceneLen, VOICE_DELAY} from './dji-data';
import {SHOP} from './data';
import {Equalizer, GOLD, Logo, Particles, RED, RED_DARK, Text3D, useSpring} from './parts';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const SKY = '#0a1424';
const CYAN = '#38d9ff';

/* Drone 3D en CSS : corps, 4 bras, hélices qui tournent */
const Drone3D: React.FC<{size?: number; color?: string; tiltX?: number; rotZ?: number}> = ({size = 300, color = '#3a4352', tiltX = 62, rotZ = 0}) => {
  const frame = useCurrentFrame();
  const arm = size * 0.42;
  return (
    <div style={{width: size, height: size, perspective: 1200}}>
      <div style={{position: 'relative', width: size, height: size, transformStyle: 'preserve-3d', transform: `rotateX(${tiltX}deg) rotateZ(${rotZ}deg)`}}>
        {[45, 135, 225, 315].map((a, i) => {
          const rad = (a * Math.PI) / 180;
          const cx = size / 2 + Math.cos(rad) * arm;
          const cy = size / 2 + Math.sin(rad) * arm;
          return (
            <React.Fragment key={i}>
              <div style={{position: 'absolute', left: size / 2, top: size / 2 - size * 0.025, width: arm, height: size * 0.05, background: color, transformOrigin: '0 50%', transform: `rotate(${a}deg)`, borderRadius: 8}} />
              <div style={{position: 'absolute', left: cx - size * 0.06, top: cy - size * 0.06, width: size * 0.12, height: size * 0.12, borderRadius: '50%', background: '#222', transform: 'translateZ(6px)'}} />
              <div style={{position: 'absolute', left: cx - size * 0.2, top: cy - size * 0.2, width: size * 0.4, height: size * 0.4, borderRadius: '50%', transform: `translateZ(14px) rotate(${frame * 47 * (i % 2 ? 1 : -1)}deg)`,
                background: 'conic-gradient(rgba(220,235,255,.55) 0 18deg, transparent 18deg 180deg, rgba(220,235,255,.55) 180deg 198deg, transparent 198deg)', boxShadow: `0 0 0 2px rgba(255,255,255,.15)`}} />
            </React.Fragment>
          );
        })}
        <div style={{position: 'absolute', left: size * 0.32, top: size * 0.36, width: size * 0.36, height: size * 0.28, borderRadius: size * 0.08, background: `linear-gradient(160deg, #6b7686, ${color} 60%, #1d222b)`, transform: 'translateZ(18px)', boxShadow: '0 0 20px rgba(0,0,0,.5)'}} />
        <div style={{position: 'absolute', left: size * 0.45, top: size * 0.58, width: size * 0.1, height: size * 0.1, borderRadius: '50%', background: 'radial-gradient(circle at 35% 35%, #9fe8ff, #0b3a5a 60%, #000)', transform: 'translateZ(24px)'}} />
        <div style={{position: 'absolute', left: size * 0.47, top: size * 0.38, width: size * 0.06, height: size * 0.03, borderRadius: 4, background: frame % 20 < 10 ? '#3dff7a' : '#0b5a24', transform: 'translateZ(30px)', boxShadow: frame % 20 < 10 ? '0 0 12px #3dff7a' : 'none'}} />
      </div>
    </div>
  );
};

/* Sol en grille 3D qui défile */
const Grid3D: React.FC<{color: string}> = ({color}) => {
  const frame = useCurrentFrame();
  return (
    <div style={{position: 'absolute', left: -800, right: -800, bottom: -200, height: 1100, perspective: 600, overflow: 'hidden'}}>
      <div style={{position: 'absolute', inset: 0, transform: 'rotateX(70deg)', transformOrigin: '50% 100%',
        backgroundImage: `linear-gradient(${color}88 2px, transparent 2px), linear-gradient(90deg, ${color}88 2px, transparent 2px)`, backgroundSize: '90px 90px', backgroundPosition: `0 ${(frame * 6) % 90}px`,
        maskImage: 'linear-gradient(0deg, #000 30%, transparent 100%)', WebkitMaskImage: 'linear-gradient(0deg, #000 30%, transparent 100%)'}} />
    </div>
  );
};

/* ---------------- INTRO ---------------- */
const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(5, 12);
  const title = useSpring(30, 11);
  const sub = useSpring(55);
  const flyX = interpolate(frame, [0, 70], [-700, 0], {...clamp, easing: Easing.out(Easing.cubic)});
  const out = interpolate(frame, [D_INTRO - 12, D_INTRO], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: `linear-gradient(180deg, #050a14 0%, ${SKY} 55%, #13284a 100%)`, overflow: 'hidden', opacity: out}}>
      <Particles color="#9fd8ff" n={50} seed="sky" />
      <Grid3D color={CYAN} />
      <div style={{position: 'absolute', top: 90, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * 180}deg) scale(${0.4 + logo * 0.75})`, opacity: logo}}>
        <Logo scale={1.15} />
      </div>
      <div style={{position: 'absolute', top: 470, width: '100%', textAlign: 'center', transform: `perspective(900px) rotateX(${(1 - title) * 80}deg) scale(${0.5 + title * 0.5})`, opacity: title}}>
        <Text3D size={110} color="#fff" depth="#0b3a5a">NOUVEAUX</Text3D>
        <Text3D size={210} color={CYAN} depth="#06304a" style={{letterSpacing: -6, marginTop: 6}}>DRONES</Text3D>
        <div style={{font: '800 64px Montserrat', color: '#fff', marginTop: 10}}>DJI <span style={{color: GOLD}}>&</span> XIAOMI</div>
      </div>
      <div style={{position: 'absolute', top: 1060, left: 540 - 230 + flyX, transform: `translateY(${Math.sin(frame / 12) * 25}px) rotate(${Math.sin(frame / 20) * 6}deg)`}}>
        <Drone3D size={460} />
      </div>
      <div style={{position: 'absolute', bottom: 160, width: '100%', textAlign: 'center', opacity: sub, transform: `translateY(${(1 - sub) * 60}px)`}}>
        <div style={{font: '700 50px Poppins', color: '#fff'}}>Filmez le monde vu du ciel</div>
        <div style={{font: '400 74px "Kaushan Script"', color: GOLD, marginTop: 4}}>avec Zeynab Store !</div>
      </div>
    </AbsoluteFill>
  );
};

/* ---------------- CLIPS ---------------- */
const MIN_SPEED = 0.4;
const DroneClips: React.FC<{d: Drone; len: number; blur?: boolean}> = ({d, len, blur}) => {
  const srcTotal = d.segments.reduce((a, s) => a + s.to - s.from, 0);
  const speed = Math.max(MIN_SPEED, Math.min(1, (srcTotal * D_FPS) / len));
  const items: React.ReactNode[] = [];
  let at = 0;
  let k = 0;
  while (at < len) {
    const s = d.segments[k % d.segments.length];
    const l = Math.min(len - at, Math.round(((s.to - s.from) / speed) * D_FPS));
    items.push(
      <Sequence key={k} from={at} durationInFrames={l} layout="none">
        <OffthreadVideo src={staticFile('dji/drones.mp4')} trimBefore={Math.round(s.from * D_FPS)} playbackRate={speed} muted
          style={{position: 'absolute', width: '100%', height: '100%', objectFit: 'cover', objectPosition: `${s.focus ?? 50}% ${s.y ?? 50}%`,
            filter: blur ? 'blur(40px) brightness(.4) saturate(1.3)' : 'contrast(1.08) saturate(1.1) brightness(1.03)', transform: `${s.rotate ? `rotate(${s.rotate}deg) ` : ''}${blur ? 'scale(1.3)' : s.zoom ? `scale(${s.zoom})` : ''}`, transformOrigin: `${s.focus ?? 50}% ${s.y ?? 50}%`}} />
      </Sequence>,
    );
    at += l;
    k++;
  }
  return <AbsoluteFill>{items}</AbsoluteFill>;
};

/* ---------------- SCÈNE PRODUIT ---------------- */
const DroneScene: React.FC<{d: Drone; index: number; len: number}> = ({d, index, len}) => {
  const frame = useCurrentFrame();
  const head = useSpring(6, 12);
  const card = useSpring(2, 15);
  const price = useSpring(Math.round(len * 0.55), 9);
  const badge = useSpring(30, 10);
  const wipe = interpolate(frame, [0, 16], [0, 1], {...clamp, easing: Easing.inOut(Easing.cubic)});
  const outWipe = interpolate(frame, [len - 10, len], [0, 1], clamp);
  const zoom = interpolate(frame, [0, len], [1.04, 1.18]);
  const title = `${d.model}`;
  const size = Math.min(124, Math.floor(960 / (title.length * 0.7)));
  const specGap = Math.max(18, Math.floor((len * 0.5 - 30) / d.specs.length));
  const flyIn = interpolate(frame, [0, 40], [1300, 890], {...clamp, easing: Easing.out(Easing.cubic)});

  return (
    <AbsoluteFill style={{background: SKY, overflow: 'hidden'}}>
      <DroneClips d={d} len={len} blur />
      <AbsoluteFill style={{background: `linear-gradient(180deg, ${SKY}ee 0%, ${SKY}55 30%, ${SKY}66 60%, ${SKY}f2 100%)`}} />
      <AbsoluteFill style={{background: `conic-gradient(from ${frame * 0.5}deg at 50% 40%, transparent 0deg, ${d.accent}22 20deg, transparent 40deg, transparent 120deg, ${d.accent}22 140deg, transparent 160deg, transparent 240deg, ${d.accent}22 260deg, transparent 280deg)`, mixBlendMode: 'screen'}} />
      <Particles color={d.accent} n={22} seed={d.id} />

      {/* en-tête */}
      <div style={{position: 'absolute', top: 40, left: 0, width: '100%', textAlign: 'center', transform: `translateY(${(1 - head) * -220}px)`, opacity: head}}>
        <div style={{display: 'inline-block', font: '800 28px Montserrat', color: SKY, background: d.accent, padding: '6px 22px', borderRadius: 30, letterSpacing: 4}}>
          {String(index + 1).padStart(2, '0')} / {String(DRONES.length).padStart(2, '0')} · ZEYNAB STORE
        </div>
        <div style={{font: '900 64px/1 Montserrat', color: d.accent, marginTop: 18, letterSpacing: 8, textShadow: '0 4px 14px rgba(0,0,0,.6)'}}>{d.brand}</div>
        <Text3D size={size} color="#fff" depth="#0b2238" style={{marginTop: 6, whiteSpace: 'nowrap'}}>{title}</Text3D>
      </div>

      {/* carte vidéo 3D */}
      <div style={{position: 'absolute', left: 40, top: 360, width: 1000, height: 760, perspective: 2000}}>
        <div style={{width: '100%', height: '100%', borderRadius: 40, overflow: 'hidden', border: `5px solid ${d.accent}`, boxShadow: `0 0 50px ${d.accent}88, 0 40px 80px rgba(0,0,0,.6)`,
          transform: `rotateY(${(1 - card) * 70 + Math.sin(frame / 45) * 4}deg) rotateX(${Math.cos(frame / 55) * 3}deg) scale(${0.7 + card * 0.3})`, opacity: card, position: 'relative'}}>
          <AbsoluteFill style={{transform: `scale(${zoom})`}}><DroneClips d={d} len={len} /></AbsoluteFill>
          <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(115deg, transparent 40%, rgba(255,255,255,.16) 48%, transparent 56%)', transform: `translateX(${((frame * 9) % 2600) - 1300}px)`}} />
          {/* coins de viseur */}
          {[[0, 0], [1, 0], [0, 1], [1, 1]].map(([x, y], i) => (
            <div key={i} style={{position: 'absolute', [x ? 'right' : 'left']: 26, [y ? 'bottom' : 'top']: 26, width: 60, height: 60, borderColor: '#fff', borderStyle: 'solid', borderWidth: 0, [y ? 'borderBottomWidth' : 'borderTopWidth']: 5, [x ? 'borderRightWidth' : 'borderLeftWidth']: 5, opacity: 0.85}} />
          ))}
          <div style={{position: 'absolute', left: 30, bottom: 30, font: '700 24px Montserrat', color: '#fff', opacity: frame % 30 < 20 ? 1 : 0.3}}>● REC</div>
        </div>
        {d.badge ? (
          <div style={{position: 'absolute', right: -14, top: 26, padding: '10px 26px', background: `linear-gradient(180deg, #ff3b55, ${RED})`, color: '#fff', font: '900 32px Montserrat', borderRadius: 12, boxShadow: '0 8px 20px rgba(0,0,0,.5)', transform: `rotate(6deg) scale(${badge})`, border: `3px solid ${GOLD}`}}>{d.badge}</div>
        ) : null}
      </div>

      {/* petit drone 3D qui arrive */}
      <div style={{position: 'absolute', left: flyIn, top: 4, transform: `translateY(${Math.sin(frame / 10) * 14}px) rotate(${Math.sin(frame / 18) * 8}deg)`}}>
        <Drone3D size={150} />
      </div>

      {/* prix */}
      <div style={{position: 'absolute', left: 0, width: '100%', top: 1150, display: 'flex', justifyContent: 'center', perspective: 900}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20, padding: '14px 44px', borderRadius: 30, background: `linear-gradient(180deg, #d01a33, ${RED_DARK})`, border: `5px solid ${GOLD}`, boxShadow: '0 16px 36px rgba(0,0,0,.55)',
          transform: `rotateX(${(1 - price) * 90}deg) scale(${0.6 + price * 0.4}) rotate(${Math.sin(frame / 20) * 1.2}deg)`, opacity: Math.min(1, price * 2)}}>
          {d.price ? (
            <>
              <div style={{font: '900 98px/1 Montserrat', color: '#fff', letterSpacing: -3, textShadow: '0 5px 0 rgba(0,0,0,.25)'}}>{d.price}</div>
              <div style={{font: '900 46px/1 Montserrat', color: GOLD}}>FCFA</div>
            </>
          ) : (
            <div style={{font: '900 66px/1.1 Montserrat', color: '#fff', textAlign: 'center'}}>PRIX SUR DEMANDE<div style={{font: '700 34px Montserrat', color: GOLD}}>Appelez le {SHOP.contact}</div></div>
          )}
        </div>
      </div>

      {/* caractéristiques en grille 2 × 2 */}
      <div style={{position: 'absolute', left: 36, right: 36, top: 1360, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 18}}>
        {d.specs.map((s, i) => {
          const sp = useSpring(20 + i * specGap, 13);
          return (
            <div key={i} style={{display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 8, padding: '20px 22px', minHeight: 220, borderRadius: 26, background: 'rgba(6,14,28,.78)', border: `2px solid ${d.accent}`, boxShadow: `0 10px 30px rgba(0,0,0,.45), inset 0 0 30px ${d.accent}22`,
              transform: `perspective(900px) rotateX(${(1 - sp) * -90}deg) translateY(${(1 - sp) * 80}px)`, opacity: Math.min(1, sp * 1.6), transformOrigin: '50% 0'}}>
              <div style={{width: 70, height: 70, borderRadius: '50%', background: `radial-gradient(circle at 35% 30%, #fff, ${d.accent} 55%, #0b2238)`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 38, boxShadow: `0 0 16px ${d.accent}`}}>{s.icon}</div>
              <div style={{font: '800 36px/1.1 Montserrat', color: '#fff'}}>{s.title}</div>
              <div style={{font: '500 27px/1.2 Poppins', color: '#cfd8e6'}}>{s.text}</div>
            </div>
          );
        })}
      </div>

      <AbsoluteFill style={{background: `linear-gradient(135deg, ${d.accent}, ${SKY})`, clipPath: `polygon(${wipe * 140}% 0, 140% 0, 140% 100%, ${wipe * 140 - 40}% 100%)`}} />
      <AbsoluteFill style={{background: RED, clipPath: `polygon(0 0, ${outWipe * 140}% 0, ${outWipe * 140 - 40}% 100%, 0 100%)`}} />
    </AbsoluteFill>
  );
};

/* ---------------- OUTRO ---------------- */
const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(0, 12);
  const recapOut = interpolate(frame, [150, 165], [1, 0], clamp);
  const info = useSpring(160, 14);
  const items = [
    {icon: '📞', k: 'Contact / WhatsApp', v: SHOP.contact, big: true},
    {icon: '📍', k: 'Siège', v: SHOP.siege},
    {icon: '🏬', k: 'Magasins annexes', v: SHOP.annexes.join(' • ')},
    {icon: '🚚', k: 'Services', v: SHOP.services.join(' • ')},
  ];
  const end = interpolate(frame, [D_OUTRO - 15, D_OUTRO], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: 'linear-gradient(180deg, #8f0d1d 0%, #5c0610 60%, #2a0207 100%)', overflow: 'hidden', opacity: end}}>
      <Particles color={GOLD} n={30} seed="outro-dji" />
      <div style={{position: 'absolute', top: 70, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * -180 + Math.sin(frame / 30) * 8}deg) scale(${0.5 + logo * 0.7})`, opacity: logo}}>
        <Logo scale={1.15} />
      </div>
      <div style={{position: 'absolute', top: 400, width: '100%', textAlign: 'center'}}>
        <div style={{font: '400 66px "Kaushan Script"', color: GOLD}}>Disponibles chez</div>
        <Text3D size={96} color="#fff" depth="#3a0208">ZEYNAB STORE</Text3D>
      </div>

      {/* récap des prix */}
      <div style={{position: 'absolute', left: 50, right: 50, top: 640, display: 'flex', flexDirection: 'column', gap: 14, opacity: recapOut}}>
        {DRONES.map((d, i) => {
          const sp = useSpring(10 + i * 6, 14);
          return (
            <div key={d.id} style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '14px 28px', borderRadius: 20, background: 'rgba(0,0,0,.3)', borderLeft: `10px solid ${d.accent}`, transform: `translateX(${(1 - sp) * (i % 2 ? 1200 : -1200)}px)`}}>
              <div style={{font: '800 38px Montserrat', color: '#fff'}}>{d.brand} {d.model}</div>
              <div style={{font: '900 40px Montserrat', color: GOLD, whiteSpace: 'nowrap'}}>{d.price ? `${d.price} F` : 'Sur demande'}</div>
            </div>
          );
        })}
      </div>

      {/* infos boutique */}
      <div style={{position: 'absolute', left: 60, right: 60, top: 680, display: 'flex', flexDirection: 'column', gap: 22, opacity: info}}>
        {items.map((it, i) => {
          const sp = useSpring(165 + i * 10, 14);
          return (
            <div key={i} style={{display: 'flex', alignItems: 'center', gap: 24, padding: '20px 26px', background: 'rgba(0,0,0,.28)', borderRadius: 24, border: `2px solid ${GOLD}88`, transform: `translateX(${(1 - sp) * 1200}px)`}}>
              <div style={{width: 88, height: 88, flex: 'none', borderRadius: '50%', background: 'radial-gradient(circle at 35% 30%,#fff3c4,#e6b850 50%,#a8761d)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 46}}>{it.icon}</div>
              <div>
                <div style={{font: '600 30px Poppins', color: GOLD}}>{it.k}</div>
                <div style={{font: it.big ? '900 72px/1.05 Montserrat' : '700 36px/1.2 Montserrat', color: '#fff'}}>{it.v}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{position: 'absolute', bottom: 150, width: '100%', display: 'flex', justifyContent: 'center', opacity: info}}>
        <Equalizer color={GOLD} bars={30} width={900} height={70} />
      </div>
      <div style={{position: 'absolute', bottom: 60, width: '100%', textAlign: 'center', font: '800 40px Montserrat', color: '#fff', opacity: info, letterSpacing: 2}}>
        LIVRAISON DISPONIBLE · COMMANDEZ VITE !
      </div>
    </AbsoluteFill>
  );
};

export const DJIVideo: React.FC = () => {
  let at = D_INTRO;
  const scenes = DRONES.map((d, i) => {
    const len = sceneLen(d);
    const el = (
      <Sequence key={d.id} from={at} durationInFrames={len}>
        <DroneScene d={d} index={i} len={len} />
        <Sequence from={VOICE_DELAY}><Audio src={staticFile(`dji/vo/${d.id}.mp3`)} /></Sequence>
      </Sequence>
    );
    at += len;
    return el;
  });
  return (
    <AbsoluteFill style={{background: '#000'}}>
      <Audio src={staticFile('dji/music.m4a')} volume={(f) => interpolate(f, [0, D_TOTAL - 45, D_TOTAL], [0.32, 0.32, 0], clamp)} />
      <Sequence durationInFrames={D_INTRO}>
        <Intro />
        <Sequence from={VOICE_DELAY}><Audio src={staticFile('dji/vo/intro.mp3')} /></Sequence>
      </Sequence>
      {scenes}
      <Sequence from={at} durationInFrames={D_OUTRO}>
        <Outro />
        <Sequence from={VOICE_DELAY}><Audio src={staticFile('dji/vo/outro.mp3')} /></Sequence>
      </Sequence>
    </AbsoluteFill>
  );
};
