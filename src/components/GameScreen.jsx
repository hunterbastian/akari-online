import { useMemo, useState, useRef } from 'react';
import { SYSTEMS, getConnections, COMMODITIES } from '../../shared/galaxy.js';
import { SHIPS, MANUFACTURERS, RARITY_COLORS, getCargoCapacity, getCargoUsed } from '../../shared/ships.js';
import { jumpTo, buyCommodity, sellCommodity, buyShip, sendChat, getCurrentSystem, getAvailableShips, getSystemMarket } from '../store';
import { generateSystem } from '../../shared/universe.js';
import GalaxyView from './GalaxyView';
import FlightView from './FlightView';

export default function GameScreen({ state }) {
  const [viewMode, setViewMode] = useState('map');
  const { player, chatMessages } = state;
  const currentSystem = getCurrentSystem();
  const shipData = SHIPS[player.ship];
  const market = getSystemMarket();
  const availableShips = getAvailableShips();
  const connections = getConnections(player.system_id);
  const capacity = getCargoCapacity(player.ship);
  const used = getCargoUsed(player.cargo);
  const chart = useMemo(
    () => (currentSystem ? generateSystem(currentSystem) : null),
    [currentSystem],
  );

  if (viewMode === 'flight') {
    return <FlightView player={player} onExit={() => setViewMode('map')} />;
  }

  return (
    <div className="game-screen">
      <div className="top-bar">
        <div className="logo">Akari</div>
        <div className="player-info">
          <div><span>Pilot</span> <strong>{player.name}</strong></div>
          <div><span>Credits</span> <strong className="credits">&cent;{player.credits.toLocaleString()}</strong></div>
          <div><span>System</span> <strong>{currentSystem.name}</strong></div>
          <div><span>Ship</span> <strong>{shipData?.name || player.ship}</strong></div>
        </div>
      </div>

      <div className="panel">
        <div className="panel-title">System</div>
        <SystemInfo system={currentSystem} />

        <button className="launch-btn" onClick={() => setViewMode('flight')}>Undock</button>
        <p className="hint">
          Mouse steers. W flies, S brakes, Shift boosts. Tab selects a target, R pulses.
          Fly into a world to land, V steps outside, Space climbs back to orbit.
          C scans, E collects, L opens the log, F docks.
        </p>

        <div className="panel-title">Planets</div>
        {(chart?.planets || []).map(planet => {
          const known = player.discoveries?.[planet.id];
          return (
            <div key={planet.id} className="planet-row">
              <span>{planet.name}</span>
              <span>{known ? known.biome : '—'}</span>
            </div>
          );
        })}

        <div className="panel-title">Jump lanes</div>
        {connections.map(id => {
          const sys = SYSTEMS.find(s => s.id === id);
          return (
            <button key={id} className="system-btn" onClick={() => jumpTo(id)}>
              <div className="sys-name" style={{ color: sys.color }}>{sys.name}</div>
              <div className="sys-type">{sys.type}</div>
            </button>
          );
        })}
      </div>

      <div className="viewport">
        <GalaxyView player={player} currentSystem={currentSystem} />
      </div>

      <div className="panel right">
        <div className="panel-title">Market</div>
        {COMMODITIES.map(c => {
          const row = market[c.id];
          if (!row) return null;
          return (
            <div key={c.id} className="market-row">
              <div>
                <div className="commodity-name">{c.name}</div>
                <div className="supply">Supply {row.supply}</div>
              </div>
              <div className="price">&cent;{Math.round(row.price)}</div>
              <div className="trade-btns">
                <button className="trade-btn buy" onClick={() => buyCommodity(c.id)}>Buy</button>
                <button className="trade-btn sell" onClick={() => sellCommodity(c.id)}>Sell</button>
              </div>
            </div>
          );
        })}

        <div className="panel-title">Cargo</div>
        <CargoSection cargo={player.cargo} capacity={capacity} used={used} />

        <div className="panel-title">Ships</div>
        <ShipDealer ships={availableShips} currentShip={player.ship} />
      </div>

      <ChatBar messages={chatMessages} />
    </div>
  );
}

