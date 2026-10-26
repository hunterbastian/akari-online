import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { mulberry32 } from '../../../shared/universe.js';

function gradeStop(hex, toward, mix, sat) {
  const color = new THREE.Color(hex);
  color.lerp(new THREE.Color(toward), mix);
  const hsl = { h: 0, s: 0, l: 0 };
  color.getHSL(hsl);
  hsl.s = Math.min(0.38, hsl.s * sat);
  hsl.l = THREE.MathUtils.clamp(hsl.l, 0.14, 0.56);
  color.setHSL(hsl.h, hsl.s, hsl.l);
  return `#${color.getHexString()}`;
}

function makeSkyTexture(sky) {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 512;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, gradeStop(sky.top, '#163e46', 0.84, 0.5));
  gradient.addColorStop(0.34, gradeStop(sky.mid, '#6e8e86', 0.62, 0.45));
  gradient.addColorStop(0.68, gradeStop(sky.bottom, '#e4c196', 0.4, 0.5));
  gradient.addColorStop(1, gradeStop(sky.top, '#1d4c52', 0.7, 0.5));
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.globalCompositeOperation = 'screen';
  const sun = ctx.createRadialGradient(760, 150, 12, 720, 190, 460);
  sun.addColorStop(0, 'rgba(255, 214, 156, 0.32)');
  sun.addColorStop(0.4, 'rgba(214, 160, 108, 0.1)');
  sun.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = sun;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const dust = ctx.createRadialGradient(200, 340, 16, 240, 310, 380);
  dust.addColorStop(0, 'rgba(110, 168, 164, 0.38)');
  dust.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = dust;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const veil = ctx.createRadialGradient(500, 250, 30, 520, 240, 520);
  veil.addColorStop(0, 'rgba(232, 198, 154, 0.14)');
  veil.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = veil;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

export function Sky({ sky }) {
  const mesh = useRef();
  const texture = useMemo(() => makeSkyTexture(sky), [sky]);
  useEffect(() => () => texture.dispose(), [texture]);

  useFrame(({ camera }) => {
    if (mesh.current) mesh.current.position.copy(camera.position);
  });

  return (
    <mesh ref={mesh} rotation={[0, 0.6, 0]} frustumCulled={false}>
      <sphereGeometry args={[700, 48, 32]} />
      <meshBasicMaterial map={texture} side={THREE.BackSide} depthWrite={false} fog={false} />
    </mesh>
  );
}

export function Starfield({ seed }) {
  const positions = useMemo(() => {
    const rng = mulberry32(seed ^ 0x9e3779b9);
    const count = 150;
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      const r = 1600 + rng() * 700;
      const theta = rng() * Math.PI * 2;
      const phi = Math.acos(2 * rng() - 1);
      arr[i * 3] = r * Math.sin(phi) * Math.cos(theta);
      arr[i * 3 + 1] = r * Math.cos(phi);
      arr[i * 3 + 2] = r * Math.sin(phi) * Math.sin(theta);
    }
    return arr;
  }, [seed]);

  return (
    <points frustumCulled={false}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial color="#efe6d4" size={1.05} sizeAttenuation={false} transparent opacity={0.42} depthWrite={false} fog={false} toneMapped={false} />
    </points>
  );
}

export function Sun({ color }) {
  return (
    <group>
      <mesh>
        <sphereGeometry args={[3.2, 24, 16]} />
        <meshBasicMaterial color="#fff3e2" toneMapped={false} />
      </mesh>
      <mesh>
        <sphereGeometry args={[15, 24, 16]} />
        <meshBasicMaterial color={color} transparent opacity={0.18} depthWrite={false} blending={THREE.AdditiveBlending} toneMapped={false} />
      </mesh>
      <mesh>
        <sphereGeometry args={[32, 20, 12]} />
        <meshBasicMaterial color="#e8b888" transparent opacity={0.08} depthWrite={false} blending={THREE.AdditiveBlending} toneMapped={false} />
      </mesh>
    </group>
  );
}

export function Station({ position, accent }) {
  const ring = useRef();
  useFrame((_, dt) => {
    if (ring.current) ring.current.rotation.z += dt * 0.12;
  });

  return (
    <group position={position}>
      <mesh rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[2.1, 2.1, 7.2, 6]} />
        <meshStandardMaterial color="#c4beb4" flatShading roughness={0.72} />
      </mesh>
      <mesh ref={ring} rotation={[Math.PI / 2, 0, 0]}>
        <torusGeometry args={[5.2, 0.07, 6, 8]} />
        <meshStandardMaterial color={accent} emissive={accent} emissiveIntensity={0.35} flatShading />
      </mesh>
    </group>
  );
}

export function Belt({ rocks }) {
  const ref = useRef();
  const dummy = useMemo(() => new THREE.Object3D(), []);

  useEffect(() => {
    if (!ref.current) return;
    rocks.forEach((rock, i) => {
      dummy.position.set(rock.position[0], rock.position[1], rock.position[2]);
      dummy.rotation.set(rock.rotation[0], rock.rotation[1], rock.rotation[2]);
      dummy.scale.setScalar(rock.scale);
      dummy.updateMatrix();
      ref.current.setMatrixAt(i, dummy.matrix);
    });
    ref.current.instanceMatrix.needsUpdate = true;
  }, [rocks, dummy]);

  if (!rocks.length) return null;

  return (
    <instancedMesh ref={ref} args={[null, null, rocks.length]}>
      <dodecahedronGeometry args={[1, 0]} />
      <meshStandardMaterial color="#a3988c" flatShading roughness={0.9} />
    </instancedMesh>
  );
}

export function Deposit({ position }) {
  const ref = useRef();
  useFrame((_, dt) => {
    if (ref.current) ref.current.rotation.y += dt * 0.35;
  });
  return (
    <mesh ref={ref} position={position}>
      <icosahedronGeometry args={[0.55, 0]} />
      <meshStandardMaterial color="#e6b089" emissive="#e6b089" emissiveIntensity={0.4} flatShading />
    </mesh>
  );
}

const _markerPos = new THREE.Vector3();

export function TargetMarker({ targetRef }) {
  const group = useRef();
  const spin = useRef();

  useFrame(({ camera }, dt) => {
    const target = targetRef.current;
    if (!group.current) return;
    if (!target) {
      group.current.visible = false;
      return;
    }
    group.current.visible = true;
    _markerPos.set(target.position[0], target.position[1], target.position[2]);
    const dist = camera.position.distanceTo(_markerPos);
    const s = THREE.MathUtils.clamp(dist * 0.006, 0.5, 6.5);
    group.current.scale.setScalar(s);
    group.current.position.set(
      target.position[0],
      target.position[1] + target.radius + s * 2.4,
      target.position[2],
    );
    if (spin.current) spin.current.rotation.y += dt * 0.5;
  });

  return (
    <group ref={group}>
      <mesh ref={spin}>
        <octahedronGeometry args={[1, 0]} />
        <meshBasicMaterial color="#f4efe6" />
      </mesh>
    </group>
  );
}
