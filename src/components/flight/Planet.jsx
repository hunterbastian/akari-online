import { useEffect, useMemo, useRef } from 'react';
import { useFrame } from '@react-three/fiber';
import * as THREE from 'three';
import { graphicsLite, sunDirection } from './atmosphere.jsx';
import { OrbitMarks } from './Interests';

// From far away the world is a few big colors and a thick rim. Up close the
// same sphere breaks into weather, coastlines, and a soft sun-lit halo.
const BIOME_ID = { lush: 0, ocean: 1, desert: 2, ice: 3, volcanic: 4, anomalous: 5 };

const noiseGlsl = `
  float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
  }
  float vnoise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
      mix(mix(hash13(i), hash13(i + vec3(1.0, 0.0, 0.0)), f.x),
          mix(hash13(i + vec3(0.0, 1.0, 0.0)), hash13(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
      mix(mix(hash13(i + vec3(0.0, 0.0, 1.0)), hash13(i + vec3(1.0, 0.0, 1.0)), f.x),
          mix(hash13(i + vec3(0.0, 1.0, 1.0)), hash13(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
      f.z);
  }
`;

const planetVertex = `
  varying vec3 vObj;
  varying vec3 vWorld;
  void main() {
    vObj = position;
    vec4 world = modelMatrix * vec4(position, 1.0);
    vWorld = world.xyz;
    gl_Position = projectionMatrix * viewMatrix * world;
  }
`;

