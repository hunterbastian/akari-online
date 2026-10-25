// Terrain shared by the surface mesh and the flight collision.
// Kept free of three.js so a landing spot and the ground under it match.

import { hashString, mulberry32 } from './universe.js';

const SKIES = {
  lush:      { top: '#24344c', mid: '#e8c49a', bottom: '#f7ead2', fog: '#e4c29a', waterLevel: -4.5, water: '#2a7a72', waterOpacity: 0.8, sun: '#ffe1b8', moon: '#f6ead6' },
  ocean:     { top: '#1a2044', mid: '#e08a66', bottom: '#f6d4b6', fog: '#e4b298', waterLevel: 1.4, water: '#186888', waterOpacity: 0.84, sun: '#ffd2aa', moon: '#f7e6d6' },
  desert:    { top: '#0d3a42', mid: '#2c8c86', bottom: '#efd2a4', fog: '#d08458', waterLevel: null, water: '#2c8c86', waterOpacity: 0, sun: '#ffe6c6', moon: '#f4e2ca' },
  ice:       { top: '#3a2458', mid: '#e8a08c', bottom: '#f7dcc8', fog: '#e4c2bc', waterLevel: -8.5, water: '#5ec4d4', waterOpacity: 0.72, sun: '#ffd4b6', moon: '#f8eee8' },
  volcanic:  { top: '#1a1024', mid: '#a44440', bottom: '#e88860', fog: '#c45440', waterLevel: null, water: '#e07040', waterOpacity: 0, sun: '#ffb088', moon: '#ead4c4' },
  anomalous: { top: '#1c1438', mid: '#e6b48a', bottom: '#f4d4c6', fog: '#c48cb4', waterLevel: -8, water: '#5a3878', waterOpacity: 0.72, sun: '#ffd8b0', moon: '#f4dce8' },
};

const SCATTER = {
  lush: ['tree', 'tree', 'flora', 'rock_a'],
  ocean: ['rock_a', 'flora', 'crystal', 'rock_b'],
  desert: ['spire', 'rock_a', 'rock_b', 'arch'],
  ice: ['shard', 'crystal', 'rock_a', 'arch'],
  volcanic: ['rock_b', 'spire', 'arch', 'crystal'],
  anomalous: ['crystal', 'flora', 'spire', 'arch'],
};

const HERO = {
  lush: 'tree',
  ocean: 'crystal',
  desert: 'arch',
  ice: 'arch',
  volcanic: 'spire',
  anomalous: 'crystal',
};

const KIND_SCALE = {
  tree: 2.15,
  flora: 1.45,
  rock_a: 1.7,
  rock_b: 1.35,
  crystal: 1.85,
  shard: 2.05,
  spire: 1.9,
  arch: 1.55,
};

const layouts = new Map();

export function surfaceSky(planet) {
  return SKIES[planet.biome] || SKIES.lush;
}

export function waterLevel(planet) {
  const sky = surfaceSky(planet);
  return sky.waterLevel == null ? null : sky.waterLevel;
}

function hash2(ix, iz, seed) {
  let h = (Math.imul(ix, 374761393) ^ Math.imul(iz, 668265263) ^ seed) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
}

function fade(t) {
  return t * t * (3 - 2 * t);
}

function valueNoise(x, z, seed) {
  const x0 = Math.floor(x);
  const z0 = Math.floor(z);
  const tx = fade(x - x0);
  const tz = fade(z - z0);
  const v00 = hash2(x0, z0, seed);
  const v10 = hash2(x0 + 1, z0, seed);
  const v01 = hash2(x0, z0 + 1, seed);
  const v11 = hash2(x0 + 1, z0 + 1, seed);
  const a = v00 + (v10 - v00) * tx;
  const b = v01 + (v11 - v01) * tx;
  return a + (b - a) * tz;
}

function fbm(x, z, seed) {
  let h = 0;
  let freq = 1;
  let weight = 1;
  let sum = 0;
  for (let octave = 0; octave < 4; octave += 1) {
    h += valueNoise(x * freq, z * freq, (seed + octave * 97) >>> 0) * weight;
    sum += weight;
    freq *= 2.04;
    weight *= 0.5;
  }
  return h / sum;
}

function ridged(x, z, seed) {
  return 1 - Math.abs(fbm(x, z, seed) * 2 - 1);
}

function terrace(v, steps) {
  return Math.floor(v * steps) / steps;
}

