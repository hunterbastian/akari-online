import { useEffect, useMemo, useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { hashString } from '../../../shared/universe.js';
import { surfaceSky } from '../../../shared/surface.js';

// Same compass as the previous sun, so a look toward it still finds the light.
export const SUN_DIR = new THREE.Vector3(0.821, 0.5, 0.303).normalize();

export const skyState = { fogHex: '' };

const REACH = {
  lush: 300,
  ocean: 340,
  desert: 240,
  ice: 380,
  volcanic: 200,
  anomalous: 230,
};

function nudge(hex, hash, slot) {
  const color = new THREE.Color(hex);
  const hsl = { h: 0, s: 0, l: 0 };
  color.getHSL(hsl);
  const wobble = (((hash >> (slot * 5)) & 31) - 15) / 15;
  hsl.h = (hsl.h + wobble * 0.02 + 1) % 1;
  hsl.s = THREE.MathUtils.clamp(hsl.s * (1 + wobble * 0.06), 0.04, 0.82);
  hsl.l = THREE.MathUtils.clamp(hsl.l + wobble * 0.02, 0.05, 0.9);
  color.setHSL(hsl.h, hsl.s, hsl.l);
  return color;
}

export function atmosphereOf(planet) {
  const base = surfaceSky(planet);
  const hash = hashString(planet.id || planet.biome || 'world');
  const zenith = nudge(base.top, hash, 0);
  const mid = nudge(base.mid, hash, 1);
  const horizon = nudge(base.bottom, hash, 2);
  const fog = nudge(base.fog, hash, 3);
  const sun = nudge(base.sun || '#ffe1b8', hash, 4);
  const fogSun = fog.clone().lerp(sun, 0.55);
  const ground = new THREE.Color(planet.colors?.[1] || '#8a7a68');
  const zenithLift = zenith.clone().lerp(mid, 0.34);
  const zenithHsl = { h: 0, s: 0, l: 0 };
  zenithLift.getHSL(zenithHsl);
  zenithLift.setHSL(zenithHsl.h, Math.min(zenithHsl.s, 0.42), Math.max(zenithHsl.l, 0.28));
  const horizonSeal = horizon.clone().lerp(fog, 0.35);
  return {
    zenith: zenithLift,
    mid,
    horizon: horizonSeal,
    fog,
    fogSun,
    sun,
    hemiSky: zenithLift.clone().lerp(horizonSeal, 0.55),
    hemiGround: ground.clone().lerp(fog, 0.45),
    moon: new THREE.Color(base.moon || '#f4ece4'),
    water: new THREE.Color(base.water || '#6aa'),
    fogNear: 34,
    fogFar: REACH[planet.biome] || 280,
    sunIntensity: 3.35,
    hemiIntensity: 0.72,
  };
}

export function graphicsLite() {
  if (typeof window === 'undefined') return false;
  const coarse = window.matchMedia('(pointer: coarse)').matches;
  const mem = navigator.deviceMemory || 8;
  return coarse || mem <= 3;
}

const domeVertex = `
  void main() {
    vec4 world = modelMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * viewMatrix * world;
    gl_Position.z = gl_Position.w * 0.9998;
  }
`;

// Direction comes from the camera ray, so the disc does not depend on how coarse the dome is.
const domeFragment = `
  uniform vec3 uZenith;
  uniform vec3 uMid;
  uniform vec3 uHorizon;
  uniform vec3 uFog;
  uniform vec3 uSun;
  uniform vec3 uSunDir;
  uniform float uAltitude;
  uniform mat4 uInvProj;
  uniform mat4 uCamWorld;
  uniform vec2 uResolution;
  void main() {
    vec2 ndc = (gl_FragCoord.xy / uResolution) * 2.0 - 1.0;
    vec4 viewRay = uInvProj * vec4(ndc, 1.0, 1.0);
    vec3 dir = normalize((uCamWorld * vec4(viewRay.xyz / viewRay.w, 0.0)).xyz);
    float up = dir.y;
    vec3 sky = mix(uFog, uHorizon, smoothstep(-0.04, 0.1, up));
    sky = mix(sky, uMid, smoothstep(0.02, 0.42, up));
    sky = mix(sky, uZenith, smoothstep(0.3, 0.92, up));

    float mu = dot(dir, uSunDir);
    float mie = pow(max(mu, 0.0), 36.0);
    float wide = pow(max(mu, 0.0), 8.0);
    sky += uSun * mie * 1.8;
    sky += uSun * wide * 0.62;
    float disc = smoothstep(0.9984, 0.9995, mu);
    sky += vec3(1.0, 0.95, 0.86) * disc * 11.0;

    float below = smoothstep(0.02, -0.12, up);
    sky = mix(sky, uFog, below);

    float alt = clamp(uAltitude, 0.0, 1.0);
    float zenithSpace = smoothstep(0.12, 0.78, up) * alt;
    sky = mix(sky, vec3(0.012, 0.013, 0.02), zenithSpace * 0.9);

    float starNoise = fract(sin(dot(floor(dir * 260.0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
    float star = step(0.996, starNoise) * smoothstep(0.08, 0.45, up);
    sky += vec3(0.82, 0.86, 0.95) * star * smoothstep(0.25, 0.75, alt);

    gl_FragColor = vec4(sky, 1.0);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

const _draw = new THREE.Vector2();

export function AtmosphereDome({ air, lite = false }) {
  const mesh = useRef();
  const material = useMemo(() => new THREE.ShaderMaterial({
    uniforms: {
      uZenith: { value: air.zenith },
      uMid: { value: air.mid },
      uHorizon: { value: air.horizon },
      uFog: { value: air.fog },
      uSun: { value: air.sun },
      uSunDir: { value: SUN_DIR },
      uAltitude: { value: 0 },
      uInvProj: { value: new THREE.Matrix4() },
      uCamWorld: { value: new THREE.Matrix4() },
      uResolution: { value: new THREE.Vector2(1280, 720) },
    },
    vertexShader: domeVertex,
    fragmentShader: domeFragment,
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
  }), [air]);

  useEffect(() => {
    skyState.fogHex = `#${air.fog.getHexString()}`;
    return () => {
      material.dispose();
    };
  }, [air, material]);

  useFrame(({ camera, gl }) => {
    if (mesh.current) mesh.current.position.copy(camera.position);
    camera.updateMatrixWorld();
    const alt = THREE.MathUtils.clamp((camera.position.y - 14) / 108, 0, 1);
    material.uniforms.uAltitude.value = alt;
    material.uniforms.uInvProj.value.copy(camera.projectionMatrixInverse);
    material.uniforms.uCamWorld.value.copy(camera.matrixWorld);
    gl.getDrawingBufferSize(_draw);
    material.uniforms.uResolution.value.copy(_draw);
  }, 0.5);

  return (
    <mesh ref={mesh} material={material} frustumCulled={false}>
      <sphereGeometry args={[600, lite ? 24 : 48, lite ? 16 : 32]} />
    </mesh>
  );
}

