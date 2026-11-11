import React from 'react';
import {AbsoluteFill, Audio, Easing, interpolate, OffthreadVideo, Sequence, staticFile, useCurrentFrame} from 'remotion';
import {FPS, INTRO, OUTRO, PRODUCTS, Product, SCENE, SHOP} from './data';
import {Equalizer, GOLD, Logo, Particles, RED, RED_DARK, SoundRings, Speaker3D, Text3D, fade, useSpring} from './parts';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

/* ---------------- INTRO ---------------- */
const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(0, 12);
  const title = useSpring(28, 10);
  const sub = useSpring(48);
  const out = interpolate(frame, [INTRO - 12, INTRO], [1, 0], clamp);
  return (
    <AbsoluteFill style={{background: `radial-gradient(circle at 50% 40%, #2a0a10 0%, #0b0204 70%)`, overflow: 'hidden', opacity: out}}>
      <SoundRings color={RED} x={540} y={1150} count={6} speed={50} />
      <Particles color="#ff9a3c" seed="intro" />
      <div style={{position: 'absolute', top: 120, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * 180}deg) scale(${0.4 + logo * 0.8})`, opacity: logo}}>
        <Logo scale={1.25} />
      </div>
      <div style={{position: 'absolute', top: 520, width: '100%', textAlign: 'center', transform: `perspective(900px) rotateX(${(1 - title) * 80}deg) scale(${0.5 + title * 0.5})`, opacity: title}}>
        <Text3D size={120} color="#fff" depth="#7a0918">SPÉCIAL</Text3D>
        <Text3D size={260} color="#ff6a00" depth="#5c1f00" style={{letterSpacing: -8, marginTop: 10}}>JBL</Text3D>
      </div>
      <div style={{position: 'absolute', top: 1000, left: '50%', transform: `translateX(-50%) rotate(${Math.sin(frame / 10) * 2}deg)`}}>
        <div style={{display: 'flex', gap: 30, transform: `translateY(${(1 - sub) * 300}px)`, opacity: sub}}>
          {PRODUCTS.map((p, i) => (
            <div key={p.id} style={{transform: `translateY(${Math.sin((frame + i * 12) / 9) * 18}px)`}}>
              <Speaker3D color={p.color} color2={p.color2} w={150} h={290} rot={frame * 3 + i * 40} />
            </div>
          ))}
        </div>
      </div>
      <div style={{position: 'absolute', bottom: 210, width: '100%', textAlign: 'center', opacity: sub, transform: `translateY(${(1 - sub) * 60}px)`}}>
        <div style={{font: '700 50px Poppins', color: '#fff'}}>Les enceintes qui font vibrer</div>
        <div style={{font: '400 76px "Kaushan Script"', color: GOLD, marginTop: 6}}>toute la ville !</div>
      </div>
    </AbsoluteFill>
  );
};

/* ---------------- CLIPS ---------------- */
const Clips: React.FC<{p: Product; blur?: boolean}> = ({p, blur}) => {
  let at = 0;
  const parts = p.segments.map((s, i) => {
    const speed = s.speed ?? 1;
    const isLast = i === p.segments.length - 1;
    const len = isLast ? SCENE - at : Math.round(((s.to - s.from) / speed) * FPS);
    const el = (
      <Sequence key={i} from={at} durationInFrames={len} layout="none">
        <OffthreadVideo src={staticFile(s.src)} trimBefore={Math.round(s.from * FPS)} playbackRate={speed} muted
          style={{width: '100%', height: '100%', objectFit: 'cover', filter: blur ? 'blur(40px) brightness(.45) saturate(1.4)' : 'contrast(1.08) saturate(1.15)', transform: blur ? 'scale(1.2)' : undefined}} />
      </Sequence>
    );
    at += len;
    return el;
  });
  return <AbsoluteFill>{parts}</AbsoluteFill>;
};

/* ---------------- SCÈNE PRODUIT ---------------- */
const ProductScene: React.FC<{p: Product; index: number}> = ({p, index}) => {
  const frame = useCurrentFrame();
  const head = useSpring(8, 12);
  const card = useSpring(4, 15);
  const wipe = interpolate(frame, [0, 16], [0, 1], {...clamp, easing: Easing.inOut(Easing.cubic)});
  const outWipe = interpolate(frame, [SCENE - 10, SCENE], [0, 1], clamp);
  const sway = Math.sin(frame / 40) * 6;
  const badge = useSpring(70, 9);

  return (
    <AbsoluteFill style={{background: '#000', overflow: 'hidden'}}>
      <Clips p={p} blur />
      <AbsoluteFill style={{background: `linear-gradient(180deg, ${p.color2}dd 0%, transparent 35%, transparent 60%, ${p.color2}ee 100%)`}} />
      {/* rayons de lumière */}
      <AbsoluteFill style={{background: `conic-gradient(from ${frame * 0.6}deg at 50% 45%, transparent 0deg, ${p.color}33 20deg, transparent 40deg, transparent 90deg, ${p.color}33 110deg, transparent 130deg, transparent 180deg, ${p.color}33 200deg, transparent 220deg, transparent 270deg, ${p.color}33 290deg, transparent 310deg)`, mixBlendMode: 'screen'}} />
      <Particles color={p.color} n={25} seed={p.id} />

      {/* carte vidéo en 3D */}
      <div style={{position: 'absolute', left: 540 - 360, top: 300, width: 720, height: 1280, perspective: 1800}}>
        <div style={{width: '100%', height: '100%', borderRadius: 44, overflow: 'hidden', border: `6px solid ${p.color}`, boxShadow: `0 0 60px ${p.color}aa, 0 40px 80px rgba(0,0,0,.6)`,
          transform: `rotateY(${(1 - card) * -70 + sway}deg) rotateX(${Math.cos(frame / 50) * 3}deg) scale(${0.7 + card * 0.3})`, opacity: card}}>
          <Clips p={p} />
          <div style={{position: 'absolute', inset: 0, background: `linear-gradient(115deg, transparent 40%, rgba(255,255,255,.18) 48%, transparent 56%)`, transform: `translateX(${((frame * 8) % 2400) - 1200}px)`}} />
        </div>
      </div>

      {/* en-tête */}
      <div style={{position: 'absolute', top: 48, left: 0, width: '100%', textAlign: 'center', transform: `translateY(${(1 - head) * -200}px)`, opacity: head}}>
        <div style={{display: 'inline-block', font: '800 30px Montserrat', color: '#fff', background: p.color, padding: '6px 22px', borderRadius: 30, letterSpacing: 4}}>
          {String(index + 1).padStart(2, '0')} / {String(PRODUCTS.length).padStart(2, '0')} · SPÉCIAL JBL
        </div>
        <div style={{display: 'flex', justifyContent: 'center', alignItems: 'baseline', gap: 24, marginTop: 14}}>
          <Text3D size={84} color="#ff6a00" depth="#3a1200">{p.name}</Text3D>
          <Text3D size={124} color="#fff" depth={p.color2}>{p.model}</Text3D>
        </div>
        <div style={{font: 'italic 600 36px Poppins', color: '#fff', marginTop: 6, textShadow: '0 3px 10px rgba(0,0,0,.7)'}}>{p.tagline}</div>
      </div>

      {/* pastille prix en 3D */}
      <div style={{position: 'absolute', right: 40, top: 360, perspective: 800}}>
        <div style={{width: 210, height: 210, borderRadius: '50%', background: `radial-gradient(circle at 35% 30%, #ff4b62, ${RED} 50%, ${RED_DARK})`, border: `6px solid ${GOLD}`, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', color: '#fff', textAlign: 'center',
          boxShadow: '0 16px 30px rgba(0,0,0,.5)', transform: `scale(${badge}) rotateY(${Math.sin(frame / 18) * 25}deg) rotate(${-10 + Math.sin(frame / 12) * 4}deg)`}}>
          {p.price ? (
            <>
              <div style={{font: '900 50px/1 Montserrat', letterSpacing: -2}}>{p.price}</div>
              <div style={{font: '800 26px Montserrat', color: GOLD}}>FCFA</div>
            </>
          ) : (
            <>
              <div style={{font: '700 26px/1 Montserrat', color: GOLD}}>PRIX</div>
              <div style={{font: '900 38px/1.05 Montserrat'}}>TRÈS<br />BIENTÔT</div>
            </>
          )}
        </div>
      </div>

      {/* caractéristiques */}
      <div style={{position: 'absolute', left: 50, right: 50, bottom: 70, display: 'flex', flexDirection: 'column', gap: 16}}>
        {p.specs.map((s, i) => {
          const start = 40 + i * 50;
          const sp = useSpring(start, 13);
          const fromLeft = i % 2 === 0;
          return (
            <div key={i} style={{display: 'flex', alignItems: 'center', gap: 22, padding: '14px 26px', borderRadius: 26, background: 'rgba(10,10,14,.72)', border: `2px solid ${p.color}`, boxShadow: `0 10px 30px rgba(0,0,0,.5), inset 0 0 30px ${p.color}33`,
              transform: `perspective(1000px) translateX(${(1 - sp) * (fromLeft ? -1100 : 1100)}px) rotateY(${(1 - sp) * (fromLeft ? 60 : -60)}deg)`, opacity: Math.min(1, sp * 1.5)}}>
              <div style={{width: 76, height: 76, flex: 'none', borderRadius: '50%', background: `radial-gradient(circle at 35% 30%, #fff, ${p.color} 55%, ${p.color2})`, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 40, boxShadow: `0 0 18px ${p.color}`}}>{s.icon}</div>
              <div>
                <div style={{font: '800 40px/1.1 Montserrat', color: '#fff'}}>{s.title}</div>
                <div style={{font: '500 28px/1.2 Poppins', color: '#ddd'}}>{s.text}</div>
              </div>
            </div>
          );
        })}
      </div>

      {/* petit logo boutique */}
      <div style={{position: 'absolute', left: -60, top: 330, opacity: 0.95}}><Logo scale={0.42} /></div>

      {/* volet d'entrée / sortie */}
      <AbsoluteFill style={{background: `linear-gradient(135deg, ${p.color}, ${p.color2})`, clipPath: `polygon(${wipe * 140}% 0, 140% 0, 140% 100%, ${wipe * 140 - 40}% 100%)`}} />
      <AbsoluteFill style={{background: RED, clipPath: `polygon(0 0, ${outWipe * 140}% 0, ${outWipe * 140 - 40}% 100%, 0 100%)`}} />
    </AbsoluteFill>
  );
};

