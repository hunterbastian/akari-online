import * as THREE from 'three';
import { floorAt } from '../../../shared/surface.js';

// First-person tuning. Distances are meters, speeds are m/s, angles are radians.
// The shape of the feel lives here: a short traction ramp into a firm stop,
// a held jump that floats at the top, and a sprint slide that spends its speed.
export const FOOT = {
  fixedDt: 1 / 120,
  maxSteps: 6,

  eyeStand: 1.64,
  eyeCrouch: 1.02,
  eyeSlide: 0.74,
  eyeOmega: 22,
  eyeZeta: 1.05,

  walkSpeed: 5.55,
  sprintSpeed: 9.05,
  crouchSpeed: 2.6,
  accelStart: 26,
  accelFull: 52,
  sprintAccel: 22,
  tractionRise: 16,
  tractionFall: 26,
  brake: 30,
  counterBrake: 48,

  airAccel: 20,
  airCap: 9.3,
  gravityRise: 21,
  gravityApex: 10.5,
  gravityCut: 36,
  gravityFall: 40,
  apexEnter: 2.15,
  apexExit: 1.35,
  jumpVelocity: 8.05,
  riseGrace: 0.09,
  coyoteTime: 0.13,
  jumpBuffer: 0.14,
  doubleJumpVelocity: 6.7,
  doubleJumpPush: 3.7,
  doubleJumpCap: 11.6,

  slideSpeed: 12.5,
  slideBoost: 1.14,
  slideTime: 0.72,
  slideEnter: 7.15,
  slideSteer: 7.5,
  slideEndSpeed: 4.1,
  slideBleed: 9,

  stepHeight: 0.5,
  stickDown: 0.22,
  bound: 200,

  mouseYaw: 0.00215,
  mousePitch: 0.00185,
  pitchLimit: 1.15,

  fov: 72,
  fovSprint: 81,
  fovSlide: 77,
  fovKick: 3.4,
  fovSmooth: 4.6,
  fovPunchDecay: 7.5,
  bobWalk: 0.01,
  bobSprint: 0.019,
  bobFreqWalk: 6.7,
  bobFreqSprint: 10.1,
  bobStrafe: 0.42,
  leanSprint: 0.068,
  leanReach: 0.09,
  strafeTilt: 0.032,
  slideRoll: 0.09,
  slideRollKick: 0.85,
  landDip: 0.11,
  landMinSpeed: 4.4,
  landHeightScale: 0.034,
  landSpeedScale: 0.0045,
  landKick: 0.07,
  landKickScale: 0.006,
  nudgePitch: -0.058,
  sprintCarry: 0.42,

  springBob: 34,
  springLean: 11,
  springRoll: 15,
  springDip: 17,
  springNudge: 16,
  zetaFollow: 1,
  zetaSettle: 0.72,
  zetaLean: 1.08,
};

const _wish = new THREE.Vector3();
const _forward = new THREE.Vector3();
const _right = new THREE.Vector3();

function mote() {
  return {
    alive: false, kind: 'dust', x: 0, y: 0, z: 0, vx: 0, vy: 0, vz: 0, life: 0, max: 0.4,
  };
}

export function createFoot() {
  const foot = {
    pos: new THREE.Vector3(),
    vel: new THREE.Vector3(),
    yaw: 0,
    pitch: 0,
    eye: FOOT.eyeStand,
    eyeV: 0,
    grounded: true,
    jumps: 0,
    coyote: FOOT.coyoteTime,
    jumpBuffer: 0,
    riseGrace: 0,
    crouchHeld: false,
    crouch: false,
    slide: 0,
    slideRollSign: 1,
    traction: 0,
    sprintLook: false,
    sprintCarry: 0,
    peakY: 0,
    accumulator: 0,
    bobPhase: 0,
    bobSpeed: 0,
    dust: 0,
    stepArm: 0,
    strafe: 0,
    events: [],
    motes: Array.from({ length: 40 }, mote),
    cam: {
      bob: 0, bobV: 0,
      sway: 0, swayV: 0,
      dip: 0, dipV: 0,
      lean: 0, leanV: 0,
      roll: 0, rollV: 0,
      nudge: 0, nudgeV: 0,
      kick: 0, kickV: 0,
      fov: FOOT.fov,
      fovPunch: 0,
    },
    view: { ox: 0, oy: FOOT.eyeStand, oz: 0, pitch: 0, roll: 0, fov: FOOT.fov },
  };
  return foot;
}

