import ChatPanel from './components/ChatPanel';
import ResourceDisplay from './components/ResourceDisplay';

export default function HomePage() {
  return (
    <main style={{ padding: '2rem', maxWidth: '1200px', margin: '0 auto' }}>
      <h1>LLMSLG — Command Center</h1>
      <p style={{ color: '#6b7280', marginBottom: '1.5rem' }}>
        Manage your space base through natural language or direct controls.
      </p>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '2rem',
        }}
      >
        <section>
          <h2 style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>Resources</h2>
          <ResourceDisplay />
        </section>

        <section>
          <h2 style={{ fontSize: '1.1rem', marginBottom: '0.5rem' }}>AI Commander</h2>
          <ChatPanel />
        </section>
      </div>
    </main>
  );
}
