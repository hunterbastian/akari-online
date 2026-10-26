import { useEffect, useState } from 'react';

function Fade({ text, className }) {
  const [shown, setShown] = useState(text);
  const [on, setOn] = useState(!!text);

  useEffect(() => {
    if (text === shown) {
      setOn(!!text);
      return undefined;
    }
    setOn(false);
    const timer = setTimeout(() => {
      setShown(text);
      setOn(!!text);
    }, 160);
    return () => clearTimeout(timer);
  }, [text, shown]);

  return <div className={`${className}${on ? ' on' : ''}`}>{shown}</div>;
}

function Prompt({ label, hint, touch }) {
  const [shown, setShown] = useState(label);
  const [key, setKey] = useState(hint);
  const [on, setOn] = useState(!!label);

  useEffect(() => {
    if (label === shown && hint === key) {
      setOn(!!label);
      return undefined;
    }
    setOn(false);
    const timer = setTimeout(() => {
      setShown(label);
      setKey(hint);
      setOn(!!label);
    }, 160);
    return () => clearTimeout(timer);
  }, [label, hint, shown, key]);

  return (
    <div className={`hud-prompt${on ? ' on' : ''}`}>
      {shown && <span>{shown}</span>}
      {shown && key && !touch && <kbd>{key}</kbd>}
    </div>
  );
}

export default function FlightHUD({ hud, bracketRef, onExit, onLog }) {
  const phase = hud.phase || 'space';
  const hint = !hud.locked && !hud.touch;
  const unit = phase === 'foot' ? 'm/s' : 'u/s';
  const speedQuiet = phase === 'landed' || (phase === 'foot' && hud.speed < 1);

  return (
    <div className={`flight-hud${hud.touch ? ' is-touch' : ''}`} data-phase={phase}>
      <button type="button" className="hud-text-btn hud-log-btn" onClick={onLog}>Log</button>
      <button type="button" className="hud-text-btn" onClick={onExit}>Map</button>

      <div className={`hud-system${phase === 'space' ? ' on' : ''}`}>{hud.systemName}</div>

      <div className="hud-readout">
        <Fade text={hud.targetName} className="hud-name" />
        <Fade text={hud.readout || ''} className="hud-meta" />
        <Fade text={hud.note || ''} className="hud-aside" />
      </div>

      <div className={`hud-reticle flight${phase === 'foot' ? '' : ' on'}`} />
      <div className={`hud-reticle foot${phase === 'foot' ? ' on' : ''}`} />
      <div ref={bracketRef} className="hud-bracket" />

      <div className={`hud-hint${hint ? ' on' : ''}`}>{hud.onFoot ? 'Click to look' : 'Click to fly'}</div>

      <div className={`hud-speed${speedQuiet ? ' is-quiet' : ''}`}>
        <span className="hud-num">{hud.speed}</span>
        <span className="hud-unit">{unit}</span>
        <span className={`hud-pulse${hud.pulse ? ' on' : ''}`}>Pulse</span>
      </div>

      <Prompt label={hud.prompt} hint={hud.promptKey} touch={hud.touch} />
    </div>
  );
}
