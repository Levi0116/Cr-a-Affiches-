import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig, random} from 'remotion';

export const RED = '#c8102e';
export const RED_DARK = '#5e0711';
export const GOLD = '#f0c66b';

// Logo Zeynab Store (même dessin que sur les affiches)
export const Logo: React.FC<{scale?: number; light?: boolean}> = ({scale = 1, light = true}) => {
  const ink = light ? '#fff' : '#1b1b1b';
  return (
    <div style={{width: 440, textAlign: 'center', transform: `scale(${scale})`, transformOrigin: 'center'}}>
      <div style={{display: 'flex', alignItems: 'flex-end', justifyContent: 'center', height: 130}}>
        <div style={{position: 'relative', width: 112, height: 104}}>
          <div style={{position: 'absolute', left: 28, top: -26, width: 56, height: 56, border: `9px solid ${light ? '#fff' : '#2b0a0e'}`, borderBottom: 0, borderRadius: '30px 30px 0 0'}} />
          <div style={{position: 'absolute', inset: '14px 0 0 0', background: 'linear-gradient(160deg,#e01b36,#8e0b1b)', borderRadius: '10px 10px 16px 16px', boxShadow: '0 6px 12px rgba(0,0,0,.35)'}} />
          <div style={{position: 'absolute', inset: '6px 0 0 0', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', font: '900 108px/1 Montserrat', letterSpacing: -4}}>Z</div>
        </div>
        <div style={{font: '900 112px/0.86 Montserrat', letterSpacing: -5, background: light ? 'linear-gradient(180deg,#fff,#ffd0d6)' : 'linear-gradient(180deg,#e3203a,#8e0b1b)', WebkitBackgroundClip: 'text', backgroundClip: 'text', color: 'transparent', marginLeft: -6, paddingBottom: 4}}>store</div>
      </div>
      <div style={{font: '800 31px Montserrat', letterSpacing: 9, marginTop: 4, color: ink}}>ZEYNAB STORE</div>
      <div style={{font: '500 19.5px Montserrat', marginTop: 2, color: ink, opacity: 0.9}}>VOTRE SATISFACTION, NOTRE PRIORITÉ</div>
      <div style={{height: 3, width: 200, margin: '8px auto 0', background: `linear-gradient(90deg,transparent,${GOLD},transparent)`, borderRadius: 3}} />
    </div>
  );
};

// Enceinte 3D en CSS : cylindre fait de facettes, qui tourne
export const Speaker3D: React.FC<{color: string; color2: string; w?: number; h?: number; rot: number; tilt?: number; label?: string}> = ({color, color2, w = 300, h = 520, rot, tilt = -12, label = ''}) => {
  const n = 28;
  const r = w / 2;
  const face = 2 * r * Math.tan(Math.PI / n) + 1;
  return (
    <div style={{width: w, height: h + r, perspective: 1600}}>
      <div style={{position: 'relative', width: w, height: h, transformStyle: 'preserve-3d', transform: `translateY(${r / 2}px) rotateX(${tilt}deg) rotateY(${rot}deg)`}}>
        {Array.from({length: n}).map((_, i) => {
          const a = (360 / n) * i;
          const shade = 0.55 + 0.45 * Math.cos(((a + rot - 40) * Math.PI) / 180);
          return (
            <div key={i} style={{position: 'absolute', left: r - face / 2, top: 0, width: face, height: h, transform: `rotateY(${a}deg) translateZ(${r}px)`, backfaceVisibility: 'hidden',
              background: `linear-gradient(180deg, ${color2} 0%, ${color} 12%, ${color} 88%, ${color2} 100%)`, filter: `brightness(${shade})`,
              backgroundImage: `radial-gradient(circle at 50% 50%, rgba(0,0,0,.35) 1.5px, transparent 2px), linear-gradient(180deg, ${color2} 0%, ${color} 12%, ${color} 88%, ${color2} 100%)`, backgroundSize: '7px 7px, 100% 100%'}} />
          );
        })}
        {[0, h].map((y, i) => (
          <div key={i} style={{position: 'absolute', left: 0, top: y - r, width: w, height: w, borderRadius: '50%', transform: `rotateX(90deg)`, background: `radial-gradient(circle, #222 0 35%, ${color2} 36% 60%, #111 61% 100%)`, boxShadow: `0 0 0 6px ${color2}`}} />
        ))}
        {label ? (
          <div style={{position: 'absolute', left: r - 120, top: h / 2 - 50, width: 240, height: 100, display: 'flex', alignItems: 'center', justifyContent: 'center', transform: `translateZ(${r + 2}px)`, font: '900 64px Montserrat', color: '#fff', letterSpacing: -2, textShadow: '0 3px 0 rgba(0,0,0,.35)', backfaceVisibility: 'hidden'}}>{label}</div>
        ) : null}
      </div>
    </div>
  );
};

// Texte en relief 3D
export const Text3D: React.FC<{children: React.ReactNode; size: number; color?: string; depth?: string; style?: React.CSSProperties}> = ({children, size, color = '#fff', depth = '#000', style}) => {
  const layers = Array.from({length: 10}).map((_, i) => `${i + 1}px ${i + 1}px 0 ${depth}`).join(',');
  return (
    <div style={{font: `900 ${size}px/1 Montserrat`, color, letterSpacing: -2, textShadow: `${layers}, 14px 18px 24px rgba(0,0,0,.55)`, ...style}}>{children}</div>
  );
};

// Ondes sonores qui partent d'un point
export const SoundRings: React.FC<{color: string; x: number; y: number; count?: number; speed?: number}> = ({color, x, y, count = 5, speed = 60}) => {
  const frame = useCurrentFrame();
  return (
    <>
      {Array.from({length: count}).map((_, i) => {
        const p = ((frame + (i * speed) / count) % speed) / speed;
        return (
          <div key={i} style={{position: 'absolute', left: x, top: y, width: 10, height: 10, borderRadius: '50%', border: `4px solid ${color}`, transform: `translate(-50%,-50%) scale(${1 + p * 110})`, opacity: (1 - p) * 0.5, borderWidth: 4 / (1 + p * 110) * 3}} />
        );
      })}
    </>
  );
};

// Particules lumineuses qui montent
export const Particles: React.FC<{color: string; n?: number; seed?: string}> = ({color, n = 40, seed = 'p'}) => {
  const frame = useCurrentFrame();
  return (
    <>
      {Array.from({length: n}).map((_, i) => {
        const x = random(seed + 'x' + i) * 1080;
        const sp = 1 + random(seed + 's' + i) * 3;
        const size = 4 + random(seed + 'z' + i) * 10;
        const y = 1920 - ((frame * sp + random(seed + 'y' + i) * 1920) % 2100);
        return (
          <div key={i} style={{position: 'absolute', left: x + Math.sin((frame + i * 20) / 25) * 20, top: y, width: size, height: size, borderRadius: '50%', background: color, boxShadow: `0 0 ${size * 2}px ${color}`, opacity: 0.35 + random(seed + 'o' + i) * 0.5}} />
        );
      })}
    </>
  );
};

// Barres d'égaliseur animées
export const Equalizer: React.FC<{color: string; bars?: number; width?: number; height?: number}> = ({color, bars = 24, width = 900, height = 80}) => {
  const frame = useCurrentFrame();
  const bw = width / bars;
  return (
    <div style={{display: 'flex', alignItems: 'flex-end', gap: bw * 0.3, height, width}}>
      {Array.from({length: bars}).map((_, i) => {
        const beat = Math.exp(-((frame % 15) / 5));
        const v = 0.2 + 0.5 * Math.abs(Math.sin(frame / 6 + i * 0.7)) * (0.6 + 0.4 * Math.sin(i * 1.3)) + 0.3 * beat * random('eq' + i);
        return <div key={i} style={{width: bw * 0.7, height: height * Math.min(1, v), borderRadius: bw, background: `linear-gradient(180deg, #fff, ${color})`, boxShadow: `0 0 12px ${color}`}} />;
      })}
    </div>
  );
};

export const useSpring = (delay: number, damping = 14) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({frame: frame - delay, fps, config: {damping}});
};

export const fade = (frame: number, start: number, end: number, len = 10) =>
  interpolate(frame, [start, start + len, end - len, end], [0, 1, 1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});
