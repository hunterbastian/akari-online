// Seeded star-system contents. The eight named systems and their markets stay
// hand-authored; everything inside a system is derived from its id.

const SYLLABLES = ['ae', 'ka', 'vel', 'no', 'sy', 'ir', 'um', 'or', 'lu', 'dra', 'xe', 'mi', 'sol', 'qua', 'rin', 'va', 'el', 'na', 'os', 'the'];

// Four ground colors, low to high, plus the rim that wraps the planet from orbit.
export const BIOMES = [
  { id: 'lush', label: 'Lush', relief: 0.05, colors: ['#3d7a4e', '#8aaa58', '#d4c47a', '#f6ead0'], atmosphere: '#f0d2a4', ring: '#e4c98a', moon: '#f6ead4', resources: ['food', 'medicine'] },
  { id: 'ocean', label: 'Ocean', relief: 0.03, colors: ['#1e6a88', '#3eb0c4', '#c8eee4', '#f6d0b4'], atmosphere: '#f0a888', ring: '#f2d0b6', moon: '#f7e6d6', resources: ['food', 'medicine'] },
  { id: 'desert', label: 'Desert', relief: 0.042, colors: ['#c45a38', '#e08848', '#f2c98a', '#f8e6c8'], atmosphere: '#2f8f8a', ring: '#e8b48a', moon: '#f4e0c8', resources: ['ore', 'fuel'] },
  { id: 'ice', label: 'Ice', relief: 0.036, colors: ['#7ecfe2', '#c5eef4', '#f2fafa', '#f6e0d4'], atmosphere: '#f0b5a4', ring: '#f6d8cc', moon: '#f8eee8', resources: ['ore', 'medicine'] },
  { id: 'volcanic', label: 'Volcanic', relief: 0.058, colors: ['#5c2a22', '#c45a38', '#ee7840', '#f6c4a0'], atmosphere: '#e08868', ring: '#f0a878', moon: '#ead2c2', resources: ['ore', 'scrap'] },
  { id: 'anomalous', label: 'Anomalous', relief: 0.048, colors: ['#5a3488', '#c070c8', '#f0c0dc', '#f8e6d4'], atmosphere: '#e6b48a', ring: '#e8c8a8', moon: '#f4dce8', resources: ['luxuries', 'scrap'] },
];

const LUMINOUS = ['lush', 'ocean', 'desert', 'ice', 'anomalous'];

const SKIES = {
  hub:        { top: '#1a1028', mid: '#e06a5c', bottom: '#f2c394', star: '#ffe1bf' },
  industrial: { top: '#1a0e0c', mid: '#e25a32', bottom: '#f0b06a', star: '#ffd0a4' },
  trade:      { top: '#071820', mid: '#2a8f86', bottom: '#d7c4a2', star: '#fff0d2' },
  frontier:   { top: '#160a18', mid: '#b45ea8', bottom: '#f0b7c4', star: '#ffe4f2' },
  military:   { top: '#0e1612', mid: '#3e8f68', bottom: '#d5e2c4', star: '#e7f2dc' },
  unknown:    { top: '#10141f', mid: '#6d78c4', bottom: '#d5d3ef', star: '#e4e7ff' },
};

const SHORT_RESOURCES = {
  fuel: 'Fuel',
  ore: 'Ore',
  electronics: 'Electronics',
  weapons: 'Weapons',
  food: 'Food',
  medicine: 'Medicine',
  luxuries: 'Luxuries',
  scrap: 'Scrap',
};

