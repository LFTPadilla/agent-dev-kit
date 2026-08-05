import React, { useState } from 'react';
import { REPO_STATS } from '../data/repoData';
import { TRANSLATIONS } from '../data/translations';
import type { Language } from '../data/translations';
import { Copy, Check, Terminal } from 'lucide-react';

interface HeroSectionProps {
  setActiveTab: (tab: string) => void;
  language: Language;
}

export const HeroSection: React.FC<HeroSectionProps> = ({ setActiveTab, language }) => {
  const [copiedCmd, setCopiedCmd] = useState<string | null>(null);
  const t = TRANSLATIONS[language].hero;

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedCmd(text);
    setTimeout(() => setCopiedCmd(null), 2000);
  };

  const installCmd = 'npx skills add LFTPadilla/agent-dev-kit';

  return (
    <section style={{ marginBottom: '4rem', paddingTop: '1rem' }}>
      {/* Top Section Tag */}
      <p className="section-label">
        <span className="num">{t.labelNum}</span>
        <span className="divider">⁄</span>
        <span>{t.labelTitle}</span>
      </p>

      {/* Main Left-Biased Editorial Title */}
      <h1 className="section-title" style={{ fontSize: '3.4rem', maxWidth: '900px', marginBottom: '1.5rem' }}>
        {language === 'es' ? (
          <>Ingeniería de sistemas para <em style={{ fontStyle: 'italic', color: 'var(--accent)' }}>agentes de código</em>.</>
        ) : (
          <>Systems engineering for <em style={{ fontStyle: 'italic', color: 'var(--accent)' }}>coding agents</em>.</>
        )}
      </h1>

      <p className="section-intro" style={{ fontSize: '1.15rem', lineHeight: 1.6 }}>
        {t.subtitle}
      </p>

      {/* Quick 1-Liner Installer & Command Pills */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '0.8rem', marginBottom: '2.5rem', maxWidth: '800px' }}>
        <div 
          onClick={() => copyToClipboard(installCmd)}
          className="hm-card" 
          style={{ 
            display: 'flex', 
            justifyContent: 'space-between', 
            alignItems: 'center', 
            cursor: 'pointer',
            padding: '0.9rem 1.2rem',
            background: 'var(--bg-surface)',
            border: '1.5px solid var(--accent)',
            borderRadius: '6px'
          }}
          title={language === 'es' ? 'Haz clic para copiar comando de instalación' : 'Click to copy installation command'}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.8rem', fontFamily: 'var(--font-mono)', fontSize: '0.92rem' }}>
            <Terminal size={18} style={{ color: 'var(--accent)' }} />
            <span style={{ color: 'var(--text-muted)' }}>$</span>
            <span style={{ fontWeight: 600, color: 'var(--text-primary)' }}>{installCmd}</span>
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.8rem', color: 'var(--accent)', fontWeight: 600 }}>
            {copiedCmd === installCmd ? (
              <>
                <Check size={16} />
                <span>{language === 'es' ? '¡Copiado!' : 'Copied!'}</span>
              </>
            ) : (
              <>
                <Copy size={16} />
                <span>{language === 'es' ? 'Copiar Installer' : 'Copy Installer'}</span>
              </>
            )}
          </div>
        </div>

        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap' }}>
          <div className="hm-terminal-pill">
            <span className="prompt-mark">$</span>
            <span>git clone https://github.com/LFTPadilla/agent-dev-kit && ./bootstrap.sh</span>
          </div>

          <div className="hm-terminal-pill" style={{ borderColor: 'var(--border-color)' }}>
            <span className="prompt-mark">$</span>
            <span>/pr-review &lt;PR-URL&gt;</span>
          </div>
        </div>
      </div>

      {/* Action Buttons */}
      <div className="hero-buttons" style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginBottom: '3rem' }}>
        <button onClick={() => setActiveTab('tutor')} className="hm-btn-primary">
          <span>{t.getStarted}</span>
          <span>→</span>
        </button>

        <button onClick={() => setActiveTab('skills')} className="hm-btn-secondary">
          <span>{t.exploreSkills}</span>
        </button>

        <button onClick={() => setActiveTab('architecture')} className="hm-btn-secondary">
          <span>01 ⁄ {language === 'es' ? 'Arquitectura' : 'Architecture'}</span>
        </button>
      </div>

      {/* Technical DNA Table (Hallmark Signature Pattern) */}
      <div className="hm-card" style={{ maxWidth: '800px' }}>
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: '0.8rem', color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '0.6rem' }}>
          Kit Specification & Runtime DNA
        </div>

        <table className="dna-table">
          <tbody>
            <tr>
              <td className="dna-k">Invocation</td>
              <td className="dna-v"><code>./bootstrap.sh</code> · <code>npm run doctor</code></td>
            </tr>
            <tr>
              <td className="dna-k">Skills Catalog</td>
              <td className="dna-v">{REPO_STATS.skillsCount} curated skills (Orchestration, Quality, Security, QA, Docs)</td>
            </tr>
            <tr>
              <td className="dna-k">Ship Gate</td>
              <td className="dna-v">Adversarial <code>/pr-review</code> protocol + <code>no-mistakes</code> gate</td>
            </tr>
            <tr>
              <td className="dna-k">Evals Recall</td>
              <td className="dna-v"><strong style={{ color: 'var(--accent)' }}>{REPO_STATS.prReviewRecall}</strong> on planted bugs (vs 8% Semgrep baseline)</td>
            </tr>
            <tr>
              <td className="dna-k">False Positives</td>
              <td className="dna-v">0% (Refuter panel adversarial verification)</td>
            </tr>
            <tr>
              <td className="dna-k">Supported Runtimes</td>
              <td className="dna-v">Claude Code, Hermes Agent, Codex, Pi, Standalone CLI</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
  );
};
