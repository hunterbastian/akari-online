import { useRef, useMemo } from 'react';
import { useFrame } from '@react-three/fiber';
import { Billboard, Text } from '@react-three/drei';
import { SHIPS, MANUFACTURERS } from '../../shared/ships.js';

// Procedural ship meshes per manufacturer
// Each returns a <group> with Borderlands-style black outlines

function VektronHull({ scale = 1 }) {
  // Industrial: chunky box hauler with cargo pods
  return (
    <group scale={scale}>
      {/* Black outline hull */}
      <mesh>
        <boxGeometry args={[0.07, 0.025, 0.04]} />
        <meshBasicMaterial color="#000000" />
      </mesh>
      {/* Main hull */}
      <mesh>
        <boxGeometry args={[0.06, 0.02, 0.035]} />
        <meshStandardMaterial color="#d07030" roughness={0.6} metalness={0.3} />
      </mesh>
      {/* Cargo pod left */}
      <mesh position={[0, -0.012, 0.025]}>
        <boxGeometry args={[0.04, 0.012, 0.015]} />
        <meshStandardMaterial color="#a05020" roughness={0.7} />
      </mesh>
      {/* Cargo pod right */}
      <mesh position={[0, -0.012, -0.025]}>
        <boxGeometry args={[0.04, 0.012, 0.015]} />
        <meshStandardMaterial color="#a05020" roughness={0.7} />
      </mesh>
      {/* Bridge */}
      <mesh position={[0.02, 0.015, 0]}>
        <boxGeometry args={[0.015, 0.01, 0.015]} />
        <meshStandardMaterial color="#f0a050" emissive="#f0a050" emissiveIntensity={0.3} />
      </mesh>
      {/* Engine glow */}
      <mesh position={[-0.035, 0, 0]}>
        <sphereGeometry args={[0.006, 8, 8]} />
        <meshBasicMaterial color="#ff6030" />
      </mesh>
    </group>
  );
}

function AstraHull({ scale = 1 }) {
  // Explorer: sleek elongated diamond shape
  return (
    <group scale={scale}>
      {/* Black outline */}
      <mesh rotation={[0, 0, Math.PI / 4]}>
        <cylinderGeometry args={[0.002, 0.025, 0.08, 4]} />
        <meshBasicMaterial color="#000000" />
      </mesh>
      {/* Main hull - elongated diamond */}
      <mesh rotation={[0, 0, Math.PI / 4]}>
        <cylinderGeometry args={[0.001, 0.02, 0.07, 4]} />
        <meshStandardMaterial color="#3090d0" roughness={0.3} metalness={0.5} />
      </mesh>
      {/* Wing left */}
      <mesh position={[0, 0, 0.02]} rotation={[0, 0, 0.1]}>
        <boxGeometry args={[0.04, 0.003, 0.025]} />
        <meshStandardMaterial color="#2080c0" roughness={0.4} metalness={0.4} />
      </mesh>
      {/* Wing right */}
      <mesh position={[0, 0, -0.02]} rotation={[0, 0, -0.1]}>
        <boxGeometry args={[0.04, 0.003, 0.025]} />
        <meshStandardMaterial color="#2080c0" roughness={0.4} metalness={0.4} />
      </mesh>
      {/* Cockpit */}
      <mesh position={[0.03, 0.005, 0]}>
        <sphereGeometry args={[0.006, 8, 8]} />
        <meshStandardMaterial color="#60c0ff" emissive="#60c0ff" emissiveIntensity={0.4} transparent opacity={0.8} />
      </mesh>
      {/* Engine */}
      <mesh position={[-0.04, 0, 0]}>
        <sphereGeometry args={[0.005, 8, 8]} />
        <meshBasicMaterial color="#40a0ff" />
      </mesh>
    </group>
  );
}

function PhantomHull({ scale = 1 }) {
  // Speed/stealth: angular wedge, sharp edges
  return (
    <group scale={scale}>
      {/* Black outline */}
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <coneGeometry args={[0.022, 0.08, 3]} />
        <meshBasicMaterial color="#000000" />
      </mesh>
      {/* Main hull - triangular wedge */}
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <coneGeometry args={[0.018, 0.07, 3]} />
        <meshStandardMaterial color="#8030b0" roughness={0.2} metalness={0.6} />
      </mesh>
      {/* Fin top */}
      <mesh position={[-0.01, 0.012, 0]}>
        <boxGeometry args={[0.025, 0.015, 0.002]} />
        <meshStandardMaterial color="#6020a0" roughness={0.3} metalness={0.5} />
      </mesh>
      {/* Cockpit slit */}
      <mesh position={[0.02, 0.003, 0]}>
        <boxGeometry args={[0.015, 0.003, 0.01]} />
        <meshStandardMaterial color="#d060ff" emissive="#d060ff" emissiveIntensity={0.5} />
      </mesh>
      {/* Twin engines */}
      <mesh position={[-0.035, 0, 0.008]}>
        <sphereGeometry args={[0.004, 6, 6]} />
        <meshBasicMaterial color="#c040ff" />
      </mesh>
      <mesh position={[-0.035, 0, -0.008]}>
        <sphereGeometry args={[0.004, 6, 6]} />
        <meshBasicMaterial color="#c040ff" />
      </mesh>
    </group>
  );
}

