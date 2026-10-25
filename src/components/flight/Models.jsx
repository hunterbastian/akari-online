import { useLayoutEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import { useGLTF } from '@react-three/drei';
import * as THREE from 'three';
import modelMeta from './modelMeta.json';
import { dressGround } from './atmosphere.jsx';

const ROCKS = new Set(['rock_a', 'rock_b', 'arch', 'shard', 'spire', 'monolith']);

const DRACO = '/draco/';

const ACCENT = {
  vektron: '#e6b089',
  astra: '#9bb8c4',
  phantom: '#c2a4bc',
  ironclad: '#9aaf96',
  drift: '#d9d3c8',
};

const FILES = [
  'ship', 'hauler', 'freighter', 'station', 'gate', 'pilot',
  'rock_a', 'rock_b', 'crystal', 'tree', 'flora', 'shard', 'spire', 'arch', 'deposit', 'monolith',
];

function prepare(source, accent, shadow = false, paint = false) {
  const clone = source.clone(true);
  const copies = new Map();
  clone.traverse((node) => {
    if (!node.isMesh) return;
    const sourceMats = Array.isArray(node.material) ? node.material : [node.material];
    const next = sourceMats.map((material) => {
      if (!copies.has(material.uuid)) {
        const copy = material.clone();
        if (copy.name === 'Accent' && accent) copy.color.set(accent);
        if (copy.name === 'Engine' || copy.name === 'Glow') {
          copy.emissive = copy.color.clone();
          copy.emissiveIntensity = copy.name === 'Engine' ? 2.6 : 1.6;
          copy.toneMapped = false;
        } else if (paint && copy.isMeshStandardMaterial) {
          const accentPaint = copy.name === 'Accent';
          copy.metalness = Math.max(copy.metalness || 0, accentPaint ? 0.1 : 0.28);
          copy.roughness = Math.min(Math.max(copy.roughness ?? 0.5, 0.24), accentPaint ? 0.55 : 0.42);
          copy.envMapIntensity = accentPaint ? 0.4 : 0.8;
        }
        copies.set(material.uuid, copy);
      }
      return copies.get(material.uuid);
    });
    node.material = Array.isArray(node.material) ? next : next[0];
    node.castShadow = shadow;
    node.receiveShadow = shadow;
  });
  return clone;
}

function useModel(name, accent, shadow = false, paint = false) {
  const gltf = useGLTF(`/models/${name}.glb`, DRACO, false);
  return useMemo(() => prepare(gltf.scene, accent, shadow, paint), [gltf, accent, shadow, paint]);
}

export function shipVariant(manufacturer) {
  return manufacturer === 'vektron' ? 'hauler' : 'ship';
}

export function shipAccent(manufacturer) {
  return ACCENT[manufacturer] || ACCENT.drift;
}

export function ShipView({ manufacturer = 'drift', thrustRef, pulseRef }) {
  const variant = shipVariant(manufacturer);
  const scene = useModel(variant, shipAccent(manufacturer), true, true);
  const flames = useRef([]);
  const engines = variant === 'hauler' ? modelMeta.hauler.engines : modelMeta.ship.engines;

  useFrame(() => {
    const hot = pulseRef?.current ? 1 : Math.max(0, thrustRef?.current || 0);
    flames.current.forEach((mesh) => {
      if (!mesh) return;
      mesh.scale.set(1, 0.28 + hot * 1.35, 1);
      mesh.material.opacity = 0.06 + hot * 0.5;
    });
  });

  return (
    <group>
      <primitive object={scene} />
      {engines.map((position, index) => (
        <mesh
          key={index}
          ref={(node) => { flames.current[index] = node; }}
          position={position}
          rotation={[Math.PI / 2, 0, 0]}
        >
          <coneGeometry args={[variant === 'hauler' ? 0.16 : 0.09, 1.05, 6]} />
          <meshBasicMaterial color="#e07a48" transparent opacity={0.12} depthWrite={false} toneMapped={false} />
        </mesh>
      ))}
    </group>
  );
}

export function StationView({ position }) {
  const scene = useModel('station');
  const ref = useRef();
  useLayoutEffect(() => {
    ref.current?.lookAt(0, position[1], 48);
  }, [position]);
  return (
    <group ref={ref} position={position} scale={2.1}>
      <primitive object={scene} />
    </group>
  );
}

export function GateView({ position }) {
  const scene = useModel('gate');
  const ref = useRef();
  useLayoutEffect(() => {
    ref.current?.lookAt(0, position[1], 0);
  }, [position]);
  return (
    <group ref={ref} position={position} scale={1.7}>
      <primitive object={scene} />
    </group>
  );
}

export function Prop({ kind, position, rotation, scale, air, lite = false }) {
  const scene = useModel(kind, undefined, true);
  useLayoutEffect(() => {
    if (!air || !ROCKS.has(kind)) return undefined;
    scene.traverse((node) => {
      if (!node.isMesh || !node.material?.isMeshStandardMaterial) return;
      const mats = Array.isArray(node.material) ? node.material : [node.material];
      mats.forEach((material) => dressGround(material, air, { lite }));
    });
    return undefined;
  }, [scene, air, kind, lite]);
  return <primitive object={scene} position={position} rotation={rotation} scale={scale} />;
}

export function PilotFigure() {
  const scene = useModel('pilot');
  return <primitive object={scene} />;
}

export function SpaceTraffic() {
  const freighter = useModel('freighter');
  const courier = useModel('hauler', ACCENT.astra);
  const freightRef = useRef();
  const courierRef = useRef();

  useFrame(({ clock }) => {
    const t = clock.elapsedTime;
    if (freightRef.current) {
      const angle = t * 0.018;
      const radius = 230;
      freightRef.current.position.set(Math.cos(angle) * radius, 16, Math.sin(angle) * radius);
      freightRef.current.lookAt(
        Math.cos(angle + 0.12) * radius,
        16,
        Math.sin(angle + 0.12) * radius,
      );
    }
    if (courierRef.current) {
      const angle = t * 0.07 + 1.4;
      const radius = 78;
      courierRef.current.position.set(Math.cos(angle) * radius, 2.5, Math.sin(angle) * radius);
      courierRef.current.lookAt(
        Math.cos(angle + 0.25) * radius,
        2.5,
        Math.sin(angle + 0.25) * radius,
      );
    }
  });

  return (
    <>
      <group ref={freightRef} scale={2.4}>
        <primitive object={freighter} />
      </group>
      <group ref={courierRef} scale={1.05}>
        <primitive object={courier} />
      </group>
    </>
  );
}

for (const name of FILES) useGLTF.preload(`/models/${name}.glb`, DRACO, false);
