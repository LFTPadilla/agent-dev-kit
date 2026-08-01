import React from 'react';
import { Cpu } from 'lucide-react';
import { REPO_STATS } from '../data/repoData';

export const Footer: React.FC = () => {
  return (
    <footer style={{
      borderTop: '1px solid rgba(255, 255, 255, 0.08)',
      background: 'rgba(4, 7, 13, 0.95)',
      padding: '3rem 1.5rem',
      color: 'var(--text-secondary)'
    }}>
      <div style={{
        maxWidth: '1280px',
        margin: '0 auto',
        display: 'flex',
        flexWrap: 'wrap',
        justifyContent: 'space-between',
        alignItems: 'center',
        gap: '1.5rem'
      }}>
        {/* Brand info */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', marginBottom: '0.4rem' }}>
            <Cpu size={20} color="var(--accent-primary)" />
            <span style={{ fontWeight: 800, color: '#ffffff', fontSize: '1.1rem' }}>agent-dev-kit</span>
            <span className="badge badge-indigo" style={{ fontSize: '0.75rem' }}>v{REPO_STATS.version}</span>
          </div>
          <p style={{ fontSize: '0.85rem', color: 'var(--text-muted)' }}>
            Systems engineering for coding agents — layered concerns, measurable gates, and honest boundaries.
          </p>
        </div>

        {/* Attribution & License */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '1.5rem', fontSize: '0.85rem' }}>
          <span>MIT License</span>
          <a
            href="https://github.com/LFTPadilla/agent-dev-kit/blob/main/ATTRIBUTION.md"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: '#a5b4fc', textDecoration: 'none' }}
          >
            ATTRIBUTION.md
          </a>
          <a
            href="https://github.com/LFTPadilla/agent-dev-kit"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: '#a5b4fc', textDecoration: 'none', display: 'flex', alignItems: 'center', gap: '0.4rem' }}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 0C5.37 0 0 5.37 0 12c0 5.31 3.435 9.795 8.205 11.385.6.105.825-.255.825-.57 0-.285-.015-1.23-.015-2.235-3.015.555-3.795-.735-4.035-1.41-.135-.345-.72-1.41-1.23-1.695-.42-.225-1.02-.78-.015-.795.945-.015 1.62.87 1.845 1.23 1.08 1.815 2.805 1.305 3.495.99.105-.78.42-1.305.765-1.605-2.67-.3-5.46-1.335-5.46-5.925 0-1.305.465-2.385 1.23-3.225-.12-.3-.54-1.53.12-3.18 0 0 1.005-.315 3.3 1.23.96-.27 1.98-.405 3-.405s2.04.135 3 .405c2.295-1.56 3.3-1.23 3.3-1.23.66 1.65.24 2.88.12 3.18.765.84 1.23 1.905 1.23 3.225 0 4.605-2.805 5.625-5.475 5.925.435.375.81 1.095.81 2.22 0 1.605-.015 2.895-.015 3.3 0 .315.225.69.825.57A12.02 12.02 0 0024 12c0-6.63-5.37-12-12-12z"/>
            </svg>
            <span>GitHub Repository</span>
          </a>
        </div>
      </div>
    </footer>
  );
};