function SystemInfo({ system }) {
  return (
    <div className="system-info">
      <div className="system-name" style={{ color: system.color }}>{system.name}</div>
      <div className="system-type">{system.type}</div>
      <div className="system-desc">{system.description}</div>
      <div className="system-meta">{system.stations.join(' · ')}</div>
    </div>
  );
}

function CargoSection({ cargo, capacity, used }) {
  const pct = Math.min(100, (used / capacity) * 100);
  const entries = Object.entries(cargo).filter(([, q]) => q > 0);

  return (
    <div>
      <div className="cargo-head">
        <span>Capacity</span>
        <span>{used} / {capacity}</span>
      </div>
      <div className="cargo-bar">
        <div className="cargo-bar-fill" style={{ width: `${pct}%` }} />
      </div>
      {entries.length === 0
        ? <div className="dim">Empty</div>
        : entries.map(([id, qty]) => {
            const c = COMMODITIES.find(item => item.id === id);
            return (
              <div key={id} className="cargo-row">
                <span>{c?.name || id}</span>
                <span className="qty">x{qty}</span>
              </div>
            );
          })
      }
    </div>
  );
}

function ShipDealer({ ships, currentShip }) {
  if (ships.length === 0) return <div className="dim">No ships for sale</div>;

  const maxCargo = 200, maxHull = 300, maxFirepower = 60;
  const oldShip = SHIPS[currentShip];
  const tradeIn = oldShip ? Math.floor(oldShip.price * 0.5) : 0;

  return ships.map(ship => {
    const isEquipped = currentShip === ship.id;
    const mfr = MANUFACTURERS[ship.manufacturer];
    const rarityColor = RARITY_COLORS[ship.rarity] || '#9a9a9a';
    const finalCost = ship.price - tradeIn;

    const stats = [
      { label: 'Cargo', value: ship.stats.cargo, max: maxCargo },
      { label: 'Speed', value: Math.round((1 / ship.stats.speed) * 50), max: 100 },
      { label: 'Hull', value: ship.stats.hull, max: maxHull },
      { label: 'Power', value: ship.stats.firepower, max: maxFirepower },
    ];

    return (
      <div key={ship.id} className={`ship-card${isEquipped ? ' equipped' : ''}`}>
        <div className="ship-header">
          <div className="ship-name" style={{ color: mfr.color }}>{ship.name}</div>
          <div className="ship-rarity" style={{ color: rarityColor, borderColor: rarityColor }}>{ship.rarity}</div>
        </div>
        <div className="ship-manufacturer">{mfr.name}</div>
        <div className="ship-desc">{ship.description}</div>

        {stats.map(s => (
          <div key={s.label} className="stat-bar-row">
            <div className="stat-label">{s.label}</div>
            <div className="stat-bar">
              <div className="stat-bar-fill" style={{ width: `${Math.min(100, (s.value / s.max) * 100)}%` }} />
            </div>
            <div className="stat-value">{s.value}</div>
          </div>
        ))}

        <div className="ship-footer">
          {isEquipped ? (
            <>
              <div className="ship-price">Equipped</div>
              <button className="buy-ship-btn equipped-label" type="button">Current</button>
            </>
          ) : (
            <>
              <div className="ship-price">
                &cent;{finalCost.toLocaleString()}
                {tradeIn > 0 && <div className="trade-in">Includes &cent;{tradeIn.toLocaleString()} trade-in</div>}
              </div>
              <button className="buy-ship-btn" type="button" onClick={() => buyShip(ship.id)}>Buy</button>
            </>
          )}
        </div>
      </div>
    );
  });
}

function ChatBar({ messages }) {
  const [input, setInput] = useState('');
  const logRef = useRef(null);

  const handleSend = () => {
    if (input.trim()) {
      sendChat(input.trim());
      setInput('');
    }
  };

  return (
    <div className="bottom-bar">
      <div className="chat-log" ref={logRef}>
        {messages.map((m, i) => (
          <div key={i} className="msg">
            <span className="sender">{m.name}</span> {m.text}
          </div>
        ))}
      </div>
      <input
        className="chat-input"
        type="text"
        placeholder="Chat"
        maxLength={200}
        value={input}
        onChange={e => setInput(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && handleSend()}
      />
    </div>
  );
}
