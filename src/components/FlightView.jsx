import { Suspense, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { SYSTEMS, getConnections } from '../../shared/galaxy.js';
import { SHIPS } from '../../shared/ships.js';
import { collectDeposit, jumpTo, surveyPlanet } from '../store';
import {
  describePlanet,
  flightProfile,
  generateSystem,
  hashString,
  resourceLabel,
} from '../../shared/universe.js';
import { floorAt, surfaceLayout, surfaceSky } from '../../shared/surface.js';
import FlightHUD from './flight/FlightHUD';
import { Belt, Deposit, Sky, Starfield, Sun, TargetMarker } from './flight/scenery';
import { GateView, PilotFigure, ShipView, SpaceTraffic, StationView } from './flight/Models';
import { SurfaceWorld } from './flight/Surface';
import { createFoot, resetFoot, stepFoot } from './flight/foot';
import { ensureFootAudio, playJump, playLand, playSlide, playStep } from './flight/footAudio';
import Planet from './flight/Planet';

const keys = Object.create(null);
const tapped = new Set();
const mouse = { dx: 0, dy: 0 };

const HOLD = ['Tab', 'KeyR', 'KeyC', 'KeyE', 'KeyF', 'KeyV', 'Space', 'ControlLeft', 'ControlRight'];

function bindInput(dom) {
  const onKeyDown = (e) => {
    ensureFootAudio();
    if (!keys[e.code]) tapped.add(e.code);
    keys[e.code] = true;
    if (HOLD.includes(e.code)) e.preventDefault();
  };
  const onKeyUp = (e) => {
    keys[e.code] = false;
  };
  const onMouseMove = (e) => {
    if (document.pointerLockElement !== dom) return;
    mouse.dx += e.movementX;
    mouse.dy += e.movementY;
  };
  const onClick = () => {
    ensureFootAudio();
    if (document.pointerLockElement !== dom) dom.requestPointerLock();
  };

  window.addEventListener('keydown', onKeyDown);
  window.addEventListener('keyup', onKeyUp);
  dom.addEventListener('mousemove', onMouseMove);
  dom.addEventListener('click', onClick);

  return () => {
    window.removeEventListener('keydown', onKeyDown);
    window.removeEventListener('keyup', onKeyUp);
    dom.removeEventListener('mousemove', onMouseMove);
    dom.removeEventListener('click', onClick);
    for (const code of Object.keys(keys)) delete keys[code];
    tapped.clear();
    mouse.dx = 0;
    mouse.dy = 0;
    if (document.pointerLockElement === dom) document.exitPointerLock();
  };
}

const _forward = new THREE.Vector3();
const _desired = new THREE.Vector3();
const _euler = new THREE.Euler(0, 0, 0, 'YXZ');
const _look = new THREE.Matrix4();
const _quat = new THREE.Quaternion();
const _up = new THREE.Vector3(0, 1, 0);
const _target = new THREE.Vector3();
const _cam = new THREE.Vector3();
const _aim = new THREE.Vector3();
const _out = new THREE.Vector3();
const _body = new THREE.Vector3();
const _radial = new THREE.Vector3();

function syncMotes(points, foot) {
  if (!points) return;
  const pos = points.geometry.attributes.position.array;
  const col = points.geometry.attributes.color.array;
  let n = 0;
  for (const m of foot.motes) {
    if (!m.alive) continue;
    const fade = Math.max(0, m.life / m.max);
    pos[n * 3] = m.x;
    pos[n * 3 + 1] = m.y;
    pos[n * 3 + 2] = m.z;
    if (m.kind === 'puff') {
      col[n * 3] = fade;
      col[n * 3 + 1] = 0.78 * fade;
      col[n * 3 + 2] = 0.55 * fade;
    } else {
      col[n * 3] = 0.95 * fade;
      col[n * 3 + 1] = 0.9 * fade;
      col[n * 3 + 2] = 0.82 * fade;
    }
    n += 1;
  }
  points.geometry.setDrawRange(0, n);
  points.geometry.attributes.position.needsUpdate = true;
  points.geometry.attributes.color.needsUpdate = true;
  points.visible = n > 0;
}

function InputBinder() {
  const dom = useThree((s) => s.gl.domElement);
  useEffect(() => bindInput(dom), [dom]);
  return null;
}

function makeGates(systemId) {
  const ids = getConnections(systemId);
  return ids.map((id, index) => {
    const sys = SYSTEMS.find((s) => s.id === id);
    const angle = -0.9 + index * ((Math.PI * 2) / Math.max(ids.length, 1));
    const dist = 390;
    return {
      kind: 'gate',
      id,
      systemId: id,
      name: sys?.name || id,
      position: [Math.cos(angle) * dist, 88, Math.sin(angle) * dist],
      radius: 14,
    };
  });
}

function Pilot({
  env,
  ship,
  speeds,
  playerRef,
  onExitRef,
  onHud,
  onSceneRef,
  targetRef,
}) {
  const shipRef = useRef();
  const hullRef = useRef();
  const personRef = useRef();
  const velocity = useRef(new THREE.Vector3());
  const footPos = useRef(new THREE.Vector3());
  const footYaw = useRef(0);
  const pulsing = useRef(false);
  const thrustRef = useRef(0);
  const targetIndex = useRef(env.planets.length ? 1 : 0);
  const started = useRef(false);
  const camReady = useRef(false);
  const bank = useRef(0);
  const note = useRef({ text: '', until: 0 });
  const pending = useRef(new Set());
  const hudClock = useRef(0);
  const mode = useRef('space');
  const surfacePlanet = useRef(null);
  const landed = useRef(false);
  const onFoot = useRef(false);
  const exitHold = useRef(0);
  const portrait = useRef(false);
  const logged = useRef(new Set());
  const reported = useRef('');
  const command = useRef(null);
  const footState = useRef(null);
  const footDrive = useRef(null);
  const jumpHeld = useRef(false);
  const landDip = useRef(0);
  const wasLanded = useRef(false);
  const frame = useRef({ space: null, surface: null, foot: null });
  const { camera, gl, scene } = useThree();
  const motesRef = useRef(null);

  useEffect(() => {
    const count = 40;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(count * 3), 3));
    geo.setAttribute('color', new THREE.BufferAttribute(new Float32Array(count * 3), 3));
    geo.setDrawRange(0, 0);
    const mat = new THREE.PointsMaterial({
      size: 0.26,
      vertexColors: true,
      transparent: true,
      depthWrite: false,
      blending: THREE.AdditiveBlending,
      sizeAttenuation: true,
    });
    const points = new THREE.Points(geo, mat);
    points.frustumCulled = false;
    points.visible = false;
    points.renderOrder = 2;
    scene.add(points);
    motesRef.current = points;
    return () => {
      scene.remove(points);
      geo.dispose();
      mat.dispose();
      motesRef.current = null;
    };
  }, [scene]);

  const bodies = useMemo(() => {
    const list = [{
      kind: 'station',
      name: env.station.name,
      position: env.station.position,
      radius: 8,
    }];
    for (const planet of env.planets) {
      list.push({
        kind: 'planet',
        id: planet.id,
        name: planet.name,
        biome: planet.biome,
        biomeLabel: planet.biomeLabel,
        resources: planet.resources,
        position: planet.position,
        radius: planet.radius,
        atmosphere: planet.atmosphere,
      });
    }
    for (const gate of env.gates) list.push(gate);
    return list;
  }, [env]);

  const consume = (code) => {
    if (!tapped.has(code)) return false;
    tapped.delete(code);
    return true;
  };

  const reportScene = () => {
    const id = surfacePlanet.current?.id || '';
    const key = `${mode.current}:${id}`;
    if (reported.current === key) return;
    reported.current = key;
    onSceneRef.current({ mode: mode.current, planetId: id || null });
  };

  const face = (from, to) => {
    _look.lookAt(from, to, _up);
    shipRef.current.quaternion.setFromRotationMatrix(_look);
  };

  const enterSurface = (planet, altitude, forwardSpeed) => {
    mode.current = 'surface';
    surfacePlanet.current = planet;
    onFoot.current = false;
    landed.current = false;
    pulsing.current = false;
    portrait.current = false;
    const group = shipRef.current;
    group.position.set(0, Math.max(altitude, 100), 52);
    group.rotation.set(0.4, 0, 0);
    velocity.current.set(0, -12, -Math.max(forwardSpeed, 24));
    camReady.current = false;
    landDip.current = 0;
    wasLanded.current = false;
    if (personRef.current) personRef.current.visible = false;
      if (!logged.current.has(planet.id)) {
        logged.current.add(planet.id);
        surveyPlanet({ id: planet.id, name: planet.name, biomeLabel: planet.biomeLabel });
        note.current = { text: describePlanet(planet), until: null };
      }
    reportScene();
  };

  const exitSurface = () => {
    const planet = surfacePlanet.current;
    const group = shipRef.current;
    if (!planet || !group) return;
    _body.set(planet.position[0], planet.position[1], planet.position[2]);
    _radial.copy(_body).normalize();
    group.position.copy(_body).addScaledVector(_radial, planet.radius + 12);
    _aim.copy(group.position).add(_radial);
    face(group.position, _aim);
    velocity.current.copy(_radial).multiplyScalar(26);
    mode.current = 'space';
    surfacePlanet.current = null;
    landed.current = false;
    onFoot.current = false;
    exitHold.current = 2.4;
    if (personRef.current) personRef.current.visible = false;
    reportScene();
  };

  useEffect(() => {
    window.__flight = {
      command(cmd) { command.current = cmd; },
      snapshot() {
        const group = shipRef.current;
        return {
          ready: true,
          mode: mode.current,
          landed: landed.current,
          onFoot: onFoot.current,
          position: group ? [group.position.x, group.position.y, group.position.z] : null,
          foot: footState.current && onFoot.current ? {
            position: [footState.current.pos.x, footState.current.pos.y, footState.current.pos.z],
            yaw: footState.current.yaw,
            pitch: footState.current.pitch,
            fov: footState.current.view?.fov ?? footState.current.fov,
            grounded: footState.current.grounded,
            slide: footState.current.slide,
            eye: footState.current.eye,
            roll: footState.current.view?.roll ?? 0,
          } : null,
          speed: Math.round(velocity.current.length()),
          planet: surfacePlanet.current && {
            name: surfacePlanet.current.name,
            biome: surfacePlanet.current.biome,
            biomeLabel: surfacePlanet.current.biomeLabel,
          },
          planets: env.planets.map((planet, index) => ({
            index,
            id: planet.id,
            name: planet.name,
            biome: planet.biome,
            biomeLabel: planet.biomeLabel,
            position: planet.position,
            radius: planet.radius,
          })),
          station: env.station.position,
          gates: env.gates.map((gate) => ({ name: gate.name, position: gate.position, systemId: gate.systemId })),
        };
      },
    };
    return () => { delete window.__flight; };
  }, [env]);

  useFrame((state, delta) => {
    const group = shipRef.current;
    if (!group) return;
    const dt = Math.min(delta, 0.05);
    const now = state.clock.elapsedTime;
    const view = frame.current;
    view.space = null;
    view.surface = null;
    view.foot = null;

    if (!started.current) {
      started.current = true;
      const spawn = env.spawn;
      group.position.set(spawn[0], spawn[1], spawn[2]);
      const first = env.planets[0];
      if (first) {
        _target.set(first.position[0], first.position[1], first.position[2]);
        face(group.position, _target);
      }
    }

    const beginFoot = (planet, yaw) => {
      if (!footState.current) footState.current = createFoot();
      const foot = footState.current;
      const x = group.position.x - Math.sin(yaw) * 2.6;
      const z = group.position.z - Math.cos(yaw) * 2.6;
      resetFoot(foot, x, floorAt(x, z, planet), z, yaw, camera.fov);
      onFoot.current = true;
      footDrive.current = null;
      jumpHeld.current = false;
      mouse.dx = 0;
      mouse.dy = 0;
      if (personRef.current) personRef.current.visible = false;
    };

    const cmd = command.current;
    if (cmd) {
      command.current = null;
      portrait.current = false;
      if (cmd.type === 'portrait') {
        portrait.current = true;
        pulsing.current = false;
        velocity.current.set(0, 0, 0);
        mode.current = 'space';
        surfacePlanet.current = null;
        onFoot.current = false;
        landed.current = false;
        reportScene();
      } else if (cmd.type === 'place') {
        mode.current = 'space';
        surfacePlanet.current = null;
        onFoot.current = false;
        landed.current = false;
        pulsing.current = !!cmd.pulse;
        group.position.set(cmd.position[0], cmd.position[1], cmd.position[2]);
        _target.set(cmd.look[0], cmd.look[1], cmd.look[2]);
        face(group.position, _target);
        velocity.current.set(
          cmd.velocity?.[0] || 0,
          cmd.velocity?.[1] || 0,
          cmd.velocity?.[2] || 0,
        );
        exitHold.current = cmd.hold || 0;
        reportScene();
        camReady.current = false;
      } else if (cmd.type === 'descend') {
        const planet = env.planets[cmd.planetIndex || 0];
        enterSurface(planet, cmd.y ?? 78, cmd.speed ?? 20);
        camReady.current = false;
      } else if (cmd.type === 'settle') {
        const planet = env.planets[cmd.planetIndex || 0];
        enterSurface(planet, 8, 0);
        const x = cmd.x ?? 4;
        const z = cmd.z ?? -10;
        group.position.set(x, floorAt(x, z, planet) + 0.4, z);
        group.rotation.set(0, cmd.yaw ?? 0.15, 0);
        velocity.current.set(0, 0, 0);
        landed.current = true;
        camReady.current = false;
      } else if (cmd.type === 'disembark') {
        const planet = surfacePlanet.current;
        if (planet && landed.current) {
          _euler.setFromQuaternion(group.quaternion, 'YXZ');
          beginFoot(planet, cmd.yaw ?? _euler.y);
        }
      } else if (cmd.type === 'drive' && footState.current) {
        footDrive.current = {
          forward: cmd.forward || 0,
          back: !!cmd.back,
          left: !!cmd.left,
          right: !!cmd.right,
          sprint: !!cmd.sprint,
          crouch: !!cmd.crouch,
          jump: !!cmd.jump,
        };
        if (cmd.yaw != null) footState.current.yaw = cmd.yaw;
        if (cmd.pitch != null) footState.current.pitch = cmd.pitch;
      }
    }

    if (portrait.current) {
      _forward.set(0, 0, -1).applyQuaternion(group.quaternion);
      _out.set(1.15, 0.82, -0.7).applyQuaternion(group.quaternion).setLength(5.5);
      _cam.copy(group.position).add(_out);
      camera.position.lerp(_cam, 1 - Math.exp(-6 * dt));
      camera.lookAt(group.position);
      camera.fov = THREE.MathUtils.damp(camera.fov, 42, 4, dt);
      camera.updateProjectionMatrix();
      thrustRef.current = 0.35;
      publish(now);
      return;
    }

    if (mode.current === 'surface') flySurface(dt, now);
    else flySpace(dt, now);
    publish(now);

    function flySpace(step, time) {
      if (consume('Tab')) {
        targetIndex.current = (targetIndex.current + 1) % bodies.length;
        pulsing.current = false;
      }
      if (consume('KeyR')) pulsing.current = !pulsing.current;

      const target = bodies[targetIndex.current] || bodies[0];
      targetRef.current = target;
      _target.set(target.position[0], target.position[1], target.position[2]);

      let yaw = 0;
      let pitch = 0;
      if (!pulsing.current) {
        yaw += -mouse.dx * 0.0032;
        pitch += mouse.dy * 0.0022;
        if (keys.KeyA || keys.ArrowLeft) yaw += 1.15 * step;
        if (keys.KeyD || keys.ArrowRight) yaw -= 1.15 * step;
        group.rotateY(yaw);
        group.rotateX(pitch);
        _euler.setFromQuaternion(group.quaternion, 'YXZ');
        _euler.x = THREE.MathUtils.clamp(_euler.x, -1.05, 1.05);
        _euler.z = 0;
        group.quaternion.setFromEuler(_euler);
        bank.current = THREE.MathUtils.damp(bank.current, THREE.MathUtils.clamp(-yaw * 5.5, -0.42, 0.42), 5, step);
      } else {
        _look.lookAt(group.position, _target, _up);
        _quat.setFromRotationMatrix(_look);
        group.quaternion.slerp(_quat, 1 - Math.exp(-3.4 * step));
        bank.current = THREE.MathUtils.damp(bank.current, 0, 4, step);
      }
      mouse.dx = 0;
      mouse.dy = 0;
      if (hullRef.current) hullRef.current.rotation.z = bank.current;

      _forward.set(0, 0, -1).applyQuaternion(group.quaternion);
      const boosting = !!(keys.ShiftLeft || keys.ShiftRight);
      let throttle = 0;
      if (keys.KeyW || keys.ArrowUp) throttle += 1;
      if (keys.KeyS || keys.ArrowDown) throttle -= 1;
      thrustRef.current = pulsing.current ? 1 : Math.max(0, throttle) * (boosting ? 1 : 0.65);

      let speed = 0;
      if (pulsing.current) speed = speeds.pulse;
      else if (throttle > 0) speed = boosting ? speeds.boost : speeds.cruise;
      else if (throttle < 0) speed = -speeds.cruise * 0.45;

      if (pulsing.current || throttle !== 0) {
        _desired.copy(_forward).multiplyScalar(speed);
        const rate = pulsing.current ? 1.3 : 2.5;
        velocity.current.lerp(_desired, 1 - Math.exp(-rate * step));
      } else {
        velocity.current.multiplyScalar(Math.exp(-0.32 * step));
      }
      if (keys.Space) velocity.current.y += 16 * step;
      if (keys.ControlLeft || keys.ControlRight) velocity.current.y -= 16 * step;

      group.position.addScaledVector(velocity.current, step);

      const dist = group.position.distanceTo(_target);
      if (target.kind === 'gate' && pulsing.current && dist < 36) {
        pulsing.current = false;
        jumpTo(target.systemId);
        return;
      }
      const stop = target.radius + (target.kind === 'station' ? 18 : 22);
      if (pulsing.current && target.kind !== 'planet' && target.kind !== 'gate' && dist < stop) {
        pulsing.current = false;
        killClosing();
      }

      const starDist = group.position.length();
      if (starDist < 12) {
        group.position.setLength(12);
        const inward = velocity.current.dot(group.position) / 12;
        if (inward < 0) velocity.current.addScaledVector(group.position, -inward / 12);
      }

      let closest = Infinity;
      let closestPlanet = null;
      for (const planet of env.planets) {
        _body.set(planet.position[0], planet.position[1], planet.position[2]);
        const center = group.position.distanceTo(_body);
        const altitude = center - planet.radius;
        if (altitude < closest) {
          closest = altitude;
          closestPlanet = planet;
        }
      }

      if (exitHold.current > 0) exitHold.current -= step;

      if (closestPlanet) {
        _body.set(closestPlanet.position[0], closestPlanet.position[1], closestPlanet.position[2]);
        _radial.copy(group.position).sub(_body);
        const center = _radial.length() || 0.001;
        _radial.multiplyScalar(1 / center);
        const closing = -velocity.current.dot(_radial);
        const dive = closest < 8 || (closest < 15 && closing > 6);
        if (exitHold.current <= 0 && dive) {
          enterSurface(closestPlanet, 96, 22);
          return;
        }
        if (closest < 3) {
          group.position.copy(_body).addScaledVector(_radial, closestPlanet.radius + 3);
          const into = velocity.current.dot(_radial);
          if (into < 0) velocity.current.addScaledVector(_radial, -into);
        }
      }

      const docking = group.position.distanceTo(_body.set(
        env.station.position[0],
        env.station.position[1],
        env.station.position[2],
      )) < 36;

      const collectible = nearestDeposit(env.deposits, 16);

      if (consume('KeyF') && docking) onExitRef.current();
      if (consume('KeyC') && target.kind === 'planet') {
        surveyPlanet(target);
        note.current = { text: describePlanet(target), until: time + 4.5 };
      }
      if (consume('KeyE') && collectible) take(collectible, time);

      const camDist = pulsing.current ? 11.2 : boosting ? 9.2 : 7.6;
      _cam.copy(group.position).addScaledVector(_up, 1.15).addScaledVector(_forward, -camDist);
      chase(step, camDist === 11.2 ? 68 : boosting ? 60 : 52, 28);
      view.space = { target, dist, docking, collectible, closest, closestPlanet, time };
    }

    function flySurface(step, time) {
      const planet = surfacePlanet.current;
      if (!planet) return;
      targetRef.current = null;
      const layout = surfaceLayout(planet);

      if (onFoot.current) {
        thrustRef.current = 0;
        flyOnFoot(step, time, planet, layout);
        return;
      }

      let yaw = -mouse.dx * 0.003;
      const pitch = mouse.dy * 0.0018;
      if (keys.KeyA || keys.ArrowLeft) yaw += 1.2 * step;
      if (keys.KeyD || keys.ArrowRight) yaw -= 1.2 * step;
      group.rotateY(yaw);
      group.rotateX(pitch);
      _euler.setFromQuaternion(group.quaternion, 'YXZ');
      const clearancePreview = group.position.y - floorAt(group.position.x, group.position.z, planet);
      const pitchCap = clearancePreview < 8 ? 0.42 : 0.85;
      _euler.x = THREE.MathUtils.clamp(_euler.x, -0.2, pitchCap);
      if (landed.current) _euler.x = THREE.MathUtils.damp(_euler.x, 0, 6, step);
      _euler.z = 0;
      group.quaternion.setFromEuler(_euler);
      bank.current = THREE.MathUtils.damp(bank.current, THREE.MathUtils.clamp(-yaw * 4.5, -0.35, 0.35), 5, step);
      mouse.dx = 0;
      mouse.dy = 0;
      if (hullRef.current) hullRef.current.rotation.z = bank.current;

      _forward.set(0, 0, -1).applyQuaternion(group.quaternion);
      const boosting = !!(keys.ShiftLeft || keys.ShiftRight);
      let throttle = 0;
      if (keys.KeyW || keys.ArrowUp) throttle += 1;
      if (keys.KeyS || keys.ArrowDown) throttle -= 1;
      thrustRef.current = Math.max(0, throttle) * (boosting ? 1 : 0.7);

      const cruise = speeds.cruise * 0.85;
      let speed = 0;
      if (throttle > 0) speed = boosting ? cruise * 1.7 : cruise;
      else if (throttle < 0) speed = -cruise * 0.4;

      if (throttle !== 0) {
        _desired.copy(_forward).multiplyScalar(speed);
        velocity.current.lerp(_desired, 1 - Math.exp(-2.4 * step));
      } else {
        velocity.current.multiplyScalar(Math.exp(-0.7 * step));
      }

      if (!landed.current) velocity.current.y -= 7 * step;
      if (keys.Space) velocity.current.y += 22 * step;
      if (keys.ControlLeft || keys.ControlRight) velocity.current.y -= 18 * step;

      const groundHere = floorAt(group.position.x, group.position.z, planet);
      const low = group.position.y - groundHere < 6;
      if ((keys.KeyW || keys.Space) && low) velocity.current.y += 16 * step;
      if (boosting && throttle > 0 && low) velocity.current.y += 8 * step;
      velocity.current.y = THREE.MathUtils.clamp(velocity.current.y, -32, 36);

      group.position.addScaledVector(velocity.current, step);

      const horizontal = Math.hypot(velocity.current.x, velocity.current.z);
      const cushion = (throttle > 0 || keys.Space || horizontal > 8) ? 2.35 : 0.42;
      const floor = floorAt(group.position.x, group.position.z, planet) + cushion;
      if (group.position.y < floor) {
        group.position.y = floor;
        if (velocity.current.y < 0) velocity.current.y = 0;
      }

      const limit = 200;
      if (Math.abs(group.position.x) > limit) {
        group.position.x = Math.sign(group.position.x) * limit;
        velocity.current.x = 0;
      }
      if (Math.abs(group.position.z) > limit) {
        group.position.z = Math.sign(group.position.z) * limit;
        velocity.current.z = 0;
      }

      const clearance = group.position.y - floorAt(group.position.x, group.position.z, planet);
      if (clearance < 1.15 && horizontal < 5 && throttle <= 0 && !keys.Space) {
        landed.current = true;
        velocity.current.multiplyScalar(Math.exp(-2.2 * step));
      } else if (throttle > 0 || keys.Space || clearance > 3.2) {
        landed.current = false;
      }

      if (consume('KeyV') && landed.current) beginFoot(planet, _euler.y);

      if (!wasLanded.current && landed.current) landDip.current = 0.16;
      wasLanded.current = landed.current;
      if (consume('KeyC')) {
        surveyPlanet({ id: planet.id, name: planet.name, biomeLabel: planet.biomeLabel });
        note.current = { text: describePlanet(planet), until: time + 4.5 };
      }

      const collectible = nearestDeposit(layout.deposits, 11);
      if (consume('KeyE') && collectible) take(collectible, time);

      if (group.position.y > 118 && velocity.current.y > 1) {
        exitSurface();
        return;
      }

      const camDist = boosting ? 10.5 : 8.4;
      _cam.copy(group.position).addScaledVector(_up, 2.15).addScaledVector(_forward, -camDist);
      const camFloor = floorAt(_cam.x, _cam.z, planet) + 1.5;
      if (_cam.y < camFloor) _cam.y = camFloor;
      chase(step, 54, 22);
      view.surface = { planet, collectible, landed: landed.current, clearance, time };
    }

    function flyOnFoot(step, time, planet, layout) {
      const foot = footState.current;
      if (!foot) return;
      if (hullRef.current) hullRef.current.rotation.z = THREE.MathUtils.damp(bank.current = 0, 0, 4, step);
      const drive = footDrive.current;
      let jump = consume('Space');
      if (drive) {
        if (drive.jump && !jumpHeld.current) jump = true;
        jumpHeld.current = !!drive.jump;
      }
      const input = drive ? {
        forward: drive.forward > 0,
        back: drive.forward < 0 || drive.back,
        left: !!drive.left,
        right: !!drive.right,
        sprint: !!drive.sprint,
        crouch: !!drive.crouch,
        jump,
        holdJump: !!drive.jump,
        mouseX: 0,
        mouseY: 0,
      } : {
        forward: !!(keys.KeyW || keys.ArrowUp),
        back: !!(keys.KeyS || keys.ArrowDown),
        left: !!(keys.KeyA || keys.ArrowLeft),
        right: !!(keys.KeyD || keys.ArrowRight),
        sprint: !!(keys.ShiftLeft || keys.ShiftRight),
        crouch: !!(keys.ControlLeft || keys.ControlRight),
        jump,
        holdJump: !!keys.Space,
        mouseX: mouse.dx,
        mouseY: mouse.dy,
      };
      mouse.dx = 0;
      mouse.dy = 0;
      const moved = stepFoot(foot, step, input, planet);
      for (const ev of moved.events) {
        if (ev.type === 'step') playStep(ev.speed);
        else if (ev.type === 'jump') playJump(false);
        else if (ev.type === 'double') playJump(true);
        else if (ev.type === 'land') playLand(ev.impact);
      }
      playSlide(foot.slide > 0, moved.speed);

      const look = foot.view;
      camera.position.set(foot.pos.x + look.ox, foot.pos.y + look.oy, foot.pos.z + look.oz);
      camera.rotation.order = 'YXZ';
      camera.rotation.set(foot.pitch + look.pitch, foot.yaw, look.roll);
      camera.fov = look.fov;
      camera.updateProjectionMatrix();
      camReady.current = true;
      syncMotes(motesRef.current, foot);

      const shipDist = Math.hypot(foot.pos.x - group.position.x, foot.pos.z - group.position.z);
      if (consume('KeyV') && shipDist < 7) {
        onFoot.current = false;
        footDrive.current = null;
        camReady.current = false;
      }

      const collectible = nearestDeposit(layout.deposits, 4.5, foot.pos);
      if (consume('KeyE') && collectible) take(collectible, time);
      if (consume('KeyC')) {
        note.current = { text: describePlanet(planet), until: time + 4.5 };
      }

      velocity.current.set(foot.vel.x, foot.vel.y, foot.vel.z);
      view.foot = { planet, collectible, shipDist, time };
    }

    function nearestDeposit(list, range, from = group.position) {
      let found = null;
      let best = range;
      const depleted = playerRef.current.depleted || [];
      for (const deposit of list) {
        if (depleted.includes(deposit.id) || pending.current.has(deposit.id)) continue;
        const pos = deposit.position;
        const d = from.distanceTo(_body.set(pos[0], pos[1], pos[2]));
        if (d < best) {
          best = d;
          found = deposit;
        }
      }
      return found;
    }

    function take(deposit, time) {
      pending.current.add(deposit.id);
      const got = collectDeposit(deposit);
      if (!got) pending.current.delete(deposit.id);
      else note.current = { text: `+${got.amount} ${resourceLabel(deposit.commodityId)}`, until: time + 3.2 };
    }

    function killClosing() {
      _out.copy(_target).sub(group.position);
      if (_out.lengthSq() < 0.0001) return;
      _out.normalize();
      const closing = velocity.current.dot(_out);
      if (closing > 0) velocity.current.addScaledVector(_out, -closing);
    }

    function chase(step, fov, lookAhead) {
      if (!camReady.current) {
        camera.position.copy(_cam);
        camReady.current = true;
      } else {
        camera.position.lerp(_cam, 1 - Math.exp(-5.2 * step));
      }
      if (landDip.current > 0.001) {
        _cam.y -= landDip.current;
        landDip.current *= Math.exp(-7 * step);
      }
      _aim.copy(group.position).addScaledVector(_forward, lookAhead);
      camera.lookAt(_aim);
      camera.fov = THREE.MathUtils.damp(camera.fov, fov, 4, step);
      camera.updateProjectionMatrix();
    }

    function publish(time) {
      if (motesRef.current && !onFoot.current) motesRef.current.visible = false;
      hudClock.current += dt;
      if (hudClock.current < 0.1) return;
      hudClock.current = 0;
      if (note.current.text && note.current.until == null) note.current.until = time + 4.2;
      const text = note.current.until > time ? note.current.text : '';
      let prompt = '';
      let targetName = '';
      let targetDist = '';
      let atmo = 0;
      let atmoColor = 'transparent';

      if (mode.current === 'surface') {
        const planet = surfacePlanet.current;
        const sky = planet ? surfaceSky(planet) : null;
        targetName = planet?.name || '';
        if (onFoot.current) targetDist = 'On foot';
        else if (landed.current) targetDist = 'Landed';
        else targetDist = `${Math.max(0, Math.round(group.position.y))} m`;
        const foot = view.foot;
        const surface = view.surface;
        if (foot) {
          if (foot.shipDist < 6) prompt = 'Board  ·  V';
          else if (foot.collectible) prompt = 'Collect  ·  E';
        } else if (surface) {
          if (surface.collectible) prompt = 'Collect  ·  E';
          else if (landed.current) prompt = 'Exit  ·  V';
        }
        const haze = THREE.MathUtils.clamp((group.position.y - 18) / 220, 0, 0.35);
        atmo = onFoot.current ? haze * 0.35 : haze;
        atmoColor = sky?.fog || '#ffffff';
      } else if (view.space) {
        const { target, dist, docking, collectible, closest, closestPlanet } = view.space;
        targetName = target.name;
        targetDist = `${Math.max(0, Math.round(dist))} u`;
        if (docking) prompt = 'Dock  ·  F';
        else if (collectible) prompt = 'Collect  ·  E';
        else if (target.kind === 'gate' && dist < 110) prompt = 'Pulse to jump';
        if (closestPlanet) {
          const band = closestPlanet.radius * 1.55;
          if (closest < band) {
            atmo = THREE.MathUtils.clamp((band - closest) / (band * 0.34), 0, 1) * 0.94;
            atmoColor = closestPlanet.atmosphere;
          }
        }
      }

      onHud({
        systemName: env.name,
        targetName,
        targetDist,
        speed: Math.round(onFoot.current
          ? Math.hypot(velocity.current.x, velocity.current.z)
          : velocity.current.length()),
        pulse: pulsing.current,
        note: text,
        prompt,
        atmo,
        atmoColor,
        locked: document.pointerLockElement === gl.domElement,
        onFoot: onFoot.current,
      });
    }
  });

  return (
    <>
      <group ref={shipRef}>
        <group ref={hullRef} scale={1.28}>
          <ShipView manufacturer={ship.manufacturer} thrustRef={thrustRef} pulseRef={pulsing} />
        </group>
      </group>
      <group ref={personRef} visible={false}>
        <PilotFigure />
      </group>
    </>
  );
}

