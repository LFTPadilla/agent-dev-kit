import React, { useState } from 'react';
import { EVAL_CASES } from '../data/repoData';

export const PrReviewEvalLab: React.FC = () => {
  const [selectedCaseId, setSelectedCaseId] = useState<string>('eval-01');
  const [isSimulatingRefuter, setIsSimulatingRefuter] = useState<boolean>(false);
  const [refuterLogs, setRefuterLogs] = useState<string[]>([]);

  const selectedCase = EVAL_CASES.find(c => c.id === selectedCaseId) || EVAL_CASES[0];

  const runAdversarialRefuterSimulation = () => {
    setIsSimulatingRefuter(true);
    setRefuterLogs([`[Adversarial Gate] Analyzing finding: ${selectedCase.name}`]);

    setTimeout(() => {
      setRefuterLogs(prev => [...prev, `[Lens 1: Correctness Audit] Flagged untrusted input sink`]);
    }, 500);

    setTimeout(() => {
      setRefuterLogs(prev => [...prev, `[Refuter Panel] Attempting to disprove finding: Checking sanitizers...`]);
    }, 1000);

    setTimeout(() => {
      if (selectedCase.type === 'planted_bug') {
        setRefuterLogs(prev => [
          ...prev,
          `[Refuter Panel] Refutation FAILED: No sanitizer present. Finding CONFIRMED as Real Vulnerability.`,
          `[Gate Verdict] BLOCKER: ${selectedCase.category} verified.`
        ]);
      } else {
        setRefuterLogs(prev => [
          ...prev,
          `[Refuter Panel] Refutation SUCCESS: ORM parameterization verified.`,
          `[Gate Verdict] DISMISSED: Clean code confirmed (0% False Positive).`
        ]);
      }
      setIsSimulatingRefuter(false);
    }, 1600);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="evals">
      <header>
        <p className="section-label">
          <span className="num">03</span>
          <span className="divider">⁄</span>
          <span>Evals & /pr-review</span>
        </p>
        <h2 className="section-title">Measured AI Systems.</h2>
      </header>

      <p className="section-intro">
        15 casos reales evaluados (12 vulnerabilidades sembradas + 3 controles limpios). Medido en recall y en tasa de falsos positivos.
      </p>

      {/* Benchmark Scoreboard Table */}
      <div className="hm-card" style={{ marginBottom: '2.5rem' }}>
        <h3 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', color: 'var(--accent)', textTransform: 'uppercase', marginBottom: '1rem' }}>
          Resultados de Benchmark (Recall & False-Positive Rate)
        </h3>

        <table className="dna-table">
          <thead>
            <tr style={{ color: 'var(--text-muted)' }}>
              <td style={{ fontWeight: 700 }}>Capa de Revisión</td>
              <td style={{ fontWeight: 700 }}>Bugs Atrapados</td>
              <td style={{ fontWeight: 700 }}>Recall</td>
              <td style={{ fontWeight: 700 }}>Falsos Pos.</td>
              <td style={{ fontWeight: 700 }}>Reproducción</td>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td>Semgrep SAST (Public Packs)</td>
              <td>1 / 12</td>
              <td style={{ color: 'var(--text-muted)' }}>8%</td>
              <td>0 / 3</td>
              <td><code>npm run eval:semgrep</code></td>
            </tr>
            <tr style={{ background: 'var(--bg-subtle)' }}>
              <td style={{ fontWeight: 700, color: 'var(--accent)' }}>/pr-review (Protocolo Multi-Lente)</td>
              <td style={{ fontWeight: 700 }}>12 / 12</td>
              <td style={{ fontWeight: 800, color: 'var(--accent)' }}>100%</td>
              <td style={{ fontWeight: 700 }}>0 / 3</td>
              <td><code>/pr-review &lt;PR-URL&gt;</code></td>
            </tr>
          </tbody>
        </table>
      </div>

      {/* Interactive Case Inspector & Refuter Simulator */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.8rem' }}>
        <div className="hm-card">
          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', marginBottom: '1rem' }}>
            Seleccionar Caso del Eval Set
          </h4>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem' }}>
            {EVAL_CASES.map((item) => (
              <button
                key={item.id}
                onClick={() => {
                  setSelectedCaseId(item.id);
                  setRefuterLogs([]);
                }}
                className={selectedCaseId === item.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
                style={{ justifyContent: 'space-between', width: '100%', fontSize: '0.85rem' }}
              >
                <span>{item.name}</span>
                <span style={{ fontSize: '0.75rem', opacity: 0.8 }}>{item.category}</span>
              </button>
            ))}
          </div>
        </div>

        <div className="hm-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
            <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1.1rem', color: 'var(--accent)' }}>
              {selectedCase.name}
            </h4>
            <button
              onClick={runAdversarialRefuterSimulation}
              disabled={isSimulatingRefuter}
              className="hm-btn-primary"
              style={{ fontSize: '0.75rem', padding: '0.3rem 0.8rem' }}
            >
              {isSimulatingRefuter ? 'Verificando...' : 'Simular Refutador'}
            </button>
          </div>

          <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.2rem' }}>
            {selectedCase.description}
          </p>

          <div className="code-block" style={{ marginBottom: '1.2rem' }}>
            {selectedCase.snippet}
          </div>

          {/* Refuter Simulation Output Terminal */}
          {refuterLogs.length > 0 && (
            <div className="code-block" style={{ marginBottom: '1.2rem', borderColor: 'var(--accent)', background: 'var(--bg-subtle)' }}>
              {refuterLogs.map((log, i) => (
                <div key={i} style={{ color: log.includes('Vulnerability') ? '#ef4444' : log.includes('DISMISSED') ? 'var(--accent)' : 'var(--text-primary)' }}>
                  {log}
                </div>
              ))}
            </div>
          )}

          <table className="dna-table">
            <tbody>
              <tr>
                <td className="dna-k">Semgrep SAST</td>
                <td className="dna-v">{selectedCase.semgrepResult}</td>
              </tr>
              <tr>
                <td className="dna-k">/pr-review</td>
                <td className="dna-v" style={{ color: 'var(--accent)', fontWeight: 700 }}>{selectedCase.prReviewResult}</td>
              </tr>
              <tr>
                <td className="dna-k">Diagnóstico</td>
                <td className="dna-v">{selectedCase.reason}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
};
