import React, { useState } from 'react';
import { SETUP_TIERS } from '../data/repoData';
import type { SetupTier } from '../data/repoData';
import type { Language } from '../data/translations';
import { TRANSLATIONS } from '../data/translations';

interface TierSetupWizardProps {
  language?: Language;
}

export const TierSetupWizard: React.FC<TierSetupWizardProps> = ({ language = 'en' }) => {
  const [activeTierId, setActiveTierId] = useState<string>('tier-a');
  const [terminalOutput, setTerminalOutput] = useState<string[]>([]);
  const [isRunningDiag, setIsRunningDiag] = useState<boolean>(false);
  const [copiedCmd, setCopiedCmd] = useState<string | null>(null);

  const activeTier: SetupTier = SETUP_TIERS.find(t => t.id === activeTierId) || SETUP_TIERS[0];
  const t = TRANSLATIONS[language].setup;
  const isEn = language === 'en';

  const runTerminalCommand = (cmdName: string) => {
    setIsRunningDiag(true);
    setTerminalOutput([`$ ${cmdName}`]);

    if (cmdName === 'npm run doctor') {
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking Node.js runtime (v20+ detected)... OK']), 400);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking GSD metaprompting framework... OK']), 800);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Checking dev-skills provenance manifest... OK']), 1200);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Verifying private overlay boundaries... CLEAN']), 1600);
      setTimeout(() => {
        setTerminalOutput(p => [...p, isEn ? '🎉 All doctor checks passed! Environment ready for agent execution.' : '🎉 ¡Comprobaciones doctor completadas! Entorno listo para ejecución de agentes.']);
        setIsRunningDiag(false);
      }, 2000);
    } else if (cmdName === 'npm run validate') {
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Validating skill frontmatter... 22 skills valid']), 400);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Verifying plugin JSON metadata alignment... ALIGNED']), 800);
      setTimeout(() => {
        setTerminalOutput(p => [...p, isEn ? '✔ Validation clean (0 errors, 0 warnings)' : '✔ Validación limpia (0 errores, 0 advertencias)']);
        setIsRunningDiag(false);
      }, 1200);
    } else {
      setTimeout(() => setTerminalOutput(p => [...p, isEn ? '✔ Running benchmark evaluation suite (15 cases)...' : '✔ Ejecutando suite de evals de benchmark (15 casos)...']), 500);
      setTimeout(() => setTerminalOutput(p => [...p, '✔ Recall: 100% | False Positives: 0%']), 1000);
      setTimeout(() => {
        setTerminalOutput(p => [...p, isEn ? '✔ Benchmark report generated. All 12 real defect cases caught.' : '✔ Reporte de benchmark generado. Todos los 12 casos con fallos fueron atrapados.']);
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
          <span className="num">{t.labelNum}</span>
          <span className="divider">⁄</span>
          <span>{t.labelTitle}</span>
        </p>
        <h2 className="section-title">{t.title}</h2>
      </header>

      <p className="section-intro">
        {t.intro}
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
            {isEn ? 'Included Features:' : 'Características Incluidas:'}
          </h4>
          <ul style={{ listStyle: 'disc', paddingLeft: '1.2rem', marginBottom: '1.5rem', color: 'var(--text-secondary)', fontSize: '0.88rem' }}>
            {activeTier.features.map((feat: string, i: number) => (
              <li key={i} style={{ marginBottom: '0.3rem' }}>{feat}</li>
            ))}
          </ul>

          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
            {isEn ? 'Setup Commands:' : 'Comandos de Instalación:'}
          </h4>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {activeTier.commands.map((cmd: string, i: number) => (
              <div
                key={i}
                className="code-block"
                onClick={() => copyCommand(cmd)}
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                  cursor: 'pointer',
                  fontSize: '0.82rem',
                  padding: '0.6rem 0.9rem'
                }}
                title={isEn ? 'Click to copy command' : 'Haz clic para copiar comando'}
              >
                <span>{cmd}</span>
                <span style={{ fontSize: '0.75rem', color: 'var(--accent)', marginLeft: '0.5rem', whiteSpace: 'nowrap' }}>
                  {copiedCmd === cmd ? (isEn ? 'Copied!' : '¡Copiado!') : (isEn ? 'Copy' : 'Copiar')}
                </span>
              </div>
            ))}
          </div>
        </div>

        {/* Live Environment Diagnostic Runner */}
        <div className="hm-card">
          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', color: 'var(--accent)', marginBottom: '1rem' }}>
            {isEn ? 'Interactive Diagnostic Console' : 'Consola Interactiva de Diagnóstico'}
          </h4>

          <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', marginBottom: '1.2rem' }}>
            {isEn ? 'Run diagnostic checks to verify skill manifests, plugin alignment, and privacy boundaries.' : 'Ejecuta comprobaciones de diagnóstico para verificar manifiestos, alineación de plugins y fronteras de privacidad.'}
          </p>

          <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1.2rem', flexWrap: 'wrap' }}>
            <button
              onClick={() => runTerminalCommand('npm run doctor')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.85rem' }}
            >
              <span>npm run doctor</span>
            </button>
            <button
              onClick={() => runTerminalCommand('npm run validate')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.85rem' }}
            >
              <span>npm run validate</span>
            </button>
            <button
              onClick={() => runTerminalCommand('npm run eval')}
              disabled={isRunningDiag}
              className="hm-btn-secondary"
              style={{ fontSize: '0.85rem' }}
            >
              <span>npm run eval</span>
            </button>
          </div>

          <div className="code-block" style={{ minHeight: '180px', maxHeight: '260px', overflowY: 'auto' }}>
            {terminalOutput.length > 0 ? (
              terminalOutput.map((line, i) => (
                <div key={i} style={{ color: line.startsWith('$') ? 'var(--accent)' : 'var(--text-primary)', marginBottom: '0.3rem' }}>
                  {line}
                </div>
              ))
            ) : (
              <span style={{ color: 'var(--text-muted)' }}>
                {isEn ? 'Select a diagnostic command above to simulate output...' : 'Selecciona un comando de diagnóstico arriba para simular su salida...'}
              </span>
            )}
          </div>
        </div>
      </div>
    </section>
  );
};