function initialHud(env) {
  const planet = env.planets[0];
  return {
    systemName: env.name,
    targetName: planet?.name || env.station.name,
    targetDist: '',
    speed: 0,
    pulse: false,
    note: '',
    prompt: '',
    atmo: 0,
    atmoColor: 'transparent',
    locked: false,
    onFoot: false,
  };
}

export default function FlightView({ player, onExit }) {
  const ship = SHIPS[player.ship];
  const system = SYSTEMS.find((s) => s.id === player.system_id);
  const env = useMemo(() => {
    if (!system) return null;
    const chart = generateSystem(system);
    return { ...chart, gates: makeGates(system.id) };
  }, [system]);
  const speeds = useMemo(() => flightProfile(ship?.stats.speed), [ship]);
  const [hud, setHud] = useState(() => (env ? initialHud(env) : initialHud({ name: '', station: { name: '' }, planets: [] })));
  const [logOpen, setLogOpen] = useState(false);
  const [scene, setScene] = useState(() => ({ mode: 'space', planetId: null, envId: env?.id || '' }));
  const onExitRef = useRef(onExit);
  const playerRef = useRef(player);
  const targetRef = useRef(null);
  const onSceneRef = useRef(() => {});
  onExitRef.current = onExit;
  playerRef.current = player;

  if (env && scene.envId !== env.id) {
    setScene({ mode: 'space', planetId: null, envId: env.id });
  }

  const onHud = useCallback((next) => {
    setHud((prev) => {
      for (const key of Object.keys(next)) {
        if (prev[key] !== next[key]) return { ...prev, ...next };
      }
      return prev;
    });
  }, []);

  const onScene = useCallback((next) => {
    setScene((prev) => {
      if (prev.mode === next.mode && prev.planetId === next.planetId) return prev;
      return { ...prev, mode: next.mode, planetId: next.planetId };
    });
  }, []);
  onSceneRef.current = onScene;

  const leave = useCallback(() => {
    document.exitPointerLock?.();
    onExitRef.current();
  }, []);

  useEffect(() => {
    const onKey = (e) => {
      if (e.code === 'KeyM') leave();
      if (e.code === 'KeyL') setLogOpen((open) => !open);
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [leave]);

  if (!ship || !env) return null;

  const depleted = player.depleted || [];
  const ground = scene.mode === 'surface'
    ? env.planets.find((planet) => planet.id === scene.planetId)
    : null;
  const sibling = ground ? env.planets.find((planet) => planet.id !== ground.id) : null;
  const sky = ground ? surfaceSky(ground) : env.sky;
  const discoveries = Object.entries(player.discoveries || {});

  return (
    <div className={`flight-root${hud.pulse ? ' pulsing' : ''}`}>
      <Canvas
        dpr={[1, 1.5]}
        camera={{ fov: 52, near: 0.12, far: 7000, position: [0, 8, 140] }}
        gl={{ antialias: true, alpha: false, powerPreference: 'high-performance' }}
        onCreated={({ gl }) => {
          gl.toneMapping = THREE.ACESFilmicToneMapping;
          gl.toneMappingExposure = 1.1;
          gl.shadowMap.enabled = true;
          gl.shadowMap.type = THREE.PCFSoftShadowMap;
        }}
      >
        <color attach="background" args={[sky.top]} />
        <Suspense fallback={null}>
          {ground ? (
            <SurfaceWorld planet={ground} depleted={depleted} sibling={sibling} />
          ) : (
            <>
              <hemisphereLight args={['#fff4ea', '#241820', 0.62]} />
              <ambientLight intensity={0.32} color="#f7f1e8" />
              <directionalLight position={[28, 46, 18]} intensity={0.85} color="#fff1df" />
              <Sky sky={env.sky} />
              <Starfield seed={hashString(env.id)} />
              <Sun color={env.sky.star} />
              <StationView position={env.station.position} />
              <SpaceTraffic />
              {env.planets.map((planet) => <Planet key={planet.id} planet={planet} />)}
              {env.gates.map((gate) => <GateView key={gate.id} position={gate.position} />)}
              <Belt rocks={env.belt} />
              {env.deposits.filter((d) => !depleted.includes(d.id)).map((d) => (
                <Deposit key={d.id} position={d.position} />
              ))}
            </>
          )}
          <InputBinder />
          <TargetMarker targetRef={targetRef} />
          <Pilot
            key={env.id}
            env={env}
            ship={ship}
            speeds={speeds}
            playerRef={playerRef}
            onExitRef={onExitRef}
            onHud={onHud}
            onSceneRef={onSceneRef}
            targetRef={targetRef}
          />
        </Suspense>
      </Canvas>
      <div className="atmo-wash" style={{ opacity: hud.atmo, background: hud.atmoColor }} />
      {logOpen && (
        <div className="discovery-log">
          <strong>Discoveries</strong>
          {discoveries.length === 0 && <div>Nothing logged yet.</div>}
          {discoveries.map(([id, entry]) => {
            const systemName = SYSTEMS.find((item) => item.id === entry.systemId)?.name || '';
            return (
              <div key={id}>
                {entry.name}
                <span>{entry.biome}{systemName ? ` · ${systemName}` : ''}</span>
              </div>
            );
          })}
        </div>
      )}
      <FlightHUD hud={hud} onExit={leave} onLog={() => setLogOpen((open) => !open)} />
    </div>
  );
}
