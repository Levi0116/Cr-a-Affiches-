import React from 'react';
import {AbsoluteFill, Audio, Img, OffthreadVideo, Sequence, interpolate, spring, staticFile, useCurrentFrame, Easing, random} from 'remotion';
import {GOLD, Logo} from '../parts';
import {SHOP} from '../data';
import SPEC from './spectrum.json';
import {Stage3D} from './Stage3D';
import {AP, FPS_A, HERO, INTRO_A, OUTRO_A, OVERLAP, PRODUCTS_A, SCENE_A, Shot, TOTAL_A, VO_DELAY_A, priceAtA, startA} from './data';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const DISP = 'Unbounded';
const BODY = 'Montserrat';
const BEAT = (60 / 112) * FPS_A; // une noire en images
const N = PRODUCTS_A.length;
const sp = (f: number, d: number, dur = 18) => spring({frame: f - d, fps: FPS_A, config: {damping: 15, stiffness: 120}, durationInFrames: dur});
const specAt = (abs: number): number[] => (SPEC as number[][])[Math.max(0, Math.min(SPEC.length - 1, Math.round(abs)))];
const pad2 = (n: number) => String(n).padStart(2, '0');
const photoSrc = (p: AP) => `audio/photos/${p.photo}`;

/* ---------- texte géant en filigrane qui défile ---------- */
const Marquee: React.FC<{text: string; f: number; accent: string; y: number; dir?: number; size?: number; op?: number}> = ({text, f, accent, y, dir = 1, size = 230, op = 0.22}) => {
  const word = `${text} • `;
  return (
    <div style={{position: 'absolute', top: y, left: -400, whiteSpace: 'nowrap', transform: `rotate(-7deg) translateX(${dir * ((f * 3.2) % 1600) - 800}px)`, font: `900 ${size}px/1 ${DISP}`, color: 'transparent', WebkitTextStroke: `2px ${accent}`, opacity: op}}>
      {word.repeat(6)}
    </div>
  );
};

/* ---------- lettres qui montent une par une ---------- */
const Stagger: React.FC<{text: string; f: number; delay: number; size: number; color?: string; step?: number; glow?: string}> = ({text, f, delay, size, color = '#fff', step = 2, glow}) => (
  <div style={{display: 'flex', justifyContent: 'center', font: `900 ${size}px/1.05 ${DISP}`, color, letterSpacing: -1, textShadow: glow ? `0 0 40px ${glow}` : undefined}}>
    {text.split('').map((ch, i) => {
      const t = interpolate(f, [delay + i * step, delay + i * step + 14], [0, 1], {...clamp, easing: Easing.out(Easing.cubic)});
      return (
        <span key={i} style={{display: 'inline-block', whiteSpace: 'pre', opacity: t, transform: `translateY(${(1 - t) * size * 0.7}px) scale(${0.6 + 0.4 * t})`, filter: `blur(${(1 - t) * 10}px)`}}>{ch}</span>
      );
    })}
  </div>
);

/* ---------- barre « lecteur de musique » ---------- */
const PlayerBar: React.FC<{f: number; len: number; accent: string; index: number; label: string}> = ({f, len, accent, index, label}) => {
  const p = Math.max(0, Math.min(1, f / len));
  const t = (s: number) => `0:${pad2(Math.floor(s))}`;
  return (
    <div style={{position: 'absolute', left: 60, right: 60, bottom: 46}}>
      <div style={{display: 'flex', justifyContent: 'space-between', font: `700 22px ${BODY}`, color: 'rgba(255,255,255,.75)', letterSpacing: 3, marginBottom: 12}}>
        <span><span style={{color: accent}}>♪ EN LECTURE</span> · TRACK {pad2(index + 1)}/{N}</span>
        <span>{label}</span>
      </div>
      <div style={{display: 'flex', alignItems: 'center', gap: 18, font: `600 22px ${BODY}`, color: '#fff'}}>
        <span style={{width: 56}}>{t((p * len) / FPS_A)}</span>
        <div style={{flex: 1, height: 6, borderRadius: 6, background: 'rgba(255,255,255,.18)', position: 'relative'}}>
          <div style={{position: 'absolute', inset: 0, width: `${p * 100}%`, borderRadius: 6, background: `linear-gradient(90deg, ${accent}, #fff)`, boxShadow: `0 0 14px ${accent}`}} />
          <div style={{position: 'absolute', left: `${p * 100}%`, top: -7, width: 20, height: 20, marginLeft: -10, borderRadius: 10, background: '#fff', boxShadow: `0 0 16px ${accent}`}} />
        </div>
        <span style={{width: 56, textAlign: 'right'}}>{t(len / FPS_A)}</span>
      </div>
    </div>
  );
};

