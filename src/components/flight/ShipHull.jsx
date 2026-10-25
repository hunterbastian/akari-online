// Geometric hulls. Local -Z is the nose so it matches the flight model.

function VektronHull() {
  return (
    <group rotation={[0, Math.PI / 2, 0]}>
      <mesh>
        <boxGeometry args={[0.6, 0.2, 0.35]} />
        <meshStandardMaterial color="#d07030" roughness={0.72} metalness={0.08} />
      </mesh>
      <mesh position={[0, -0.1, 0.22]}>
        <boxGeometry args={[0.35, 0.1, 0.12]} />
        <meshStandardMaterial color="#a05020" roughness={0.8} />
      </mesh>
      <mesh position={[0, -0.1, -0.22]}>
        <boxGeometry args={[0.35, 0.1, 0.12]} />
        <meshStandardMaterial color="#a05020" roughness={0.8} />
      </mesh>
      <mesh position={[0.18, 0.13, 0]}>
        <boxGeometry args={[0.12, 0.08, 0.12]} />
        <meshStandardMaterial color="#f0a050" emissive="#f0a050" emissiveIntensity={0.18} />
      </mesh>
      <mesh position={[-0.35, 0, 0.08]}>
        <sphereGeometry args={[0.04, 8, 8]} />
        <meshBasicMaterial color="#ff6030" />
      </mesh>
      <mesh position={[-0.35, 0, -0.08]}>
        <sphereGeometry args={[0.04, 8, 8]} />
        <meshBasicMaterial color="#ff6030" />
      </mesh>
    </group>
  );
}

function AstraHull() {
  return (
    <group rotation={[0, Math.PI / 2, 0]}>
      <mesh rotation={[0, 0, Math.PI / 4]}>
        <cylinderGeometry args={[0.01, 0.18, 0.65, 4]} />
        <meshStandardMaterial color="#3090d0" roughness={0.45} metalness={0.15} />
      </mesh>
      <mesh position={[0, 0, 0.18]} rotation={[0, 0, 0.1]}>
        <boxGeometry args={[0.35, 0.02, 0.22]} />
        <meshStandardMaterial color="#2080c0" roughness={0.5} />
      </mesh>
      <mesh position={[0, 0, -0.18]} rotation={[0, 0, -0.1]}>
        <boxGeometry args={[0.35, 0.02, 0.22]} />
        <meshStandardMaterial color="#2080c0" roughness={0.5} />
      </mesh>
      <mesh position={[0.28, 0.04, 0]}>
        <sphereGeometry args={[0.05, 8, 8]} />
        <meshStandardMaterial color="#60c0ff" emissive="#60c0ff" emissiveIntensity={0.22} />
      </mesh>
      <mesh position={[-0.35, 0, 0]}>
        <sphereGeometry args={[0.04, 8, 8]} />
        <meshBasicMaterial color="#40a0ff" />
      </mesh>
    </group>
  );
}

function PhantomHull() {
  return (
    <group rotation={[0, Math.PI, 0]}>
      <mesh rotation={[Math.PI / 2, 0, 0]}>
        <coneGeometry args={[0.16, 0.65, 3]} />
        <meshStandardMaterial color="#8030b0" roughness={0.4} metalness={0.16} />
      </mesh>
      <mesh position={[-0.08, 0.1, 0]}>
        <boxGeometry args={[0.2, 0.12, 0.015]} />
        <meshStandardMaterial color="#6020a0" roughness={0.45} />
      </mesh>
      <mesh position={[0.18, 0.02, 0]}>
        <boxGeometry args={[0.12, 0.02, 0.08]} />
        <meshStandardMaterial color="#d060ff" emissive="#d060ff" emissiveIntensity={0.28} />
      </mesh>
      <mesh position={[-0.3, 0, 0.06]}>
        <sphereGeometry args={[0.03, 6, 6]} />
        <meshBasicMaterial color="#c040ff" />
      </mesh>
      <mesh position={[-0.3, 0, -0.06]}>
        <sphereGeometry args={[0.03, 6, 6]} />
        <meshBasicMaterial color="#c040ff" />
      </mesh>
    </group>
  );
}

function IroncladHull() {
  return (
    <group rotation={[0, Math.PI / 2, 0]}>
      <mesh>
        <boxGeometry args={[0.6, 0.25, 0.4]} />
        <meshStandardMaterial color="#408040" roughness={0.78} metalness={0.1} />
      </mesh>
      <mesh position={[0, 0.16, 0]}>
        <boxGeometry args={[0.45, 0.04, 0.3]} />
        <meshStandardMaterial color="#306030" roughness={0.8} />
      </mesh>
      <mesh position={[0.08, 0.2, 0]}>
        <cylinderGeometry args={[0.04, 0.06, 0.08, 6]} />
        <meshStandardMaterial color="#508050" roughness={0.7} />
      </mesh>
      <mesh position={[0.25, 0.2, 0]} rotation={[0, 0, Math.PI / 2]}>
        <cylinderGeometry args={[0.015, 0.015, 0.25, 4]} />
        <meshStandardMaterial color="#303030" metalness={0.4} roughness={0.4} />
      </mesh>
      <mesh position={[-0.35, 0, 0]}>
        <sphereGeometry args={[0.06, 8, 8]} />
        <meshBasicMaterial color="#40ff60" />
      </mesh>
    </group>
  );
}

function DriftHull() {
  return (
    <group>
      <mesh>
        <torusGeometry args={[0.22, 0.07, 8, 6]} />
        <meshStandardMaterial color="#6f6f78" roughness={0.4} metalness={0.2} flatShading />
      </mesh>
      <mesh>
        <sphereGeometry args={[0.1, 10, 8]} />
        <meshStandardMaterial color="#e8e8e8" emissive="#9aa0d0" emissiveIntensity={0.22} />
      </mesh>
    </group>
  );
}

const HULLS = {
  vektron: VektronHull,
  astra: AstraHull,
  phantom: PhantomHull,
  ironclad: IroncladHull,
  drift: DriftHull,
};

export default function ShipHull({ manufacturer }) {
  const Hull = HULLS[manufacturer] || DriftHull;
  return <Hull />;
}
