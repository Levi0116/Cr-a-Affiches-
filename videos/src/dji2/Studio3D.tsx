import React, {useEffect, useLayoutEffect, useMemo, useState} from 'react';
import {useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {ThreeCanvas} from '@remotion/three';
import {continueRender, delayRender, interpolate, Easing, staticFile, random} from 'remotion';
import {Environment, Lightformer, MeshReflectorMaterial, Text3D, Center, RoundedBox} from '@react-three/drei';
import {EffectComposer, Bloom, Vignette, ChromaticAberration, Noise} from '@react-three/postprocessing';
import {BlendFunction} from 'postprocessing';
import FONT from './montserrat-black.json';
import {Drone3D} from './Drone3D';

const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

export const useTex = (file: string | null) => {
  const [tex, setTex] = useState<THREE.Texture | null>(null);
  const [handle] = useState(() => (file ? delayRender('tex ' + file) : null));
  useEffect(() => {
    if (!file) return;
    new THREE.TextureLoader().load(staticFile(file), (t) => {
      t.colorSpace = THREE.SRGBColorSpace;
      t.anisotropy = 8;
      setTex(t);
      if (handle !== null) continueRender(handle);
    });
  }, [file, handle]);
  return tex;
};

const col = (hex: string, k: number) => new THREE.Color(hex).multiplyScalar(k);

/* Plateforme lumineuse avec anneaux qui tournent */
const Platform: React.FC<{frame: number; accent: string; appear: number}> = ({frame, accent, appear}) => (
  <group scale={[appear, 1, appear]}>
    <mesh position={[0, 0.05, 0]}>
      <cylinderGeometry args={[1.55, 1.65, 0.1, 96]} />
      <meshPhysicalMaterial color="#0d1016" metalness={0.9} roughness={0.25} clearcoat={1} />
    </mesh>
    {[1.62, 1.3, 0.95].map((r, i) => (
      <mesh key={i} position={[0, 0.105 + i * 0.002, 0]} rotation={[-Math.PI / 2, 0, frame * (i % 2 ? 0.02 : -0.03)]}>
        <ringGeometry args={[r - 0.025, r, 128, 1, 0, Math.PI * (i === 0 ? 2 : 1.4)]} />
        <meshBasicMaterial color={col(accent, i === 0 ? 5 : 3)} toneMapped={false} side={THREE.DoubleSide} />
      </mesh>
    ))}
  </group>
);

/* Faisceau de lumière volumétrique */
const BeamMaterial = (color: string) =>
  new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
    uniforms: {uColor: {value: new THREE.Color(color)}, uI: {value: 0.5}},
    vertexShader: 'varying vec2 vUv; varying vec3 vN; varying vec3 vV; void main(){ vUv=uv; vN=normalize(normalMatrix*normal); vec4 mv=modelViewMatrix*vec4(position,1.); vV=normalize(-mv.xyz); gl_Position=projectionMatrix*mv; }',
    fragmentShader: 'uniform vec3 uColor; uniform float uI; varying vec2 vUv; varying vec3 vN; varying vec3 vV; void main(){ float f=pow(abs(dot(vN,vV)),2.0); float a=uI*f*pow(vUv.y,1.6); gl_FragColor=vec4(uColor*a,a); }',
  });

const Beam: React.FC<{color: string; intensity: number}> = ({color, intensity}) => {
  const mat = useMemo(() => BeamMaterial(color), [color]);
  mat.uniforms.uI.value = intensity;
  return (
    <mesh position={[0, 3.2, 0]} material={mat}>
      <cylinderGeometry args={[0.35, 1.7, 6.4, 64, 1, true]} />
    </mesh>
  );
};

const Dust: React.FC<{frame: number; color: string; n?: number}> = ({frame, color, n = 260}) => {
  const geo = useMemo(() => {
    const g = new THREE.BufferGeometry();
    const p = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) {
      p[i * 3] = (random('dx' + i) - 0.5) * 9;
      p[i * 3 + 1] = random('dy' + i) * 6;
      p[i * 3 + 2] = (random('dz' + i) - 0.5) * 9;
    }
    g.setAttribute('position', new THREE.BufferAttribute(p, 3));
    return g;
  }, [n]);
  return (
    <points geometry={geo} position={[0, ((frame * 0.004) % 1) - 0.5, 0]} rotation={[0, frame * 0.002, 0]}>
      <pointsMaterial size={0.035} color={col(color, 2)} transparent opacity={0.8} toneMapped={false} blending={THREE.AdditiveBlending} depthWrite={false} />
    </points>
  );
};

