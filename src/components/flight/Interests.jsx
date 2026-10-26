import { useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { interestPoints } from '../../../shared/universe.js';
import { heightAt } from '../../../shared/surface.js';

const INK = '#e7b07a';
const EDGE = '#241c16';

function faceOut(position) {
  const n = new THREE.Vector3(position[0], position[1], position[2]);
  if (n.lengthSq() < 1e-6) n.set(0, 0, 1);
  n.normalize();
  return new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 0, 1), n);
}

function OrbitPin({ position, radius }) {
  const quat = useMemo(() => faceOut(position), [position]);
  return (
    <group position={position} quaternion={quat}>
      <mesh renderOrder={3}>
        <ringGeometry args={[radius * 0.078, radius * 0.1, 28]} />
        <meshBasicMaterial
          color={EDGE}
          transparent
          opacity={0.72}
          side={THREE.DoubleSide}
          depthWrite={false}
          toneMapped={false}
          fog={false}
        />
      </mesh>
      <mesh position={[0, 0, radius * 0.01]} renderOrder={3}>
        <ringGeometry args={[radius * 0.05, radius * 0.074, 28]} />
        <meshBasicMaterial
          color={INK}
          transparent
          opacity={0.95}
          side={THREE.DoubleSide}
          depthWrite={false}
          toneMapped={false}
          fog={false}
        />
      </mesh>
      <mesh position={[0, 0, radius * 0.02]} renderOrder={3}>
        <circleGeometry args={[radius * 0.016, 12]} />
        <meshBasicMaterial color={INK} toneMapped={false} fog={false} />
      </mesh>
    </group>
  );
}

export function OrbitMarks({ planet }) {
  const points = useMemo(() => interestPoints(planet), [planet]);
  return (
    <group>
      {points.map((point) => (
        <OrbitPin key={point.id} position={point.orbit} radius={planet.radius} />
      ))}
    </group>
  );
}

function SurfacePin({ point, planet }) {
  const y = heightAt(point.surface[0], point.surface[2], planet) + 0.4;
  return (
    <group position={[point.surface[0], y, point.surface[2]]}>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, 0.35, 0]}>
        <ringGeometry args={[2.6, 4.1, 24]} />
        <meshBasicMaterial
          color={INK}
          transparent
          opacity={0.95}
          side={THREE.DoubleSide}
          depthWrite={false}
          toneMapped={false}
          fog={false}
        />
      </mesh>
      <mesh position={[0, 4.2, 0]}>
        <cylinderGeometry args={[0.09, 0.09, 8, 6]} />
        <meshBasicMaterial color={INK} toneMapped={false} fog={false} />
      </mesh>
    </group>
  );
}

export function SurfaceMarks({ planet }) {
  const points = useMemo(() => interestPoints(planet), [planet]);
  return (
    <group>
      {points.map((point) => (
        <SurfacePin key={point.id} point={point} planet={planet} />
      ))}
    </group>
  );
}

export function ScanPulse({ pulseRef }) {
  const group = useRef();
  const mats = useRef([]);

  useFrame(({ clock, camera }) => {
    const root = group.current;
    if (!root) return;
    const pulse = pulseRef.current;
    const age = pulse.hold == null ? clock.elapsedTime - pulse.start : pulse.hold;
    if (age < 0 || age > 1.7 || (pulse.hold == null && pulse.start < 0)) {
      root.visible = false;
      return;
    }
    root.visible = true;
    root.position.copy(pulse.origin);
    root.quaternion.copy(camera.quaternion);
    root.children.forEach((ring, index) => {
      const local = Math.min(1, Math.max(0, (age - index * 0.16) / 1.25));
      const alive = age > index * 0.16;
      ring.visible = alive;
      const scale = 1.4 + local * local * 62;
      ring.scale.setScalar(scale);
      const mat = mats.current[index];
      if (mat) mat.opacity = alive ? Math.sin(Math.PI * (1 - local)) * (index === 0 ? 0.78 : 0.4) : 0;
    });
  });

  return (
    <group ref={group} visible={false}>
      {[0, 1].map((index) => (
        <mesh key={index}>
          <ringGeometry args={[0.86, 1, 48]} />
          <meshBasicMaterial
            ref={(mat) => { mats.current[index] = mat; }}
            color={INK}
            transparent
            opacity={0}
            side={THREE.DoubleSide}
            depthWrite={false}
            blending={THREE.AdditiveBlending}
            toneMapped={false}
            fog={false}
          />
        </mesh>
      ))}
    </group>
  );
}
