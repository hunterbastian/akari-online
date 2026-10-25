import { useEffect, useMemo } from 'react';
import * as THREE from 'three';
import { heightAt, surfaceLayout, waterLevel } from '../../../shared/surface.js';
import { Prop } from './Models';
import {
  AltitudeFog,
  AtmosphereDome,
  FollowSun,
  SUN_DIR,
  atmosphereOf,
  tintedFog,
} from './atmosphere.jsx';

const SIZE = 520;
const SEGMENTS = 72;

const BANDS = {
  ice: [0, 11, 20],
  desert: [1, 8, 16],
  lush: [-2, 5, 12],
  ocean: [-1, 3, 8],
  volcanic: [-6, 4, 14],
  anomalous: [-4, 2, 10],
};

const waterVertex = `
  varying vec3 vWorld;
  void main() {
    vec3 p = position;
    p.z += sin(p.x * 0.04) * cos(p.y * 0.03) * 0.35;
    vec4 world = modelMatrix * vec4(p, 1.0);
    vWorld = world.xyz;
    gl_Position = projectionMatrix * viewMatrix * world;
  }
`;

const waterFragment = `
  uniform vec3 uColor;
  uniform vec3 uSky;
  uniform vec3 uSun;
  varying vec3 vWorld;
  void main() {
    vec3 viewDir = normalize(cameraPosition - vWorld);
    float facing = clamp(dot(vec3(0.0, 1.0, 0.0), viewDir), 0.0, 1.0);
    float fres = pow(1.0 - facing, 2.0);
    vec3 sunDir = normalize(vec3(0.821, 0.5, 0.303));
    vec3 halfDir = normalize(sunDir + viewDir);
    float spec = pow(max(halfDir.y, 0.0), 64.0);
    vec3 col = mix(uColor, uSky, fres * 0.72);
    col += uSun * spec * 0.7;
    float dist = length(cameraPosition - vWorld);
    float fogFactor = smoothstep(48.0, 280.0, dist);
    float sunward = pow(max(dot(normalize(vWorld - cameraPosition), normalize(vec3(0.821, 0.5, 0.303))), 0.0), 1.4);
    col = mix(col, mix(uSky, uSun, sunward * 0.35), fogFactor);
    gl_FragColor = vec4(col, mix(0.82, 0.55, fres));
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

function buildTerrain(planet) {
  const geo = new THREE.PlaneGeometry(SIZE, SIZE, SEGMENTS, SEGMENTS);
  geo.rotateX(-Math.PI / 2);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const stops = (planet.colors || []).map((hex) => new THREE.Color(hex));
  while (stops.length < 4) stops.push(stops[stops.length - 1] || new THREE.Color('#d9d3c8'));
  const bands = BANDS[planet.biome] || BANDS.lush;
  const chosen = new THREE.Color();

  for (let i = 0; i < pos.count; i += 1) {
    const h = heightAt(pos.getX(i), pos.getZ(i), planet);
    pos.setY(i, h);
    if (h < bands[0]) chosen.copy(stops[0]);
    else if (h < bands[1]) chosen.copy(stops[1]);
    else if (h < bands[2]) chosen.copy(stops[2]);
    else chosen.copy(stops[3]);
    colors[i * 3] = chosen.r;
    colors[i * 3 + 1] = chosen.g;
    colors[i * 3 + 2] = chosen.b;
  }
  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

function Terrain({ planet, air }) {
  const geometry = useMemo(() => buildTerrain(planet), [planet]);
  const material = useMemo(() => tintedFog(new THREE.MeshStandardMaterial({
    vertexColors: true,
    roughness: 0.86,
    metalness: 0,
    flatShading: true,
  }), air), [air]);
  useEffect(() => () => {
    geometry.dispose();
    material.dispose();
  }, [geometry, material]);
  return <mesh geometry={geometry} material={material} castShadow receiveShadow />;
}

function Water({ level, air }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: air.water },
      uSky: { value: air.horizon },
      uSun: { value: air.sun },
    },
    vertexShader: waterVertex,
    fragmentShader: waterFragment,
    transparent: true,
    depthWrite: false,
  }), [air]);
  useEffect(() => () => material.dispose(), [material]);

  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, level, 0]} material={material}>
      <planeGeometry args={[SIZE + 120, SIZE + 120, 24, 24]} />
    </mesh>
  );
}

const HORIZON_AT = [-78, 30, -500];

const horizonVertex = `
  varying vec3 vWorld;
  void main() {
    vec4 world = modelMatrix * vec4(position, 1.0);
    vWorld = world.xyz;
    gl_Position = projectionMatrix * viewMatrix * world;
  }
