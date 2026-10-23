import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Canvas, useFrame, useThree } from '@react-three/fiber';
import * as THREE from 'three';
import { SYSTEMS } from '../../shared/galaxy.js';
import { SHIPS } from '../../shared/ships.js';
import { collectDeposit, surveyPlanet } from '../store';
import {
  describePlanet,
  flightProfile,
  generateSystem,
  hashString,
  resourceLabel,
} from '../../shared/universe.js';
import ShipHull from './flight/ShipHull';
import Planet from './flight/Planet';
import FlightHUD from './flight/FlightHUD';
import { Belt, Deposit, Sky, Starfield, Station, Sun, TargetMarker } from './flight/scenery';

const keys = Object.create(null);
const tapped = new Set();
const mouse = { dx: 0, dy: 0 };

const HOLD = ['Tab', 'KeyR', 'KeyC', 'KeyE', 'KeyF', 'Space'];

function bindInput(dom) {
  const onKeyDown = (e) => {
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

function InputBinder() {
  const dom = useThree((s) => s.gl.domElement);
  useEffect(() => bindInput(dom), [dom]);
  return null;
}

function Pilot({ env, ship, speeds, playerRef, onExitRef, onHud, targetRef }) {
  const shipRef = useRef();
  const hullRef = useRef();
  const velocity = useRef(new THREE.Vector3());
  const pulsing = useRef(false);
  const targetIndex = useRef(env.planets.length ? 1 : 0);
  const started = useRef(false);
  const camReady = useRef(false);
  const bank = useRef(0);
  const note = useRef({ text: '', until: 0 });
  const pending = useRef(new Set());
  const hudClock = useRef(0);
  const { camera, gl } = useThree();

  const bodies = useMemo(() => {
    const list = [{
      kind: 'station',
      name: env.station.name,
      position: env.station.position,
      radius: 6,
    }];
    for (const planet of env.planets) {
      list.push({
        kind: 'planet',
        id: planet.id,
        name: planet.name,
        biomeLabel: planet.biomeLabel,
        resources: planet.resources,
        position: planet.position,
        radius: planet.radius,
        atmosphere: planet.atmosphere,
      });
    }
    return list;
  }, [env]);

  const consume = (code) => {
    if (!tapped.has(code)) return false;
    tapped.delete(code);
    return true;
  };

  useFrame((_, delta) => {
    const group = shipRef.current;
    if (!group) return;
    const dt = Math.min(delta, 0.05);

    if (!started.current) {
      started.current = true;
      const spawn = env.spawn;
      group.position.set(spawn[0], spawn[1], spawn[2]);
      const first = env.planets[0];
      if (first) {
        _target.set(first.position[0], first.position[1], first.position[2]);
        _look.lookAt(group.position, _target, _up);
        group.quaternion.setFromRotationMatrix(_look);
      }
    }

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
      if (keys.KeyA || keys.ArrowLeft) yaw += 1.15 * dt;
      if (keys.KeyD || keys.ArrowRight) yaw -= 1.15 * dt;
      group.rotateY(yaw);
      group.rotateX(pitch);
      _euler.setFromQuaternion(group.quaternion, 'YXZ');
      _euler.x = THREE.MathUtils.clamp(_euler.x, -1.05, 1.05);
      _euler.z = 0;
      group.quaternion.setFromEuler(_euler);
      bank.current = THREE.MathUtils.damp(bank.current, THREE.MathUtils.clamp(-yaw * 5.5, -0.38, 0.38), 5, dt);
    } else {
      _look.lookAt(group.position, _target, _up);
      _quat.setFromRotationMatrix(_look);
      group.quaternion.slerp(_quat, 1 - Math.exp(-3.4 * dt));
      bank.current = THREE.MathUtils.damp(bank.current, 0, 4, dt);
    }
    mouse.dx = 0;
    mouse.dy = 0;
    if (hullRef.current) hullRef.current.rotation.z = bank.current;

    _forward.set(0, 0, -1).applyQuaternion(group.quaternion);
    const boosting = !!(keys.ShiftLeft || keys.ShiftRight);
    let throttle = 0;
    if (keys.KeyW || keys.ArrowUp) throttle += 1;
    if (keys.KeyS || keys.ArrowDown) throttle -= 1;

    let speed = 0;
    if (pulsing.current) speed = speeds.pulse;
    else if (throttle > 0) speed = boosting ? speeds.boost : speeds.cruise;
    else if (throttle < 0) speed = -speeds.cruise * 0.45;

    if (pulsing.current || throttle !== 0) {
      _desired.copy(_forward).multiplyScalar(speed);
      const rate = pulsing.current ? 1.3 : 2.5;
      velocity.current.lerp(_desired, 1 - Math.exp(-rate * dt));
    } else {
      velocity.current.multiplyScalar(Math.exp(-0.32 * dt));
    }
    if (keys.Space) velocity.current.y += 16 * dt;
    if (keys.ControlLeft || keys.ControlRight) velocity.current.y -= 16 * dt;

    group.position.addScaledVector(velocity.current, dt);

    const dist = group.position.distanceTo(_target);
    const stop = target.radius + 20;
    if (pulsing.current && dist < stop) {
      pulsing.current = false;
      _out.copy(_target).sub(group.position);
      if (_out.lengthSq() > 0.0001) {
        _out.normalize();
        const closing = velocity.current.dot(_out);
        if (closing > 0) velocity.current.addScaledVector(_out, -closing);
      }
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
      const min = planet.radius + 5;
      if (center < min && center > 0.001) {
        _out.copy(group.position).sub(_body).setLength(min);
        group.position.copy(_body).add(_out);
        _out.normalize();
        const into = velocity.current.dot(_out);
        if (into < 0) velocity.current.addScaledVector(_out, -into);
      }
    }

    if (!pulsing.current && closest < 42 && velocity.current.length() > 20) {
      velocity.current.setLength(20);
    }

    const docking = group.position.distanceTo(_body.set(
      env.station.position[0],
      env.station.position[1],
      env.station.position[2],
    )) < 34;

    let collectible = null;
    let collectDist = 14;
    const depleted = playerRef.current.depleted || [];
    for (const deposit of env.deposits) {
      if (depleted.includes(deposit.id) || pending.current.has(deposit.id)) continue;
      const d = group.position.distanceTo(_body.set(deposit.position[0], deposit.position[1], deposit.position[2]));
      if (d < collectDist) {
        collectDist = d;
        collectible = deposit;
      }
    }

    if (consume('KeyF') && docking) onExitRef.current();
    if (consume('KeyC') && target.kind === 'planet') {
      surveyPlanet(target);
      note.current = { text: describePlanet(target), until: _.clock.elapsedTime + 4.5 };
    }
    if (consume('KeyE') && collectible) {
      pending.current.add(collectible.id);
      const got = collectDeposit(collectible);
      if (!got) pending.current.delete(collectible.id);
      else note.current = { text: `+${got.amount} ${resourceLabel(collectible.commodityId)}`, until: _.clock.elapsedTime + 3.2 };
    }

    const camDist = pulsing.current ? 8.4 : boosting ? 6.6 : 5.2;
    _cam.copy(group.position).addScaledVector(_up, 0.85).addScaledVector(_forward, -camDist);
    if (!camReady.current) {
      camera.position.copy(_cam);
      camReady.current = true;
    } else {
      camera.position.lerp(_cam, 1 - Math.exp(-5.5 * dt));
    }
    _aim.copy(group.position).addScaledVector(_forward, 36);
    camera.lookAt(_aim);
    const fov = pulsing.current ? 70 : boosting ? 62 : 56;
    camera.fov = THREE.MathUtils.damp(camera.fov, fov, 4, dt);
    camera.updateProjectionMatrix();

    let atmo = 0;
    let atmoColor = 'transparent';
    if (closestPlanet) {
      const enter = closestPlanet.radius * 1.85;
      if (closest < enter) {
        atmo = THREE.MathUtils.clamp(1 - closest / enter, 0, 1) * 0.16;
        atmoColor = closestPlanet.atmosphere;
      }
    }

    hudClock.current += dt;
    if (hudClock.current > 0.1) {
      hudClock.current = 0;
      const now = _.clock.elapsedTime;
      const text = note.current.until > now ? note.current.text : '';
      let prompt = '';
      if (docking) prompt = 'Dock  ·  F';
      else if (collectible) prompt = 'Collect  ·  E';
      onHud({
        systemName: env.name,
        targetName: target.name,
        targetDist: `${Math.max(0, Math.round(dist))} u`,
        speed: Math.round(velocity.current.length()),
        pulse: pulsing.current,
        note: text,
        prompt,
        atmo,
        atmoColor,
        locked: document.pointerLockElement === gl.domElement,
      });
    }
  });

  return (
    <group ref={shipRef}>
      <group ref={hullRef}>
        <group scale={1.8}>
          <ShipHull manufacturer={ship.manufacturer} />
        </group>
      </group>
    </group>
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
  };
}

export default function FlightView({ player, onExit }) {
  const ship = SHIPS[player.ship];
  const system = SYSTEMS.find((s) => s.id === player.system_id);
  const env = useMemo(() => (system ? generateSystem(system) : null), [system]);
  const speeds = useMemo(() => flightProfile(ship?.stats.speed), [ship]);
  const [hud, setHud] = useState(() => (env ? initialHud(env) : initialHud({ name: '', station: { name: '' }, planets: [] })));
  const onExitRef = useRef(onExit);
  const playerRef = useRef(player);
  const targetRef = useRef(null);
  onExitRef.current = onExit;
  playerRef.current = player;

  const onHud = useCallback((next) => {
    setHud((prev) => {
      for (const key of Object.keys(next)) {
        if (prev[key] !== next[key]) return { ...prev, ...next };
      }
      return prev;
    });
  }, []);

  const leave = useCallback(() => {
    document.exitPointerLock?.();
    onExitRef.current();
  }, []);

  useEffect(() => {
    const onKey = (e) => {
      if (e.code === 'KeyM') leave();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [leave]);

  if (!ship || !env) return null;

  const depleted = player.depleted || [];

  return (
    <div className="flight-root">
      <Canvas
        dpr={[1, 1.5]}
        camera={{ fov: 56, near: 0.1, far: 6000, position: [0, 8, 140] }}
        gl={{ antialias: true, alpha: false }}
        onCreated={({ gl }) => {
          gl.toneMapping = THREE.ACESFilmicToneMapping;
          gl.toneMappingExposure = 1.08;
        }}
      >
        <color attach="background" args={[env.sky.top]} />
        <hemisphereLight args={['#fff4ea', '#241820', 0.62]} />
        <ambientLight intensity={0.32} color="#f7f1e8" />
        <directionalLight position={[28, 46, 18]} intensity={0.8} color="#fff1df" />
        <InputBinder />
        <Sky sky={env.sky} />
        <Starfield seed={hashString(env.id)} />
        <Sun color={env.sky.star} />
        <Station position={env.station.position} accent={env.sky.star} />
        {env.planets.map((planet) => <Planet key={planet.id} planet={planet} />)}
        <Belt rocks={env.belt} />
        {env.deposits.filter((d) => !depleted.includes(d.id)).map((d) => (
          <Deposit key={d.id} position={d.position} />
        ))}
        <TargetMarker targetRef={targetRef} />
        <Pilot
          env={env}
          ship={ship}
          speeds={speeds}
          playerRef={playerRef}
          onExitRef={onExitRef}
          onHud={onHud}
          targetRef={targetRef}
        />
      </Canvas>
      <div className="atmo-wash" style={{ opacity: hud.atmo, background: hud.atmoColor }} />
      <FlightHUD hud={hud} onExit={leave} />
    </div>
  );
}
