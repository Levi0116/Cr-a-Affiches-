import React from 'react';
import {AbsoluteFill, Audio, Easing, Img, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame} from 'remotion';
import {H_FPS, H_INTRO, H_OUTRO, H_TOTAL, H_VOICE_DELAY, HK, HKS, hSceneLen} from './hk-data';
import {SHOP} from './data';
import {Equalizer, GOLD, Logo, Particles, RED, RED_DARK, SoundRings, Text3D, useSpring} from './parts';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const BG = '#0b0b0d';
const CHAMPAGNE = '#e9d29a';

/* Gyroscope 3D : anneaux dorés qui tournent autour d'une sphère lumineuse */
const Gyro3D: React.FC<{size?: number; color?: string}> = ({size = 420, color = CHAMPAGNE}) => {
  const frame = useCurrentFrame();
  const rings = [
    {rx: 70, ry: frame * 1.6, w: 10},
    {rx: frame * 1.2, ry: 60, w: 8},
    {rx: 20 + frame * 0.8, ry: -frame * 1.1, w: 6},
  ];
  return (
    <div style={{width: size, height: size, perspective: 1400}}>
      <div style={{position: 'relative', width: size, height: size, transformStyle: 'preserve-3d'}}>
        <div style={{position: 'absolute', left: size * 0.3, top: size * 0.3, width: size * 0.4, height: size * 0.4, borderRadius: '50%',
          background: `radial-gradient(circle at 35% 30%, #fff, ${color} 35%, #4a3a12 75%, #0b0b0d)`, boxShadow: `0 0 ${size * 0.25}px ${color}aa`}} />
        {rings.map((r, i) => (
          <div key={i} style={{position: 'absolute', inset: i * size * 0.06, borderRadius: '50%', border: `${r.w}px solid ${color}`, boxShadow: `0 0 18px ${color}88, inset 0 0 18px ${color}55`,
            transform: `rotateX(${r.rx}deg) rotateY(${r.ry}deg)`}} />
        ))}
      </div>
    </div>
  );
};