/* ---------- un plan dans la carte (vidéo ou photo) ---------- */
const CW = 920;
const CH = 1000;
const ShotView: React.FC<{s: Shot; len: number; f: number; accent: string}> = ({s, len, f, accent}) => {
  if ('video' in s) {
    const d = s.to - s.from;
    const rate = Math.max(0.55, Math.min(1, (d * FPS_A) / len));
    const trim = Math.round(s.from * FPS_A + Math.max(0, (d * FPS_A - len * rate) / 2));
    if (s.fit === 'contain') {
      const sc = CW / s.w;
      const dh = s.h * sc;
      return (
        <AbsoluteFill>
          <Img src={staticFile(`audio/photos/onyx9.png`)} style={{position: 'absolute', inset: -80, width: CW + 160, height: CH + 160, objectFit: 'cover', filter: 'blur(40px) brightness(.45)'}} />
          <div style={{position: 'absolute', left: 0, top: (CH - dh) / 2, width: CW, height: dh, boxShadow: `0 0 50px ${accent}55`}}>
            <OffthreadVideo src={staticFile(s.video)} trimBefore={trim} playbackRate={rate} muted style={{width: CW, height: dh, transform: `scale(${1.04 + f * 0.0004})`}} />
          </div>
        </AbsoluteFill>
      );
    }
    const sc = Math.max(CW / s.w, CH / s.h) * (s.zoom ?? 1) * (1.02 + f * 0.0003);
    const dw = s.w * sc;
    const dh = s.h * sc;
    const left = Math.min(0, Math.max(CW - dw, CW / 2 - (s.cx ?? 0.5) * dw));
    const top = Math.min(0, Math.max(CH - dh, CH / 2 - (s.cy ?? 0.5) * dh));
    return (
      <AbsoluteFill>
        <OffthreadVideo src={staticFile(s.video)} trimBefore={trim} playbackRate={rate} muted style={{position: 'absolute', left, top, width: dw, height: dh, filter: 'contrast(1.08) saturate(1.12)'}} />
      </AbsoluteFill>
    );
  }
  const z = interpolate(f, [0, len], [s.z0, s.z1]);
  if (s.studio) {
    const base = Math.min((CW * 0.78) / s.w, (CH * 0.72) / s.h);
    const sc = base * z;
    const dw = s.w * sc;
    const dh = s.h * sc;
    const sweep = interpolate(f, [0, len], [-0.4, 1.4]);
    return (
      <AbsoluteFill style={{background: `radial-gradient(circle at 50% 45%, ${accent}55, #0b0d13 55%, #040507)`}}>
        <div style={{position: 'absolute', left: CW * 0.1, right: CW * 0.1, bottom: 70, height: 60, borderRadius: '50%', background: 'rgba(0,0,0,.6)', filter: 'blur(18px)'}} />
        <Img src={staticFile(s.img)} style={{position: 'absolute', left: CW / 2 - (s.cx ?? 0.5) * dw, top: CH / 2 - (s.cy ?? 0.5) * dh, width: dw, height: dh, filter: `drop-shadow(0 30px 40px rgba(0,0,0,.6)) drop-shadow(0 0 30px ${accent}44)`}} />
        <AbsoluteFill style={{background: `linear-gradient(105deg, transparent ${sweep * 100 - 12}%, rgba(255,255,255,.18) ${sweep * 100}%, transparent ${sweep * 100 + 12}%)`, mixBlendMode: 'screen'}} />
      </AbsoluteFill>
    );
  }
  const sc = Math.max(CW / s.w, CH / s.h) * z;
  const dw = s.w * sc;
  const dh = s.h * sc;
  const left = Math.min(0, Math.max(CW - dw, CW / 2 - (s.cx ?? 0.5) * dw));
  const top = Math.min(0, Math.max(CH - dh, CH / 2 - (s.cy ?? 0.5) * dh));
  return (
    <AbsoluteFill>
      <Img src={staticFile(s.img)} style={{position: 'absolute', left, top, width: dw, height: dh}} />
    </AbsoluteFill>
  );
};

