import React, {useMemo} from 'react';
import * as THREE from 'three';
import {RoundedBox} from '@react-three/drei';

// Drone 3D procédural (style Mavic) : corps, bras, moteurs, hélices floues, nacelle triple caméra, LED.
const bodyMat = () => new THREE.MeshPhysicalMaterial({color: '#5d636c', metalness: 0.45, roughness: 0.35, clearcoat: 1, clearcoatRoughness: 0.15});
const darkMat = () => new THREE.MeshPhysicalMaterial({color: '#16181c', metalness: 0.5, roughness: 0.3, clearcoat: 1});
const glassMat = () => new THREE.MeshPhysicalMaterial({color: '#05070a', metalness: 0.9, roughness: 0.05, clearcoat: 1, clearcoatRoughness: 0});

const propDiscTexture = () => {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d')!;
  const grd = g.createRadialGradient(128, 128, 10, 128, 128, 128);
  grd.addColorStop(0, 'rgba(40,40,40,0.0)');
  grd.addColorStop(0.15, 'rgba(60,60,60,0.55)');
  grd.addColorStop(0.85, 'rgba(70,70,70,0.25)');
  grd.addColorStop(0.95, 'rgba(255,150,40,0.35)');
  grd.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = grd;
  g.beginPath();
  g.arc(128, 128, 128, 0, Math.PI * 2);
  g.fill();
  return new THREE.CanvasTexture(c);
};

export const Drone3D: React.FC<{frame: number; ledColor?: string}> = ({frame, ledColor = '#ff2a2a'}) => {
  const mats = useMemo(() => ({body: bodyMat(), dark: darkMat(), glass: glassMat(), disc: new THREE.MeshBasicMaterial({map: propDiscTexture(), transparent: true, depthWrite: false, side: THREE.DoubleSide})}), []);
  const arms: [number, number, number, string][] = [
    [0.95, 0.75, 0.05, ledColor], [-0.95, 0.75, 0.05, ledColor], [0.95, -0.85, -0.05, '#22ff66'], [-0.95, -0.85, -0.05, '#22ff66'],
  ];
  return (
    <group>
      {/* corps */}
      <RoundedBox args={[0.78, 0.36, 1.5]} radius={0.16} smoothness={6} material={mats.body} />
      <RoundedBox args={[0.6, 0.12, 1.0]} radius={0.05} position={[0, 0.2, -0.1]} material={mats.dark} />
      {/* capteurs avant */}
      {[-0.18, 0.18].map((x) => (
        <mesh key={x} position={[x, 0.05, 0.76]} material={mats.glass}><sphereGeometry args={[0.055, 24, 24]} /></mesh>
      ))}
      {/* bras + moteurs + hélices */}
      {arms.map(([x, z, y, led], i) => (
        <group key={i}>
          <mesh position={[x / 2, y, z / 2]} rotation={[0, Math.atan2(x, z), 0]} material={mats.body}>
            <boxGeometry args={[0.09, 0.07, Math.hypot(x, z)]} />
          </mesh>
          <mesh position={[x, y + 0.06, z]} material={mats.dark}><cylinderGeometry args={[0.085, 0.095, 0.16, 32]} /></mesh>
          <mesh position={[x, y - 0.04, z]}><sphereGeometry args={[0.03, 16, 16]} /><meshBasicMaterial color={new THREE.Color(led).multiplyScalar(4)} toneMapped={false} /></mesh>
          <group position={[x, y + 0.16, z]} rotation={[0, frame * (i % 2 ? 1.9 : -1.9), 0]}>
            <mesh rotation={[-Math.PI / 2, 0, 0]} material={mats.disc}><circleGeometry args={[0.62, 64]} /></mesh>
            <mesh material={mats.dark}><boxGeometry args={[1.2, 0.012, 0.07]} /></mesh>
          </group>
        </group>
      ))}
      {/* nacelle triple caméra */}
      <group position={[0, -0.12, 0.82]}>
        <RoundedBox args={[0.46, 0.4, 0.34]} radius={0.12} smoothness={6} material={mats.dark} />
        {[[0, 0.03, 0.12], [-0.12, -0.08, 0.06], [0.12, -0.08, 0.06]].map(([x, y, r], i) => (
          <group key={i} position={[x, y, 0.17]} rotation={[Math.PI / 2, 0, 0]}>
            <mesh material={mats.body}><cylinderGeometry args={[r + 0.02, r + 0.02, 0.06, 40]} /></mesh>
            <mesh position={[0, 0.032, 0]} material={mats.glass}><cylinderGeometry args={[r, r, 0.01, 40]} /></mesh>
          </group>
        ))}
      </group>
    </group>
  );
};