const Title3D: React.FC<{text: string; frame: number; accent: string; y?: number; size?: number}> = ({text, frame, accent, y = 3.15, size = 0.62}) => {
  const t = interpolate(frame, [4, 30], [0, 1], {...clamp, easing: Easing.out(Easing.back(1.4))});
  return (
    <group position={[0, y, -1.6]} rotation={[0, (1 - t) * -1.2 + Math.sin(frame / 40) * 0.06, 0]} scale={[t, t, t]}>
      <Center>
        <Text3D font={FONT as unknown as string} size={size} height={0.16} curveSegments={10} bevelEnabled bevelThickness={0.025} bevelSize={0.015} bevelSegments={4} letterSpacing={-0.02}>
          {text}
          <meshPhysicalMaterial color="#f4f7fb" metalness={0.85} roughness={0.12} clearcoat={1} />
        </Text3D>
      </Center>
      <mesh position={[0, -0.5, 0]}>
        <planeGeometry args={[text.length * 0.42, 0.03]} />
        <meshBasicMaterial color={col(accent, 5)} toneMapped={false} />
      </mesh>
    </group>
  );
};

/* Photo produit : détourée (debout sur la plateforme) ou carte en verre */
const Product: React.FC<{tex: THREE.Texture; cutout: boolean; frame: number; accent: string}> = ({tex, cutout, frame, accent}) => {
  const img = tex.image as HTMLImageElement;
  const ar = img.width / img.height;
  const h = cutout ? 2.5 : 2.1;
  const w = h * ar;
  const scale = cutout ? Math.min(1, 3.4 / w) : Math.min(1, 2.5 / w);
  const rise = interpolate(frame, [0, 26], [-1.4, 0], {...clamp, easing: Easing.out(Easing.cubic)});
  const op = interpolate(frame, [0, 14], [0, 1], clamp);
  const rotY = Math.sin(frame / 22) * 0.22 + interpolate(frame, [0, 30], [0.9, 0], {...clamp, easing: Easing.out(Easing.cubic)});
  const y = 0.12 + (h * scale) / 2 + 0.08 + Math.sin(frame / 14) * 0.05 + rise;
  return (
    <group position={[0, y, 0]} rotation={[0, rotY, 0]} scale={[scale, scale, scale]}>
      {cutout ? (
        <mesh>
          <planeGeometry args={[w, h]} />
          <meshBasicMaterial map={tex} transparent opacity={op} toneMapped={false} side={THREE.DoubleSide} alphaTest={0.02} />
        </mesh>
      ) : (
        <group>
          <RoundedBox args={[w + 0.12, h + 0.12, 0.06]} radius={0.06} position={[0, 0, -0.04]}>
            <meshPhysicalMaterial color="#0a0d12" metalness={0.9} roughness={0.2} clearcoat={1} />
          </RoundedBox>
          <mesh position={[0, 0, 0.0]}>
            <planeGeometry args={[w, h]} />
            <meshBasicMaterial map={tex} transparent opacity={op} toneMapped={false} />
          </mesh>
          {[[0, h / 2 + 0.06, w + 0.12, 0.02], [0, -h / 2 - 0.06, w + 0.12, 0.02], [w / 2 + 0.06, 0, 0.02, h + 0.12], [-w / 2 - 0.06, 0, 0.02, h + 0.12]].map(([x, yy, ww, hh], i) => (
            <mesh key={i} position={[x, yy, 0.01]}><planeGeometry args={[ww, hh]} /><meshBasicMaterial color={col(accent, 4)} toneMapped={false} /></mesh>
          ))}
        </group>
      )}
    </group>
  );
};

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

export type StudioMode = 'product' | 'intro' | 'outro';

