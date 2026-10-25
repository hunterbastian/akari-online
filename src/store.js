// Simple reactive game store (no external deps)
// Will be replaced with server sync for MMO mode

import { SYSTEMS, COMMODITIES, getConnections } from '../shared/galaxy.js';
import { SHIPS, SHIP_DEALERS, getCargoCapacity, getCargoUsed } from '../shared/ships.js';

const SAVE_KEY = 'space-online-save';
let listeners = new Set();

// ── State ─────────────────────────────────────

let state = {
  screen: 'login', // 'login' | 'game'
  player: null,
  marketPrices: {},
  toasts: [],
  chatMessages: [],
};

export function getState() { return state; }

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

function emit() {
  for (const fn of listeners) fn(state);
}

function setState(partial) {
  state = { ...state, ...partial };
  emit();
}

// ── Toast ─────────────────────────────────────

let toastId = 0;
export function showToast(text, isError = false) {
  const id = ++toastId;
  setState({ toasts: [...state.toasts, { id, text, isError }] });
  setTimeout(() => {
    setState({ toasts: state.toasts.filter(t => t.id !== id) });
  }, 2500);
}

// ── Save / Load ───────────────────────────────

function saveGame() {
  localStorage.setItem(SAVE_KEY, JSON.stringify({
    player: state.player,
    marketPrices: state.marketPrices,
    version: 1,
  }));
}

function loadGame() {
  const raw = localStorage.getItem(SAVE_KEY);
  if (!raw) return null;
  try { return JSON.parse(raw); } catch { return null; }
}

// ── Market ────────────────────────────────────

function getSystemPriceModifier(systemType, commodityId) {
  const modifiers = {
    hub:        { fuel: 1.0, ore: 1.1, electronics: 0.9, weapons: 1.2, food: 0.9, medicine: 0.9, luxuries: 1.0, scrap: 1.1 },
    industrial: { fuel: 0.8, ore: 0.6, electronics: 1.2, weapons: 1.0, food: 1.1, medicine: 1.1, luxuries: 1.5, scrap: 0.7 },
    trade:      { fuel: 1.1, ore: 1.2, electronics: 0.8, weapons: 1.3, food: 0.8, medicine: 0.8, luxuries: 0.7, scrap: 1.2 },
    frontier:   { fuel: 1.3, ore: 0.9, electronics: 1.4, weapons: 0.6, food: 1.3, medicine: 1.3, luxuries: 1.8, scrap: 0.5 },
    military:   { fuel: 0.9, ore: 1.0, electronics: 1.0, weapons: 0.8, food: 1.0, medicine: 0.7, luxuries: 1.4, scrap: 1.0 },
    unknown:    { fuel: 1.5, ore: 0.7, electronics: 1.1, weapons: 1.1, food: 1.5, medicine: 1.5, luxuries: 0.5, scrap: 0.3 },
  };
  return (modifiers[systemType]?.[commodityId] ?? 1.0) * (0.85 + Math.random() * 0.3);
}

function generateAllMarkets() {
  const prices = {};
  for (const system of SYSTEMS) {
    prices[system.id] = {};
    for (const commodity of COMMODITIES) {
      const modifier = getSystemPriceModifier(system.type, commodity.id);
      prices[system.id][commodity.id] = {
        price: Math.round(commodity.basePrice * modifier),
        supply: Math.floor(50 + Math.random() * 100),
      };
    }
  }
  return prices;
}

// Price fluctuation
setInterval(() => {
  if (!state.player) return;
  const mp = { ...state.marketPrices };
  for (const systemId in mp) {
    mp[systemId] = { ...mp[systemId] };
    for (const commodityId in mp[systemId]) {
      const row = { ...mp[systemId][commodityId] };
      const commodity = COMMODITIES.find(c => c.id === commodityId);
      if (!commodity) continue;
      const change = 1 + (Math.random() - 0.5) * commodity.volatility * 0.1;
      row.price = Math.max(1, Math.round(row.price * change));
      row.supply = Math.max(0, row.supply + Math.floor((Math.random() - 0.45) * 5));
      mp[systemId][commodityId] = row;
    }
  }
  setState({ marketPrices: mp });
  saveGame();
}, 30000);

// ── Actions ───────────────────────────────────

export function login(name) {
  const save = loadGame();
  let player, marketPrices;

  if (save?.player) {
    player = {
      ...save.player,
      name,
      discoveries: save.player.discoveries || {},
      depleted: Array.isArray(save.player.depleted) ? save.player.depleted : [],
    };
    marketPrices = save.marketPrices || generateAllMarkets();
  } else {
    player = {
      id: crypto.randomUUID(),
      name,
      credits: 1000,
      system_id: 'sol',
      cargo: {},
      ship: 'starter',
      discoveries: {},
      depleted: [],
    };
    marketPrices = generateAllMarkets();
  }

  setState({ screen: 'game', player, marketPrices, chatMessages: [
    { name: 'SYSTEM', text: `Welcome, ${name}.` },
  ]});
  saveGame();
}

