import React, {useLayoutEffect, useMemo} from 'react';
import {useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {ThreeCanvas} from '@remotion/three';
import {interpolate, Easing, random} from 'remotion';
import {Environment, Lightformer, MeshReflectorMaterial, RoundedBox} from '@react-three/drei';
import {EffectComposer, Bloom, Vignette, ChromaticAberration, Noise} from '@react-three/postprocessing';
import {BlendFunction} from 'postprocessing';
import {useTex} from '../dji2/Studio3D';

// Scène « Studio Son » : produit sur un sol miroir, entouré d'un anneau d'égaliseur 3D qui réagit à la musique.
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;
const col = (hex: string, k: number) => new THREE.Color(hex).multiplyScalar(k);

const Rig: React.FC<{pos: [number, number, number]; look: [number, number, number]; fov: number}> = ({pos, look, fov}) => {
  const {camera} = useThree();
  useLayoutEffect(() => {
    camera.position.set(...pos);
    camera.lookAt(...look);
    (camera as THREE.PerspectiveCamera).fov = fov;
    camera.updateProjectionMatrix();
  });
  return null;
};

/* Anneau d'égaliseur : N barres disposées en cercle, hauteur = spectre de la musique */
const EqRing: React.FC<{spec: number[]; accent: string; radius: number; n?: number; appear: number; frame: number}> = ({spec, accent, radius, n = 84, appear, frame}) => {
  const ref = React.useRef<THREE.InstancedMesh>(null);
  const geo = useMemo(() => {
    const g = new THREE.BoxGeometry(0.07, 1, 0.07);
    g.translate(0, 0.5, 0);
    return g;
  }, []);
  const mat = useMemo(() => new THREE.MeshBasicMaterial({toneMapped: false}), []);
  const dummy = useMemo(() => new THREE.Object3D(), []);
  const c1 = useMemo(() => col(accent, 3.2), [accent]);
  const c2 = useMemo(() => col('#ffffff', 2.4), []);
  useLayoutEffect(() => {
    const m = ref.current;
    if (!m) return;
    for (let i = 0; i < n; i++) {
      const a = (i / n) * Math.PI * 2 + frame * 0.004;
      // spectre en miroir (graves devant et derrière)
      const k = Math.abs(((i / n) * 2 - 1));
      const idx = Math.min(spec.length - 1, Math.floor(k * spec.length * 0.7));
      const v = spec[idx] ?? 0;
      const h = (0.06 + Math.min(1.6, v * 3.2) * (0.75 + 0.25 * random('b' + i))) * appear;
      dummy.position.set(Math.sin(a) * radius, 0, Math.cos(a) * radius);
      dummy.rotation.set(0, a, 0);
      dummy.scale.set(1, Math.max(0.001, h), 1);
      dummy.updateMatrix();
      m.setMatrixAt(i, dummy.matrix);
      m.setColorAt(i, new THREE.Color().lerpColors(c1, c2, Math.min(1, v * 1.6)));
    }
    m.instanceMatrix.needsUpdate = true;
    if (m.instanceColor) m.instanceColor.needsUpdate = true;
  });
  return <instancedMesh ref={ref} args={[geo, mat, n]} />;
};

/* Ondes de choc au sol, sur les temps forts */
const Shock: React.FC<{frame: number; accent: string; beat: number}> = ({frame, accent, beat}) => {
  const rings = [0, 1, 2];
  return (
    <group>
      {rings.map((i) => {
        const p = ((frame / beat + i / 3) % 1);
        const r = 0.8 + p * 4.5;
        return (
          <mesh key={i} rotation-x={-Math.PI / 2} position={[0, 0.006 + i * 0.001, 0]}>
            <ringGeometry args={[r - 0.02, r, 128]} />
            <meshBasicMaterial color={col(accent, 2.5)} transparent opacity={(1 - p) * 0.55} toneMapped={false} depthWrite={false} />
          </mesh>
        );
      })}
    </group>
  );
};

/* Socle : disque noir laqué avec liseré lumineux */
const Plinth: React.FC<{accent: string; appear: number; bass: number}> = ({accent, appear, bass}) => (
  <group scale={[appear, 1, appear]}>
    <mesh position={[0, 0.08, 0]}>
      <cylinderGeometry args={[1.35, 1.42, 0.16, 96]} />
      <meshPhysicalMaterial color="#07090d" metalness={0.8} roughness={0.18} clearcoat={1} />
    </mesh>
    <mesh position={[0, 0.162, 0]} rotation-x={-Math.PI / 2}>
      <ringGeometry args={[1.28, 1.35, 128]} />
      <meshBasicMaterial color={col(accent, 3 + bass * 4)} toneMapped={false} />
    </mesh>
  </group>
);

const Product: React.FC<{tex: THREE.Texture; cutout: boolean; frame: number; accent: string}> = ({tex, cutout, frame, accent}) => {
  const img = tex.image as HTMLImageElement;
  const ar = img.width / img.height;
  let h = cutout ? 2.6 : 2.0;
  let w = h * ar;
  const maxW = cutout ? 3.0 : 3.2;
  if (w > maxW) {
    w = maxW;
    h = w / ar;
  }
  const rise = interpolate(frame, [0, 28], [1.6, 0], {...clamp, easing: Easing.out(Easing.cubic)});
  const op = interpolate(frame, [0, 12], [0, 1], clamp);
  const rotY = Math.sin(frame / 26) * 0.18 + interpolate(frame, [0, 32], [-1.1, 0], {...clamp, easing: Easing.out(Easing.back(1.2))});
  const y = 0.18 + h / 2 + 0.12 + Math.sin(frame / 16) * 0.05 + rise;
  return (
    <group position={[0, y, 0]} rotation={[0, rotY, 0]}>
      {cutout ? (
        <mesh>
          <planeGeometry args={[w, h]} />
          <meshBasicMaterial map={tex} transparent opacity={op} toneMapped={false} side={THREE.DoubleSide} alphaTest={0.03} />
        </mesh>
      ) : (
        <group>
          <RoundedBox args={[w + 0.1, h + 0.1, 0.06]} radius={0.05} position={[0, 0, -0.04]}>
            <meshPhysicalMaterial color="#0a0d12" metalness={0.9} roughness={0.2} clearcoat={1} />
          </RoundedBox>
          <mesh>
            <planeGeometry args={[w, h]} />
            <meshBasicMaterial map={tex} transparent opacity={op} toneMapped={false} />
          </mesh>
          <mesh position={[0, -h / 2 - 0.05, 0.01]}><planeGeometry args={[w + 0.1, 0.02]} /><meshBasicMaterial color={col(accent, 4)} toneMapped={false} /></mesh>
        </group>
      )}
    </group>
  );
};

const Dust: React.FC<{frame: number; color: string}> = ({frame, color}) => {
  const geo = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const n = 220;
    const p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      p[i * 3] = (random('ax' + i) - 0.5) * 10;
      p[i * 3 + 1] = random('ay' + i) * 6;
      p[i * 3 + 2] = (random('az' + i) - 0.5) * 10;
    }
    g.setAttribute('position', new THREE.BufferAttribute(p, 3));
    return g;
  }, []);
  return (
    <points geometry={geo} position={[0, ((frame * 0.003) % 1) - 0.5, 0]} rotation={[0, -frame * 0.002, 0]}>
      <pointsMaterial size={0.03} color={col(color, 2)} transparent opacity={0.7} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
    </points>
  );
};

