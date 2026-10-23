import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';

const planetVertex = `
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

const planetFragment = `
  uniform vec3 uCenter;
  varying vec3 vColor;
  varying vec3 vWorld;
  void main() {
    vec3 n = normalize(vWorld - uCenter);
    vec3 lightDir = normalize(-uCenter);
    float ndl = dot(n, lightDir);
    float day = smoothstep(-0.25, 0.28, ndl);
    float limb = smoothstep(0.25, 0.85, 1.0 - max(ndl, 0.0));
    vec3 night = vColor * vec3(0.62, 0.55, 0.78);
    vec3 warm = vec3(1.0, 0.78, 0.55);
    vec3 color = mix(night, vColor, day) + warm * limb * day * 0.16;
    gl_FragColor = vec4(color, 1.0);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

const atmosphereVertex = `
  varying vec3 vNormal;
  varying vec3 vWorld;
  void main() {
    vec4 world = modelMatrix * vec4(position, 1.0);
    vWorld = world.xyz;
    vNormal = normalize(mat3(modelMatrix) * normal);
    gl_Position = projectionMatrix * viewMatrix * world;
  }
`;

const atmosphereFragment = `
  uniform vec3 uColor;
  uniform float uPower;
  uniform float uStrength;
  varying vec3 vNormal;
  varying vec3 vWorld;
  void main() {
    vec3 viewDir = normalize(cameraPosition - vWorld);
    float fres = pow(1.0 - clamp(dot(normalize(vNormal), viewDir), 0.0, 1.0), uPower);
    gl_FragColor = vec4(uColor, fres * uStrength);
    #include <colorspace_fragment>
  }
`;

function fade(t) {
  return t * t * (3 - 2 * t);
}

function hash(ix, iy, iz) {
  let n = ix * 374761393 + iy * 668265263 + iz * 2147483647;
  n = (n ^ (n >> 13)) * 1274126177;
  return ((n ^ (n >> 16)) >>> 0) / 4294967296;
}

function valueNoise(x, y, z) {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const iz = Math.floor(z);
  const fx = fade(x - ix);
  const fy = fade(y - iy);
  const fz = fade(z - iz);
  const lerp = (a, b, t) => a + (b - a) * t;
  const x00 = lerp(hash(ix, iy, iz), hash(ix + 1, iy, iz), fx);
  const x10 = lerp(hash(ix, iy + 1, iz), hash(ix + 1, iy + 1, iz), fx);
  const x01 = lerp(hash(ix, iy, iz + 1), hash(ix + 1, iy, iz + 1), fx);
  const x11 = lerp(hash(ix, iy + 1, iz + 1), hash(ix + 1, iy + 1, iz + 1), fx);
  return lerp(lerp(x00, x10, fy), lerp(x01, x11, fy), fz);
}

function fbm(x, y, z) {
  let sum = 0;
  let amp = 0.55;
  let f = 1;
  for (let i = 0; i < 3; i++) {
    sum += amp * valueNoise(x * f, y * f, z * f);
    f *= 2.02;
    amp *= 0.45;
  }
  return sum;
}

function buildGeometry(planet) {
  const geo = new THREE.IcosahedronGeometry(planet.radius, 4);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const stops = (planet.colors || []).map((hex) => new THREE.Color(hex));
  while (stops.length < 4) stops.push(stops[stops.length - 1] || new THREE.Color('#d9d3c8'));
  const color = new THREE.Color();
  const v = new THREE.Vector3();
  const nrm = new THREE.Vector3();
  const amp = planet.radius * planet.relief;

  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    nrm.copy(v).normalize();
    const field = fbm(nrm.x * 2.15 + planet.seed, nrm.y * 2.15, nrm.z * 2.15 + planet.seed * 0.37);
    const lat = Math.abs(nrm.y);
    v.addScaledVector(nrm, (field - 0.45) * amp);
    pos.setXYZ(i, v.x, v.y, v.z);

    if (lat > 0.84) color.copy(stops[3]);
    else if (field < 0.34) color.copy(stops[0]);
    else if (field < 0.52) color.copy(stops[1]);
    else if (lat > 0.68) color.lerpColors(stops[2], stops[3], (lat - 0.68) / 0.16);
    else color.copy(stops[2]);

    const band = Math.abs(Math.sin(nrm.y * 7.5 + planet.seed));
    if (band > 0.92 && lat < 0.7) color.lerp(stops[3], 0.45);

    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;
  }

  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

function Atmosphere({ radius, color, scale, power, strength }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uPower: { value: power },
      uStrength: { value: strength },
    },
    vertexShader: atmosphereVertex,
    fragmentShader: atmosphereFragment,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  }), [color, power, strength]);

  useEffect(() => () => material.dispose(), [material]);

  return (
    <mesh material={material}>
      <sphereGeometry args={[radius * scale, 48, 32]} />
    </mesh>
  );
}

export default function Planet({ planet }) {
  const spin = useRef();
  const geometry = useMemo(() => buildGeometry(planet), [planet]);
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uCenter: { value: new THREE.Vector3(planet.position[0], planet.position[1], planet.position[2]) },
    },
    vertexShader: planetVertex,
    fragmentShader: planetFragment,
  }), [planet]);

  useEffect(() => () => {
    geometry.dispose();
    material.dispose();
  }, [geometry, material]);

  useFrame((_, dt) => {
    if (spin.current) spin.current.rotation.y += dt * 0.02;
  });

  const moonPos = useMemo(() => {
    const toStar = new THREE.Vector3(planet.position[0], planet.position[1], planet.position[2]);
    if (toStar.lengthSq() < 1) toStar.set(0, 0, 1);
    toStar.multiplyScalar(-1 / toStar.length());
    const up = new THREE.Vector3(0, 1, 0);
    const side = new THREE.Vector3().crossVectors(toStar, up);
    if (side.lengthSq() < 1e-4) side.set(1, 0, 0);
    side.normalize();
    const r = planet.radius;
    return toStar.multiplyScalar(r * 1.85).addScaledVector(up, r * 1.2).addScaledVector(side, r * (planet.seed % 1 < 0.5 ? 0.7 : -0.7)).toArray();
  }, [planet]);
  const ring = planet.ring || planet.colors[3] || planet.atmosphere;

  return (
    <group position={planet.position}>
      <mesh ref={spin} geometry={geometry} material={material} />
      <Atmosphere radius={planet.radius} color={planet.atmosphere} scale={1.045} power={3.2} strength={0.7} />
      <Atmosphere radius={planet.radius} color={planet.atmosphere} scale={1.2} power={4.4} strength={0.28} />
      {planet.rings && (
        <group rotation={planet.ringTilt}>
          <mesh>
            <ringGeometry args={[planet.radius * 1.42, planet.radius * 1.58, 96]} />
            <meshBasicMaterial color={ring} transparent opacity={0.62} side={THREE.DoubleSide} depthWrite={false} toneMapped={false} />
          </mesh>
          <mesh>
            <ringGeometry args={[planet.radius * 1.7, planet.radius * 2.18, 96]} />
            <meshBasicMaterial color={planet.colors[2]} transparent opacity={0.28} side={THREE.DoubleSide} depthWrite={false} toneMapped={false} />
          </mesh>
        </group>
      )}
      <mesh position={moonPos}>
        <sphereGeometry args={[planet.radius * 0.16, 20, 14]} />
        <meshBasicMaterial color={planet.moon || '#f4ece4'} toneMapped={false} />
      </mesh>
    </group>
  );
}