export function resetFoot(foot, x, y, z, yaw, fov = FOOT.fov) {
  foot.pos.set(x, y, z);
  foot.vel.set(0, 0, 0);
  foot.yaw = yaw;
  foot.pitch = 0;
  foot.eye = FOOT.eyeStand;
  foot.eyeV = 0;
  foot.grounded = true;
  foot.jumps = 0;
  foot.coyote = FOOT.coyoteTime;
  foot.jumpBuffer = 0;
  foot.riseGrace = 0;
  foot.crouchHeld = false;
  foot.crouch = false;
  foot.slide = 0;
  foot.slideRollSign = 1;
  foot.traction = 0;
  foot.sprintLook = false;
  foot.sprintCarry = 0;
  foot.peakY = y;
  foot.accumulator = 0;
  foot.bobPhase = 0;
  foot.bobSpeed = 0;
  foot.dust = 0;
  foot.stepArm = 0;
  foot.strafe = 0;
  foot.events.length = 0;
  for (const m of foot.motes) m.alive = false;
  const cam = foot.cam;
  cam.bob = cam.bobV = 0;
  cam.sway = cam.swayV = 0;
  cam.dip = cam.dipV = 0;
  cam.lean = cam.leanV = 0;
  cam.roll = cam.rollV = 0;
  cam.nudge = cam.nudgeV = 0;
  cam.kick = cam.kickV = 0;
  cam.fov = fov;
  cam.fovPunch = 0;
  foot.view.ox = 0;
  foot.view.oy = y + FOOT.eyeStand;
  foot.view.oz = 0;
  foot.view.pitch = 0;
  foot.view.roll = 0;
  foot.view.fov = fov;
}

function damp(current, target, rate, dt) {
  return current + (target - current) * (1 - Math.exp(-rate * dt));
}

function spring(pos, vel, target, omega, zeta, dt) {
  let p = pos;
  let v = vel;
  let left = Math.min(Math.max(dt, 0), 0.05);
  const step = 1 / 240;
  while (left > 0.00001) {
    const h = Math.min(step, left);
    const x = p - target;
    const a = -omega * omega * x - 2 * zeta * omega * v;
    v += a * h;
    p += v * h;
    left -= h;
  }
  return [p, v];
}

function accelerate(vel, dir, wishSpeed, accel, dt) {
  const current = vel.x * dir.x + vel.z * dir.z;
  const add = wishSpeed - current;
  if (add <= 0) return;
  const gain = Math.min(accel * dt, add);
  vel.x += dir.x * gain;
  vel.z += dir.z * gain;
}

function brake(vel, rate, dt) {
  const speed = Math.hypot(vel.x, vel.z);
  if (speed <= 0.0001) {
    vel.x = 0;
    vel.z = 0;
    return;
  }
  const drop = Math.min(speed, rate * dt);
  const scale = (speed - drop) / speed;
  vel.x *= scale;
  vel.z *= scale;
}

function takeMote(foot) {
  const found = foot.motes.find((m) => !m.alive);
  return found || foot.motes[0];
}