export const Stage3D: React.FC<{
  frame: number; len: number; accent: string; mode: 'product' | 'intro'; photo?: string | null; cutout?: boolean; spec: number[]; beat: number;
}> = ({frame, len, accent, mode, photo = null, cutout = true, spec, beat}) => {
  const tex = useTex(photo);
  const bass = (spec[0] + spec[1] + spec[2]) / 3;

  let camPos: [number, number, number];
  let look: [number, number, number];
  if (mode === 'product') {
    const a = interpolate(frame, [0, len], [0.6, -0.25]);
    const d = interpolate(frame, [0, len - 16, len], [9.2, 7.6, 3.2], {...clamp, easing: Easing.in(Easing.quad)});
    camPos = [Math.sin(a) * d, interpolate(frame, [0, len], [1.0, 1.7]), Math.cos(a) * d];
    look = [0, 1.55, 0];
  } else {
    const a = interpolate(frame, [0, len], [-0.8, 0.4]);
    const d = interpolate(frame, [0, len], [5.5, 9.5], {...clamp, easing: Easing.inOut(Easing.cubic)});
    camPos = [Math.sin(a) * d, interpolate(frame, [0, len], [6.5, 2.2], {...clamp, easing: Easing.inOut(Easing.cubic)}), Math.cos(a) * d];
    look = [0, 1.0, 0];
  }
  const appear = interpolate(frame, [0, 24], [0, 1], {...clamp, easing: Easing.out(Easing.back(1.5))});

  if (photo && !tex) return null;
  return (
    <ThreeCanvas width={1080} height={1920} gl={{antialias: true, toneMapping: THREE.ACESFilmicToneMapping, outputColorSpace: THREE.SRGBColorSpace}} dpr={1}>
      <Rig pos={camPos} look={look} fov={36} />
      <color attach="background" args={['#030407']} />
      <fog attach="fog" args={['#030407', 10, 24]} />
      <Environment resolution={256} frames={1}>
        <Lightformer intensity={3} position={[0, 6, -4]} scale={[12, 3, 1]} />
        <Lightformer intensity={2.4} position={[-6, 2, 1]} rotation-y={Math.PI / 2} scale={[10, 3, 1]} color={accent} />
        <Lightformer intensity={1.6} position={[6, 2, 1]} rotation-y={-Math.PI / 2} scale={[10, 3, 1]} color="#ffffff" />
        <Lightformer intensity={2.2} position={[0, 2, 6]} scale={[8, 2, 1]} color="#ffffff" />
      </Environment>
      <ambientLight intensity={0.2} />
      <spotLight position={[0, 7, 2]} angle={0.4} penumbra={0.8} intensity={110} color="#ffffff" />
      <pointLight position={[-3, 2, 3]} intensity={10 + bass * 40} color={accent} />

      <Plinth accent={accent} appear={appear} bass={bass} />
      <EqRing spec={spec} accent={accent} radius={mode === 'intro' ? 1.9 : 2.05} appear={appear} frame={frame} />
      <EqRing spec={spec} accent={accent} radius={mode === 'intro' ? 2.6 : 2.9} n={120} appear={appear * 0.55} frame={-frame} />
      <Shock frame={frame} accent={accent} beat={beat * 2} />
      <Dust frame={frame} color={accent} />
      {mode === 'product' && tex ? <Product tex={tex} cutout={cutout} frame={frame} accent={accent} /> : null}

      <mesh rotation-x={-Math.PI / 2}>
        <planeGeometry args={[40, 40]} />
        <MeshReflectorMaterial resolution={512} mirror={0.9} blur={[300, 100]} mixBlur={1.1} mixStrength={3.2} roughness={0.8} depthScale={1.1} minDepthThreshold={0.4} maxDepthThreshold={1.4} color="#07080c" metalness={0.6} />
      </mesh>

      <EffectComposer multisampling={0}>
        <Bloom intensity={1.5} luminanceThreshold={0.7} luminanceSmoothing={0.2} mipmapBlur />
        <ChromaticAberration offset={new THREE.Vector2(0.001, 0.0007)} radialModulation={false} modulationOffset={0} blendFunction={BlendFunction.NORMAL} />
        <Noise opacity={0.05} premultiply blendFunction={BlendFunction.SCREEN} />
        <Vignette eskil={false} offset={0.25} darkness={0.85} />
      </EffectComposer>
    </ThreeCanvas>
  );
};
