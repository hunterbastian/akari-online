import { useState, useSyncExternalStore } from 'react';
import { getState, subscribe, login } from './store';
import GameScreen from './components/GameScreen';

function useStore() {
  return useSyncExternalStore(subscribe, getState);
}

function LoginScreen() {
  const [name, setName] = useState('');

  const handleLaunch = () => login((name.trim() || 'Pilot').slice(0, 20));

  return (
    <div className="login-screen">
      <h1>Akari</h1>
      <p className="subtitle">Online</p>
      <input
        type="text"
        placeholder="Pilot name"
        maxLength={20}
        autoFocus
        value={name}
        onChange={e => setName(e.target.value)}
        onKeyDown={e => e.key === 'Enter' && handleLaunch()}
      />
      <button onClick={handleLaunch}>Enter</button>
    </div>
  );
}

export default function App() {
  const state = useStore();

  return (
    <>
      {state.screen === 'login' && <LoginScreen />}
      {state.screen === 'game' && <GameScreen state={state} />}
      {/* Toasts */}
      {state.toasts.map(t => (
        <div key={t.id} className={`toast${t.isError ? ' error' : ''}`}>
          {t.text}
        </div>
      ))}
    </>
  );
}

export { useStore };
