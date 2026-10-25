import { useEffect, useRef, useState } from 'react';
import { ensureFootAudio } from './footAudio';
import {
  TOUCH,
  curveLook,
  latchSprint,
  prefersTouch,
  resetTouch,
  shapeStick,
  tapHaptic,
  touch,
} from './touch';

function HoldButton({ className, label, onDown, onUp }) {
  const [held, setHeld] = useState(false);
  const end = (event) => {
    event.preventDefault();
    event.stopPropagation();
    setHeld(false);
    onUp?.();
  };
  return (
    <div
      role="button"
      className={`touch-btn${className ? ` ${className}` : ''}${held ? ' held' : ''}`}
      onPointerDown={(event) => {
        event.preventDefault();
        event.stopPropagation();
        try { event.currentTarget.setPointerCapture?.(event.pointerId); } catch { /* synthetic pointers */ }
        setHeld(true);
        ensureFootAudio();
        onDown();
      }}
      onPointerUp={end}
      onPointerCancel={end}
    >
      {label}
    </div>
  );
}

export default function TouchControls({ onFoot, canBoard, canExit, canLand }) {
  const [shown, setShown] = useState(prefersTouch);
  const [portrait, setPortrait] = useState(false);
  const [stickOn, setStickOn] = useState(false);
  const [sprinting, setSprinting] = useState(false);
  const layerRef = useRef(null);
  const stickRef = useRef(null);
  const knobRef = useRef(null);
  const stickId = useRef(null);
  const lookId = useRef(null);
  const origin = useRef({ x: 0, y: 0 });
  const lookAt = useRef({ x: 0, y: 0 });
  const sprintLatch = useRef(false);

  useEffect(() => {
    const update = () => setShown(prefersTouch() || document.documentElement.classList.contains('touch-live'));
    update();
    const queries = ['(pointer: coarse)', '(pointer: fine)', '(hover: none)', '(hover: hover)']
      .map((query) => window.matchMedia(query));
    queries.forEach((mq) => mq.addEventListener?.('change', update));
    const onDown = (event) => {
      if (event.pointerType !== 'touch') return;
      document.documentElement.classList.add('touch-live');
      setShown(true);
    };
    window.addEventListener('pointerdown', onDown, true);
    return () => {
      queries.forEach((mq) => mq.removeEventListener?.('change', update));
      window.removeEventListener('pointerdown', onDown, true);
    };
  }, []);

  useEffect(() => {
    const update = () => {
      const upright = window.matchMedia('(orientation: portrait)').matches;
      setPortrait(upright || window.innerHeight > window.innerWidth);
    };
    update();
    window.addEventListener('resize', update);
    window.addEventListener('orientationchange', update);
    return () => {
      window.removeEventListener('resize', update);
      window.removeEventListener('orientationchange', update);
    };
  }, []);

  useEffect(() => {
    touch.enabled = shown;
    if (!shown) resetTouch();
    return () => {
      touch.enabled = false;
      resetTouch();
    };
  }, [shown]);

  useEffect(() => {
    const layer = layerRef.current;
    if (!shown || !layer) return undefined;
    const block = (event) => event.preventDefault();
    layer.addEventListener('touchstart', block, { passive: false });
    layer.addEventListener('touchmove', block, { passive: false });
    layer.addEventListener('contextmenu', block);
    document.addEventListener('gesturestart', block);
    return () => {
      layer.removeEventListener('touchstart', block);
      layer.removeEventListener('touchmove', block);
      layer.removeEventListener('contextmenu', block);
      document.removeEventListener('gesturestart', block);
    };
  }, [shown]);

  const hideStick = () => {
    stickId.current = null;
    sprintLatch.current = false;
    touch.axisX = 0;
    touch.axisY = 0;
    touch.sprint = false;
    setStickOn(false);
    setSprinting(false);
  };

  const onPointerDown = (event) => {
    if (event.target.closest('.touch-btn')) return;
    ensureFootAudio();
    const rect = event.currentTarget.getBoundingClientRect();
    const inLeft = event.clientX < rect.left + rect.width * 0.5;
    if (inLeft && stickId.current == null) {
      stickId.current = event.pointerId;
      origin.current = { x: event.clientX, y: event.clientY };
      try { event.currentTarget.setPointerCapture?.(event.pointerId); } catch { /* synthetic pointers */ }
      const stick = stickRef.current;
      if (stick) {
        stick.style.left = `${event.clientX - rect.left}px`;
        stick.style.top = `${event.clientY - rect.top}px`;
      }
      if (knobRef.current) knobRef.current.style.transform = 'translate(0px, 0px)';
      sprintLatch.current = false;
      touch.axisX = 0;
      touch.axisY = 0;
      touch.sprint = false;
      setSprinting(false);
      setStickOn(true);
      event.preventDefault();
      return;
    }
    if (!inLeft && lookId.current == null) {
      lookId.current = event.pointerId;
      lookAt.current = { x: event.clientX, y: event.clientY };
      try { event.currentTarget.setPointerCapture?.(event.pointerId); } catch { /* synthetic pointers */ }
      event.preventDefault();
    }
  };

  const onPointerMove = (event) => {
    if (event.pointerId === stickId.current) {
      const dx = event.clientX - origin.current.x;
      const dy = event.clientY - origin.current.y;
      const stick = shapeStick(dx, dy);
      const sprint = latchSprint(sprintLatch.current, stick);
      if (sprint && !sprintLatch.current) tapHaptic(14);
      sprintLatch.current = sprint;
      touch.axisX = stick.x;
      touch.axisY = stick.y;
      touch.sprint = sprint;
      const reach = Math.hypot(dx, dy);
      const limit = reach > TOUCH.ring ? TOUCH.ring / reach : 1;
      if (knobRef.current) {
        knobRef.current.style.transform = `translate(${dx * limit}px, ${dy * limit}px)`;
      }
      setSprinting(sprint);
      event.preventDefault();
      return;
    }
    if (event.pointerId === lookId.current) {
      const dx = event.clientX - lookAt.current.x;
      const dy = event.clientY - lookAt.current.y;
      lookAt.current = { x: event.clientX, y: event.clientY };
      const look = curveLook(dx, dy, touch.sprint);
      touch.lookX += look.x;
      touch.lookY += look.y;
      event.preventDefault();
    }
  };

  const onPointerUp = (event) => {
    if (event.pointerId === stickId.current) hideStick();
    if (event.pointerId === lookId.current) lookId.current = null;
  };

  if (!shown) return null;

  const action = canBoard ? 'Board' : canExit ? 'Exit' : canLand ? 'Land' : '';

  return (
    <div
      ref={layerRef}
      className="touch-layer"
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerUp}
      onPointerCancel={onPointerUp}
    >
      {portrait && <div className="touch-rotate">Rotate to landscape</div>}
      <div ref={stickRef} className={`touch-stick${sprinting ? ' sprint' : ''}${stickOn ? ' on' : ''}`}>
        <div ref={knobRef} className="touch-knob" />
      </div>
      <div className="touch-arc">
        {action && (
          <HoldButton
            className="act"
            label={action}
            onDown={() => {
              if (action === 'Land') touch.landEdge = true;
              else touch.interactEdge = true;
              tapHaptic(10);
            }}
          />
        )}
        <HoldButton
          className="slide"
          label={onFoot ? 'Slide' : 'Boost'}
          onDown={() => {
            if (onFoot) {
              touch.crouchHeld = true;
              touch.crouchPulse = true;
              tapHaptic(10);
            } else {
              touch.boostHeld = true;
            }
          }}
          onUp={() => {
            touch.crouchHeld = false;
            touch.boostHeld = false;
          }}
        />
        <HoldButton
          className="jump"
          label={onFoot ? 'Jump' : 'Lift'}
          onDown={() => {
            if (onFoot) {
              touch.jumpEdge = true;
              touch.jumpHeld = true;
              tapHaptic(12);
            } else {
              touch.liftHeld = true;
              tapHaptic(8);
            }
          }}
          onUp={() => {
            touch.jumpHeld = false;
            touch.liftHeld = false;
          }}
        />
      </div>
    </div>
  );
}
