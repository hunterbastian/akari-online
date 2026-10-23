import { useEffect, useMemo } from 'react';
import * as THREE from 'three';
import { heightAt, surfaceLayout, surfaceSky, waterLevel } from '../../../shared/surface.js';
import { Sky } from './scenery';
import { Prop } from './Models';

const SIZE = 480;
const SEGMENTS = 64;

function buildTerrain(planet) {
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEGMENTS, SEGMENTS);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const low = new THREE.Color(planet.colors[0]);
  const mid = new THREE.Color(planet.colors[1]);
  const high = new THREE.Color(planet.colors[2]);
  const mix = new THREE.Color();
  let min = Infinity;
  let max = -Infinity;
  const samples = new Float32Array(pos.count);
  for (let i = 0; i < pos.count; i += 1) {
    const h = heightAt(pos.getX(i), pos.getZ(i), planet);
    samples[i] = h;
    if (h < min) min = h;
    if (h > max) max = h;
  }
  const span = Math.max(0.001, max - min);
  for (let i = 0; i < pos.count; i += 1) {
    const h = samples[i];
    pos.setY(i, h);
    const t = (h - min) / span;
    mix.copy(low).lerp(mid, Math.min(1, t * 1.4));
    if (t > 0.55) mix.lerp(high, (t - 0.55) / 0.45);
    colors[i * 3] = mix.r;
    colors[i * 3 + 1] = mix.g;
    colors[i * 3 + 2] = mix.b;
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

export function SurfaceWorld({ planet, depleted }) {
  const sky = surfaceSky(planet);
  const water = waterLevel(planet);
  const layout = useMemo(() => surfaceLayout(planet), [planet]);
  const terrain = useMemo(() => buildTerrain(planet), [planet]);
  useEffect(() => () => terrain.dispose(), [terrain]);

  const deposits = layout.deposits.filter((deposit) => !depleted.includes(deposit.id));

  return (
    <group>
      <Sky sky={sky} />
      <hemisphereLight args={[sky.bottom, '#3a342c', 0.55]} />
      <ambientLight intensity={0.28} color="#f4efe6" />
      <directionalLight position={[70, 110, 36]} intensity={1.35} color="#fff3e4" />
      <mesh position={[240, 150, 90]}>
        <sphereGeometry args={[16, 20, 12]} />
        <meshBasicMaterial color="#fff6ea" toneMapped={false} fog={false} />
      </mesh>
      <mesh geometry={terrain}>
        <meshStandardMaterial vertexColors flatShading roughness={0.94} metalness={0} />
      </mesh>
      {water != null && (
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, water, 0]}>
          <planeGeometry args={[SIZE + 80, SIZE + 80]} />
          <meshStandardMaterial
            color={sky.water}
            transparent
            opacity={sky.waterOpacity}
            roughness={0.18}
            metalness={0.04}
          />
        </mesh>
      )}
      {layout.props.map((prop, index) => (
        <Prop key={`${prop.kind}-${index}`} kind={prop.kind} position={prop.position} rotation={prop.rotation} scale={prop.scale} />
      ))}
      <Prop kind="monolith" position={layout.monolith.position} rotation={layout.monolith.rotation} scale={layout.monolith.scale} />
      {deposits.map((deposit) => (
        <Prop key={deposit.id} kind="deposit" position={deposit.position} rotation={[0, 0.4, 0]} scale={1.2} />
      ))}
      <fog attach="fog" args={[sky.fog, 52, 280]} />
    </group>
  );
}
