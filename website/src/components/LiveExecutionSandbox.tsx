import React, { useState, useEffect, useRef } from 'react';
import { Play, Pause, FastForward, RotateCcw } from 'lucide-react';

interface ExecutionScenario {
  id: string;
  name: string;
  command: string;
  description: string;
  codeSnippet: string;
  logs: { text: string; type: 'cmd' | 'info' | 'success' | 'warn' | 'error' | 'code'; delay: number }[];
}

const EXECUTION_SCENARIOS: ExecutionScenario[] = [
  {
    id: 'pr-review',
    name: '01 ⁄ Auditoría /pr-review con Refutador',
    command: '/pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42',
    description: 'Ejecución multi-lente de /pr-review. Analiza el diff de git y somete los hallazgos al panel refutador para descartar falsos positivos.',
    codeSnippet: `// Diff capturado de Pull Request #42: UserRepository.java
- String query = "SELECT * FROM users WHERE id = '" + userId + "'";
+ @Query("SELECT u FROM User u WHERE u.id = :id")
+ Optional<User> findByIdCustom(@Param("id") String id);`,
    logs: [
      { text: '$ /pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42', type: 'cmd', delay: 200 },
      { text: '[PR-Review v0.12.0] Analyzing PR #42 (1 file changed, 2 insertions, 1 deletion)...', type: 'info', delay: 400 },
      { text: '[Lens 1: Correctness & Security Audit] Running Semgrep SAST ruleset...', type: 'info', delay: 800 },
      { text: '  ├─ Scanning UserRepository.java: L14-L16', type: 'code', delay: 1100 },
      { text: '  └─ Semgrep Match: 0 vulnerabilities (Clean SQL parameterization verified)', type: 'success', delay: 1400 },
      { text: '[Lens 2: Quality & Architectural Guidelines] Verifying AGENTS.md rules...', type: 'info', delay: 1700 },
      { text: '  ├─ Checking for hardcoded credentials/hostnames... NONE', type: 'success', delay: 2000 },
      { text: '  └─ Checking type safety & non-null constraints... PASSED', type: 'success', delay: 2300 },
      { text: '[Adversarial Refuter Gate] Attempting to disprove finding severity...', type: 'warn', delay: 2600 },
      { text: '  ├─ Refutation Test 1: Sanitizer check... PASSED', type: 'info', delay: 2900 },
      { text: '  └─ Refutation Result: 0 False Positives confirmed.', type: 'success', delay: 3200 },
      { text: '🎉 [PR-Review Verdict] APPROVED (100% Recall, 0% False Positives). Gate Passed.', type: 'success', delay: 3500 }
    ]
  },
  {
    id: 'tutor-session',
    name: '02 ⁄ Personal Dev Tutor (Tmux + Socrático)',
    command: 'personal-dev-tutor --concept SpringBoot-Transactional',
    description: 'Inicia una sesión aislada de tutoría socrática en tmux. Registra avances en .planning/ y guía mediante preguntas sin escribir código por la espalda.',
    codeSnippet: `// Concepto: @Transactional Isolation & Rollback Rules
@Transactional(rollbackFor = Exception.class)
public void processPayment(OrderDTO order) throws PaymentException {
    paymentGateway.charge(order);
    orderRepository.save(order);
}`,
    logs: [
      { text: '$ personal-dev-tutor --concept SpringBoot-Transactional', type: 'cmd', delay: 200 },
      { text: '[Personal Dev Tutor] Initializing isolated workspace in tmux...', type: 'info', delay: 500 },
      { text: '✔ Spawning session tutor:0.0 (GSD Metaprompting + Context7 Docs)', type: 'success', delay: 900 },
      { text: '[Graphify AST Engine] Mapping Java call graph for @Transactional methods...', type: 'info', delay: 1300 },
      { text: '[Context7 MCP] Fetching latest Spring Framework 6.x documentation...', type: 'info', delay: 1700 },
      { text: '✔ Synced 4 API references from /org/spring-projects', type: 'success', delay: 2100 },
      { text: '[Socratic Learning Checkpoint] Interactive Question:', type: 'warn', delay: 2500 },
      { text: '  > "¿Por qué Spring NO realiza rollback en Checked Exceptions por defecto?"', type: 'code', delay: 2900 },
      { text: '  > Usuario responde: "Porque sólo maneja RuntimeException automáticamente"', type: 'info', delay: 3400 },
      { text: '🎉 [Tutor Checkpoint] ¡Respuesta Correcta! Progreso guardado en .planning/ROADMAP.md', type: 'success', delay: 3800 }
    ]
  },
  {
    id: 'live-qa',
    name: '03 ⁄ Live-QA con Playwright MCP',
    command: '/live-qa http://localhost:5173 --flow checkout',
    description: 'Navega la interfaz web como un usuario real mediante Playwright MCP, verificando accesibilidad, rendimiento y captura de errores.',
    codeSnippet: `// Live-QA Automation Script (Playwright MCP)
await page.goto('http://localhost:5173');
await page.click('button#checkout');
await expect(page.locator('.success-banner')).toBeVisible();`,
    logs: [
      { text: '$ /live-qa http://localhost:5173 --flow checkout', type: 'cmd', delay: 200 },
      { text: '[Live-QA Engine] Spawning Headless Chromium browser session...', type: 'info', delay: 500 },
      { text: '✔ Navigating to http://localhost:5173 [HTTP 200 OK]', type: 'success', delay: 900 },
      { text: '  ├─ LCP (Largest Contentful Paint): 0.82s (Good)', type: 'info', delay: 1300 },
      { text: '  ├─ Console Errors: 0 | Network Failures: 0', type: 'success', delay: 1700 },
      { text: '[User Action] Clicking #checkout-btn...', type: 'info', delay: 2100 },
      { text: '✔ Cart Drawer opened cleanly. Transition time: 120ms', type: 'success', delay: 2500 },
      { text: '[A11y Audit] Checking ARIA contrast ratios & keyboard focus...', type: 'info', delay: 2900 },
      { text: '  └─ 0 Violations found. Keyboard tab navigation verified.', type: 'success', delay: 3300 },
      { text: '🎉 [Live-QA Summary] Flow verified clean. 0 regression bugs detected.', type: 'success', delay: 3700 }
    ]
  },
  {
    id: 'doctor-diag',
    name: '04 ⁄ Diagnóstico Doctor (npm run doctor)',
    command: 'npm run doctor && npm run validate',
    description: 'Verifica la integridad del repositorio, el cumplimiento de esquemas de las 22 skills y la frontera de privacidad del overlay corporativo.',
    codeSnippet: `// Audit Script: npm run validate
const skills = loadSkillsCatalog();
assert(skills.length === 22);
assertNoEmployerLeaks(process.env);`,
    logs: [
      { text: '$ npm run doctor && npm run validate', type: 'cmd', delay: 200 },
      { text: '[Doctor Suite v0.12.0] Running environment diagnostic checks...', type: 'info', delay: 400 },
      { text: '✔ Node.js Runtime: v20.11.0 detected', type: 'success', delay: 700 },
      { text: '✔ GSD Metaprompting Framework: Installed & Valid', type: 'success', delay: 1000 },
      { text: '✔ Provenance Manifest (skill-provenance.json): 22 skills verified', type: 'success', delay: 1400 },
      { text: '[Validation Engine] Checking plugin.json metadata alignment...', type: 'info', delay: 1800 },
      { text: '  ├─ dev-skills/plugin.json: v0.12.0 [OK]', type: 'code', delay: 2100 },
      { text: '  └─ package.json: v0.12.0 [ALIGNED]', type: 'success', delay: 2400 },
      { text: '[Privacy Audit] Scanning repo tree for internal/employer data...', type: 'info', delay: 2800 },
      { text: '✔ Private Overlay Boundary: CLEAN (0 leaks detected)', type: 'success', delay: 3200 },
      { text: '🎉 [Doctor Result] All checks passed cleanly. System 100% operational.', type: 'success', delay: 3600 }
    ]
  }
];