function spawnBurst(foot, kind, count) {
  const fx = -Math.sin(foot.yaw);
  const fz = -Math.cos(foot.yaw);
  const rx = Math.cos(foot.yaw);
  const rz = -Math.sin(foot.yaw);
  for (let i = 0; i < count; i += 1) {
    const m = takeMote(foot);
    const spread = Math.random() - 0.5;
    m.alive = true;
    m.kind = kind;
    if (kind === 'puff') {
      m.x = foot.pos.x + fx * 0.45 + rx * spread * 0.4;
      m.y = foot.pos.y + 0.55 + (i % 4) * 0.12;
      m.z = foot.pos.z + fz * 0.45 + rz * spread * 0.4;
      m.vx = -fx * 1.1 + rx * spread * 2.4;
      m.vy = i % 3 === 0 ? 2.6 + Math.random() * 0.6 : -1.6 - Math.random();
      m.vz = -fz * 1.1 + rz * spread * 2.4;
      m.max = 0.4;
    } else {
      const ahead = 0.45 + Math.random() * 0.9;
      m.x = foot.pos.x + fx * ahead + rx * spread * 0.7;
      m.y = foot.pos.y + 0.12;
      m.z = foot.pos.z + fz * ahead + rz * spread * 0.7;
      m.vx = -fx * (2.2 + Math.random() * 2) + rx * spread * 1.6;
      m.vy = 0.25 + Math.random() * 0.7;
      m.vz = -fz * (2.2 + Math.random() * 2) + rz * spread * 1.6;
      m.max = 0.48;
    }
    m.life = m.max;
  }
}

function moveHorizontal(foot, dt, wishDir, moving, wishSpeed, sprintMove, airCap) {
  if (foot.slide > 0) {
    const along = foot.slide / FOOT.slideTime;
    const shaped = along * along;
    const target = FOOT.slideEndSpeed + (FOOT.slideSpeed - FOOT.slideEndSpeed) * shaped;
    if (moving) {
      foot.vel.x += wishDir.x * FOOT.slideSteer * dt;
      foot.vel.z += wishDir.z * FOOT.slideSteer * dt;
    }
    const current = Math.hypot(foot.vel.x, foot.vel.z);
    if (current > 0.001) {
      const next = current + (target - current) * (1 - Math.exp(-FOOT.slideBleed * dt));
      const scale = Math.max(next, 0) / current;
      foot.vel.x *= scale;
      foot.vel.z *= scale;
    }
    return;
  }

  if (!foot.grounded) {
    if (moving) accelerate(foot.vel, wishDir, airCap, FOOT.airAccel, dt);
    return;
  }

  if (!moving) {
    brake(foot.vel, FOOT.brake, dt);
    return;
  }

  const along = foot.vel.x * wishDir.x + foot.vel.z * wishDir.z;
  const lx = foot.vel.x - wishDir.x * along;
  const lz = foot.vel.z - wishDir.z * along;
  const lat = Math.hypot(lx, lz);
  if (lat > 0.0001) {
    const drop = Math.min(lat, FOOT.brake * dt);
    const keep = (lat - drop) / lat;
    foot.vel.x -= lx * (1 - keep);
    foot.vel.z -= lz * (1 - keep);
  }
  const alongNow = foot.vel.x * wishDir.x + foot.vel.z * wishDir.z;
  if (alongNow < 0) {
    const drop = Math.min(-alongNow, FOOT.counterBrake * dt);
    foot.vel.x += wishDir.x * drop;
    foot.vel.z += wishDir.z * drop;
  }
  const capped = foot.vel.x * wishDir.x + foot.vel.z * wishDir.z;
  if (capped > wishSpeed) {
    const drop = Math.min(capped - wishSpeed, FOOT.brake * dt);
    foot.vel.x -= wishDir.x * drop;
    foot.vel.z -= wishDir.z * drop;
    return;
  }
  const full = sprintMove ? FOOT.sprintAccel : FOOT.accelFull;
  const rate = FOOT.accelStart + (full - FOOT.accelStart) * foot.traction * foot.traction;
  accelerate(foot.vel, wishDir, wishSpeed, rate, dt);
}