function planetFragment(lite) {
  return `
  uniform vec3 uCenter;
  uniform vec3 uSunDir;
  uniform vec3 uC0;
  uniform vec3 uC1;
  uniform vec3 uC2;
  uniform vec3 uC3;
  uniform vec3 uAtmo;
  uniform float uSeed;
  uniform float uTime;
  uniform float uBiome;
  varying vec3 vObj;
  varying vec3 vWorld;
  ${noiseGlsl}
  void main() {
    vec3 nrm = normalize(vObj);
    float freq = 1.22 + fract(uSeed * 0.37) * 0.28;
    vec3 p = nrm * freq + vec3(uSeed * 0.21, uSeed * 0.13, -uSeed * 0.17);
    vec3 p2 = p * 2.05 + vec3(4.2, 1.3, 2.7);
    float n1 = vnoise(p);
    float n2 = vnoise(p2);
    ${lite ? '' : 'float n3 = vnoise(p * 4.09 + 9.1); float n4 = vnoise(p * 8.21 + 2.4);'}
    float shape = n1;
    float paint = ${lite ? 'n2' : 'n2 * 0.58 + n3 * 0.42'};
    float detail = ${lite ? 'n2' : 'n3 * 0.62 + n4 * 0.38'};
    float lat = abs(nrm.y);

    vec3 worldN = normalize(vWorld - uCenter);
    ${lite ? '' : `
    float bx = vnoise(p2 + vec3(0.14, 0.0, 0.0)) - n2;
    float by = vnoise(p2 + vec3(0.0, 0.14, 0.0)) - n2;
    float bz = vnoise(p2 + vec3(0.0, 0.0, 0.14)) - n2;
    worldN = normalize(mat3(modelMatrix) * normalize(nrm - vec3(bx, by, bz) * 2.6));
    `}

    vec3 albedo = uC1;
    float specMask = 0.0;
    float shine = 24.0;
    float sheenAmt = 0.0;
    float cloudAmt = 0.45;
    float crack = 0.0;

    if (uBiome < 0.5) {
      float sea = smoothstep(0.4, 0.28, shape);
      vec3 water = mix(uC0 * 0.72, uC0, paint);
      vec3 canopy = mix(uC0, uC1, smoothstep(0.18, 0.78, paint));
      vec3 clearing = mix(uC1, uC2, smoothstep(0.22, 0.82, detail));
      albedo = mix(canopy, clearing, smoothstep(0.48, 0.76, shape) * 0.72);
      albedo = mix(albedo, uC3, smoothstep(0.72, 0.93, lat));
      albedo = mix(albedo, water, sea);
      specMask = sea;
      shine = 34.0;
      sheenAmt = 0.08;
      cloudAmt = 0.64;
    } else if (uBiome < 1.5) {
      float sea = smoothstep(0.62, 0.5, shape);
      vec3 water = mix(uC0 * 0.78, uC1, 0.18 + paint * 0.5);
      water = mix(water, uC0 * 0.7, smoothstep(0.4, 0.16, shape) * 0.55);
      vec3 land = mix(uC1, mix(uC2, uC3, paint * 0.65), 0.8);
      albedo = mix(land, water, sea);
      albedo = mix(albedo, uC3, smoothstep(0.74, 0.94, lat) * (1.0 - sea));
      specMask = sea;
      shine = 26.0;
      sheenAmt = 0.15;
      cloudAmt = 0.72;
    } else if (uBiome < 2.5) {
      float basin = smoothstep(0.46, 0.24, shape);
      float dune = 0.5 + 0.5 * sin(nrm.y * 7.0 + shape * 4.0);
      vec3 sand = mix(uC1, uC2, dune * 0.55 + paint * 0.25);
      vec3 rust = mix(uC0, uC1, paint * 0.28);
      albedo = mix(sand, rust, basin);
      albedo = mix(albedo, mix(uC1, uC2, dune), (1.0 - basin) * 0.22);
      albedo = mix(albedo, uC3, smoothstep(0.82, 0.97, lat) * 0.28);
      cloudAmt = 0.12;
    } else if (uBiome < 3.5) {
      vec3 blue = mix(uC0, uC1, 0.22 + paint * 0.5);
      vec3 pale = mix(uC1, uC2, 0.4);
      float high = smoothstep(0.7, 0.88, shape);
      albedo = mix(blue, pale, high * 0.5);
      albedo = mix(albedo, uC2, smoothstep(0.78, 0.96, lat) * 0.5);
      float crev = smoothstep(0.4, 0.14, detail);
      albedo = mix(albedo, uC0 * 0.62, crev * 0.4);
      specMask = 0.5;
      shine = 30.0;
      sheenAmt = 0.04;
      cloudAmt = 0.2;
    } else if (uBiome < 4.5) {
      vec3 rock = mix(uC0, uC1, 0.18 + smoothstep(0.25, 0.8, shape) * 0.35);
      float vein = 1.0 - smoothstep(0.0, 0.08, abs(shape - 0.5));
      float fine = 1.0 - smoothstep(0.015, 0.08, abs(paint - 0.46));
      crack = clamp(vein * 0.9 + fine * 0.28, 0.0, 1.0);
      albedo = mix(rock, uC2, crack * 0.92);
      cloudAmt = 0.18;
    } else {
      float sea = smoothstep(0.44, 0.32, shape);
      vec3 low = mix(uC0, uC1, paint);
      vec3 high = mix(uC1, uC2, smoothstep(0.2, 0.86, detail));
      albedo = mix(low, high, smoothstep(0.34, 0.7, shape));
      albedo = mix(albedo, uC3, smoothstep(0.7, 0.93, lat));
      albedo = mix(albedo, uC0, sea * 0.72);
      specMask = sea * 0.45;
      shine = 22.0;
      sheenAmt = 0.06;
      cloudAmt = 0.46;
    }

    vec3 lightDir = normalize(uSunDir);
    vec3 viewDir = normalize(cameraPosition - vWorld);
    float ndl = dot(worldN, lightDir);
    float day = smoothstep(-0.32, 0.46, ndl);
    float wrap = smoothstep(-0.4, 0.7, ndl);
    vec3 lit = albedo * (0.58 + 0.42 * wrap);
    vec3 night = mix(albedo * 0.24, uAtmo * 0.14, 0.2);
    vec3 color = mix(night, lit, day);
    float term = exp(-ndl * ndl * 7.5);
    color = mix(color, color * vec3(1.08, 0.86, 0.58), term * 0.38);
    color += vec3(1.0, 0.42, 0.16) * crack * 0.2;

    vec3 halfDir = normalize(lightDir + viewDir);
    float ndh = max(dot(worldN, halfDir), 0.0);
    float glint = pow(ndh, shine) * 0.55 + pow(ndh, 5.0) * sheenAmt;
    color += vec3(1.0, 0.97, 0.92) * glint * specMask * smoothstep(-0.02, 0.22, ndl);

    ${lite ? `
    float band = sin(nrm.y * 2.6 + uSeed * 1.4 + uTime * 0.015);
    float cloud = smoothstep(0.2, 0.86, band * 0.5 + 0.5);
    ` : `
    float band = sin(nrm.y * 2.4 + uSeed * 1.4 + shape * 1.6 + uTime * 0.012);
    float cn = vnoise(nrm * 1.8 + vec3(uTime * 0.01, uSeed, 0.4));
    float cloud = smoothstep(0.18, 0.88, band * 0.5 + 0.5);
    cloud = clamp(cloud * 0.7 + smoothstep(0.42, 0.8, cn) * 0.55, 0.0, 1.0);
    `}
    vec3 cloudCol = mix(vec3(0.93, 0.9, 0.82), uAtmo, 0.16);
    float cloudVis = mix(0.2, 1.0, smoothstep(-0.25, 0.35, ndl));
    color = mix(color, cloudCol * mix(0.4, 1.0, day), clamp(cloud * cloudAmt, 0.0, 0.36) * cloudVis);

    float fres = pow(1.0 - clamp(dot(worldN, viewDir), 0.0, 1.0), 2.2);
    color += uAtmo * fres * mix(0.06, 0.28, day);

    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    color = mix(vec3(luma), color, 0.86);
    color = mix(color * vec3(0.9, 0.97, 1.0), color * vec3(1.03, 0.98, 0.92), smoothstep(0.16, 0.7, luma));
    gl_FragColor = vec4(color, 1.0);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;
}

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
  uniform vec3 uSunDir;
  varying vec3 vNormal;
  varying vec3 vWorld;
  void main() {
    vec3 viewDir = normalize(cameraPosition - vWorld);
    vec3 n = normalize(vNormal);
    float ndotv = clamp(dot(n, viewDir), 0.0, 1.0);
    float rim = pow(1.0 - ndotv, 1.55);
    float halo = pow(1.0 - ndotv, 1.05);
    float ndl = dot(n, normalize(uSunDir));
    float day = smoothstep(-0.4, 0.62, ndl);
    float term = exp(-ndl * ndl * 5.5);
    vec3 col = uColor * mix(0.42, 1.05, day);
    col += vec3(1.0, 0.8, 0.5) * term * halo * 0.65;
    float alpha = (halo * 0.32 + rim * 0.58) * mix(0.28, 0.82, day);
    gl_FragColor = vec4(col, alpha);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

function palette(planet) {
  const stops = (planet.colors || []).map((hex) => new THREE.Color(hex));
  while (stops.length < 4) stops.push(stops[stops.length - 1]?.clone() || new THREE.Color('#d9d3c8'));
  return stops;
}

export default function Planet({ planet, marks = false }) {
  const spin = useRef();
  const lite = graphicsLite();
  const geometry = useMemo(
    () => new THREE.SphereGeometry(planet.radius, lite ? 28 : 48, lite ? 20 : 32),
    [planet, lite],
  );
  const material = useMemo(() => {
    const colors = palette(planet);
    return new THREE.ShaderMaterial({
      uniforms: {
        uCenter: { value: new THREE.Vector3(planet.position[0], planet.position[1], planet.position[2]) },
        uSunDir: { value: sunDirection(planet.id) },
        uC0: { value: colors[0] },
        uC1: { value: colors[1] },
        uC2: { value: colors[2] },
        uC3: { value: colors[3] },
        uAtmo: { value: new THREE.Color(planet.atmosphere) },
        uSeed: { value: planet.seed || 0 },
        uTime: { value: 0 },
        uBiome: { value: BIOME_ID[planet.biome] ?? 0 },
      },
      vertexShader: planetVertex,
      fragmentShader: planetFragment(lite),
      fog: false,
    });
  }, [planet, lite]);
  const atmo = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(planet.atmosphere) },
      uSunDir: { value: sunDirection(planet.id) },
    },
    vertexShader: atmosphereVertex,
    fragmentShader: atmosphereFragment,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    toneMapped: false,
    fog: false,
  }), [planet]);

  useEffect(() => () => {
    geometry.dispose();
    material.dispose();
    atmo.dispose();
  }, [geometry, material, atmo]);

  useFrame((_, dt) => {
    const step = Math.min(dt, 0.05);
    if (spin.current) spin.current.rotation.y += step * 0.02;
    material.uniforms.uTime.value += step;
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
      {marks && <OrbitMarks planet={planet} />}
      <mesh material={atmo} renderOrder={2}>
        <sphereGeometry args={[planet.radius * 1.28, lite ? 36 : 48, lite ? 24 : 32]} />
      </mesh>
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
