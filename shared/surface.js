// Terrain shared by the surface mesh and the flight collision.
// Kept free of three.js so a landing spot and the ground under it match.

import { hashString, mulberry32 } from './universe.js';

const SKIES = {
  lush:      { top: '#163528', mid: '#7eae86', bottom: '#d7e7c4', fog: '#a9cbb0', waterLevel: -1.5, water: '#2f7f86', waterOpacity: 0.72 },
  ocean:     { top: '#143044', mid: '#6eb0d0', bottom: '#d5efe8', fog: '#9ec8d8', waterLevel: 1.7, water: '#1a5674', waterOpacity: 0.8 },
  desert:    { top: '#a8643c', mid: '#e6b15c', bottom: '#f4e3c4', fog: '#e4c49a', waterLevel: null, water: '#e6b15c', waterOpacity: 0 },
  ice:       { top: '#2c5f86', mid: '#b7dff3', bottom: '#f4fbff', fog: '#d4eef8', waterLevel: -3.1, water: '#d5eef6', waterOpacity: 0.58 },
  volcanic:  { top: '#24120f', mid: '#8d4034', bottom: '#e07a48', fog: '#c48468', waterLevel: null, water: '#e07a48', waterOpacity: 0 },
  anomalous: { top: '#241433', mid: '#8d62b0', bottom: '#f0d2f4', fog: '#c9b0d4', waterLevel: -3.6, water: '#5b3e78', waterOpacity: 0.62 },
};

const SCATTER = {
  lush: ['tree', 'tree', 'flora', 'flora', 'rock_a', 'rock_b'],
  ocean: ['rock_a', 'flora', 'rock_b', 'crystal'],
  desert: ['spire', 'rock_b', 'rock_a', 'rock_a'],
  ice: ['shard', 'rock_a', 'crystal', 'rock_b'],
  volcanic: ['rock_b', 'spire', 'rock_a', 'crystal'],
  anomalous: ['crystal', 'flora', 'rock_b', 'spire'],
};

const KIND_SCALE = {
  tree: 1.7,
  flora: 1.15,
  rock_a: 1.35,
  rock_b: 1.05,
  crystal: 1.25,
  shard: 1.4,
  spire: 1.35,
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

export function heightAt(x, z, planet) {
  const seed = hashString(planet.id);
  const amp = 8 + (planet.relief || 0.06) * 90;
  let h = 0;
  let freq = 0.016;
  let weight = 1;
  let sum = 0;
  for (let octave = 0; octave < 4; octave += 1) {
    h += valueNoise(x * freq, z * freq, (seed + octave * 97) >>> 0) * weight;
    sum += weight;
    freq *= 2.08;
    weight *= 0.48;
  }
  return (h / sum - 0.46) * amp * 2;
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

  for (let i = 0; i < 36; i += 1) {
    const radius = 16 + rng() * 168;
    const angle = rng() * Math.PI * 2;
    const spot = drySpot(Math.cos(angle) * radius, Math.sin(angle) * radius, planet);
    const kind = kinds[Math.floor(rng() * kinds.length)];
    props.push({
      kind,
      position: [spot.x, spot.y, spot.z],
      rotation: [0, rng() * Math.PI * 2, 0],
      scale: (KIND_SCALE[kind] || 1) * (0.78 + rng() * 0.55),
    });
  }

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
      scale: 1.5,
    },
  };
  layouts.set(planet.id, layout);
  return layout;
}