function substep(foot, dt, input, planet, crouchEdge) {
  _forward.set(-Math.sin(foot.yaw), 0, -Math.cos(foot.yaw));
  _right.set(Math.cos(foot.yaw), 0, -Math.sin(foot.yaw));
  _wish.set(0, 0, 0);
  let analog = 1;
  if (input.axis) {
    _wish.addScaledVector(_right, input.axis.x || 0);
    _wish.addScaledVector(_forward, input.axis.y || 0);
    analog = Math.min(1, _wish.length());
  } else {
    if (input.forward) _wish.add(_forward);
    if (input.back) _wish.sub(_forward);
    if (input.right) _wish.add(_right);
    if (input.left) _wish.sub(_right);
  }
  const moving = _wish.lengthSq() > 0.0001;
  if (moving) _wish.normalize();

  let jumped = false;
  const canGroundJump = foot.jumps === 0 && (foot.grounded || foot.coyote > 0);
  if (foot.jumpBuffer > 0 && canGroundJump) {
    foot.vel.y = FOOT.jumpVelocity;
    foot.grounded = false;
    foot.jumps = 1;
    foot.slide = 0;
    foot.coyote = 0;
    foot.jumpBuffer = 0;
    foot.riseGrace = FOOT.riseGrace;
    foot.peakY = foot.pos.y;
    jumped = true;
    foot.events.push({ type: 'jump' });
  } else if (foot.jumpBuffer > 0 && !foot.grounded && foot.jumps === 1) {
    foot.vel.y = FOOT.doubleJumpVelocity;
    foot.vel.x += _forward.x * FOOT.doubleJumpPush;
    foot.vel.z += _forward.z * FOOT.doubleJumpPush;
    const burst = Math.hypot(foot.vel.x, foot.vel.z);
    if (burst > FOOT.doubleJumpCap) {
      const scale = FOOT.doubleJumpCap / burst;
      foot.vel.x *= scale;
      foot.vel.z *= scale;
    }
    foot.jumps = 2;
    foot.jumpBuffer = 0;
    foot.riseGrace = FOOT.riseGrace * 0.7;
    foot.cam.nudge = FOOT.nudgePitch;
    foot.cam.nudgeV = 0.35;
    foot.cam.fovPunch = FOOT.fovKick;
    spawnBurst(foot, 'puff', 12);
    jumped = true;
    foot.events.push({ type: 'double' });
  } else {
    foot.jumpBuffer = Math.max(0, foot.jumpBuffer - dt);
  }

  if (!foot.grounded) foot.coyote = Math.max(0, foot.coyote - dt);
  foot.riseGrace = Math.max(0, foot.riseGrace - dt);

  const horiz = Math.hypot(foot.vel.x, foot.vel.z);
  if (!jumped && crouchEdge && foot.grounded && input.sprint && input.forward && horiz >= FOOT.slideEnter && foot.slide <= 0) {
    foot.slide = FOOT.slideTime;
    const dirx = foot.vel.x / horiz;
    const dirz = foot.vel.z / horiz;
    const burst = Math.max(horiz * FOOT.slideBoost, FOOT.slideSpeed);
    foot.vel.x = dirx * burst;
    foot.vel.z = dirz * burst;
    const side = dirx * _right.x + dirz * _right.z;
    foot.slideRollSign = side < -0.08 ? -1 : 1;
    foot.cam.rollV += FOOT.slideRollKick * foot.slideRollSign;
    foot.events.push({ type: 'slide' });
  }
  if (foot.slide > 0) foot.slide = Math.max(0, foot.slide - dt);

  const sprintMove = !!(input.sprint && input.forward && !input.crouch && foot.slide <= 0 && foot.grounded);
  if (sprintMove) foot.sprintCarry = FOOT.sprintCarry;
  else foot.sprintCarry = Math.max(0, foot.sprintCarry - dt);
  foot.sprintLook = sprintMove || (foot.sprintCarry > 0 && !!input.sprint && !input.crouch && foot.slide <= 0);

  const pushing = moving && foot.grounded && foot.slide <= 0;
  const tractionRate = pushing ? FOOT.tractionRise : FOOT.tractionFall;
  foot.traction = damp(foot.traction, pushing ? 1 : 0, tractionRate, dt);

  let wishSpeed = 0;
  if (moving) {
    if (input.crouch || foot.slide > 0) wishSpeed = FOOT.crouchSpeed;
    else if (sprintMove) wishSpeed = FOOT.sprintSpeed;
    else wishSpeed = FOOT.walkSpeed;
    if (input.axis && !sprintMove) wishSpeed *= analog;
  }
  const airCap = input.sprint || foot.sprintLook ? FOOT.airCap : FOOT.walkSpeed + 0.35;
  moveHorizontal(foot, dt, _wish, moving, wishSpeed, sprintMove, airCap);

  let nextX = foot.pos.x + foot.vel.x * dt;
  let nextZ = foot.pos.z + foot.vel.z * dt;
  const rise = floorAt(nextX, nextZ, planet) - foot.pos.y;
  if (rise > FOOT.stepHeight) {
    if (floorAt(nextX, foot.pos.z, planet) - foot.pos.y > FOOT.stepHeight) {
      nextX = foot.pos.x;
      foot.vel.x = 0;
    }
    if (floorAt(foot.pos.x, nextZ, planet) - foot.pos.y > FOOT.stepHeight) {
      nextZ = foot.pos.z;
      foot.vel.z = 0;
    }
  }
  foot.pos.x = THREE.MathUtils.clamp(nextX, -FOOT.bound, FOOT.bound);
  foot.pos.z = THREE.MathUtils.clamp(nextZ, -FOOT.bound, FOOT.bound);
  if (Math.abs(foot.pos.x) >= FOOT.bound - 0.001) foot.vel.x = 0;
  if (Math.abs(foot.pos.z) >= FOOT.bound - 0.001) foot.vel.z = 0;

  const floor = floorAt(foot.pos.x, foot.pos.z, planet);
  const stepUp = floor - foot.pos.y;
  const planted = foot.grounded && !jumped && foot.vel.y <= 0 && stepUp >= -FOOT.stickDown && stepUp <= FOOT.stepHeight;
  if (planted) {
    foot.pos.y = floor;
    foot.vel.y = 0;
    foot.jumps = 0;
    foot.coyote = FOOT.coyoteTime;
    foot.peakY = floor;
  } else {
    if (!jumped) {
      const vy = foot.vel.y;
      const committed = !!input.holdJump || foot.riseGrace > 0;
      let g = FOOT.gravityFall;
      if (vy > FOOT.apexEnter) g = committed ? FOOT.gravityRise : FOOT.gravityCut;
      else if (vy > -FOOT.apexExit && committed && foot.jumps > 0) g = FOOT.gravityApex;
      foot.vel.y -= g * dt;
    }
    foot.pos.y += foot.vel.y * dt;
    const landedFloor = floorAt(foot.pos.x, foot.pos.z, planet);
    if (foot.vel.y <= 0 && foot.pos.y <= landedFloor) {
      const impact = -foot.vel.y;
      const wasGrounded = foot.grounded;
      foot.pos.y = landedFloor;
      foot.vel.y = 0;
      if (!wasGrounded) {
        const fall = Math.max(0, foot.peakY - landedFloor);
        if (impact > FOOT.landMinSpeed) {
          const dip = Math.min(FOOT.landDip, fall * FOOT.landHeightScale + impact * FOOT.landSpeedScale);
          foot.cam.dip = Math.max(foot.cam.dip, dip);
          foot.cam.dipV = 0;
          foot.cam.kick = Math.min(FOOT.landKick, impact * FOOT.landKickScale);
          foot.cam.kickV = 0;
          foot.events.push({ type: 'land', impact, fall });
        }
      }
      foot.grounded = true;
      foot.jumps = 0;
      foot.coyote = FOOT.coyoteTime;
      foot.peakY = landedFloor;
    } else {
      if (foot.pos.y < landedFloor) foot.pos.y = landedFloor;
      if (foot.grounded) foot.peakY = foot.pos.y;
      foot.grounded = false;
      foot.peakY = Math.max(foot.peakY, foot.pos.y);
    }
  }

  foot.crouch = !!(input.crouch || foot.slide > 0);
}

