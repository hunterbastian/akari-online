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
  varying vec3 vColor;
  varying vec3 vWorld;
  void main() {
    vec3 n = normalize(cross(dFdx(vWorld), dFdy(vWorld)));
    float ndl = max(dot(n, normalize(-vWorld)), 0.0);
    float shade = 0.62 + 0.38 * ndl;
    gl_FragColor = vec4(vColor * shade, 1.0);
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
  varying vec3 vNormal;
  varying vec3 vWorld;
  void main() {
    vec3 viewDir = normalize(cameraPosition - vWorld);
    float fres = pow(1.0 - clamp(dot(normalize(vNormal), viewDir), 0.0, 1.0), 2.6);
    gl_FragColor = vec4(uColor, fres * 0.55);
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
  let amp = 0.5;
  let f = 1;
  for (let i = 0; i < 4; i++) {
    sum += amp * valueNoise(x * f, y * f, z * f);
    f *= 2.05;
    amp *= 0.5;
  }
  return sum;
}

function buildGeometry(planet) {
  const geo = new THREE.IcosahedronGeometry(planet.radius, 3);
  const pos = geo.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const low = new THREE.Color(planet.colors[0]);
  const mid = new THREE.Color(planet.colors[1]);
  const high = new THREE.Color(planet.colors[2]);
  const color = new THREE.Color();
  const v = new THREE.Vector3();
  const nrm = new THREE.Vector3();
  const amp = planet.radius * planet.relief;

  for (let i = 0; i < pos.count; i++) {
    v.fromBufferAttribute(pos, i);
    nrm.copy(v).normalize();
    const h = fbm(nrm.x * 1.8 + planet.seed, nrm.y * 1.8, nrm.z * 1.8 + planet.seed * 0.37);
    v.addScaledVector(nrm, (h - 0.46) * amp);
    pos.setXYZ(i, v.x, v.y, v.z);
    if (h < 0.4) color.copy(low);
    else if (h > 0.7) color.copy(high);
    else color.copy(mid);
    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;
  }

  geo.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geo.computeVertexNormals();
  return geo;
}

function Atmosphere({ radius, color }) {
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: { uColor: { value: new THREE.Color(color) } },
    vertexShader: atmosphereVertex,
    fragmentShader: atmosphereFragment,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
  }), [color]);

  useEffect(() => () => material.dispose(), [material]);

  return (
    <mesh material={material}>
      <sphereGeometry args={[radius * 1.14, 36, 24]} />
    </mesh>
  );
}

export default function Planet({ planet }) {
  const spin = useRef();
  const geometry = useMemo(() => buildGeometry(planet), [planet]);
  const material = useMemo(() => new THREE.ShaderMaterial({
    vertexShader: planetVertex,
    fragmentShader: planetFragment,
    toneMapped: false,
  }), []);

  useEffect(() => () => {
    geometry.dispose();
    material.dispose();
  }, [geometry, material]);

  useFrame((_, dt) => {
    if (spin.current) spin.current.rotation.y += dt * 0.035;
  });

  return (
    <group position={planet.position}>
      <mesh ref={spin} geometry={geometry} material={material} />
      <Atmosphere radius={planet.radius} color={planet.atmosphere} />
      {planet.rings && (
        <mesh rotation={planet.ringTilt}>
          <ringGeometry args={[planet.radius * 1.5, planet.radius * 2.2, 64]} />
          <meshBasicMaterial
            color={planet.colors[2]}
            transparent
            opacity={0.38}
            side={THREE.DoubleSide}
            depthWrite={false}
          />
        </mesh>
      )}
    </group>
  );
}