export function FollowSun({ air, lite }) {
  const light = useRef();
  const target = useRef();
  const span = lite ? 32 : 48;
  const map = lite ? 512 : 1024;

  useEffect(() => {
    if (light.current && target.current) light.current.target = target.current;
  }, []);

  useFrame(({ camera }) => {
    if (!light.current || !target.current) return;
    const x = camera.position.x;
    const z = camera.position.z;
    const y = Math.min(camera.position.y, 12);
    target.current.position.set(x, y, z);
    light.current.position.set(x + SUN_DIR.x * 96, y + SUN_DIR.y * 96, z + SUN_DIR.z * 96);
  });

  return (
    <>
      <directionalLight
        ref={light}
        color={air.sun}
        intensity={air.sunIntensity}
        castShadow
        shadow-mapSize-width={map}
        shadow-mapSize-height={map}
        shadow-camera-near={4}
        shadow-camera-far={190}
        shadow-camera-left={-span}
        shadow-camera-right={span}
        shadow-camera-top={span}
        shadow-camera-bottom={-span}
        shadow-bias={-0.00022}
        shadow-normalBias={0.05}
      />
      <object3D ref={target} />
    </>
  );
}

export function AltitudeFog({ air }) {
  const fog = useRef();
  useFrame(({ camera }) => {
    if (!fog.current) return;
    const alt = THREE.MathUtils.clamp((camera.position.y - 16) / 100, 0, 1);
    fog.current.near = THREE.MathUtils.lerp(air.fogNear, air.fogNear + 40, alt);
    fog.current.far = THREE.MathUtils.lerp(air.fogFar, air.fogFar + 240, alt);
  });
  return <fog ref={fog} attach="fog" args={[air.fog, air.fogNear, air.fogFar]} />;
}