function updatePresentation(foot, dt, input) {
  const step = Math.min(Math.max(dt, 0), 0.05);
  const speed = Math.hypot(foot.vel.x, foot.vel.z);
  foot.bobSpeed = damp(foot.bobSpeed, speed, 8, step);
  foot.strafe = (input.right ? 1 : 0) - (input.left ? 1 : 0);

  const targetEye = foot.slide > 0 ? FOOT.eyeSlide : foot.crouch ? FOOT.eyeCrouch : FOOT.eyeStand;
  [foot.eye, foot.eyeV] = spring(foot.eye, foot.eyeV, targetEye, FOOT.eyeOmega, FOOT.eyeZeta, step);

  const fast = foot.bobSpeed / FOOT.sprintSpeed;
  const freq = THREE.MathUtils.lerp(FOOT.bobFreqWalk, FOOT.bobFreqSprint, THREE.MathUtils.clamp(fast, 0, 1));
  const ampScale = foot.crouch ? 0.35 : 1;
  if (foot.grounded && foot.slide <= 0 && foot.bobSpeed > 0.7) {
    foot.bobPhase += step * freq * (0.72 + foot.bobSpeed / FOOT.sprintSpeed);
    const amp = THREE.MathUtils.lerp(FOOT.bobWalk, FOOT.bobSprint, THREE.MathUtils.clamp(fast, 0, 1)) * ampScale;
    const bobTarget = Math.sin(foot.bobPhase) * amp;
    const swayTarget = Math.cos(foot.bobPhase * 0.5) * amp * FOOT.bobStrafe;
    [foot.cam.bob, foot.cam.bobV] = spring(foot.cam.bob, foot.cam.bobV, bobTarget, FOOT.springBob, FOOT.zetaFollow, step);
    [foot.cam.sway, foot.cam.swayV] = spring(foot.cam.sway, foot.cam.swayV, swayTarget, FOOT.springBob, FOOT.zetaFollow, step);
    const stride = Math.floor(foot.bobPhase / Math.PI);
    if (stride !== foot.stepArm && foot.bobSpeed > 1.15) {
      foot.stepArm = stride;
      foot.events.push({ type: 'step', speed: foot.bobSpeed });
    }
  } else {
    [foot.cam.bob, foot.cam.bobV] = spring(foot.cam.bob, foot.cam.bobV, 0, FOOT.springBob, FOOT.zetaFollow, step);
    [foot.cam.sway, foot.cam.swayV] = spring(foot.cam.sway, foot.cam.swayV, 0, FOOT.springBob, FOOT.zetaFollow, step);
  }

  const leanTarget = foot.sprintLook && foot.slide <= 0 ? FOOT.leanSprint : 0;
  [foot.cam.lean, foot.cam.leanV] = spring(foot.cam.lean, foot.cam.leanV, leanTarget, FOOT.springLean, FOOT.zetaLean, step);

  let rollTarget = foot.strafe * FOOT.strafeTilt;
  if (foot.slide > 0) rollTarget += FOOT.slideRoll * foot.slideRollSign;
  [foot.cam.roll, foot.cam.rollV] = spring(foot.cam.roll, foot.cam.rollV, rollTarget, FOOT.springRoll, 0.86, step);
  [foot.cam.dip, foot.cam.dipV] = spring(foot.cam.dip, foot.cam.dipV, 0, FOOT.springDip, FOOT.zetaSettle, step);
  [foot.cam.nudge, foot.cam.nudgeV] = spring(foot.cam.nudge, foot.cam.nudgeV, 0, FOOT.springNudge, 0.62, step);
  [foot.cam.kick, foot.cam.kickV] = spring(foot.cam.kick, foot.cam.kickV, 0, FOOT.springDip, FOOT.zetaSettle, step);

  const fovTarget = (foot.slide > 0 ? FOOT.fovSlide : foot.sprintLook ? FOOT.fovSprint : FOOT.fov) + foot.cam.fovPunch;
  foot.cam.fov = damp(foot.cam.fov, fovTarget, FOOT.fovSmooth, step);
  foot.cam.fovPunch *= Math.exp(-FOOT.fovPunchDecay * step);

  if (foot.slide > 0) {
    foot.dust += step;
    while (foot.dust >= 0.032) {
      foot.dust -= 0.032;
      spawnBurst(foot, 'dust', 2);
    }
  } else {
    foot.dust = 0;
  }

  for (const m of foot.motes) {
    if (!m.alive) continue;
    m.life -= step;
    m.x += m.vx * step;
    m.y += m.vy * step;
    m.z += m.vz * step;
    m.vy -= (m.kind === 'puff' ? 11 : 7) * step;
    const floor = foot.pos.y + 0.05;
    if (m.kind === 'dust' && m.y < floor) {
      m.y = floor;
      m.vy = 0;
      m.vx *= 0.9;
      m.vz *= 0.9;
    }
    if (m.life <= 0) m.alive = false;
  }

  const fx = -Math.sin(foot.yaw);
  const fz = -Math.cos(foot.yaw);
  const rx = Math.cos(foot.yaw);
  const rz = -Math.sin(foot.yaw);
  const lean01 = FOOT.leanSprint > 0 ? THREE.MathUtils.clamp(foot.cam.lean / FOOT.leanSprint, -0.2, 1.4) : 0;
  foot.view.ox = rx * foot.cam.sway + fx * lean01 * FOOT.leanReach;
  foot.view.oy = foot.eye + foot.cam.bob - foot.cam.dip;
  foot.view.oz = rz * foot.cam.sway + fz * lean01 * FOOT.leanReach;
  foot.view.pitch = foot.cam.lean + foot.cam.nudge + foot.cam.kick;
  foot.view.roll = foot.cam.roll;
  foot.view.fov = foot.cam.fov;
  foot.fov = foot.cam.fov;
}

