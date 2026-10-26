// Short synthesized cues. No samples: a step, a jump whoosh, a land thud, a slide scrape.

let ctx = null;
let noise = null;
let slideSource = null;
let slideGain = null;
let lastStep = 0;

function context() {
  if (typeof window === 'undefined') return null;
  const AudioCtx = window.AudioContext || window.webkitAudioContext;
  if (!AudioCtx) return null;
  if (!ctx) ctx = new AudioCtx();
  return ctx;
}

export function ensureFootAudio() {
  const audio = context();
  if (audio && audio.state === 'suspended') audio.resume().catch(() => {});
  return audio;
}

function brown(audio) {
  if (noise) return noise;
  const seconds = 1;
  const count = Math.floor(audio.sampleRate * seconds);
  const buffer = audio.createBuffer(1, count, audio.sampleRate);
  const data = buffer.getChannelData(0);
  let held = 0;
  for (let i = 0; i < count; i += 1) {
    const white = Math.random() * 2 - 1;
    held = held * 0.97 + white * 0.03;
    data[i] = held * 3.2;
  }
  noise = buffer;
  return buffer;
}

function burst(audio, { freq, to, q, vol, dur, type = 'bandpass' }) {
  const source = audio.createBufferSource();
  source.buffer = brown(audio);
  const filter = audio.createBiquadFilter();
  filter.type = type;
  filter.frequency.setValueAtTime(freq, audio.currentTime);
  if (to) filter.frequency.exponentialRampToValueAtTime(Math.max(40, to), audio.currentTime + dur);
  filter.Q.value = q;
  const gain = audio.createGain();
  const t = audio.currentTime;
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(Math.max(0.0001, vol), t + Math.min(0.02, dur * 0.25));
  gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  source.connect(filter);
  filter.connect(gain);
  gain.connect(audio.destination);
  source.start(t);
  source.stop(t + dur + 0.02);
}

export function playStep(speed) {
  const audio = context();
  if (!audio || audio.state !== 'running') return;
  const now = audio.currentTime;
  if (now - lastStep < 0.12) return;
  lastStep = now;
  const vol = Math.min(0.05, 0.012 + speed * 0.0032);
  burst(audio, { freq: 140 + speed * 28, to: 90, q: 0.8, vol, dur: 0.07, type: 'lowpass' });
}

export function playScan() {
  const audio = context();
  if (!audio) return;
  if (audio.state === 'suspended') audio.resume().catch(() => {});
  if (audio.state !== 'running') return;
  const t = audio.currentTime;
  const osc = audio.createOscillator();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(280, t);
  osc.frequency.exponentialRampToValueAtTime(920, t + 0.22);
  const gain = audio.createGain();
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.04, t + 0.03);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.42);
  osc.connect(gain);
  gain.connect(audio.destination);
  osc.start(t);
  osc.stop(t + 0.44);
  burst(audio, { freq: 160, to: 70, q: 0.7, vol: 0.028, dur: 0.32, type: 'lowpass' });
}

export function playJump(doubleJump) {
  const audio = context();
  if (!audio || audio.state !== 'running') return;
  const t = audio.currentTime;
  const osc = audio.createOscillator();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(doubleJump ? 240 : 170, t);
  osc.frequency.exponentialRampToValueAtTime(doubleJump ? 620 : 440, t + 0.12);
  const gain = audio.createGain();
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(doubleJump ? 0.05 : 0.038, t + 0.025);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
  osc.connect(gain);
  gain.connect(audio.destination);
  osc.start(t);
  osc.stop(t + 0.18);
  burst(audio, {
    freq: doubleJump ? 900 : 640,
    to: 220,
    q: 0.6,
    vol: doubleJump ? 0.04 : 0.028,
    dur: 0.14,
  });
}

export function playLand(impact) {
  const audio = context();
  if (!audio || audio.state !== 'running') return;
  const t = audio.currentTime;
  const osc = audio.createOscillator();
  osc.type = 'sine';
  osc.frequency.setValueAtTime(96, t);
  osc.frequency.exponentialRampToValueAtTime(42, t + 0.11);
  const gain = audio.createGain();
  const vol = Math.min(0.09, 0.02 + impact * 0.005);
  gain.gain.setValueAtTime(vol, t);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.14);
  osc.connect(gain);
  gain.connect(audio.destination);
  osc.start(t);
  osc.stop(t + 0.16);
  burst(audio, { freq: 180, to: 60, q: 0.5, vol: vol * 0.6, dur: 0.09, type: 'lowpass' });
}

export function playSlide(active, speed) {
  const audio = context();
  if (!audio || audio.state !== 'running') return;
  if (active && !slideSource) {
    slideSource = audio.createBufferSource();
    slideSource.buffer = brown(audio);
    slideSource.loop = true;
    const filter = audio.createBiquadFilter();
    filter.type = 'bandpass';
    filter.frequency.value = 520;
    filter.Q.value = 0.45;
    slideGain = audio.createGain();
    slideGain.gain.value = 0.0001;
    slideSource.connect(filter);
    filter.connect(slideGain);
    slideGain.connect(audio.destination);
    slideSource.start();
  }
  if (!slideGain) return;
  const vol = active ? Math.min(0.04, 0.016 + speed * 0.0016) : 0.0001;
  slideGain.gain.setTargetAtTime(vol, audio.currentTime, active ? 0.04 : 0.09);
}