/* ---------- console de mixage : fiche technique ---------- */
const Console: React.FC<{p: AP; f: number; abs: number; priceAt: number}> = ({p, f, abs, priceAt}) => {
  const start = HERO + 8;
  const step = (priceAt - 16 - start) / p.specs.length;
  const spec = specAt(abs);
  const dim = interpolate(f, [priceAt, priceAt + 12], [1, 0.55], clamp);
  return (
    <div style={{position: 'absolute', left: 60, right: 60, top: 1300, opacity: dim}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 14, font: `700 22px ${BODY}`, color: p.accent, letterSpacing: 6, marginBottom: 10, opacity: sp(f, HERO, 14)}}>
        <div style={{width: 12, height: 12, borderRadius: 6, background: p.accent, boxShadow: `0 0 12px ${p.accent}`}} />
        FICHE TECHNIQUE
        <div style={{flex: 1, height: 2, background: `linear-gradient(90deg, ${p.accent}, transparent)`}} />
      </div>
      {p.specs.map((s, i) => {
        const at = start + i * step;
        const t = sp(f, at, 16);
        const active = f >= at && f < at + step + 4 && f < priceAt;
        const chars = Math.floor(interpolate(f, [at + 2, at + 14], [0, s.v.length], clamp));
        const lvl = Math.min(1, (spec[(i * 2 + 1) % 16] ?? 0) * 1.3);
        return (
          <div key={i} style={{display: 'flex', alignItems: 'center', height: 72, padding: '0 22px', marginBottom: 6, borderRadius: 16, background: active ? `linear-gradient(90deg, ${p.accent}38, rgba(255,255,255,.04))` : 'rgba(255,255,255,.045)', border: `1.5px solid ${active ? p.accent : 'rgba(255,255,255,.08)'}`, boxShadow: active ? `0 0 26px ${p.accent}55` : 'none', opacity: t, transform: `translateX(${(1 - t) * -160}px)`}}>
            <div style={{width: 46, font: `900 24px ${DISP}`, color: active ? p.accent : 'rgba(255,255,255,.4)'}}>{pad2(i + 1)}</div>
            <div style={{width: 250, font: `700 21px ${BODY}`, color: p.accent, letterSpacing: 3}}>{s.k}</div>
            <div style={{flex: 1, font: `700 33px ${BODY}`, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden'}}>{s.v.slice(0, chars)}</div>
            <div style={{display: 'flex', gap: 4, alignItems: 'flex-end', height: 36}}>
              {Array.from({length: 8}).map((_, k) => (
                <div key={k} style={{width: 7, height: 8 + k * 3.6, borderRadius: 2, background: k / 8 < lvl * (active ? 1 : 0.5) ? (k > 5 ? '#fff' : p.accent) : 'rgba(255,255,255,.12)'}} />
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
};

/* ---------- vinyle + prix ---------- */
const PriceDrop: React.FC<{p: AP; f: number; priceAt: number}> = ({p, f, priceAt}) => {
  const t = sp(f, priceAt, 20);
  if (f < priceAt - 2) return null;
  const slam = interpolate(f, [priceAt, priceAt + 8], [2.2, 1], {...clamp, easing: Easing.out(Easing.back(2))});
  const ring = interpolate(f, [priceAt + 4, priceAt + 30], [0, 1], clamp);
  return (
    <div style={{position: 'absolute', left: 0, right: 0, top: 1035, height: 220, display: 'flex', justifyContent: 'center', alignItems: 'center'}}>
      <div style={{position: 'absolute', width: 900 * ring, height: 900 * ring, borderRadius: '50%', border: `4px solid ${p.accent}`, opacity: 1 - ring}} />
      <div style={{display: 'flex', alignItems: 'center', gap: 24, transform: `scale(${slam})`, opacity: t}}>
        {/* vinyle */}
        <div style={{width: 190, height: 190, borderRadius: '50%', flex: 'none', transform: `rotate(${f * 9}deg)`, background: `repeating-radial-gradient(circle, #111 0 3px, #1d1d1d 3px 5px)`, boxShadow: `0 0 0 3px #000, 0 20px 40px rgba(0,0,0,.6), 0 0 40px ${p.accent}66`, display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative'}}>
          <div style={{position: 'absolute', inset: 0, borderRadius: '50%', background: 'conic-gradient(from 20deg, transparent 0 20%, rgba(255,255,255,.18) 25%, transparent 30% 70%, rgba(255,255,255,.12) 75%, transparent 80%)'}} />
          <div style={{width: 76, height: 76, borderRadius: '50%', background: `radial-gradient(circle, #000 0 5px, ${p.accent} 6px)`, display: 'flex', alignItems: 'center', justifyContent: 'center', font: `900 11px ${DISP}`, color: '#000'}} />
        </div>
        <div style={{padding: '16px 34px 18px', borderRadius: 26, background: `linear-gradient(135deg, ${p.accent}, #ffffff)`, boxShadow: `0 20px 50px rgba(0,0,0,.55), 0 0 60px ${p.accent}88`}}>
          <div style={{font: `700 20px ${BODY}`, color: '#000', letterSpacing: 5, opacity: 0.75}}>PRIX ZEYNAB STORE</div>
          <div style={{font: `900 78px/1 ${DISP}`, color: '#05060a', letterSpacing: -2, whiteSpace: 'nowrap'}}>{p.price}<span style={{font: `800 30px ${BODY}`, marginLeft: 10}}>FCFA</span></div>
        </div>
      </div>
    </div>
  );
};

/* ---------- transition « onde sonore » ---------- */
const waveClip = (p: number, f: number) => {
  if (p >= 1) return undefined;
  const pts: string[] = [];
  const base = (1920 + 200) * (1 - p) - 100;
  for (let x = 0; x <= 1080; x += 36) pts.push(`${x}px ${base + Math.sin(x / 95 + f * 0.5) * 90 * (1 - p)}px`);
  return `polygon(0px 1920px, ${pts.join(', ')}, 1080px 1920px)`;
};

/* ---------- scène produit ---------- */
const ProductScene: React.FC<{p: AP; index: number}> = ({p, index}) => {
  const raw = useCurrentFrame();
  const f = raw - OVERLAP; // 0 = début officiel de la scène
  const abs = startA(index) + f;
  const priceAt = priceAtA(p);
  const wipe = interpolate(f, [-OVERLAP, 0], [0, 1], {...clamp, easing: Easing.inOut(Easing.cubic)});
  const heroOut = interpolate(f, [HERO - 8, HERO + 4], [1, 0], clamp);
  const feat = sp(f, HERO - 4, 18);
  const flash = interpolate(f, [HERO - 4, HERO, HERO + 10], [0, 0.85, 0], clamp);
  const shake = f > priceAt && f < priceAt + 14 ? Math.sin(f * 2.3) * (14 - (f - priceAt)) * 1.2 : 0;
  const spec = specAt(abs);
  const bass = (spec[0] + spec[1]) / 2;

  // plans de la carte
  const L = SCENE_A - HERO;
  const durs = p.shots.map((s) => ('video' in s ? s.to - s.from : s.dur));
  const tot = durs.reduce((a, b) => a + b, 0);
  let acc = HERO;
  const shots = p.shots.map((s, i) => {
    const len = i === p.shots.length - 1 ? SCENE_A - acc : Math.round((L * durs[i]) / tot);
    const from = acc;
    acc += len;
    return {s, from, len};
  });
  const cur = shots.find((x) => f >= x.from && f < x.from + x.len) ?? shots[0];
  const cutFlash = shots.slice(1).reduce((a, x) => (f >= x.from ? Math.max(a, interpolate(f, [x.from, x.from + 7], [0.7, 0], clamp)) : a), 0);
  const tilt = Math.sin(f / 45) * 3;
  const titleSize = Math.min(64, 780 / (p.model.length * 0.8));
  const heroSize = Math.min(118, 960 / (p.model.length * 0.82));

  return (
    <AbsoluteFill style={{clipPath: waveClip(wipe, f), background: '#030407'}}>
      {/* ----- partie 2 : carte vidéo + console ----- */}
      {f >= HERO - 10 ? (
        <AbsoluteFill style={{opacity: feat, transform: `translate(${shake}px, ${shake * 0.4}px)`}}>
          <Img src={staticFile(photoSrc(p))} style={{position: 'absolute', left: -200, top: 200, width: 1480, height: 1480, objectFit: 'contain', filter: 'blur(70px) brightness(.55) saturate(1.6)', opacity: 0.8}} />
          <AbsoluteFill style={{background: `radial-gradient(circle at 50% 35%, ${p.accent}30, transparent 60%), linear-gradient(180deg, rgba(3,4,7,.55), rgba(3,4,7,.85) 70%, #030407)`}} />
          <Marquee text={p.model} f={f} accent={p.accent} y={300} />
          <Marquee text={p.brand} f={f} accent="#ffffff" y={760} dir={-1} size={180} op={0.08} />
          {/* en-tête */}
          <div style={{position: 'absolute', left: 60, top: 70, right: 230}}>
            <div style={{font: `700 22px ${BODY}`, color: p.accent, letterSpacing: 6}}>TRACK {pad2(index + 1)} · {p.brand}</div>
            <div style={{font: `900 ${titleSize}px/1.1 ${DISP}`, color: '#fff', whiteSpace: 'nowrap', marginTop: 6}}>{p.model}</div>
          </div>
          <div style={{position: 'absolute', right: 30, top: 40, transform: 'scale(.36)', transformOrigin: 'top right'}}><Logo /></div>
          {/* carte */}
          <div style={{position: 'absolute', left: (1080 - CW) / 2, top: 220, width: CW, height: CH, perspective: 1600}}>
            <div style={{width: '100%', height: '100%', borderRadius: 44, overflow: 'hidden', position: 'relative', transform: `rotateY(${tilt}deg) rotateX(${-tilt * 0.4}deg) scale(${0.9 + 0.1 * feat})`, boxShadow: `0 40px 90px rgba(0,0,0,.7), 0 0 ${40 + bass * 60}px ${p.accent}${Math.round(40 + bass * 90).toString(16).padStart(2, '0')}`, border: `2px solid ${p.accent}aa`}}>
              {shots.map((x, i) => (
                <Sequence key={i} from={x.from + OVERLAP} durationInFrames={x.len + 8} layout="none">
                  <AbsoluteFill style={{clipPath: i === 0 ? undefined : `circle(${interpolate(f, [x.from, x.from + 12], [0, 120], {...clamp, easing: Easing.out(Easing.cubic)})}% at 50% 50%)`, opacity: interpolate(f, [x.from + x.len, x.from + x.len + 8], [1, 1], clamp)}}>
                    <ShotView s={x.s} len={x.len + 8} f={f - x.from} accent={p.accent} />
                  </AbsoluteFill>
                </Sequence>
              ))}
              <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(0,0,0,.25), transparent 22%, transparent 70%, rgba(0,0,0,.55))'}} />
              <AbsoluteFill style={{background: '#fff', opacity: cutFlash}} />
              {/* repères coins */}
              <div style={{position: 'absolute', left: 26, top: 24, display: 'flex', gap: 10, alignItems: 'center', font: `800 20px ${BODY}`, color: '#fff', letterSpacing: 3, padding: '8px 16px', borderRadius: 30, background: 'rgba(0,0,0,.45)', backdropFilter: 'blur(6px)'}}>
                <div style={{width: 10, height: 10, borderRadius: 5, background: p.accent, boxShadow: `0 0 10px ${p.accent}`}} />{p.kind}
              </div>
              {p.badge ? <div style={{position: 'absolute', right: 26, top: 24, font: `900 20px ${DISP}`, color: '#000', padding: '9px 18px', borderRadius: 30, background: p.accent}}>{p.badge}</div> : null}
              <div style={{position: 'absolute', left: 26, bottom: 22, font: `700 18px ${BODY}`, color: 'rgba(255,255,255,.8)', letterSpacing: 3}}>{pad2(cur ? shots.indexOf(cur) + 1 : 1)} / {pad2(shots.length)}</div>
            </div>
          </div>
          <PriceDrop p={p} f={f} priceAt={priceAt} />
          <Console p={p} f={f} abs={abs} priceAt={priceAt} />
        </AbsoluteFill>
      ) : null}

      {/* ----- partie 1 : présentation 3D ----- */}
      {f < HERO + 6 ? (
        <AbsoluteFill style={{opacity: heroOut, transform: `scale(${1 + (1 - heroOut) * 0.25})`}}>
          <Stage3D frame={f + OVERLAP} len={HERO + OVERLAP} accent={p.accent} mode="product" photo={photoSrc(p)} cutout={p.cutout} spec={spec} beat={BEAT} />
          <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(3,4,7,.65), transparent 28%, transparent 72%, rgba(3,4,7,.7))'}} />
          <div style={{position: 'absolute', top: 140, left: 0, right: 0, textAlign: 'center'}}>
            <div style={{font: `700 26px ${BODY}`, color: p.accent, letterSpacing: 12, opacity: sp(f, 0, 14)}}>{p.brand}</div>
            <div style={{marginTop: 10}}><Stagger text={p.model} f={f} delay={4} size={heroSize} glow={`${p.accent}88`} /></div>
            <div style={{display: 'inline-flex', marginTop: 18, gap: 14, opacity: sp(f, 18, 14)}}>
              <span style={{font: `800 22px ${BODY}`, color: '#fff', letterSpacing: 5, padding: '8px 20px', border: `2px solid ${p.accent}`, borderRadius: 30}}>{p.kind}</span>
              {p.badge ? <span style={{font: `900 22px ${DISP}`, color: '#000', padding: '9px 20px', background: p.accent, borderRadius: 30}}>{p.badge}</span> : null}
            </div>
          </div>
          <div style={{position: 'absolute', left: 60, top: 60, font: `900 30px ${DISP}`, color: 'rgba(255,255,255,.9)'}}>{pad2(index + 1)}<span style={{color: 'rgba(255,255,255,.4)'}}>/{N}</span></div>
          <div style={{position: 'absolute', right: 30, top: 30, transform: 'scale(.32)', transformOrigin: 'top right'}}><Logo /></div>
        </AbsoluteFill>
      ) : null}
      <AbsoluteFill style={{background: '#fff', opacity: flash, pointerEvents: 'none'}} />
      <PlayerBar f={f} len={SCENE_A} accent={p.accent} index={index} label={`${p.brand} ${p.model}`} />
      {/* liseré lumineux de l'onde pendant la transition */}
      {wipe < 1 ? (
        <svg width={1080} height={1920} style={{position: 'absolute', inset: 0}}>
          <path d={`M ${Array.from({length: 31}, (_, k) => k * 36).map((x) => `${x} ${(1920 + 200) * (1 - wipe) - 100 + Math.sin(x / 95 + f * 0.5) * 90 * (1 - wipe)}`).join(' L ')}`} stroke={p.accent} strokeWidth={8} fill="none" style={{filter: `drop-shadow(0 0 14px ${p.accent})`}} />
        </svg>
      ) : null}
    </AbsoluteFill>
  );
};

/* ---------- INTRO ---------- */
const BRANDS = ['JBL', 'HARMAN KARDON', 'BOSE', 'APPLE'];
const IntroA: React.FC = () => {
  const f = useCurrentFrame();
  const spec = specAt(f);
  const logo = sp(f, 14, 20);
  const hit = 66;
  const out = interpolate(f, [INTRO_A - 8, INTRO_A], [1, 0], clamp);
  const beatIdx = Math.floor(Math.max(0, f - hit) / (BEAT * 2)) % BRANDS.length;
  // ligne d'onde
  const wave = Array.from({length: 61}, (_, k) => {
    const x = k * 18;
    const amp = (spec[k % 16] ?? 0) * 140 * Math.sin((k / 60) * Math.PI);
    return `${x} ${960 + Math.sin(k * 0.7 + f * 0.4) * amp}`;
  }).join(' L ');
  const draw = interpolate(f, [0, 40], [0, 1], clamp);
  return (
    <AbsoluteFill style={{background: '#030407', opacity: out}}>
      {f >= hit - 4 ? <Stage3D frame={f - hit + 4} len={INTRO_A - hit} accent={GOLD} mode="intro" spec={spec} beat={BEAT} /> : null}
      <AbsoluteFill style={{background: 'linear-gradient(180deg, rgba(3,4,7,.7), transparent 35%, transparent 60%, rgba(3,4,7,.85))'}} />
      {f < hit + 6 ? (
        <svg width={1080} height={1920} style={{position: 'absolute', inset: 0, opacity: interpolate(f, [hit - 2, hit + 6], [1, 0], clamp)}}>
          <path d={`M ${wave}`} stroke={GOLD} strokeWidth={6} fill="none" strokeDasharray={2400} strokeDashoffset={2400 * (1 - draw)} style={{filter: `drop-shadow(0 0 16px ${GOLD})`}} />
        </svg>
      ) : null}
      <div style={{position: 'absolute', top: 120, left: 0, right: 0, display: 'flex', justifyContent: 'center', opacity: logo, transform: `scale(${0.7 + logo * 0.4})`}}><Logo scale={1.15} /></div>
      {f >= hit ? (
        <div style={{position: 'absolute', top: 1190, left: 0, right: 0}}>
          <Stagger text="SOUND" f={f} delay={hit} size={170} glow={`${GOLD}aa`} step={3} />
          <div style={{position: 'relative'}}>
            {[2, 1].map((k) => (
              <div key={k} style={{position: 'absolute', left: 0, right: 0, top: k * 14, textAlign: 'center', font: `900 92px/1 ${DISP}`, color: 'transparent', WebkitTextStroke: `2px ${GOLD}`, opacity: 0.35 / k * sp(f, hit + 14, 16)}}>COLLECTION</div>
            ))}
            <Stagger text="COLLECTION" f={f} delay={hit + 8} size={92} color={GOLD} step={2} />
          </div>
        </div>
      ) : null}
      <div style={{position: 'absolute', bottom: 210, left: 0, right: 0, textAlign: 'center', opacity: sp(f, hit + 20, 16)}}>
        <div style={{display: 'flex', justifyContent: 'center', gap: 22, font: `800 30px ${BODY}`, letterSpacing: 4}}>
          {BRANDS.map((b, i) => <span key={b} style={{color: i === beatIdx ? GOLD : 'rgba(255,255,255,.55)', textShadow: i === beatIdx ? `0 0 20px ${GOLD}` : 'none'}}>{b}</span>)}
        </div>
        <div style={{font: `600 30px ${BODY}`, color: '#fff', letterSpacing: 5, marginTop: 18}}>{N} PRODUITS · PRIX CHOC · LIVRAISON</div>
      </div>
      <AbsoluteFill style={{background: '#fff', opacity: interpolate(f, [hit - 3, hit, hit + 12], [0, 0.95, 0], clamp)}} />
    </AbsoluteFill>
  );
};

/* ---------- OUTRO ---------- */
const OutroA: React.FC = () => {
  const f = useCurrentFrame();
  const abs = TOTAL_A - OUTRO_A + f;
  const spec = specAt(abs);
  const SPLIT = 220;
  const list = interpolate(f, [SPLIT - 12, SPLIT], [1, 0], clamp);
  const info = sp(f, SPLIT - 4, 18);
  const end = interpolate(f, [OUTRO_A - 14, OUTRO_A], [1, 0], clamp);
  const items = [
    {icon: '📞', k: 'CONTACT / WHATSAPP', v: SHOP.contact, big: true},
    {icon: '📍', k: 'SIÈGE', v: SHOP.siege},
    {icon: '🏬', k: 'MAGASINS ANNEXES', v: SHOP.annexes.join(' • ')},
    {icon: '🚚', k: 'SERVICES', v: SHOP.services.join(' • ')},
  ];
  return (
    <AbsoluteFill style={{background: 'radial-gradient(circle at 50% 30%, #1a1406, #030407 65%)', opacity: end}}>
      <Marquee text="ZEYNAB STORE" f={f} accent={GOLD} y={880} size={200} op={0.1} />
      {/* égaliseur bas de l'écran */}
      <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 260, display: 'flex', alignItems: 'flex-end', gap: 6, padding: '0 12px', opacity: 0.5}}>
        {Array.from({length: 48}).map((_, i) => {
          const v = spec[Math.abs(i - 24) % 16] ?? 0;
          return <div key={i} style={{flex: 1, height: 10 + v * 230 * (0.6 + 0.4 * random('o' + i)), borderRadius: 4, background: `linear-gradient(0deg, ${GOLD}, transparent)`}} />;
        })}
      </div>
      <div style={{position: 'absolute', top: 60, left: 0, right: 0, display: 'flex', justifyContent: 'center', opacity: sp(f, 0, 16)}}><Logo scale={0.95} /></div>
      {/* tracklist */}
      <div style={{position: 'absolute', left: 50, right: 50, top: 330, opacity: list}}>
        <div style={{font: `900 46px ${DISP}`, color: '#fff', marginBottom: 18, display: 'flex', justifyContent: 'space-between', alignItems: 'baseline'}}>
          <span>TRACKLIST</span><span style={{font: `700 22px ${BODY}`, color: GOLD, letterSpacing: 5}}>PRIX EN FCFA</span>
        </div>
        {PRODUCTS_A.map((p, i) => {
          const t = sp(f, 6 + i * 4, 14);
          return (
            <div key={p.id} style={{display: 'flex', alignItems: 'center', gap: 18, height: 74, borderBottom: '1px solid rgba(255,255,255,.1)', opacity: t, transform: `translateX(${(1 - t) * 300}px)`}}>
              <div style={{width: 40, font: `900 20px ${DISP}`, color: p.accent}}>{pad2(i + 1)}</div>
              <div style={{width: 62, height: 62, borderRadius: 12, background: 'rgba(255,255,255,.92)', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden', flex: 'none'}}>
                <Img src={staticFile(photoSrc(p))} style={{maxWidth: p.cutout ? 54 : 62, maxHeight: p.cutout ? 54 : 62, objectFit: p.cutout ? 'contain' : 'cover', width: p.cutout ? undefined : 62, height: p.cutout ? undefined : 62}} />
              </div>
              <div style={{flex: 1, minWidth: 0}}>
                <div style={{font: `700 16px ${BODY}`, color: 'rgba(255,255,255,.55)', letterSpacing: 3}}>{p.brand}</div>
                <div style={{font: `800 28px/1.1 ${BODY}`, color: '#fff', whiteSpace: 'nowrap'}}>{p.model}</div>
              </div>
              <div style={{font: `900 32px ${DISP}`, color: GOLD, whiteSpace: 'nowrap'}}>{p.price}</div>
            </div>
          );
        })}
      </div>
      {/* infos boutique */}
      {f >= SPLIT - 6 ? (
        <>
          <div style={{position: 'absolute', top: 360, left: 0, right: 0, textAlign: 'center', opacity: info}}>
            <div style={{font: `700 30px ${BODY}`, color: GOLD, letterSpacing: 10}}>DISPONIBLE CHEZ</div>
            <div style={{font: `900 88px/1.1 ${DISP}`, color: '#fff', textShadow: `0 0 40px ${GOLD}55`}}>ZEYNAB STORE</div>
          </div>
          <div style={{position: 'absolute', left: 56, right: 56, top: 590, display: 'flex', flexDirection: 'column', gap: 22}}>
            {items.map((it, i) => {
              const t = sp(f, SPLIT + i * 8, 16);
              return (
                <div key={i} style={{display: 'flex', alignItems: 'center', gap: 24, padding: '22px 26px', background: 'rgba(10,9,6,.8)', borderRadius: 28, border: `2px solid ${GOLD}aa`, boxShadow: `0 0 30px ${GOLD}22`, transform: `translateX(${(1 - t) * 1200}px)`}}>
                  <div style={{width: 92, height: 92, flex: 'none', borderRadius: '50%', background: 'radial-gradient(circle at 35% 30%,#fff3c4,#e6b850 50%,#a8761d)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 46}}>{it.icon}</div>
                  <div>
                    <div style={{font: `700 24px ${BODY}`, color: GOLD, letterSpacing: 4}}>{it.k}</div>
                    <div style={{font: it.big ? `900 70px/1.05 ${DISP}` : `700 38px/1.25 ${BODY}`, color: '#fff'}}>{it.v}</div>
                  </div>
                </div>
              );
            })}
          </div>
          <div style={{position: 'absolute', bottom: 300, left: 0, right: 0, textAlign: 'center', font: `900 46px ${DISP}`, color: '#fff', opacity: sp(f, SPLIT + 40, 16)}}>
            COMMANDEZ <span style={{color: GOLD}}>MAINTENANT</span>
          </div>
        </>
      ) : null}
    </AbsoluteFill>
  );
};

export const AudioVideo: React.FC = () => {
  const outroAt = INTRO_A + N * SCENE_A;
  return (
    <AbsoluteFill style={{background: '#030407'}}>
      <Audio src={staticFile('audio/music.wav')} volume={(fr) => interpolate(fr, [0, 60, TOTAL_A - 45, TOTAL_A], [0.45, 0.24, 0.24, 0], clamp)} />
      <Sequence durationInFrames={INTRO_A}>
        <IntroA />
        <Audio src={staticFile('audio/riser.mp3')} volume={0.5} />
        <Sequence from={64}><Audio src={staticFile('audio/impact.mp3')} volume={0.75} /></Sequence>
        <Sequence from={84}><Audio src={staticFile('audio/vo/intro.mp3')} /></Sequence>
      </Sequence>
      {PRODUCTS_A.map((p, i) => {
        const lead = OVERLAP;
        return (
          <Sequence key={p.id} from={startA(i) - lead} durationInFrames={SCENE_A + lead}>
            <ProductScene p={p} index={i} />
            <Sequence from={lead + VO_DELAY_A}><Audio src={staticFile(`audio/vo/${p.id}.mp3`)} /></Sequence>
            <Audio src={staticFile('audio/whoosh.mp3')} volume={0.55} />
            <Sequence from={lead + HERO - 10}><Audio src={staticFile('audio/whoosh.mp3')} volume={0.4} /></Sequence>
            <Sequence from={lead + priceAtA(p) + 2}><Audio src={staticFile('audio/impact.mp3')} volume={0.5} /></Sequence>
          </Sequence>
        );
      })}
      <Sequence from={outroAt} durationInFrames={OUTRO_A}>
        <OutroA />
        <Sequence from={VO_DELAY_A}><Audio src={staticFile('audio/vo/outro.mp3')} /></Sequence>
      </Sequence>
    </AbsoluteFill>
  );
};
