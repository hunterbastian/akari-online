import { useRef, useMemo } from 'react';
import { Canvas, useFrame } from '@react-three/fiber';
import { OrbitControls, Text, Line, Billboard } from '@react-three/drei';
import * as THREE from 'three';
import { SYSTEMS, JUMP_LANES, getConnections } from '../../shared/galaxy.js';
import PlayerShip from './ShipModel';

const SCALE = 0.01;

const systemPositions = {};
for (const sys of SYSTEMS) {
  const hash = sys.id.split('').reduce((a, c) => a + c.charCodeAt(0), 0);
  systemPositions[sys.id] = [
    (sys.x - 500) * SCALE,
    ((hash % 60) - 30) * SCALE,
    (sys.y - 400) * SCALE,
  ];
}

const NEBULAE = [
  { pos: [-1.3, 0.1, -0.15], scale: 3.1, color: '#e06a5c', opacity: 0.32 },
  { pos: [1.45, -0.15, 0.3], scale: 3.3, color: '#b45ea8', opacity: 0.28 },
  { pos: [0.1, 0.2, -1.45], scale: 2.8, color: '#2a8f86', opacity: 0.26 },
  { pos: [-0.25, -0.3, 1.2], scale: 2.5, color: '#e6b089', opacity: 0.2 },
];

function Starfield({ count = 280 }) {
  const positions = useMemo(() => {
    const arr = new Float32Array(count * 3);
    for (let i = 0; i < count; i++) {
      arr[i * 3] = (Math.random() - 0.5) * 18;
      arr[i * 3 + 1] = (Math.random() - 0.5) * 10;
      arr[i * 3 + 2] = (Math.random() - 0.5) * 18;
    }
    return arr;
  }, [count]);

  return (
    <points>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
      </bufferGeometry>
      <pointsMaterial size={0.018} color="#f3efe7" transparent opacity={0.7} sizeAttenuation depthWrite={false} />
    </points>
  );
}

function JumpLane({ from, to, isActive }) {
  const points = useMemo(() => [new THREE.Vector3(...from), new THREE.Vector3(...to)], [from, to]);
  return (
    <Line
      points={points}
      color={isActive ? '#e6b089' : '#3c3844'}
      lineWidth={1}
      transparent
      opacity={isActive ? 0.9 : 0.45}
    />
  );
}

function SystemNode({ system, isCurrent, isReachable }) {
  const meshRef = useRef();
  const baseSize = isCurrent ? 0.07 : 0.045;

  useFrame(() => {
    if (meshRef.current && isCurrent) {
      const pulse = 1 + Math.sin(Date.now() * 0.0025) * 0.06;
      meshRef.current.scale.setScalar(pulse);
    }
  });

  const pos = systemPositions[system.id];

  return (
    <group position={pos}>
      {isCurrent && (
        <sprite scale={[0.28, 0.28, 0.28]}>
          <spriteMaterial color={system.color} transparent opacity={0.22} blending={THREE.AdditiveBlending} depthWrite={false} />
        </sprite>
      )}
      <mesh ref={meshRef}>
        <sphereGeometry args={[baseSize, 20, 16]} />
        <meshStandardMaterial
          color={system.color}
          emissive={system.color}
          emissiveIntensity={isCurrent ? 0.55 : isReachable ? 0.22 : 0.05}
          transparent
          opacity={isCurrent ? 1 : isReachable ? 0.92 : 0.38}
          roughness={0.45}
        />
      </mesh>
      <Billboard position={[0, -baseSize - 0.045, 0]}>
        <Text
          fontSize={0.028}
          color={isCurrent ? '#f4efe6' : isReachable ? '#d9d3c8' : '#7d786f'}
          anchorX="center"
          anchorY="top"
          outlineWidth={0.0015}
          outlineColor="#121016"
        >
          {system.name}
        </Text>
      </Billboard>
      {isCurrent && (
        <Billboard position={[0, baseSize + 0.04, 0]}>
          <Text fontSize={0.02} color="#e6b089" anchorX="center" anchorY="bottom" outlineWidth={0.0012} outlineColor="#121016">
            Here
          </Text>
        </Billboard>
      )}
    </group>
  );
}

function GalaxyScene({ player }) {
  const connections = getConnections(player.system_id);

  return (
    <>
      <ambientLight intensity={0.85} />
      <Starfield />
      {NEBULAE.map((cloud) => (
        <mesh key={cloud.color + cloud.pos.join()} position={cloud.pos}>
          <sphereGeometry args={[cloud.scale, 28, 18]} />
          <meshBasicMaterial color={cloud.color} transparent opacity={cloud.opacity} depthWrite={false} />
        </mesh>
      ))}
      {JUMP_LANES.map(([aId, bId]) => {
        const isActive = (aId === player.system_id && connections.includes(bId))
          || (bId === player.system_id && connections.includes(aId));
        return (
          <JumpLane
            key={`${aId}-${bId}`}
            from={systemPositions[aId]}
            to={systemPositions[bId]}
            isActive={isActive}
          />
        );
      })}
      {SYSTEMS.map(sys => (
        <SystemNode
          key={sys.id}
          system={sys}
          isCurrent={sys.id === player.system_id}
          isReachable={connections.includes(sys.id)}
        />
      ))}
      <PlayerShip shipId={player.ship} systemPosition={systemPositions[player.system_id]} />
      <fog attach="fog" args={['#16121c', 12, 28]} />
    </>
  );
}

export default function GalaxyView({ player }) {
  const cameraPos = useMemo(() => {
    const pos = systemPositions[player.system_id];
    return [pos[0] + 0.4, pos[1] + 0.7, pos[2] + 1.15];
  }, [player.system_id]);

  const target = systemPositions[player.system_id];

  return (
    <Canvas
      camera={{ position: cameraPos, fov: 48, near: 0.01, far: 50 }}
      style={{ width: '100%', height: '100%' }}
      gl={{ antialias: true, alpha: false }}
      onCreated={({ gl }) => {
        gl.setClearColor('#121016');
        gl.toneMapping = THREE.ACESFilmicToneMapping;
        gl.toneMappingExposure = 1.05;
      }}
    >
      <GalaxyScene player={player} />
      <OrbitControls
        target={target}
        enableDamping
        dampingFactor={0.08}
        minDistance={0.35}
        maxDistance={4.5}
        autoRotate
        autoRotateSpeed={0.22}
      />
    </Canvas>
  );
}
