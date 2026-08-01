import React, { useState } from 'react';
import { SETUP_TIERS } from '../data/repoData';
import type { SetupTier } from '../data/repoData';

export const TierSetupWizard: React.FC = () => {
  const [activeTierId, setActiveTierId] = useState<string>('tier-a');
  const [terminalOutput, setTerminalOutput] = useState<string[]>([]);
  const [isRunningDiag, setIsRunningDiag] = useState<boolean>(false);
  const [copiedCmd, setCopiedCmd] = useState<string | null>(null);

  const activeTier: SetupTier = SETUP_TIERS.find(t => t.id === activeTierId) || SETUP_TIERS[0];

  const runTerminalCommand = (cmdName: string) => {
    setIsRunningDiag(true);
    setTerminalOutput([`$ ${cmdName}`]);

    if (cmdName === 'npm run doctor') {
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking Node.js runtime (v20+ detected)... OK']), 400);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking GSD metaprompting framework... OK']), 800);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking dev-skills provenance manifest... OK']), 1200);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Verifying private overlay boundaries... CLEAN']), 1600);
      setTimeout(() => {
        setTerminalOutput(p => [...p, '🎉 All doctor checks passed! Environment ready for agent execution.']);
        setIsRunningDiag(false);
      }, 2000);
    } else if (cmdName === 'npm run validate') {
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Validating skill frontmatter... 22 skills valid']), 400);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Verifying plugin JSON metadata alignment... ALIGNED']), 800);
      setTimeout(() => {
        setTerminalOutput(p => [...p, '✔ Validation clean (0 errors, 0 warnings)']);
        setIsRunningDiag(false);
      }, 1200);
    } else {
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Running benchmark evaluation suite (15 cases)...']), 500);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Recall: 100% | False Positives: 0%']), 1000);
      setTimeout(() => {
        setTerminalOutput(p => [...p, '✔ Benchmark report generated. All 12 planted bugs caught.']);
        setIsRunningDiag(false);
      }, 1500);
    }
  };

  const copyCommand = (cmd: string) => {
    navigator.clipboard.writeText(cmd);
    setCopiedCmd(cmd);
    setTimeout(() => setCopiedCmd(null), 2000);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="install">
      <header>
        <p className="section-label">
          <span className="num">05</span>
          <span className="divider">⁄</span>
          <span>Instalación & Tiers</span>
        </p>
        <h2 className="section-title">Setup Tiers.</h2>
      </header>

      <p className="section-intro">
        Elige el nivel de integración adecuado para tu flujo de trabajo: desde skills ligeras en Codex hasta la suite completa de orquestación en tmux.
      </p>

      {/* Tier Switcher Buttons */}
      <div style={{ display: 'flex', gap: '0.8rem', marginBottom: '2.5rem', flexWrap: 'wrap' }}>
        {SETUP_TIERS.map((tier: SetupTier) => (
          <button
            key={tier.id}
            onClick={() => setActiveTierId(tier.id)}
            className={activeTierId === tier.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
            style={{ fontSize: '0.88rem' }}
          >
            <span>{tier.title}</span>
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.8rem' }}>
        {/* Tier Details Card */}
        <div className="hm-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
            <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '1.4rem' }}>
              {activeTier.title}
            </h3>
            <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--accent)', background: 'var(--bg-subtle)', padding: '0.2rem 0.6rem', borderRadius: '3px' }}>
              {activeTier.recommendedFor}
            </span>
          </div>

          <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
            {activeTier.subtitle}
          </p>

          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
            Características Incluidas:
          </h4>
          <ul style={{ listStyle: 'disc', paddingLeft: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-secondary)', fontSize: '0.88rem' }}>
            {activeTier.features.map((feat: string, i: number) => (
              <li key={i} style={{ marginBottom: '0.3rem' }}>{feat}</li>
            ))}
          </ul>

          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
            Comandos de Bootstrap:
          </h4>
          <div className="code-block" style={{ marginBottom: '1.2rem' }}>
            {activeTier.commands.join('\n')}
          </div>

          <button
            onClick={() => copyCommand(activeTier.commands.join('\n'))}
            className="hm-btn-primary"
            style={{ width: '100%', fontSize: '0.85rem' }}
          >
            <span>{copiedCmd === activeTier.commands.join('\n') ? '¡Comandos Copiados!' : 'Copiar Comandos de Instalación'}</span>
          </button>
        </div>

        {/* Live Terminal Diagnostic Simulator */}
        <div className="hm-card">
          <h3 style={{ fontFamily: 'var(--font-mono)', fontSize: '1.1rem', color: 'var(--accent)', marginBottom: '1rem' }}>
            Terminal de Diagnóstico (`npm run doctor`)
          </h3>

          <p style={{ fontSize: '0.88rem', color: 'var(--text-secondary)', marginBottom: '1.2rem' }}>
            Ejecuta diagnósticos simulados en tiempo real para verificar el estado de las herramientas y skills del entorno:
          </p>

          <div style={{ display: 'flex', gap: '0.6rem', marginBottom: '1.2rem', flexWrap: 'wrap' }}>
            <button
              onClick={() => runTerminalCommand('npm run doctor')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.8rem' }}
            >
              <span>Ejecutar Doctor</span>
            </button>
            <button
              onClick={() => runTerminalCommand('npm run validate')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.8rem' }}
            >
              <span>Validar Skills</span>
            </button>
            <button
              onClick={() => runTerminalCommand('npm run eval:semgrep')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.8rem' }}
            >
              <span>Correr Evals</span>
            </button>
          </div>

          <div className="code-block" style={{ minHeight: '180px', background: '#0a0a0c', color: '#e2e8f0', borderColor: 'var(--border-strong)' }}>
            {terminalOutput.length === 0 ? (
              <span style={{ color: '#64748b' }}>Haga clic en cualquiera de los botones de arriba para simular la ejecución en la terminal...</span>
            ) : (
              terminalOutput.map((line, idx) => (
                <div key={idx} style={{
                  color: line.startsWith('$') ? '#38bdf8' : line.includes('✔') || line.includes('🎉') ? '#4ade80' : '#e2e8f0',
                  marginBottom: '0.3rem'
                }}>
                  {line}
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
