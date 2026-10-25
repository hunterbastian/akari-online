export default function FlightHUD({ hud, onExit, onLog }) {
  return (
    <div className="flight-hud">
      <button type="button" className="hud-text-btn hud-log-btn" onClick={onLog}>Log</button>
      <button type="button" className="hud-text-btn" onClick={onExit}>Map</button>
      <div className="hud-top">{hud.systemName}</div>
      {hud.targetName && (
        <div className="hud-target">
          {hud.targetName}
          {hud.targetDist && <span>{hud.targetDist}</span>}
        </div>
      )}
      {!hud.locked && !hud.touch && <div className="hud-lock">{hud.onFoot ? 'Click to look' : 'Click to fly'}</div>}
      <div className="hud-reticle" />
      <div className="hud-bottom">
        {(hud.prompt || hud.note) && <div className="hud-note">{hud.prompt || hud.note}</div>}
        <div className="hud-speed">
          {hud.speed}
          <span>u/s</span>
        </div>
        {hud.pulse && <div className="hud-pulse">Pulse</div>}
      </div>
    </div>
  );
}