export function jumpTo(systemId) {
  const connections = getConnections(state.player.system_id);
  if (!connections.includes(systemId)) {
    showToast('No jump lane to that system.', true);
    return;
  }
  const sys = SYSTEMS.find(s => s.id === systemId);
  setState({ player: { ...state.player, system_id: systemId } });
  saveGame();
  showToast(`Jumped to ${sys.name}`);
}

export function buyCommodity(commodityId) {
  const player = state.player;
  const capacity = getCargoCapacity(player.ship);
  const used = getCargoUsed(player.cargo);
  if (used + 1 > capacity) {
    showToast(`Cargo full! ${used}/${capacity} units.`, true);
    return;
  }
  const row = state.marketPrices[player.system_id]?.[commodityId];
  if (!row || row.supply < 1) { showToast('Not enough supply.', true); return; }
  if (player.credits < row.price) { showToast('Not enough credits.', true); return; }

  const newCargo = { ...player.cargo, [commodityId]: (player.cargo[commodityId] || 0) + 1 };
  const newMarket = { ...state.marketPrices, [player.system_id]: {
    ...state.marketPrices[player.system_id],
    [commodityId]: { ...row, supply: row.supply - 1 },
  }};

  setState({
    player: { ...player, credits: player.credits - row.price, cargo: newCargo },
    marketPrices: newMarket,
  });
  saveGame();
  showToast('Purchase complete');
}

export function sellCommodity(commodityId) {
  const player = state.player;
  if (!player.cargo[commodityId] || player.cargo[commodityId] < 1) {
    showToast('Nothing to sell.', true);
    return;
  }
  const row = state.marketPrices[player.system_id]?.[commodityId];
  if (!row) return;

  const newCargo = { ...player.cargo };
  newCargo[commodityId] -= 1;
  if (newCargo[commodityId] <= 0) delete newCargo[commodityId];

  const newMarket = { ...state.marketPrices, [player.system_id]: {
    ...state.marketPrices[player.system_id],
    [commodityId]: { ...row, supply: row.supply + 1 },
  }};

  setState({
    player: { ...player, credits: player.credits + row.price, cargo: newCargo },
    marketPrices: newMarket,
  });
  saveGame();
  showToast('Sale complete');
}

export function buyShip(shipId) {
  const player = state.player;
  const ship = SHIPS[shipId];
  if (!ship) return;

  const sys = SYSTEMS.find(s => s.id === player.system_id);
  if (!(SHIP_DEALERS[sys.type] || []).includes(shipId)) {
    showToast('Not sold here.', true); return;
  }
  if (player.ship === shipId) { showToast('Already your ship.', true); return; }

  const oldShip = SHIPS[player.ship];
  const tradeIn = oldShip ? Math.floor(oldShip.price * 0.5) : 0;
  const cost = ship.price - tradeIn;
  if (player.credits < cost) { showToast(`Need \u00A2${cost.toLocaleString()}`, true); return; }

  const cargo = getCargoUsed(player.cargo);
  if (cargo > ship.stats.cargo) {
    showToast(`Cargo won't fit! Sell ${cargo - ship.stats.cargo} units.`, true); return;
  }

  setState({ player: { ...player, credits: player.credits - cost, ship: shipId } });
  saveGame();
  showToast(`New ship: ${ship.name}!`);
}

export function surveyPlanet(planet) {
  const player = state.player;
  if (!player || !planet?.id) return;
  if (player.discoveries?.[planet.id]) return;
  setState({
    player: {
      ...player,
      discoveries: {
        ...(player.discoveries || {}),
        [planet.id]: {
          name: planet.name,
          biome: planet.biomeLabel,
          systemId: player.system_id,
        },
      },
    },
  });
  saveGame();
}

export function collectDeposit(deposit) {
  const player = state.player;
  if (!player || !deposit) return null;
  const depleted = player.depleted || [];
  if (depleted.includes(deposit.id)) return null;

  const capacity = getCargoCapacity(player.ship);
  const used = getCargoUsed(player.cargo);
  const amount = deposit.amount || 1;
  if (used + amount > capacity) {
    showToast('Cargo full');
    return null;
  }

  const commodity = COMMODITIES.find(c => c.id === deposit.commodityId);
  setState({
    player: {
      ...player,
      cargo: {
        ...player.cargo,
        [deposit.commodityId]: (player.cargo[deposit.commodityId] || 0) + amount,
      },
      depleted: [...depleted, deposit.id],
    },
  });
  saveGame();
  return { name: commodity?.name || 'Resource', amount };
}

export function sendChat(text) {
  if (!text || !state.player) return;
  setState({ chatMessages: [
    ...state.chatMessages.slice(-49),
    { name: state.player.name, text },
  ]});
}

// ── Selectors ─────────────────────────────────

export function getCurrentSystem() {
  if (!state.player) return null;
  return SYSTEMS.find(s => s.id === state.player.system_id);
}

export function getAvailableShips() {
  if (!state.player) return [];
  const sys = getCurrentSystem();
  return (SHIP_DEALERS[sys.type] || []).map(id => SHIPS[id]).filter(Boolean);
}

export function getSystemMarket() {
  if (!state.player) return [];
  return state.marketPrices[state.player.system_id] || {};
}
