import { useEffect, useMemo } from 'react';
import * as THREE from 'three';
import { heightAt, surfaceLayout, surfaceSky, waterLevel } from '../../../shared/surface.js';
import { Sky } from './scenery';
import { Prop } from './Models';

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

const terrainVertex = `
  attribute vec3 color;
  varying vec3 vColor;
  varying vec3 vWorld;
  void main() {
    vColor = color;
    vec4 world = modelMatrix * vec4(position, 1.0);
    vWorld = world.xyz;
    gl_Position = projectionMatrix * viewMatrix * world;
  }
`;

const terrainFragment = `
  varying vec3 vColor;
  varying vec3 vWorld;
  void main() {
    vec3 n = normalize(cross(dFdx(vWorld), dFdy(vWorld)));
    if (n.y < 0.0) n = -n;
    vec3 key = normalize(vec3(0.78, 0.55, 0.3));
    vec3 fill = normalize(vec3(-0.55, 0.4, -0.45));
    float sun = clamp(dot(n, key), 0.0, 1.0);
    float sky = clamp(dot(n, fill), 0.0, 1.0);
    vec3 col = vColor * (0.58 + 0.42 * sun);
    col += vec3(1.0, 0.72, 0.48) * sun * 0.05;
    col += vColor * vec3(0.62, 0.78, 0.95) * sky * 0.12;
    gl_FragColor = vec4(col, 1.0);
    #include <colorspace_fragment>
  }
`;

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
    vec3 sunDir = normalize(vec3(0.72, 0.62, 0.28));
    vec3 halfDir = normalize(sunDir + viewDir);
    float spec = pow(max(halfDir.y, 0.0), 64.0);
    vec3 col = mix(uColor, uSky, fres * 0.72);
    col += uSun * spec * 0.7;
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

function Terrain({ planet }) {
  const geometry = useMemo(() => buildTerrain(planet), [planet]);
  const material = useMemo(() => new THREE.ShaderMaterial({
    vertexShader: terrainVertex,
    fragmentShader: terrainFragment,
  }), []);
  useEffect(() => () => {
    geometry.dispose();
    material.dispose();
  }, [geometry, material]);
  return <mesh geometry={geometry} material={material} />;
}

function Water({ level, sky }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(sky.water) },
      uSky: { value: new THREE.Color(sky.bottom) },
      uSun: { value: new THREE.Color(sky.sun || '#ffd8b0') },
    },
    vertexShader: waterVertex,
    fragmentShader: waterFragment,
    transparent: true,
    depthWrite: false,
  }), [sky]);
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
    toneMapped: false,
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

export function SurfaceWorld({ planet, depleted, sibling }) {
  const sky = surfaceSky(planet);
  const water = waterLevel(planet);
  const layout = useMemo(() => surfaceLayout(planet), [planet]);
  const deposits = layout.deposits.filter((deposit) => !depleted.includes(deposit.id));
  const horizonColor = sibling?.colors?.[1] || '#d06a42';
  const horizonRim = sibling?.atmosphere || '#f0b5a4';

  return (
    <group>
      <Sky sky={sky} />
      <hemisphereLight args={[sky.mid, '#243044', 0.42]} />
      <ambientLight intensity={0.18} color={sky.bottom} />
      <directionalLight
        position={[140, 110, 54]}
        intensity={1.7}
        color={sky.sun || '#ffd8b0'}
        castShadow
        shadow-mapSize-width={1024}
        shadow-mapSize-height={1024}
        shadow-camera-near={20}
        shadow-camera-far={340}
        shadow-camera-left={-110}
        shadow-camera-right={110}
        shadow-camera-top={110}
        shadow-camera-bottom={-110}
        shadow-bias={-0.0006}
        shadow-normalBias={0.08}
      />
      <directionalLight position={[-90, 36, -48]} intensity={0.4} color="#7eafd4" />
      <group position={[460, 280, 170]}>
        <mesh>
          <sphereGeometry args={[26, 24, 16]} />
          <meshBasicMaterial color="#fff6ea" toneMapped={false} fog={false} />
        </mesh>
        <mesh>
          <sphereGeometry args={[78, 20, 14]} />
          <meshBasicMaterial color={sky.sun || '#ffd2b0'} transparent opacity={0.28} depthWrite={false} toneMapped={false} fog={false} />
        </mesh>
        <mesh>
          <sphereGeometry args={[140, 16, 12]} />
          <meshBasicMaterial color={sky.sun || '#ffd2b0'} transparent opacity={0.1} depthWrite={false} toneMapped={false} fog={false} />
        </mesh>
      </group>
      <mesh position={[-340, 210, -260]}>
        <sphereGeometry args={[22, 20, 14]} />
        <meshBasicMaterial color={sky.moon || '#f6eee6'} toneMapped={false} fog={false} />
      </mesh>
      <HorizonBody radius={168} color={horizonColor} rim={horizonRim} />
      <Terrain planet={planet} />
      {water != null && <Water level={water} sky={sky} />}
      {layout.props.map((prop, index) => (
        <Prop key={`${prop.kind}-${index}`} kind={prop.kind} position={prop.position} rotation={prop.rotation} scale={prop.scale} />
      ))}
      <Prop kind="monolith" position={layout.monolith.position} rotation={layout.monolith.rotation} scale={layout.monolith.scale} />
      {deposits.map((deposit) => (
        <Prop key={deposit.id} kind="deposit" position={deposit.position} rotation={[0, 0.4, 0]} scale={1.35} />
      ))}
      <fog attach="fog" args={[sky.fog, 120, 360]} />
    </group>
  );
}
