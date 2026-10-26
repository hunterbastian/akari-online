import { useEffect, useMemo, useRef } from 'react';
import { useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { EffectComposer } from 'three/examples/jsm/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/examples/jsm/postprocessing/RenderPass.js';
import { ShaderPass } from 'three/examples/jsm/postprocessing/ShaderPass.js';
import { SSAOPass } from 'three/examples/jsm/postprocessing/SSAOPass.js';
import { UnrealBloomPass } from 'three/examples/jsm/postprocessing/UnrealBloomPass.js';
import { hashString } from '../../../shared/universe.js';
import { surfaceSky } from '../../../shared/surface.js';

// Shared stand-in. Each world copies its own daytime sun into this before drawing.
export const SUN_DIR = new THREE.Vector3(0.821, 0.5, 0.303).normalize();

export const skyState = {
  fogHex: '',
  sunDir: SUN_DIR.clone(),
};

// Daytime only: elevation stays between 20° and 60°, azimuth is the planet's own.
export function sunDirection(id, target = new THREE.Vector3()) {
  const hash = hashString(`${id || 'world'}:sun`);
  const azimuth = ((hash & 65535) / 65535) * Math.PI * 2;
  const elevation = (20 + ((hash >>> 16) % 41)) * (Math.PI / 180);
  const flat = Math.cos(elevation);
  return target.set(Math.sin(azimuth) * flat, Math.sin(elevation), Math.cos(azimuth) * flat);
}

const REACH = {
  lush: 620,
  ocean: 680,
  desert: 500,
  ice: 740,
  volcanic: 440,
  anomalous: 480,
};

// Believable sky hues. The biome still tints the horizon and the sun.
const SKY_HUE = {
  lush: [0.60, 0.50, 0.32],
  ocean: [0.63, 0.54, 0.26],
  desert: [0.51, 0.42, 0.36],
  ice: [0.58, 0.48, 0.38],
  volcanic: [0.74, 0.38, 0.16],
  anomalous: [0.70, 0.40, 0.20],
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

function biasedSky(planet, hash, slot, lift = 0) {
  const [h, s, l] = SKY_HUE[planet.biome] || SKY_HUE.lush;
  const wobble = (((hash >> (slot * 5)) & 31) - 15) / 15;
  const color = new THREE.Color();
  color.setHSL(
    (h + wobble * 0.012 + 1) % 1,
    THREE.MathUtils.clamp(s + wobble * 0.03, 0.22, 0.7),
    THREE.MathUtils.clamp(l + lift + wobble * 0.012, 0.08, 0.55),
  );
  return color;
}

export function atmosphereOf(planet) {
  const base = surfaceSky(planet);
  const hash = hashString(planet.id || planet.biome || 'world');
  const zenith = biasedSky(planet, hash, 0);
  const mid = biasedSky(planet, hash, 1, 0.12);
  mid.lerp(nudge(base.mid, hash, 1), 0.16);
  const horizon = nudge(base.bottom, hash, 2);
  const horizonHsl = { h: 0, s: 0, l: 0 };
  horizon.getHSL(horizonHsl);
  horizon.setHSL(horizonHsl.h, Math.min(horizonHsl.s, 0.32), Math.max(horizonHsl.l, 0.78));
  horizon.lerp(zenith, 0.06);
  const fog = horizon.clone();
  const fogHsl = { h: 0, s: 0, l: 0 };
  fog.getHSL(fogHsl);
  fog.setHSL(fogHsl.h, fogHsl.s * 0.65, Math.min(fogHsl.l, 0.8));
  const sun = new THREE.Color('#ffb15e');
  sun.lerp(nudge(base.sun || '#ffe1b8', hash, 4), 0.32);
  const fogSun = fog.clone().lerp(sun, 0.62);
  const ground = new THREE.Color(planet.colors?.[1] || '#8a7a68');
  return {
    zenith,
    mid,
    horizon,
    fog,
    fogSun,
    sun,
    hemiSky: zenith.clone().lerp(mid, 0.35),
    hemiGround: ground.clone().multiplyScalar(0.42).lerp(zenith, 0.22),
    moon: new THREE.Color(base.moon || '#f4ece4'),
    water: new THREE.Color(base.water || '#6aa'),
    fogNear: 120,
    fogFar: REACH[planet.biome] || 560,
    sunIntensity: 3.7,
    hemiIntensity: 0.55,
    sunDir: sunDirection(planet.id),
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
  uniform vec3 uSun;
  uniform vec3 uSunDir;
  uniform float uAltitude;
  uniform float uTime;
  uniform mat4 uInvProj;
  uniform mat4 uCamWorld;
  uniform vec2 uResolution;

  float hash12(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }
  float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
  }

  void main() {
    vec2 ndc = (gl_FragCoord.xy / uResolution) * 2.0 - 1.0;
    vec4 viewRay = uInvProj * vec4(ndc, 1.0, 1.0);
    vec3 dir = normalize((uCamWorld * vec4(viewRay.xyz / viewRay.w, 0.0)).xyz);
    float up = dir.y;
    vec3 sky = mix(uHorizon, uMid, smoothstep(0.0, 0.26, up));
    sky = mix(sky, uZenith, smoothstep(0.06, 0.62, up));

    float mu = dot(dir, uSunDir);
    float mie = pow(max(mu, 0.0), 56.0);
    float wide = pow(max(mu, 0.0), 14.0);
    sky += uSun * mie * 1.15;
    sky += uSun * wide * 0.22;

    /*CLOUD*/
    float body = smoothstep(0.2, 0.62, n);
    float rim = smoothstep(0.16, 0.38, n) * (1.0 - smoothstep(0.52, 0.84, n));
    float shade = clamp(0.18 + (n - nShade) * 1.7, 0.0, 1.0);
    float sunLit = pow(max(mu, 0.0), 1.15);
    vec3 shadowCol = uZenith * 0.38 + vec3(0.08, 0.09, 0.11);
    vec3 litCol = mix(vec3(0.9, 0.92, 0.95), uSun, 0.32);
    vec3 cloud = mix(shadowCol, litCol, shade * 0.72 + sunLit * 0.2 + 0.06);
    cloud = mix(cloud, litCol, rim * (0.28 + sunLit * 0.6));
    float mask = body * smoothstep(0.02, 0.2, up) * (1.0 - smoothstep(0.992, 0.9992, mu));
    sky = mix(sky, cloud, mask * 0.78);
    cir *= smoothstep(0.22, 0.5, up) * (1.0 - smoothstep(0.8, 0.97, up)) * (1.0 - body * 0.65);
    sky = mix(sky, vec3(0.95, 0.96, 0.99), cir * 0.36);

    float disc = smoothstep(0.9985, 0.99955, mu);
    sky += vec3(1.0, 0.93, 0.8) * disc * 12.0;

    float below = smoothstep(0.02, -0.1, up);
    sky = mix(sky, uHorizon * 0.9, below);

    float alt = clamp(uAltitude, 0.0, 1.0);
    float zenithSpace = smoothstep(0.12, 0.78, up) * alt;
    sky = mix(sky, vec3(0.012, 0.014, 0.024), zenithSpace * 0.92);

    float starNoise = fract(sin(dot(floor(dir * 260.0), vec3(127.1, 311.7, 74.7))) * 43758.5453);
    float star = step(0.996, starNoise) * smoothstep(0.08, 0.45, up);
    sky += vec3(0.82, 0.86, 0.95) * star * smoothstep(0.25, 0.75, alt);

    gl_FragColor = vec4(sky, 1.0);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

const cloudPhone = `
    vec2 cuv = dir.xz / (abs(dir.y) + 0.5);
    float drift = uTime * 0.008;
    vec2 scroll = vec2(drift, drift * 0.16);
    float n = vnoise(cuv * 0.62 + scroll);
    float nShade = vnoise(cuv * 0.62 + scroll + uSunDir.xz * 0.16);
    float cir = sin(dir.x * 6.5 + dir.z * 1.4 + drift * 1.8) * sin(dir.z * 5.0 - dir.x * 0.8);
    cir = smoothstep(0.4, 0.8, cir * 0.5 + 0.5);
`;

const cloudDesktop = `
    vec2 cuv = dir.xz / (abs(dir.y) + 0.5);
    float drift = uTime * 0.008;
    vec2 scroll = vec2(drift, drift * 0.16);
    vec2 warp = vec2(
      vnoise(cuv * 0.85 + vec2(1.7, 0.4)),
      vnoise(cuv * 0.85 + vec2(4.2, 2.6))
    );
    vec2 puffed = cuv + (warp - 0.5) * 0.62;
    float n = vnoise(puffed * 0.55 + scroll);
    n += vnoise(puffed * 1.2 - scroll * 0.7) * 0.42;
    float nShade = vnoise(puffed * 0.55 + scroll + uSunDir.xz * 0.18);
    float cir = smoothstep(0.5, 0.82, vnoise(vec2(dir.x * 3.6 + dir.z * 0.7 + drift * 0.25, dir.y * 7.5)));
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
      uSunDir: { value: air.sunDir },
      uAltitude: { value: 0 },
      uTime: { value: 0 },
      uInvProj: { value: new THREE.Matrix4() },
      uCamWorld: { value: new THREE.Matrix4() },
      uResolution: { value: new THREE.Vector2(1280, 720) },
    },
    vertexShader: domeVertex,
    fragmentShader: domeFragment.replace('/*CLOUD*/', lite ? cloudPhone : cloudDesktop),
    side: THREE.BackSide,
    depthWrite: false,
    fog: false,
  }), [air, lite]);

  useEffect(() => {
    skyState.fogHex = `#${air.fog.getHexString()}`;
    return () => {
      material.dispose();
    };
  }, [air, material]);

  useFrame(({ camera, gl, clock }) => {
    if (mesh.current) mesh.current.position.copy(camera.position);
    camera.updateMatrixWorld();
    const alt = THREE.MathUtils.clamp((camera.position.y - 14) / 108, 0, 1);
    material.uniforms.uAltitude.value = alt;
    material.uniforms.uTime.value = clock.elapsedTime;
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
  const span = lite ? 16 : 20;
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
    const sun = air.sunDir;
    light.current.position.set(x + sun.x * 96, y + sun.y * 96, z + sun.z * 96);
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
        shadow-camera-near={2}
        shadow-camera-far={120}
        shadow-camera-left={-span}
        shadow-camera-right={span}
        shadow-camera-top={span}
        shadow-camera-bottom={-span}
        shadow-bias={-0.00018}
        shadow-normalBias={0.022}
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
    fog.current.near = THREE.MathUtils.lerp(air.fogNear, air.fogNear + 160, alt);
    fog.current.far = THREE.MathUtils.lerp(air.fogFar, air.fogFar + 420, alt);
  });
  return <fog ref={fog} attach="fog" args={[air.fog, air.fogNear, air.fogFar]} />;
}

const GradeShader = {
  uniforms: {
    tDiffuse: { value: null },
    uSunUv: { value: new THREE.Vector2(0.5, 1.4) },
    uFlare: { value: 0 },
    uOrbit: { value: 0 },
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
    uniform vec2 uSunUv;
    uniform float uFlare;
    uniform float uOrbit;
    varying vec2 vUv;
    void main() {
      vec3 c = texture2D(tDiffuse, vUv).rgb;
      if (uOrbit > 0.5) {
        float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(vec3(luma), c, 0.84);
        float tone = smoothstep(0.08, 0.55, luma);
        c = mix(c * vec3(0.82, 0.94, 0.98), c * vec3(1.08, 0.96, 0.82), tone);
        vec2 d = vUv - uSunUv;
        float glare = exp(-dot(d, d) * 5.5) * uFlare;
        c += vec3(1.0, 0.86, 0.62) * glare * 0.22;
        float grain = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453);
        c += (grain - 0.5) * 0.028;
        float vig = smoothstep(0.95, 0.28, length(vUv - vec2(0.5)));
        c *= mix(0.76, 1.0, vig);
      } else {
        float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(vec3(luma), c, 1.08);
        c = clamp((c - 0.5) * 1.05 + 0.5, 0.0, 1.0);
        luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
        float tone = smoothstep(0.18, 0.72, luma);
        c *= mix(vec3(0.86, 0.93, 1.08), vec3(1.07, 1.03, 0.92), tone);
        vec2 d = vUv - uSunUv;
        vec2 g = vUv - (vec2(1.0) - uSunUv);
        float glare = exp(-dot(d, d) * 14.0) * uFlare;
        float ghost = exp(-dot(g, g) * 46.0) * uFlare;
        c += vec3(1.0, 0.9, 0.72) * (glare * 0.16 + ghost * 0.05);
        float edge = smoothstep(0.38, 0.92, distance(vUv, vec2(0.5)));
        c *= mix(1.0, 0.86, edge);
      }
      gl_FragColor = vec4(clamp(c, 0.0, 1.0), 1.0);
    }
  `,
};

const _sun = new THREE.Vector3();
const _sunView = new THREE.Vector3();

export function Grade({ lite, contact = false }) {
  const composer = useRef(null);
  const grade = useRef(null);
  const { gl, scene, camera, size } = useThree();

  useEffect(() => {
    if (lite) {
      composer.current = null;
      grade.current = null;
      return undefined;
    }
    const effect = new EffectComposer(gl);
    let ssao = null;
    let bloom = null;
    // SSAOPass only multiplies occlusion onto the previous buffer. Draw the scene first.
    effect.addPass(new RenderPass(scene, camera));
    if (contact) {
      ssao = new SSAOPass(scene, camera, size.width, size.height, 16);
      ssao.kernelRadius = 12;
      ssao.minDistance = 0.0015;
      ssao.maxDistance = 0.04;
      effect.addPass(ssao);
    }
    if (!lite) {
      bloom = new UnrealBloomPass(
        new THREE.Vector2(size.width, size.height),
        contact ? 0.18 : 0.12,
        contact ? 0.46 : 0.5,
        contact ? 0.9 : 0.92,
      );
      effect.addPass(bloom);
    }
    const pass = new ShaderPass(GradeShader);
    grade.current = pass;
    effect.addPass(pass);
    composer.current = effect;
    return () => {
      ssao?.dispose();
      bloom?.dispose();
      effect.dispose();
      composer.current = null;
      grade.current = null;
    };
  }, [lite, contact, gl, scene, camera, size.width, size.height]);

  useEffect(() => {
    const effect = composer.current;
    if (!effect) return;
    effect.setPixelRatio(gl.getPixelRatio());
    effect.setSize(size.width, size.height);
  }, [gl, size]);

  useFrame(() => {
    const effect = composer.current;
    const pass = grade.current;
    if (!effect || !pass) {
      gl.render(scene, camera);
      return;
    }
    camera.updateMatrixWorld();
    const orbit = !contact;
    pass.uniforms.uOrbit.value = orbit ? 1 : 0;
    if (orbit) _sun.set(0, 0, 0);
    else _sun.copy(camera.position).addScaledVector(skyState.sunDir, 40);
    _sunView.copy(_sun).applyMatrix4(camera.matrixWorldInverse);
    _sun.project(camera);
    const visible = _sunView.z < 0 && Math.abs(_sun.x) < 1.15 && Math.abs(_sun.y) < 1.15;
    pass.uniforms.uSunUv.value.set(_sun.x * 0.5 + 0.5, _sun.y * 0.5 + 0.5);
    pass.uniforms.uFlare.value = visible && !lite && (contact || orbit) ? (orbit ? 0.65 : 1) : 0;
    effect.render();
  }, 1);

  return null;
}

export function SkyEnvironment({ air, lite = false }) {
  const { gl, scene } = useThree();
  useEffect(() => {
    if (lite) return undefined;
    const canvas = document.createElement('canvas');
    canvas.width = 256;
    canvas.height = 128;
    const ctx = canvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 128);
    const css = (color) => `#${color.clone().convertLinearToSRGB().getHexString()}`;
    gradient.addColorStop(0, css(air.zenith));
    gradient.addColorStop(0.45, css(air.mid));
    gradient.addColorStop(1, css(air.horizon));
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 256, 128);
    const u = (Math.atan2(air.sunDir.z, air.sunDir.x) / (Math.PI * 2) + 1) % 1;
    const v = Math.acos(THREE.MathUtils.clamp(air.sunDir.y, -1, 1)) / Math.PI;
    const glow = ctx.createRadialGradient(u * 256, v * 128, 2, u * 256, v * 128, 46);
    glow.addColorStop(0, '#fff3d4');
    glow.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.globalCompositeOperation = 'screen';
    ctx.fillStyle = glow;
    ctx.fillRect(0, 0, 256, 128);
    const tex = new THREE.CanvasTexture(canvas);
    tex.mapping = THREE.EquirectangularReflectionMapping;
    tex.colorSpace = THREE.SRGBColorSpace;
    const pmrem = new THREE.PMREMGenerator(gl);
    const target = pmrem.fromEquirectangular(tex);
    const previous = scene.environment;
    const previousIntensity = scene.environmentIntensity;
    scene.environment = target.texture;
    scene.environmentIntensity = 0.9;
    return () => {
      scene.environment = previous;
      scene.environmentIntensity = previousIntensity;
      target.dispose();
      tex.dispose();
      pmrem.dispose();
    };
  }, [air, gl, scene, lite]);
  return null;
}

