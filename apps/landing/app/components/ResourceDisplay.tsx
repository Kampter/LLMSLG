'use client';

import { useCallback, useEffect, useState } from 'react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000';

interface PlayerResources {
  user_id: string;
  energy: number;
  energy_capacity: number;
  energy_rate: number;
  mineral: number;
  mineral_capacity: number;
  mineral_rate: number;
  last_tick_at: string;
}

export default function ResourceDisplay() {
  const [userId, setUserId] = useState('');
  const [resources, setResources] = useState<PlayerResources | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchResources = useCallback(async (uid: string) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/api/v1/player/${uid}/resources`);
      if (!res.ok) {
        const body = await res.text();
        throw new Error(`HTTP ${res.status}: ${body}`);
      }
      const data = (await res.json()) as PlayerResources;
      setResources(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
      setResources(null);
    } finally {
      setLoading(false);
    }
  }, []);

  const createPlayer = async () => {
    if (!userId.trim()) {
      setError('Please enter a user ID');
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`${API_BASE}/api/v1/player/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ user_id: userId.trim() }),
      });
      if (!res.ok) {
        const body = await res.text();
        throw new Error(`HTTP ${res.status}: ${body}`);
      }
      const data = (await res.json()) as PlayerResources;
      setResources(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setLoading(false);
    }
  };

  // Auto-refresh every second to show resource growth
  useEffect(() => {
    if (!resources?.user_id) return;
    const interval = setInterval(() => {
      fetchResources(resources.user_id);
    }, 1000);
    return () => clearInterval(interval);
  }, [resources?.user_id, fetchResources]);

  return (
    <div>
      <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1rem' }}>
        <input
          type="text"
          placeholder="Enter user ID..."
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          style={{
            padding: '0.5rem',
            fontSize: '1rem',
            borderRadius: '4px',
            border: '1px solid #ccc',
            flex: 1,
          }}
        />
        <button
          onClick={createPlayer}
          disabled={loading}
          style={{
            padding: '0.5rem 1rem',
            fontSize: '1rem',
            borderRadius: '4px',
            border: 'none',
            background: '#3b82f6',
            color: 'white',
            cursor: loading ? 'not-allowed' : 'pointer',
            opacity: loading ? 0.6 : 1,
          }}
        >
          Create Player
        </button>
        <button
          onClick={() => fetchResources(userId.trim())}
          disabled={loading || !userId.trim()}
          style={{
            padding: '0.5rem 1rem',
            fontSize: '1rem',
            borderRadius: '4px',
            border: '1px solid #ccc',
            background: 'white',
            cursor: loading || !userId.trim() ? 'not-allowed' : 'pointer',
            opacity: loading || !userId.trim() ? 0.6 : 1,
          }}
        >
          Load
        </button>
      </div>

      {loading && <p>Loading...</p>}
      {error && <p style={{ color: 'red', marginBottom: '1rem' }}>Error: {error}</p>}

      {resources && (
        <div
          style={{
            display: 'flex',
            gap: '2rem',
            fontSize: '1.2rem',
            padding: '1rem',
            border: '1px solid #e5e7eb',
            borderRadius: '8px',
            background: '#f9fafb',
          }}
        >
          <div>
            <span style={{ color: '#f59e0b', fontWeight: 'bold' }}>Energy</span>
            <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>
              {resources.energy.toFixed(2)}
              <span
                style={{
                  fontSize: '0.8rem',
                  color: '#6b7280',
                  fontWeight: 'normal',
                }}
              >
                / {resources.energy_capacity}
              </span>
            </div>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>+{resources.energy_rate}/s</div>
          </div>
          <div>
            <span style={{ color: '#3b82f6', fontWeight: 'bold' }}>Mineral</span>
            <div style={{ fontSize: '2rem', fontWeight: 'bold' }}>
              {resources.mineral.toFixed(2)}
              <span
                style={{
                  fontSize: '0.8rem',
                  color: '#6b7280',
                  fontWeight: 'normal',
                }}
              >
                / {resources.mineral_capacity}
              </span>
            </div>
            <div style={{ fontSize: '0.75rem', color: '#6b7280' }}>+{resources.mineral_rate}/s</div>
          </div>
          <div
            style={{
              fontSize: '0.8rem',
              color: '#6b7280',
              alignSelf: 'flex-end',
            }}
          >
            Player: {resources.user_id}
          </div>
        </div>
      )}
    </div>
  );
}