/* ---------------- INTRO ---------------- */
const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(5, 12);
  const title = useSpring(30, 11);
  const sub = useSpring(60);
  const gyro = useSpring(15, 18);
  const out = interpolate(frame, [H_INTRO - 12, H_INTRO], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: `radial-gradient(circle at 50% 60%, #2a2416 0%, ${BG} 65%)`, overflow: 'hidden', opacity: out}}>
      <Particles color={CHAMPAGNE} n={45} seed="hk" />
      <SoundRings color={CHAMPAGNE} x={540} y={1250} count={6} speed={70} />
      <div style={{position: 'absolute', top: 90, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * 180}deg) scale(${0.4 + logo * 0.75})`, opacity: logo}}>
        <Logo scale={1.15} />
      </div>
      <div style={{position: 'absolute', top: 470, width: '100%', textAlign: 'center', transform: `perspective(900px) rotateX(${(1 - title) * 80}deg) scale(${0.5 + title * 0.5})`, opacity: title}}>
        <div style={{font: '600 46px Montserrat', color: CHAMPAGNE, letterSpacing: 18}}>L’ÉLÉGANCE DU SON</div>
        <Text3D size={150} color="#fff" depth="#3a2e12" style={{marginTop: 18}}>HARMAN</Text3D>
        <Text3D size={150} color={CHAMPAGNE} depth="#3a2e12" style={{marginTop: 4}}>KARDON</Text3D>
      </div>
      <div style={{position: 'absolute', top: 1040, left: 540 - 210, transform: `scale(${gyro}) translateY(${Math.sin(frame / 15) * 15}px)`}}>
        <Gyro3D size={420} />
      </div>
      <div style={{position: 'absolute', bottom: 150, width: '100%', textAlign: 'center', opacity: sub, transform: `translateY(${(1 - sub) * 60}px)`}}>
        <div style={{font: '700 50px Poppins', color: '#fff'}}>Design de luxe, son d’exception</div>
        <div style={{font: '400 74px "Kaushan Script"', color: GOLD, marginTop: 4}}>chez Zeynab Store !</div>
      </div>
    </AbsoluteFill>
  );
};

/* ---------------- CLIPS (vidéo ou photo) ---------------- */
const MIN_SPEED = 0.45;
const segLen = (s: HK['segments'][number], speed: number) => (s.src.endsWith('.jpg') ? Math.round((s.hold ?? 4) * H_FPS) : Math.round((((s.to ?? 0) - (s.from ?? 0)) / speed) * H_FPS));

const Clips: React.FC<{d: HK; len: number; blur?: boolean}> = ({d, len, blur}) => {
  const vids = d.segments.filter((s) => !s.src.endsWith('.jpg'));
  const srcTotal = vids.reduce((a, s) => a + (s.to ?? 0) - (s.from ?? 0), 0);
  const speed = vids.length ? Math.max(MIN_SPEED, Math.min(1, (srcTotal * H_FPS) / len)) : 1;
  const items: React.ReactNode[] = [];
  let at = 0;
  let k = 0;
  while (at < len) {
    const s = d.segments[k % d.segments.length];
    const l = Math.min(len - at, segLen(s, speed));
    const pos = `${s.focus ?? 50}% ${s.y ?? 50}%`;
    const base: React.CSSProperties = {position: 'absolute', width: '100%', height: '100%', objectFit: 'cover', objectPosition: pos, transformOrigin: pos,
      filter: blur ? 'blur(40px) brightness(.35) saturate(1.2)' : 'contrast(1.06) saturate(1.08) brightness(1.04)'};
    items.push(
      <Sequence key={k} from={at} durationInFrames={l} layout="none">
        {s.src.endsWith('.jpg') ? (
          <KenBurns s={s} len={l} style={base} blur={blur} />
        ) : (
          <OffthreadVideo src={staticFile(`hk/${s.src}`)} trimBefore={Math.round((s.from ?? 0) * H_FPS)} playbackRate={speed} muted
            style={{...base, transform: blur ? 'scale(1.3)' : s.zoom ? `scale(${s.zoom[0]})` : undefined}} />
        )}
      </Sequence>,
    );
    at += l;
    k++;
  }
  return <AbsoluteFill>{items}</AbsoluteFill>;
};

const KenBurns: React.FC<{s: HK['segments'][number]; len: number; style: React.CSSProperties; blur?: boolean}> = ({s, len, style, blur}) => {
  const frame = useCurrentFrame();
  const [z0, z1] = s.zoom ?? [1, 1.1];
  const z = blur ? 1.3 : interpolate(frame, [0, len], [z0, z1], clamp);
  return <Img src={staticFile(`hk/${s.src}`)} style={{...style, transform: `scale(${z})`}} />;
};

/* ---------------- SCÈNE PRODUIT ---------------- */
const Scene: React.FC<{d: HK; index: number; len: number}> = ({d, index, len}) => {
  const frame = useCurrentFrame();
  const head = useSpring(6, 12);
  const card = useSpring(2, 15);
  const price = useSpring(Math.round(len * 0.55), 9);
  const badge = useSpring(30, 10);
  const wipe = interpolate(frame, [0, 16], [0, 1], {...clamp, easing: Easing.inOut(Easing.cubic)});
  const outWipe = interpolate(frame, [len - 10, len], [0, 1], clamp);
  const zoom = interpolate(frame, [0, len], [1.03, 1.12]);
  const specGap = Math.max(18, Math.floor((len * 0.5 - 30) / d.specs.length));
  const gyroX = interpolate(frame, [0, 40], [1300, 900], {...clamp, easing: Easing.out(Easing.cubic)});

  return (
    <AbsoluteFill style={{background: BG, overflow: 'hidden'}}>
      <Clips d={d} len={len} blur />
      <AbsoluteFill style={{background: `linear-gradient(180deg, ${BG}f0 0%, ${BG}66 30%, ${BG}77 60%, ${BG}f5 100%)`}} />
      <AbsoluteFill style={{background: `conic-gradient(from ${frame * 0.4}deg at 50% 40%, transparent 0deg, ${d.accent}1f 20deg, transparent 40deg, transparent 120deg, ${d.accent}1f 140deg, transparent 160deg, transparent 240deg, ${d.accent}1f 260deg, transparent 280deg)`, mixBlendMode: 'screen'}} />
      <Particles color={CHAMPAGNE} n={22} seed={d.id} />

      <div style={{position: 'absolute', left: gyroX, top: 6, transform: `translateY(${Math.sin(frame / 14) * 10}px)`}}><Gyro3D size={140} color={d.accent} /></div>

      {/* en-tête */}
      <div style={{position: 'absolute', top: 40, left: 0, width: '100%', textAlign: 'center', transform: `translateY(${(1 - head) * -220}px)`, opacity: head}}>
        <div style={{display: 'inline-block', font: '800 28px Montserrat', color: BG, background: CHAMPAGNE, padding: '6px 22px', borderRadius: 30, letterSpacing: 4}}>
          {String(index + 1).padStart(2, '0')} / {String(HKS.length).padStart(2, '0')} · ZEYNAB STORE
        </div>
        <div style={{font: '600 46px/1 Montserrat', color: CHAMPAGNE, marginTop: 20, letterSpacing: 12}}>HARMAN KARDON</div>
        <Text3D size={Math.min(116, Math.floor(960 / (d.model.length * 0.7)))} color="#fff" depth="#2a2410" style={{marginTop: 10, whiteSpace: 'nowrap'}}>{d.model}</Text3D>
      </div>

      {/* carte vidéo 3D */}
      <div style={{position: 'absolute', left: 40, top: 330, width: 1000, height: 900, perspective: 2000}}>
        <div style={{width: '100%', height: '100%', borderRadius: 40, overflow: 'hidden', border: `4px solid ${CHAMPAGNE}`, boxShadow: `0 0 50px ${d.accent}66, 0 40px 80px rgba(0,0,0,.65)`, position: 'relative',
          transform: `rotateY(${(1 - card) * 70 + Math.sin(frame / 45) * 4}deg) rotateX(${Math.cos(frame / 55) * 3}deg) scale(${0.7 + card * 0.3})`, opacity: card}}>
          <AbsoluteFill style={{transform: `scale(${zoom})`}}><Clips d={d} len={len} /></AbsoluteFill>
          <div style={{position: 'absolute', inset: 0, background: 'linear-gradient(115deg, transparent 40%, rgba(255,255,255,.16) 48%, transparent 56%)', transform: `translateX(${((frame * 9) % 2600) - 1300}px)`}} />
          <div style={{position: 'absolute', inset: 0, boxShadow: 'inset 0 0 120px rgba(0,0,0,.55)'}} />
        </div>
        {d.badge ? (
          <div style={{position: 'absolute', right: -14, top: 26, padding: '10px 26px', background: `linear-gradient(180deg, #ff3b55, ${RED})`, color: '#fff', font: '900 32px Montserrat', borderRadius: 12, boxShadow: '0 8px 20px rgba(0,0,0,.5)', transform: `rotate(6deg) scale(${badge})`, border: `3px solid ${GOLD}`}}>{d.badge}</div>
        ) : null}
      </div>

      {/* prix */}
      <div style={{position: 'absolute', left: 0, width: '100%', top: 1255, display: 'flex', justifyContent: 'center', perspective: 900}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20, padding: '12px 44px', borderRadius: 30, background: `linear-gradient(180deg, #d01a33, ${RED_DARK})`, border: `5px solid ${GOLD}`, boxShadow: '0 16px 36px rgba(0,0,0,.55)',
          transform: `rotateX(${(1 - price) * 90}deg) scale(${0.6 + price * 0.4}) rotate(${Math.sin(frame / 20) * 1.2}deg)`, opacity: Math.min(1, price * 2)}}>
          <div style={{font: '900 96px/1 Montserrat', color: '#fff', letterSpacing: -3, textShadow: '0 5px 0 rgba(0,0,0,.25)'}}>{d.price}</div>
          <div style={{font: '900 46px/1 Montserrat', color: GOLD}}>FCFA</div>
        </div>
      </div>

      {/* caractéristiques 2 × 2 */}
      <div style={{position: 'absolute', left: 36, right: 36, top: 1430, display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16}}>
        {d.specs.map((s, i) => {
          const sp = useSpring(20 + i * specGap, 13);
          return (
            <div key={i} style={{display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 6, padding: '18px 22px', minHeight: 200, borderRadius: 26, background: 'rgba(14,12,8,.8)', border: `2px solid ${CHAMPAGNE}aa`, boxShadow: `0 10px 30px rgba(0,0,0,.45), inset 0 0 30px ${d.accent}1f`,
              transform: `perspective(900px) rotateX(${(1 - sp) * -90}deg) translateY(${(1 - sp) * 80}px)`, opacity: Math.min(1, sp * 1.6), transformOrigin: '50% 0'}}>
              <div style={{width: 66, height: 66, borderRadius: '50%', background: `radial-gradient(circle at 35% 30%, #fff, ${CHAMPAGNE} 55%, #4a3a12)`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 36, boxShadow: `0 0 14px ${CHAMPAGNE}88`}}>{s.icon}</div>
              <div style={{font: '800 35px/1.1 Montserrat', color: '#fff'}}>{s.title}</div>
              <div style={{font: '500 27px/1.2 Poppins', color: '#d8d2c4'}}>{s.text}</div>
            </div>
          );
        })}
      </div>

      <AbsoluteFill style={{background: `linear-gradient(135deg, ${CHAMPAGNE}, #3a2e12)`, clipPath: `polygon(${wipe * 140}% 0, 140% 0, 140% 100%, ${wipe * 140 - 40}% 100%)`}} />
      <AbsoluteFill style={{background: RED, clipPath: `polygon(0 0, ${outWipe * 140}% 0, ${outWipe * 140 - 40}% 100%, 0 100%)`}} />
    </AbsoluteFill>
  );
};