const FOG_CHUNK = `#ifdef USE_FOG
        float fogFactor = smoothstep(fogNear, fogFar, vFogDepth);
        vec3 viewDir = normalize(vSurfWorld - cameraPosition);
        float sunward = pow(max(dot(viewDir, normalize(uSunDir)), 0.0), 1.6);
        vec3 fogCol = mix(uFogBase, uFogSun, sunward * 0.55);
        gl_FragColor.rgb = mix(gl_FragColor.rgb, fogCol, fogFactor);
      #endif`;

export function dressGround(material, air, { crease = false, lite = false } = {}) {
  material.onBeforeCompile = (shader) => {
    shader.uniforms.uSunDir = { value: air.sunDir };
    shader.uniforms.uFogSun = { value: air.fogSun };
    shader.uniforms.uFogBase = { value: air.fog };
    shader.vertexShader = `
      varying vec3 vSurfWorld;
      varying float vSurfUp;
      ${crease ? 'attribute float ao;\nvarying float vCrease;' : ''}
      ${shader.vertexShader}
    `.replace(
      '#include <beginnormal_vertex>',
      `#include <beginnormal_vertex>
       vSurfUp = normalize(mat3(modelMatrix) * objectNormal).y;`,
    ).replace(
      '#include <project_vertex>',
      `#include <project_vertex>
       vSurfWorld = (modelMatrix * vec4(transformed, 1.0)).xyz;
       ${crease ? 'vCrease = ao;' : ''}`,
    );
    const detail = lite ? '' : `
      float hash12(vec2 p) {
        return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
      }
      float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        float a = hash12(i);
        float b = hash12(i + vec2(1.0, 0.0));
        float c = hash12(i + vec2(0.0, 1.0));
        float d = hash12(i + vec2(1.0, 1.0));
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
      }
    `;
    const colorChunk = lite
      ? `#include <color_fragment>
       float slope = smoothstep(0.8, 0.25, vSurfUp);
       diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(0.82, 0.8, 0.76), slope * 0.35);
       float hemi = mix(0.58, 1.0, clamp(vSurfUp * 0.5 + 0.5, 0.0, 1.0));
       ${crease ? 'diffuseColor.rgb *= mix(0.64, 1.0, vCrease) * hemi;' : 'diffuseColor.rgb *= hemi;'}`
      : `#include <color_fragment>
       float macro = vnoise(vSurfWorld.xz * 0.085);
       float grain = vnoise(vSurfWorld.xz * 1.65);
       float slope = smoothstep(0.8, 0.25, vSurfUp);
       diffuseColor.rgb *= 0.7 + macro * 0.32;
       diffuseColor.rgb *= 0.94 + grain * 0.1;
       diffuseColor.rgb = mix(diffuseColor.rgb, diffuseColor.rgb * vec3(0.8, 0.78, 0.74), slope * 0.48);
       float hemi = mix(0.55, 1.0, clamp(vSurfUp * 0.5 + 0.5, 0.0, 1.0));
       ${crease ? 'diffuseColor.rgb *= mix(0.62, 1.0, vCrease) * hemi;' : 'diffuseColor.rgb *= hemi;'}`;
    const roughChunk = lite
      ? '#include <roughnessmap_fragment>'
      : `#include <roughnessmap_fragment>
       float roughN = vnoise(vSurfWorld.xz * 0.12);
       float slopeR = smoothstep(0.8, 0.25, vSurfUp);
       roughnessFactor = clamp(roughnessFactor * (0.82 + (1.0 - roughN) * 0.32 + slopeR * 0.08), 0.32, 1.0);`;
    const normalChunk = lite
      ? '#include <normal_fragment_begin>'
      : `#include <normal_fragment_begin>
       float bh = vnoise(vSurfWorld.xz * 0.46);
       bh = mix(bh, vnoise(vSurfWorld.xy * 0.52 + vSurfWorld.zy * 0.38), smoothstep(0.62, 0.18, vSurfUp));
       normal = normalize(normal - vec3(dFdx(bh), dFdy(bh), 0.0) * 2.6);`;
    shader.fragmentShader = `
      varying vec3 vSurfWorld;
      varying float vSurfUp;
      ${crease ? 'varying float vCrease;' : ''}
      uniform vec3 uSunDir;
      uniform vec3 uFogSun;
      uniform vec3 uFogBase;
      ${detail}
      ${shader.fragmentShader}
    `.replace('#include <color_fragment>', colorChunk)
      .replace('#include <roughnessmap_fragment>', roughChunk)
      .replace('#include <normal_fragment_begin>', normalChunk)
      .replace('#include <fog_fragment>', FOG_CHUNK);
  };
  const key = `${crease ? 'ao' : 'plain'}-${lite ? 'lite' : 'full'}`;
  material.customProgramCacheKey = () => `ground-${key}`;
  material.needsUpdate = true;
  return material;
}