export function heightAt(x, z, planet) {
  const seed = hashString(planet.id);
  const n = fbm(x * 0.009, z * 0.009, seed);
  if (planet.biome === 'desert') {
    const dune = Math.sin(x * 0.042 + n * 3.1) * Math.cos(z * 0.028 + n * 1.4);
    const mesa = terrace(fbm(x * 0.0065, z * 0.0065, seed + 11), 4);
    return dune * 3.4 + (mesa - 0.32) * 30;
  }
  if (planet.biome === 'ice') {
    const hills = (n - 0.5) * 34;
    const ridge = ridged(x * 0.011, z * 0.011, seed + 5);
    return hills + Math.pow(ridge, 1.35) * 24;
  }
  if (planet.biome === 'ocean') {
    const island = Math.max(0, fbm(x * 0.007, z * 0.007, seed + 3) - 0.52);
    return (n - 0.64) * 12 + island * 24;
  }
  if (planet.biome === 'volcanic') {
    const mesa = terrace(fbm(x * 0.008, z * 0.008, seed + 7), 5);
    const ridge = ridged(x * 0.02, z * 0.02, seed + 13);
    return (mesa - 0.28) * 28 + ridge * ridge * ridge * 10;
  }
  if (planet.biome === 'anomalous') {
    const bowl = Math.sin(x * 0.018) * Math.cos(z * 0.018);
    return (n - 0.5) * 20 + bowl * 9 + ridged(x * 0.014, z * 0.014, seed + 2) * 7;
  }
  const hills = (n - 0.46) * 22;
  const soft = Math.sin(x * 0.028 + n * 2) * Math.cos(z * 0.022) * 3.2;
  return hills + soft;
}

export function floorAt(x, z, planet) {
  const ground = heightAt(x, z, planet);
  const water = waterLevel(planet);
  if (water == null) return ground;
  return Math.max(ground, water);
}

function drySpot(x, z, planet) {
  const water = waterLevel(planet);
  let px = x;
  let pz = z;
  for (let i = 0; i < 7; i += 1) {
    const y = heightAt(px, pz, planet);
    if (water == null || y > water + 0.3) return { x: px, y, z: pz };
    px += 7;
    pz += 5;
  }
  const y = water == null ? heightAt(x, z, planet) : Math.max(heightAt(x, z, planet), water);
  return { x, y, z };
}

export function surfaceLayout(planet) {
  const cached = layouts.get(planet.id);
  if (cached) return cached;

  const rng = mulberry32(hashString(`${planet.id}:ground`));
  const kinds = SCATTER[planet.biome] || SCATTER.lush;
  const props = [];
  const clusters = 7;

  for (let c = 0; c < clusters; c += 1) {
    const angle = rng() * Math.PI * 2;
    const radius = 28 + rng() * 150;
    const cx = Math.cos(angle) * radius;
    const cz = Math.sin(angle) * radius;
    const count = 4 + Math.floor(rng() * 3);
    for (let k = 0; k < count; k += 1) {
      const x = cx + (rng() - 0.5) * 14;
      const z = cz + (rng() - 0.5) * 14;
      if (Math.hypot(x, z) < 20) continue;
      const spot = drySpot(x, z, planet);
      const kind = kinds[Math.floor(rng() * kinds.length)];
      props.push({
        kind,
        position: [spot.x, spot.y, spot.z],
        rotation: [0, rng() * Math.PI * 2, 0],
        scale: (KIND_SCALE[kind] || 1) * (0.85 + rng() * 0.55),
      });
    }
    if (Math.hypot(cx, cz) < 26) continue;
    const heroKind = HERO[planet.biome] || 'spire';
    const hero = drySpot(cx, cz, planet);
    props.push({
      kind: heroKind,
      position: [hero.x, hero.y, hero.z],
      rotation: [0, rng() * Math.PI * 2, 0],
      scale: (KIND_SCALE[heroKind] || 1) * (2.4 + rng() * 1.1),
    });
  }

  const vista = drySpot(16, -46, planet);
  for (let k = 0; k < 5; k += 1) {
    const x = vista.x + (rng() - 0.5) * 12;
    const z = vista.z + (rng() - 0.5) * 12;
    if (Math.hypot(x, z) < 16) continue;
    const spot = drySpot(x, z, planet);
    const kind = kinds[k % kinds.length];
    props.push({
      kind,
      position: [spot.x, spot.y, spot.z],
      rotation: [0, rng() * Math.PI * 2, 0],
      scale: (KIND_SCALE[kind] || 1) * (1.15 + rng() * 0.45),
    });
  }
  const landmark = drySpot(28, -62, planet);
  const landmarkKind = HERO[planet.biome] || 'spire';
  props.push({
    kind: landmarkKind,
    position: [landmark.x, landmark.y, landmark.z],
    rotation: [0, 0.4, 0],
    scale: (KIND_SCALE[landmarkKind] || 1) * 3.4,
  });

  const deposits = (planet.resources || []).map((commodityId, index) => {
    const spot = drySpot(-12 + index * 18, -24, planet);
    return {
      id: `${planet.id}:${commodityId}`,
      planetId: planet.id,
      commodityId,
      amount: 2,
      position: [spot.x, spot.y, spot.z],
    };
  });

  const monolithSpot = drySpot(26, -52, planet);
  const layout = {
    props,
    deposits,
    monolith: {
      position: [monolithSpot.x, monolithSpot.y, monolithSpot.z],
      rotation: [0, 0.45, 0],
      scale: 2.35,
    },
  };
  layouts.set(planet.id, layout);
  return layout;
}