/* ---------------- OUTRO ---------------- */
const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const logo = useSpring(0, 12);
  const t1 = useSpring(20);
  const items = [
    {icon: '📞', k: 'Contact / WhatsApp', v: SHOP.contact, big: true},
    {icon: '📍', k: 'Siège', v: SHOP.siege},
    {icon: '🏬', k: 'Magasins annexes', v: SHOP.annexes.join(' • ')},
    {icon: '🚚', k: 'Services', v: SHOP.services.join(' • ')},
  ];
  return (
    <AbsoluteFill style={{background: `linear-gradient(180deg, #8f0d1d 0%, #5c0610 60%, #2a0207 100%)`, overflow: 'hidden', opacity: fade(frame, 0, OUTRO + 20, 12)}}>
      <SoundRings color={GOLD} x={540} y={360} count={5} speed={60} />
      <Particles color={GOLD} n={30} seed="outro" />
      <div style={{position: 'absolute', top: 110, width: '100%', display: 'flex', justifyContent: 'center', transform: `perspective(1200px) rotateY(${(1 - logo) * -180 + Math.sin(frame / 30) * 8}deg) scale(${0.5 + logo * 0.8})`, opacity: logo}}>
        <Logo scale={1.3} />
      </div>
      <div style={{position: 'absolute', top: 520, width: '100%', textAlign: 'center', opacity: t1, transform: `scale(${0.6 + t1 * 0.4})`}}>
        <div style={{font: '400 74px "Kaushan Script"', color: GOLD}}>Disponibles chez</div>
        <Text3D size={104} color="#fff" depth="#3a0208">ZEYNAB STORE</Text3D>
        <div style={{display: 'flex', justifyContent: 'center', gap: 14, marginTop: 26}}>
          {PRODUCTS.map((p, i) => (
            <div key={p.id} style={{font: '800 30px Montserrat', color: '#fff', background: p.color, padding: '8px 18px', borderRadius: 18, transform: `translateY(${Math.sin((frame + i * 10) / 8) * 6}px)`}}>{p.model}</div>
          ))}
        </div>
      </div>
      <div style={{position: 'absolute', left: 60, right: 60, top: 880, display: 'flex', flexDirection: 'column', gap: 20}}>
        {items.map((it, i) => {
          const sp = useSpring(45 + i * 14, 14);
          return (
            <div key={i} style={{display: 'flex', alignItems: 'center', gap: 24, padding: '18px 26px', background: 'rgba(0,0,0,.28)', borderRadius: 24, border: `2px solid ${GOLD}88`, transform: `translateX(${(1 - sp) * 1200}px)`}}>
              <div style={{width: 84, height: 84, flex: 'none', borderRadius: '50%', background: 'radial-gradient(circle at 35% 30%,#fff3c4,#e6b850 50%,#a8761d)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 44}}>{it.icon}</div>
              <div>
                <div style={{font: '600 28px Poppins', color: GOLD}}>{it.k}</div>
                <div style={{font: it.big ? '900 66px/1.05 Montserrat' : '700 34px/1.2 Montserrat', color: '#fff'}}>{it.v}</div>
              </div>
            </div>
          );
        })}
      </div>
      <div style={{position: 'absolute', bottom: 150, width: '100%', display: 'flex', justifyContent: 'center', opacity: useSpring(110)}}>
        <Equalizer color={GOLD} bars={30} width={900} height={70} />
      </div>
      <div style={{position: 'absolute', bottom: 60, width: '100%', textAlign: 'center', font: '800 40px Montserrat', color: '#fff', opacity: useSpring(120), letterSpacing: 2}}>
        PRIX TRÈS BIENTÔT · RESTEZ CONNECTÉS !
      </div>
    </AbsoluteFill>
  );
};

export const JBLVideo: React.FC = () => (
  <AbsoluteFill style={{background: '#000'}}>
    <Audio src={staticFile('music.m4a')} volume={0.8} />
    <Sequence durationInFrames={INTRO}><Intro /></Sequence>
    {PRODUCTS.map((p, i) => (
      <Sequence key={p.id} from={INTRO + i * SCENE} durationInFrames={SCENE}><ProductScene p={p} index={i} /></Sequence>
    ))}
    <Sequence from={INTRO + PRODUCTS.length * SCENE} durationInFrames={OUTRO}><Outro /></Sequence>
  </AbsoluteFill>
);