export const Studio3D: React.FC<{
  frame: number; len: number; accent: string; mode: StudioMode; title?: string; photo?: string | null; cutout?: boolean;
}> = ({frame, len, accent, mode, title, photo = null, cutout = true}) => {
  const tex = useTex(photo ? `dji2/photos/${photo}` : null);

  // caméra
  let camPos: [number, number, number];
  let look: [number, number, number] = [0, 1.5, 0];
  if (mode === 'product') {
    const a = interpolate(frame, [0, len], [-0.55, 0.25]);
    const d = interpolate(frame, [0, len - 14, len], [8.6, 7.3, 2.0], {...clamp, easing: Easing.in(Easing.quad)});
    camPos = [Math.sin(a) * d, 1.9 + Math.sin(frame / 30) * 0.08, Math.cos(a) * d];
    look = [0, 1.75, 0];
  } else if (mode === 'intro') {
    const a = interpolate(frame, [0, len], [0.9, -0.3]);
    const d = interpolate(frame, [0, len], [6.5, 9.5], {...clamp, easing: Easing.inOut(Easing.cubic)});
    camPos = [Math.sin(a) * d, interpolate(frame, [0, len], [0.6, 2.4]), Math.cos(a) * d];
    look = [0, 1.8, 0];
  } else {
    const a = frame * 0.004;
    camPos = [Math.sin(a) * 8, 2.2, Math.cos(a) * 8];
    look = [0, 1.6, 0];
  }

  // drone (intro / outro / produit sans photo)
  const showDrone = mode !== 'product' || !photo;
  const dronePos: [number, number, number] =
    mode === 'intro'
      ? [interpolate(frame, [0, 70], [-6, 0], {...clamp, easing: Easing.out(Easing.cubic)}), interpolate(frame, [0, 70], [3.5, 1.9], {...clamp, easing: Easing.out(Easing.cubic)}) + Math.sin(frame / 12) * 0.06, interpolate(frame, [0, 70], [-5, 0], {...clamp, easing: Easing.out(Easing.cubic)})]
      : [0, 1.75 + Math.sin(frame / 12) * 0.07 + (mode === 'product' ? interpolate(frame, [0, 26], [-1.2, 0], {...clamp, easing: Easing.out(Easing.cubic)}) : 0), 0];
  const droneRot: [number, number, number] =
    mode === 'intro' ? [interpolate(frame, [0, 70], [0.35, 0.05], clamp), interpolate(frame, [0, 70], [0.9, 0.3], clamp) + Math.sin(frame / 30) * 0.1, interpolate(frame, [0, 70], [-0.3, 0], clamp)] : mode === 'product' ? [0.32, -0.55 + Math.sin(frame / 40) * 0.35, 0.04] : [0.08, frame * 0.012 + 0.6, Math.sin(frame / 20) * 0.05];

  const appear = interpolate(frame, [0, 22], [0.3, 1], {...clamp, easing: Easing.out(Easing.back(1.6))});
  const flash = mode === 'intro' ? interpolate(frame, [68, 72, 90], [0, 1, 0], clamp) : 0;

  if (photo && !tex) return null; // on attend la photo avant de monter la scène 3D
  return (
    <ThreeCanvas width={1080} height={1920} gl={{antialias: true, toneMapping: THREE.ACESFilmicToneMapping, outputColorSpace: THREE.SRGBColorSpace}} dpr={1}>
      <Rig pos={camPos} look={look} fov={38} />
      <color attach="background" args={['#04060b']} />
      <fog attach="fog" args={['#04060b', 9, 22]} />
      <Environment resolution={256} frames={1}>
        <Lightformer intensity={3} position={[0, 6, -4]} scale={[12, 3, 1]} />
        <Lightformer intensity={2.2} position={[-6, 2, 1]} rotation-y={Math.PI / 2} scale={[10, 3, 1]} color={accent} />
        <Lightformer intensity={1.6} position={[6, 2, 1]} rotation-y={-Math.PI / 2} scale={[10, 3, 1]} color="#ffffff" />
        <Lightformer intensity={2.5} position={[0, 2, 6]} scale={[8, 2, 1]} color="#ffffff" />
        <Lightformer intensity={0.6} position={[3, -1, 5]} scale={[4, 1, 1]} color="#ff9a3c" />
      </Environment>
      <ambientLight intensity={0.15} />
      <spotLight position={[0, 7, 1.5]} angle={0.42} penumbra={0.7} intensity={120} color="#ffffff" />
      <pointLight position={[-3, 2, 3]} intensity={8 + flash * 80} color={accent} />

      <Platform frame={frame} accent={accent} appear={appear} />
      <Beam color={accent} intensity={0.35 + 0.1 * Math.sin(frame / 9)} />
      <Dust frame={frame} color={accent} />

      {mode === 'product' && tex ? <Product tex={tex} cutout={cutout} frame={frame} accent={accent} /> : null}
      {showDrone ? (
        <group position={dronePos} rotation={droneRot} scale={mode === 'product' ? 1.15 : 1.15}>
          <Drone3D frame={frame} />
        </group>
      ) : null}
      {title ? <Title3D text={title} frame={frame} accent={accent} y={mode === 'product' ? 3.75 : 3.35} size={mode === 'product' ? Math.min(0.62, 3.1 / (title.length * 0.72)) : 0.5} /> : null}

      {/* sol miroir */}
      <mesh rotation-x={-Math.PI / 2} position={[0, 0, 0]}>
        <planeGeometry args={[40, 40]} />
        <MeshReflectorMaterial resolution={512} mirror={0.85} blur={[400, 120]} mixBlur={1.2} mixStrength={3} roughness={0.85} depthScale={1.1} minDepthThreshold={0.4} maxDepthThreshold={1.4} color="#0b0e14" metalness={0.6} />
      </mesh>
      {/* quadrillage holographique au sol */}
      <gridHelper args={[40, 80, col(accent, 0.6), col(accent, 0.25)]} position={[0, 0.003, 0]} />

      <EffectComposer multisampling={0}>
        <Bloom intensity={1.4} luminanceThreshold={0.75} luminanceSmoothing={0.2} mipmapBlur />
        <ChromaticAberration offset={new THREE.Vector2(0.0012, 0.0008)} radialModulation={false} modulationOffset={0} blendFunction={BlendFunction.NORMAL} />
        <Noise opacity={0.06} premultiply blendFunction={BlendFunction.SCREEN} />
        <Vignette eskil={false} offset={0.25} darkness={0.85} />
      </EffectComposer>
    </ThreeCanvas>
  );
};
