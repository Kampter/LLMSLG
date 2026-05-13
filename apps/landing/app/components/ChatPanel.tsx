'use client';

import { useCallback, useEffect, useRef, useState } from 'react';

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8000';

interface ChatMessage {
  role: 'user' | 'assistant';
  text: string;
  timestamp: string;
}

export default function ChatPanel() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({
      top: scrollRef.current.scrollHeight,
      behavior: 'smooth',
    });
  }, [messages]);

  const addMessage = useCallback((role: 'user' | 'assistant', text: string) => {
    setMessages((prev) => [...prev, { role, text, timestamp: new Date().toLocaleTimeString() }]);
  }, []);

  const sendMessage = async () => {
    const text = input.trim();
    if (!text || busy) return;

    setBusy(true);
    addMessage('user', text);
    setInput('');

    // Simple keyword-based routing (placeholder for LLM agent)
    const reply = await routeCommand(text);
    addMessage('assistant', reply);
    setBusy(false);
  };

  const routeCommand = async (text: string): Promise<string> => {
    const lower = text.toLowerCase();

    // Create account
    const createMatch = lower.match(/(?:create|make|新建|创建)\s+(?:account\s+)?([\w-]+)/);
    if (createMatch && createMatch[1]) {
      const userId = createMatch[1];
      try {
        const res = await fetch(`${API_BASE}/api/v1/player/create`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ user_id: userId }),
        });
        if (!res.ok) {
          const err = await res.json();
          return `Failed to create account for "${userId}": ${err.detail}`;
        }
        const data = await res.json();
        return `Account "${data.user_id}" created successfully! Starting resources: Energy ${data.energy}, Mineral ${data.mineral}`;
      } catch (e) {
        return `Error: ${e instanceof Error ? e.message : String(e)}`;
      }
    }

    // Get resources
    const getMatch = lower.match(
      /(?:get|check|view|show|查看|查询)\s+(?:resources?\s+(?:for\s+)?)?([\w-]+)/,
    );
    if (getMatch && getMatch[1]) {
      const userId = getMatch[1];
      try {
        const res = await fetch(`${API_BASE}/api/v1/player/${userId}/resources`);
        if (!res.ok) {
          const err = await res.json();
          return `Player "${userId}" not found: ${err.detail}`;
        }
        const data = await res.json();
        return (
          `${data.user_id} resources:\n` +
          `Energy: ${data.energy} / ${data.energy_capacity} (+${data.energy_rate}/s)\n` +
          `Mineral: ${data.mineral} / ${data.mineral_capacity} (+${data.mineral_rate}/s)`
        );
      } catch (e) {
        return `Error: ${e instanceof Error ? e.message : String(e)}`;
      }
    }

    // Consume resources
    const consumeMatch = lower.match(
      /(?:consume|spend|use|消耗|花费)\s+(\d+)\s+(?:energy|矿物)?.*?(?:for\s+)?([\w-]+)/i,
    );
    if (consumeMatch && consumeMatch[1] && consumeMatch[2]) {
      const amount = parseFloat(consumeMatch[1]);
      const userId = consumeMatch[2];
      try {
        const res = await fetch(`${API_BASE}/api/v1/player/${userId}/consume`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ energy_cost: amount, mineral_cost: 0 }),
        });
        if (!res.ok) {
          const err = await res.json();
          return `Failed: ${err.detail}`;
        }
        const data = await res.json();
        return `Consumed ${amount} energy. Remaining: Energy ${data.energy}, Mineral ${data.mineral}`;
      } catch (e) {
        return `Error: ${e instanceof Error ? e.message : String(e)}`;
      }
    }

    return (
      "I didn't understand that. Try:\n" +
      '"Create account alice"\n' +
      '"Check alice resources"\n' +
      '"Consume 20 energy for alice"'
    );
  };

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '400px',
        border: '1px solid #e5e7eb',
        borderRadius: '8px',
        background: '#fff',
      }}
    >
      <div
        style={{
          padding: '0.75rem 1rem',
          borderBottom: '1px solid #e5e7eb',
          fontWeight: 'bold',
          background: '#f9fafb',
          borderRadius: '8px 8px 0 0',
        }}
      >
        AI Commander
      </div>

      <div
        ref={scrollRef}
        style={{
          flex: 1,
          overflowY: 'auto',
          padding: '1rem',
          display: 'flex',
          flexDirection: 'column',
          gap: '0.75rem',
        }}
      >
        {messages.length === 0 && (
          <div style={{ color: '#9ca3af', textAlign: 'center', marginTop: '2rem' }}>
            Type a command to interact with the game server...
          </div>
        )}
        {messages.map((m, i) => (
          <div
            key={i}
            style={{
              alignSelf: m.role === 'user' ? 'flex-end' : 'flex-start',
              maxWidth: '80%',
              padding: '0.5rem 0.75rem',
              borderRadius: '12px',
              background: m.role === 'user' ? '#3b82f6' : '#f3f4f6',
              color: m.role === 'user' ? 'white' : '#1f2937',
              fontSize: '0.9rem',
              whiteSpace: 'pre-line',
            }}
          >
            <div style={{ fontSize: '0.7rem', opacity: 0.7, marginBottom: '0.25rem' }}>
              {m.role === 'user' ? 'You' : 'AI'} · {m.timestamp}
            </div>
            {m.text}
          </div>
        ))}
      </div>

      <div
        style={{
          display: 'flex',
          gap: '0.5rem',
          padding: '0.75rem',
          borderTop: '1px solid #e5e7eb',
        }}
      >
        <input
          type="text"
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && sendMessage()}
          placeholder="Type a command..."
          disabled={busy}
          style={{
            flex: 1,
            padding: '0.5rem',
            borderRadius: '6px',
            border: '1px solid #d1d5db',
            fontSize: '0.9rem',
          }}
        />
        <button
          onClick={sendMessage}
          disabled={busy || !input.trim()}
          style={{
            padding: '0.5rem 1rem',
            borderRadius: '6px',
            border: 'none',
            background: busy ? '#9ca3af' : '#3b82f6',
            color: 'white',
            cursor: busy ? 'not-allowed' : 'pointer',
            fontSize: '0.9rem',
          }}
        >
          {busy ? '...' : 'Send'}
        </button>
      </div>
    </div>
  );
}
