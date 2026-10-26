// Destiny Rising-style touch. Screen deltas stay here; flight and on-foot
// read the same axes the keyboard already feeds.
export const TOUCH = {
  deadzone: 0.1,
  ring: 58,
  sprintOn: 0.55,
  sprintHold: 0.22,
  lookCurve: 0.3,
  lookSens: 1.85,
  sprintTurn: 0.6,
  jitter: 0.45,
  lookGate: 12,
};

export const touch = {
  enabled: false,
  axisX: 0,
  axisY: 0,
  sprint: false,
  lookX: 0,
  lookY: 0,
  jumpEdge: false,
  jumpHeld: false,
  crouchHeld: false,
  crouchPulse: false,
  interactEdge: false,
  landEdge: false,
  boostHeld: false,
  liftHeld: false,
};

export function prefersTouch() {
  if (typeof window === 'undefined' || !window.matchMedia) return false;
  const coarse = window.matchMedia('(pointer: coarse)').matches;
  const noHover = window.matchMedia('(hover: none)').matches;
  const fine = window.matchMedia('(pointer: fine)').matches;
  const hover = window.matchMedia('(hover: hover)').matches;
  if (coarse || noHover) return true;
  if (fine && hover) return false;
  return (navigator.maxTouchPoints || 0) > 0;
}

export function shapeStick(dx, dy, ring = TOUCH.ring) {
  const rawX = dx / ring;
  const rawY = -dy / ring;
  const rawMag = Math.hypot(rawX, rawY);
  let x = rawX;
  let y = rawY;
  if (rawMag > 1) {
    x /= rawMag;
    y /= rawMag;
  }
  const mag = Math.min(1, rawMag);
  const pastUp = rawY > 1;
  if (mag < TOUCH.deadzone) return { x: 0, y: 0, mag: 0, pastUp };
  const scaled = (mag - TOUCH.deadzone) / ((1 - TOUCH.deadzone) * (mag || 1));
  return {
    x: x * scaled,
    y: y * scaled,
    mag: (mag - TOUCH.deadzone) / (1 - TOUCH.deadzone),
    pastUp,
  };
}

export function latchSprint(latched, stick) {
  if (stick.pastUp || stick.y >= TOUCH.sprintOn) return true;
  if (stick.y < TOUCH.sprintHold) return false;
  return latched;
}

export function curveLook(dx, dy, sprinting) {
  const curve = (d) => {
    const amount = Math.abs(d);
    if (amount < TOUCH.jitter) return 0;
    const shaped = Math.sign(d) * (amount ** (1 + TOUCH.lookCurve)) / (TOUCH.lookGate ** TOUCH.lookCurve);
    return shaped;
  };
  const scale = TOUCH.lookSens * (sprinting ? TOUCH.sprintTurn : 1);
  return { x: curve(dx) * scale, y: curve(dy) * scale };
}

export function consumeLook() {
  const x = touch.lookX;
  const y = touch.lookY;
  touch.lookX = 0;
  touch.lookY = 0;
  return { x, y };
}

export function takeEdge(name) {
  const value = !!touch[name];
  touch[name] = false;
  return value;
}

export function releaseActions() {
  touch.jumpEdge = false;
  touch.jumpHeld = false;
  touch.crouchHeld = false;
  touch.crouchPulse = false;
  touch.interactEdge = false;
  touch.landEdge = false;
  touch.boostHeld = false;
  touch.liftHeld = false;
}

export function resetTouch() {
  touch.axisX = 0;
  touch.axisY = 0;
  touch.sprint = false;
  touch.lookX = 0;
  touch.lookY = 0;
  releaseActions();
}

export function tapHaptic(ms = 12) {
  try {
    navigator.vibrate?.(ms);
  } catch {
    /* iOS no-ops or throws; either is fine */
  }
}