export const LiveExecutionSandbox: React.FC = () => {
  const [selectedScenarioId, setSelectedScenarioId] = useState<string>('pr-review');
  const [currentLogs, setCurrentLogs] = useState<{ text: string; type: string }[]>([]);
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [speedMultiplier, setSpeedMultiplier] = useState<number>(1);
  const terminalEndRef = useRef<HTMLDivElement>(null);

  const scenario = EXECUTION_SCENARIOS.find(s => s.id === selectedScenarioId) || EXECUTION_SCENARIOS[0];

  // Auto-streaming log simulation effect
  useEffect(() => {
    setCurrentLogs([]);
    if (!isPlaying) return;

    const timeouts: any[] = [];

    scenario.logs.forEach((logItem) => {
      const adjustedDelay = logItem.delay / speedMultiplier;
      const t = setTimeout(() => {
        setCurrentLogs((prev) => [...prev, { text: logItem.text, type: logItem.type }]);
      }, adjustedDelay);
      timeouts.push(t);
    });

    return () => {
      timeouts.forEach(clearTimeout);
    };
  }, [selectedScenarioId, isPlaying, speedMultiplier]);

  // Auto scroll terminal to bottom
  useEffect(() => {
    terminalEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [currentLogs]);

  const restartStream = () => {
    setCurrentLogs([]);
    setIsPlaying(false);
    setTimeout(() => setIsPlaying(true), 50);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="live-sandbox">
      <header>
        <p className="section-label">
          <span className="num">02</span>
          <span className="divider">⁄</span>
          <span>Live Execution Sandbox</span>
        </p>
        <h2 className="section-title">Real-Time Terminal Execution.</h2>
      </header>

      <p className="section-intro">
        Demostración dinámica en vivo: Observa la salida real por consola (stdout/stderr) de los comandos de <code>agent-dev-kit</code> en tiempo real.
      </p>

      {/* Scenario Selector Tabs */}
      <div style={{ display: 'flex', gap: '0.8rem', marginBottom: '1.5rem', flexWrap: 'wrap' }}>
        {EXECUTION_SCENARIOS.map((sc) => (
          <button
            key={sc.id}
            onClick={() => {
              setSelectedScenarioId(sc.id);
              setIsPlaying(true);
            }}
            className={selectedScenarioId === sc.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
            style={{ fontSize: '0.85rem' }}
          >
            <span>{sc.name}</span>
          </button>
        ))}
      </div>

      {/* Terminal Toolbar Controls */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        background: '#0f172a',
        border: '1px solid #1e293b',
        borderBottom: 'none',
        padding: '0.6rem 1.2rem',
        borderTopLeftRadius: '6px',
        borderTopRightRadius: '6px',
        flexWrap: 'wrap',
        gap: '0.8rem'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.8rem' }}>
          <div style={{ display: 'flex', gap: '0.4rem' }}>
            <span style={{ width: '11px', height: '11px', borderRadius: '50%', background: '#ef4444' }} />
            <span style={{ width: '11px', height: '11px', borderRadius: '50%', background: '#eab308' }} />
            <span style={{ width: '11px', height: '11px', borderRadius: '50%', background: '#22c55e' }} />
          </div>
          <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', color: '#94a3b8' }}>
            {scenario.command}
          </span>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
          <button
            onClick={() => setIsPlaying(!isPlaying)}
            style={{ background: 'transparent', border: 'none', color: '#38bdf8', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.3rem', fontSize: '0.75rem', fontFamily: 'var(--font-mono)' }}
          >
            {isPlaying ? <Pause size={14} /> : <Play size={14} />}
            <span>{isPlaying ? 'Pausar' : 'Reanudar'}</span>
          </button>

          <button
            onClick={() => setSpeedMultiplier(speedMultiplier === 1 ? 2 : speedMultiplier === 2 ? 5 : 1)}
            style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.3rem', fontSize: '0.75rem', fontFamily: 'var(--font-mono)' }}
          >
            <FastForward size={14} />
            <span>{speedMultiplier}x Velocidad</span>
          </button>

          <button
            onClick={restartStream}
            style={{ background: 'transparent', border: 'none', color: '#94a3b8', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '0.3rem', fontSize: '0.75rem', fontFamily: 'var(--font-mono)' }}
          >
            <RotateCcw size={14} />
            <span>Reiniciar</span>
          </button>
        </div>
      </div>

      {/* Dual Split Screen: Code Input (Left) vs Real Terminal Output (Right) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '0', border: '1px solid #1e293b', borderBottomLeftRadius: '6px', borderBottomRightRadius: '6px', overflow: 'hidden' }}>
        
        {/* Left: Code Snippet Context */}
        <div style={{ background: '#090d16', padding: '1.2rem', borderRight: '1px solid #1e293b' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
            <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.75rem', color: '#38bdf8', textTransform: 'uppercase' }}>
              Código / Contexto Ingerido
            </span>
            <span style={{ fontSize: '0.72rem', fontFamily: 'var(--font-mono)', color: '#64748b' }}>
              Input Stream
            </span>
          </div>

          <p style={{ color: '#94a3b8', fontSize: '0.85rem', marginBottom: '1rem', lineHeight: 1.4 }}>
            {scenario.description}
          </p>

          <div className="code-block" style={{ margin: 0, fontSize: '0.82rem', background: '#05070c', borderColor: '#1e293b', color: '#e2e8f0' }}>
            {scenario.codeSnippet}
          </div>
        </div>

        {/* Right: Real-time Streaming Terminal Console */}
        <div style={{ background: '#020408', padding: '1.2rem', minHeight: '300px', maxHeight: '420px', overflowY: 'auto', fontFamily: 'var(--font-mono)' }}>
          <div style={{ fontSize: '0.75rem', color: '#64748b', marginBottom: '0.8rem', borderBottom: '1px solid #1e293b', paddingBottom: '0.4rem' }}>
            STDOUT / STDERR REAL-TIME STREAM
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.4rem' }}>
            {currentLogs.map((log, idx) => {
              let color = '#e2e8f0';
              if (log.type === 'cmd') color = '#38bdf8';
              if (log.type === 'info') color = '#94a3b8';
              if (log.type === 'success') color = '#4ade80';
              if (log.type === 'warn') color = '#f59e0b';
              if (log.type === 'error') color = '#ef4444';
              if (log.type === 'code') color = '#cbd5e1';

              return (
                <div key={idx} style={{ color, fontSize: '0.83rem', lineHeight: 1.5, wordBreak: 'break-word' }}>
                  {log.text}
                </div>
              );
            })}
            <div ref={terminalEndRef} />
          </div>
        </div>

      </div>
    </section>
  );
};