/* ---------------- OUTRO ---------------- */
const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(0, 12);
  const recapOut = interpolate(frame, [190, 205], [1, 0], clamp);
  const info = useSpring(200, 14);
  const items = [
    {icon: '📞', k: 'Contact / WhatsApp', v: SHOP.contact, big: true},
    {icon: '📍', k: 'Siège', v: SHOP.siege},
    {icon: '🏬', k: 'Magasins annexes', v: SHOP.annexes.join(' • ')},
    {icon: '🚚', k: 'Services', v: SHOP.services.join(' • ')},
  ];
  const end = interpolate(frame, [H_OUTRO - 15, H_OUTRO], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: 'linear-gradient(180deg, #8f0d1d 0%, #5c0610 60%, #2a0207 100%)', overflow: 'hidden', opacity: end}}>
      <Particles color={GOLD} n={30} seed="outro-hk" />
      <div style={{position: 'absolute', top: 70, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * -180 + Math.sin(frame / 30) * 8}deg) scale(${0.5 + logo * 0.7})`, opacity: logo}}>
        <Logo scale={1.15} />
      </div>
      <div style={{position: 'absolute', top: 400, width: '100%', textAlign: 'center'}}>
        <div style={{font: '400 66px "Kaushan Script"', color: GOLD}}>Disponibles chez</div>
        <Text3D size={96} color="#fff" depth="#3a0208">ZEYNAB STORE</Text3D>
      </div>

      <div style={{position: 'absolute', left: 50, right: 50, top: 700, display: 'flex', flexDirection: 'column', gap: 26, opacity: recapOut}}>
        {HKS.map((d, i) => {
          const sp = useSpring(10 + i * 8, 14);
          return (
            <div key={d.id} style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '26px 30px', borderRadius: 24, background: 'rgba(0,0,0,.3)', borderLeft: `12px solid ${CHAMPAGNE}`, transform: `translateX(${(1 - sp) * (i % 2 ? 1200 : -1200)}px)`}}>
              <div>
                <div style={{font: '600 26px Montserrat', color: CHAMPAGNE, letterSpacing: 4}}>HARMAN KARDON</div>
                <div style={{font: '800 46px Montserrat', color: '#fff'}}>{d.model}</div>
              </div>
              <div style={{font: '900 52px Montserrat', color: GOLD, whiteSpace: 'nowrap'}}>{d.price} F</div>
            </div>
          );
        })}
      </div>

      <div style={{position: 'absolute', left: 60, right: 60, top: 680, display: 'flex', flexDirection: 'column', gap: 22, opacity: info}}>
        {items.map((it, i) => {
          const sp = useSpring(205 + i * 10, 14);
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

export const HKVideo: React.FC = () => {
  let at = H_INTRO;
  const scenes = HKS.map((d, i) => {
    const len = hSceneLen(d);
    const el = (
      <Sequence key={d.id} from={at} durationInFrames={len}>
        <Scene d={d} index={i} len={len} />
        <Sequence from={H_VOICE_DELAY}><Audio src={staticFile(`hk/vo/${d.id}.mp3`)} /></Sequence>
      </Sequence>
    );
    at += len;
    return el;
  });
  return (
    <AbsoluteFill style={{background: '#000'}}>
      <Audio src={staticFile('hk/music.m4a')} volume={(f) => interpolate(f, [0, H_TOTAL - 45, H_TOTAL], [0.34, 0.34, 0], clamp)} />
      <Sequence durationInFrames={H_INTRO}>
        <Intro />
        <Sequence from={H_VOICE_DELAY}><Audio src={staticFile('hk/vo/intro.mp3')} /></Sequence>
      </Sequence>
      {scenes}
      <Sequence from={at} durationInFrames={H_OUTRO}>
        <Outro />
        <Sequence from={H_VOICE_DELAY}><Audio src={staticFile('hk/vo/outro.mp3')} /></Sequence>
      </Sequence>
    </AbsoluteFill>
  );
};
