import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { mulberry32 } from '../../../shared/universe.js';

function makeSkyTexture(sky) {
  const canvas = document.createElement('canvas');
  canvas.width = 512;
  canvas.height = 256;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 0, canvas.height);
  gradient.addColorStop(0, sky.top);
  gradient.addColorStop(0.46, sky.mid);
  gradient.addColorStop(1, sky.bottom);
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  ctx.globalCompositeOperation = 'screen';
  const blob = ctx.createRadialGradient(360, 90, 8, 360, 100, 180);
  blob.addColorStop(0, sky.mid);
  blob.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.globalAlpha = 0.55;
  ctx.fillStyle = blob;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  const blob2 = ctx.createRadialGradient(120, 170, 6, 130, 175, 150);
  blob2.addColorStop(0, sky.bottom);
  blob2.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.globalAlpha = 0.4;
  ctx.fillStyle = blob2;
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
    const count = 420;
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
      <pointsMaterial color="#f6f1e8" size={1.35} sizeAttenuation={false} transparent opacity={0.8} depthWrite={false} fog={false} />
    </points>
  );
}

export function Sun({ color }) {
  return (
    <group>
      <mesh>
        <sphereGeometry args={[4.6, 32, 20]} />
        <meshBasicMaterial color="#fff8f0" toneMapped={false} />
      </mesh>
      <mesh>
        <sphereGeometry args={[8.4, 28, 16]} />
        <meshBasicMaterial color={color} transparent opacity={0.28} depthWrite={false} toneMapped={false} />
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