const VignetteShader = {
  uniforms: {
    tDiffuse: { value: null },
    uStrength: { value: 0.22 },
  },
  vertexShader: `
    varying vec2 vUv;
    void main() {
      vUv = uv;
      gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    }
  `,
  fragmentShader: `
    uniform sampler2D tDiffuse;
    uniform float uStrength;
    varying vec2 vUv;
    void main() {
      vec4 color = texture2D(tDiffuse, vUv);
      float edge = smoothstep(0.32, 0.9, distance(vUv, vec2(0.5)));
      color.rgb *= mix(1.0, 1.0 - uStrength, edge);
      gl_FragColor = color;
    }
  `,
};

export function Grade({ lite }) {
  const composer = useRef(null);
  const { gl, scene, camera, size } = useThree();

  useEffect(() => {
    if (lite) {
      composer.current = null;
      return undefined;
    }
    const effect = new EffectComposer(gl);
    effect.addPass(new RenderPass(scene, camera));
    const bloom = new UnrealBloomPass(new THREE.Vector2(size.width, size.height), 0.16, 0.42, 0.94);
    effect.addPass(bloom);
    effect.addPass(new ShaderPass(VignetteShader));
    composer.current = effect;
    return () => {
      bloom.dispose();
      effect.dispose();
      composer.current = null;
    };
  }, [lite, gl, scene, camera, size.width, size.height]);

  useEffect(() => {
    const effect = composer.current;
    if (!effect) return;
    effect.setPixelRatio(gl.getPixelRatio());
    effect.setSize(size.width, size.height);
  }, [gl, size]);

  useFrame(() => {
    if (composer.current) composer.current.render();
    else gl.render(scene, camera);
  }, 1);

  return null;
}

export function tintedFog(material, air) {
  const previous = material.onBeforeCompile;
  material.onBeforeCompile = (shader) => {
    if (previous) previous(shader);
    shader.uniforms.uSunDir = { value: SUN_DIR };
    shader.uniforms.uFogSun = { value: air.fogSun };
    shader.uniforms.uFogBase = { value: air.fog };
    shader.vertexShader = `varying vec3 vAtmoWorld;\n${shader.vertexShader}`.replace(
      '#include <project_vertex>',
      `#include <project_vertex>
       vAtmoWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;`,
    );
    shader.fragmentShader = `varying vec3 vAtmoWorld;\nuniform vec3 uSunDir;\nuniform vec3 uFogSun;\nuniform vec3 uFogBase;\n${shader.fragmentShader}`.replace(
      '#include <fog_fragment>',
      `#ifdef USE_FOG
        float fogFactor = smoothstep(fogNear, fogFar, vFogDepth);
        float low = smoothstep(26.0, -6.0, vAtmoWorld.y);
        fogFactor = clamp(fogFactor + low * 0.42 * (0.3 + fogFactor), 0.0, 1.0);
        vec3 viewDir = normalize(vAtmoWorld - cameraPosition);
        float sunward = pow(max(dot(viewDir, normalize(uSunDir)), 0.0), 1.45);
        vec3 fogCol = mix(uFogBase, uFogSun, sunward * 0.72);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, fogCol, fogFactor);
      #endif`,
    );
  };
  material.customProgramCacheKey = () => 'atmo-fog';
  return material;
}