function IroncladHull({ scale = 1 }) {
  // Military: heavy, angular, armored
  return (
    <group scale={scale}>
      {/* Black outline hull */}
      <mesh>
        <boxGeometry args={[0.075, 0.035, 0.05]} />
        <meshBasicMaterial color="#000000" />
      </mesh>
      {/* Main armored hull */}
      <mesh>
        <boxGeometry args={[0.065, 0.028, 0.042]} />
        <meshStandardMaterial color="#408040" roughness={0.7} metalness={0.4} />
      </mesh>
      {/* Armor plates top */}
      <mesh position={[0, 0.018, 0]}>
        <boxGeometry args={[0.05, 0.005, 0.035]} />
        <meshStandardMaterial color="#306030" roughness={0.8} metalness={0.3} />
      </mesh>
      {/* Turret */}
      <mesh position={[0.01, 0.022, 0]}>
        <cylinderGeometry args={[0.005, 0.007, 0.01, 6]} />
        <meshStandardMaterial color="#508050" roughness={0.6} />
      </mesh>
      {/* Gun barrel */}
      <mesh position={[0.03, 0.022, 0]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.002, 0.002, 0.03, 4]} />
        <meshStandardMaterial color="#303030" metalness={0.8} roughness={0.2} />
      </mesh>
      {/* Engine */}
      <mesh position={[-0.038, 0, 0]}>
        <sphereGeometry args={[0.008, 8, 8]} />
        <meshBasicMaterial color="#40ff60" />
      </mesh>
    </group>
  );
}

function DriftHull({ scale = 1 }) {
  // Exotic: organic/alien, smooth curves, mysterious
  return (
    <group scale={scale}>
      {/* Black outline */}
      <mesh>
        <torusGeometry args={[0.025, 0.012, 8, 12]} />
        <meshBasicMaterial color="#000000" />
      </mesh>
      {/* Ring hull */}
      <mesh>
        <torusGeometry args={[0.025, 0.008, 8, 12]} />
        <meshStandardMaterial color="#b0b0b0" roughness={0.2} metalness={0.7} />
      </mesh>
      {/* Central core */}
      <mesh>
        <sphereGeometry args={[0.012, 12, 12]} />
        <meshStandardMaterial
          color="#e0e0e0"
          emissive="#8080ff"
          emissiveIntensity={0.4}
          roughness={0.1}
          metalness={0.8}
        />
      </mesh>
      {/* Inner glow */}
      <mesh>
        <sphereGeometry args={[0.008, 8, 8]} />
        <meshBasicMaterial color="#a0a0ff" transparent opacity={0.6} />
      </mesh>
      {/* Spokes */}
      {[0, Math.PI / 2, Math.PI, Math.PI * 1.5].map((angle, i) => (
        <mesh key={i} position={[Math.cos(angle) * 0.015, Math.sin(angle) * 0.015, 0]} rotation={[0, 0, angle]}>
          <boxGeometry args={[0.015, 0.003, 0.003]} />
          <meshStandardMaterial color="#c0c0c0" metalness={0.6} />
        </mesh>
      ))}
    </group>
  );
}

// Map manufacturer to hull component
const HULL_COMPONENTS = {
  vektron: VektronHull,
  astra: AstraHull,
  phantom: PhantomHull,
  ironclad: IroncladHull,
  drift: DriftHull,
};

// Main ship component that orbits the current system
export default function PlayerShip({ shipId, systemPosition }) {
  const groupRef = useRef();
  const shipRef = useRef();
  const trailRef = useRef();
  const ship = SHIPS[shipId];
  if (!ship) return null;

  const HullComponent = HULL_COMPONENTS[ship.manufacturer] || DriftHull;
  const orbitRadius = 0.12;
  const orbitSpeed = 0.4;

  // Engine trail particles
  const trailPositions = useMemo(() => {
    const arr = new Float32Array(30 * 3);
    return arr;
  }, []);

  useFrame((state) => {
    if (!groupRef.current) return;
    const t = state.clock.elapsedTime;

    // Orbit around system node
    const x = Math.cos(t * orbitSpeed) * orbitRadius;
    const z = Math.sin(t * orbitSpeed) * orbitRadius;
    const y = Math.sin(t * orbitSpeed * 0.7) * 0.03;

    groupRef.current.position.set(
      systemPosition[0] + x,
      systemPosition[1] + y,
      systemPosition[2] + z,
    );

    // Face direction of travel
    if (shipRef.current) {
      const nextX = Math.cos((t + 0.05) * orbitSpeed) * orbitRadius;
      const nextZ = Math.sin((t + 0.05) * orbitSpeed) * orbitRadius;
      shipRef.current.lookAt(
        systemPosition[0] + nextX,
        systemPosition[1] + y,
        systemPosition[2] + nextZ,
      );
    }
  });

  return (
    <group ref={groupRef}>
      <group ref={shipRef}>
        <HullComponent scale={1.2} />
      </group>

      {/* Ship name label */}
      <Billboard position={[0, 0.04, 0]}>
        <Text
          fontSize={0.015}
          color={MANUFACTURERS[ship.manufacturer]?.color || '#ffffff'}
          anchorX="center"
          anchorY="bottom"
          outlineWidth={0.001}
          outlineColor="#000000"
        >
          {ship.name}
        </Text>
      </Billboard>
    </group>
  );
}