export function hashString(str) {
  let h = 2166136261;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

export function mulberry32(seed) {
  let a = seed >>> 0;
  return function rng() {
    a |= 0;
    a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function resourceLabel(id) {
  return SHORT_RESOURCES[id] || id;
}

export function flightProfile(speedStat = 1) {
  const agility = Math.min(2.4, 1 / (speedStat || 1));
  const cruise = 30 * (0.85 + 0.28 * agility);
  return {
    cruise,
    boost: cruise * 2.05,
    pulse: 120 * (0.92 + 0.2 * agility),
  };
}

function biomeById(id) {
  return BIOMES.find(b => b.id === id) || BIOMES[0];
}

function pickName(rng, used) {
  let name = 'World';
  for (let attempt = 0; attempt < 8; attempt++) {
    const parts = 2 + (rng() > 0.82 ? 1 : 0);
    let word = '';
    for (let i = 0; i < parts; i++) word += SYLLABLES[Math.floor(rng() * SYLLABLES.length)];
    name = word.charAt(0).toUpperCase() + word.slice(1);
    if (!used.has(name)) break;
  }
  used.add(name);
  return name;
}

function makeBelt(seed) {
  const rng = mulberry32(seed ^ 0xBEE5);
  if (rng() < 0.4) return [];
  const count = 16;
  const rocks = [];
  for (let i = 0; i < count; i++) {
    const angle = (i / count) * Math.PI * 2 + rng() * 0.18;
    const radius = 188 + rng() * 28;
    rocks.push({
      position: [Math.cos(angle) * radius, (rng() - 0.5) * 8, Math.sin(angle) * radius],
      rotation: [rng() * Math.PI, rng() * Math.PI, 0],
      scale: 0.35 + rng() * 0.85,
    });
  }
  return rocks;
}

export function generateSystem(system) {
  const rng = mulberry32(hashString(system.id));
  const sky = SKIES[system.type] || SKIES.unknown;
  const count = 3 + Math.floor(rng() * 2);
  const usedNames = new Set();
  const usedBiomes = new Set();
  const planets = [];
  const deposits = [];

  for (let i = 0; i < count; i++) {
    const pool = BIOMES.filter(b => !usedBiomes.has(b.id) && (i > 0 || LUMINOUS.includes(b.id)));
    const choices = pool.length ? pool : BIOMES;
    const biome = choices[Math.floor(rng() * choices.length)];
    usedBiomes.add(biome.id);

    const angle = -Math.PI / 2 + 0.42 + (i / count) * Math.PI * 2 + (rng() - 0.5) * 0.12;
    const dist = 190 + i * 250 + rng() * 20;
    const position = [
      Math.cos(angle) * dist,
      (rng() - 0.5) * dist * 0.05,
      Math.sin(angle) * dist,
    ];
    const radius = 24 + rng() * 10;
    const id = `${system.id}:${i}`;
    const resources = biome.resources.slice();
    const rings = rng() > 0.64;

    planets.push({
      id,
      name: pickName(rng, usedNames),
      biome: biome.id,
      biomeLabel: biome.label,
      relief: biome.relief,
      position,
      radius,
      colors: biome.colors,
      atmosphere: biome.atmosphere,
      ring: biome.ring,
      moon: biome.moon,
      rings,
      ringTilt: [0.35 + rng() * 0.45, rng() * Math.PI, (rng() - 0.5) * 0.35],
      seed: (hashString(id) % 997) / 97,
      resources,
    });

    const len = Math.hypot(position[0], position[1], position[2]) || 1;
    const nx = position[0] / len;
    const ny = position[1] / len;
    const nz = position[2] / len;
    const tx = -nz;
    const tz = nx;

    resources.forEach((commodityId, d) => {
      const lateral = (d === 0 ? -0.55 : 0.7) * radius * (0.65 + rng() * 0.35);
      const hover = radius + 9 + rng() * 8;
      deposits.push({
        id: `${id}:${commodityId}`,
        planetId: id,
        commodityId,
        amount: 2 + Math.floor(rng() * 2),
        position: [
          position[0] - nx * hover + tx * lateral,
          position[1] - ny * hover + (rng() - 0.5) * 3,
          position[2] - nz * hover + tz * lateral,
        ],
      });
    });
  }

  return {
    id: system.id,
    name: system.name,
    sky,
    spawn: [0, 6, 48],
    station: {
      name: system.stations[0] || 'Station',
      position: [32, -1, 102],
    },
    planets,
    deposits,
    belt: makeBelt(hashString(system.id)),
  };
}

export function describePlanet(planet) {
  const labels = planet.resources.map(resourceLabel);
  return `${planet.biomeLabel} · ${labels.join(', ')}`;
}