`;

const horizonFragment = `
  uniform vec3 uColor;
  uniform vec3 uRim;
  uniform vec3 uCenter;
  varying vec3 vWorld;
  void main() {
    vec3 n = normalize(vWorld - uCenter);
    float day = smoothstep(-0.35, 0.25, dot(n, normalize(vec3(0.2, 0.85, 0.35))));
    vec3 col = mix(uColor * vec3(0.7, 0.62, 0.8), uColor, day);
    float fres = pow(1.0 - clamp(dot(n, normalize(cameraPosition - vWorld)), 0.0, 1.0), 2.6);
    col += uRim * fres * 0.45;
    gl_FragColor = vec4(col, 1.0);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

function HorizonBody({ radius, color, rim }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uRim: { value: new THREE.Color(rim) },
      uCenter: { value: new THREE.Vector3(...HORIZON_AT) },
    },
    vertexShader: horizonVertex,
    fragmentShader: horizonFragment,
    fog: false,
  }), [color, rim]);
  useEffect(() => () => material.dispose(), [material]);

  return (
    <group position={HORIZON_AT}>
      <mesh material={material}>
        <sphereGeometry args={[radius, 40, 28]} />
      </mesh>
    </group>
  );
}

export function SurfaceWorld({ planet, depleted, sibling, lite = false }) {
  const air = useMemo(() => atmosphereOf(planet), [planet]);
  const water = waterLevel(planet);
  const layout = useMemo(() => surfaceLayout(planet), [planet]);
  const deposits = layout.deposits.filter((deposit) => !depleted.includes(deposit.id));
  const horizonColor = sibling?.colors?.[1] || '#d06a42';
  const horizonRim = sibling?.atmosphere || '#f0b5a4';
  const moon = useMemo(() => {
    const placed = SUN_DIR.clone().multiplyScalar(-460);
    placed.y = Math.abs(placed.y) + 150;
    return placed;
  }, []);

  return (
    <group>
      <AtmosphereDome air={air} lite={lite} />
      <hemisphereLight args={[air.hemiSky, air.hemiGround, air.hemiIntensity]} />
      <ambientLight intensity={0.16} color={air.horizon} />
      <FollowSun air={air} lite={lite} />
      <mesh position={moon}>
        <sphereGeometry args={[18, 20, 14]} />
        <meshBasicMaterial color={air.moon} fog={false} />
      </mesh>
      <HorizonBody radius={168} color={horizonColor} rim={horizonRim} />
      <Terrain planet={planet} air={air} />
      {water != null && <Water level={water} air={air} />}
      {layout.props.map((prop, index) => (
        <Prop key={`${prop.kind}-${index}`} kind={prop.kind} position={prop.position} rotation={prop.rotation} scale={prop.scale} />
      ))}
      <Prop kind="monolith" position={layout.monolith.position} rotation={layout.monolith.rotation} scale={layout.monolith.scale} />
      {deposits.map((deposit) => (
        <Prop key={deposit.id} kind="deposit" position={deposit.position} rotation={[0, 0.4, 0]} scale={1.35} />
      ))}
      <AltitudeFog air={air} />
    </group>
  );
}
