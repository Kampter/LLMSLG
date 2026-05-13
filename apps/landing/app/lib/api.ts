export const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000';

export interface PlayerResources {
  user_id: string;
  energy: number;
  energy_capacity: number;
  energy_rate: number;
  mineral: number;
  mineral_capacity: number;
  mineral_rate: number;
  version: number;
  last_tick_at: string;
  created_at: string;
  updated_at: string;
}

export interface ChatMessage {
  role: 'user' | 'assistant';
  text: string;
  timestamp: string;
}

export async function createPlayer(userId: string): Promise<PlayerResources> {
  const res = await fetch(`${API_BASE}/api/v1/player/create`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ user_id: userId }),
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.detail ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<PlayerResources>;
}

export async function getResources(userId: string): Promise<PlayerResources> {
  const res = await fetch(`${API_BASE}/api/v1/player/${userId}/resources`);
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.detail ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<PlayerResources>;
}

export async function consumeResources(
  userId: string,
  energyCost: number,
  mineralCost?: number,
): Promise<PlayerResources> {
  const res = await fetch(`${API_BASE}/api/v1/player/${userId}/consume`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ energy_cost: energyCost, mineral_cost: mineralCost ?? 0 }),
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(err.detail ?? `HTTP ${res.status}`);
  }
  return res.json() as Promise<PlayerResources>;
}