export function stepFoot(foot, dt, input, planet) {
  const frame = Math.min(Math.max(dt, 0), 0.05);
  foot.events.length = 0;
  const mouseX = THREE.MathUtils.clamp(input.mouseX || 0, -400, 400);
  const mouseY = THREE.MathUtils.clamp(input.mouseY || 0, -400, 400);
  foot.yaw -= mouseX * FOOT.mouseYaw;
  foot.pitch = THREE.MathUtils.clamp(
    foot.pitch + mouseY * FOOT.mousePitch,
    -FOOT.pitchLimit,
    FOOT.pitchLimit,
  );
  if (input.jump) foot.jumpBuffer = FOOT.jumpBuffer;

  const crouchEdge = !!input.crouch && !foot.crouchHeld;
  foot.crouchHeld = !!input.crouch;

  foot.accumulator += frame;
  let steps = 0;
  let edge = crouchEdge;
  while (foot.accumulator >= FOOT.fixedDt && steps < FOOT.maxSteps) {
    substep(foot, FOOT.fixedDt, input, planet, edge);
    foot.accumulator -= FOOT.fixedDt;
    edge = false;
    steps += 1;
  }
  if (steps === FOOT.maxSteps) foot.accumulator = 0;

  updatePresentation(foot, frame, input);
  return {
    sprinting: foot.sprintLook,
    speed: Math.hypot(foot.vel.x, foot.vel.z),
    events: foot.events,
  };
}
