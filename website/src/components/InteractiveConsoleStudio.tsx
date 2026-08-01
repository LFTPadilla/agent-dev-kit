import React, { useState, useEffect } from 'react';
import { Search, Sparkles } from 'lucide-react';

interface Preset {
  id: string;
  name: string;
  command: string;
  matchedSkills: { name: string; desc: string; match: string }[];
  toolOutput: string;
  sandboxCode1: string;
  sandboxCode2: string;
  status: string;
}

const PRESETS: Preset[] = [
  {
    id: 'pr-review',
    name: 'Auditoría /pr-review (Capa 2)',
    command: '/pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42',
    matchedSkills: [
      { name: 'PR_REVIEW_MULTI_LENS', desc: 'Auditoría multi-lente (seguridad, perf, calidad)', match: 'MATCH' },
      { name: 'SEMGREP_SAST_ENGINE', desc: 'Escaneo estático de firmas conocidas', match: 'MATCH' },
      { name: 'ADVERSARIAL_REFUTER', desc: 'Panel refutador de falsos positivos', match: 'ACTIVE' }
    ],
    toolOutput: '200 OK • 12 planted bugs caught • 0% False Positives',
    sandboxCode1: `// STEP 1: PARSE GIT DIFF & RUN SAST
const diff = git.getPullRequestDiff(42);
const sastHits = semgrep.scan(diff);
// Found 1 potential SQL injection sink in UserRepository.java`,
    sandboxCode2: `// STEP 2: ADVERSARIAL REFUTER VERIFICATION
const isRefuted = refuterPanel.checkSanitizers(sastHits[0]);
// Refutation FAILED -> Verified as REAL BLOCKER (100% Recall)`,
    status: 'PASS - BLOCKER CONFIRMED'
  },
  {
    id: 'tutor-session',
    name: 'Personal Dev Tutor Socrático (Capa 3)',
    command: 'personal-dev-tutor --concept SpringBoot-Transactional',
    matchedSkills: [
      { name: 'PERSONAL_DEV_TUTOR', desc: 'Tutor Socrático en tmux session tutor:0.0', match: 'MATCH' },
      { name: 'CONTEXT7_DOCS_MCP', desc: 'Documentación actualizada de Spring & JPA', match: 'MATCH' },
      { name: 'GRAPHIFY_AST_MAPPER', desc: 'Mapeo de AST y grafo de llamadas', match: 'ACTIVE' }
    ],
    toolOutput: '200 OK • Socratic Checkpoint 1 Active in tmux',
    sandboxCode1: `// STEP 1: INITIALIZE TMUX SESSION & CONTEXT
const tmux = new TmuxManager('tutor');
tmux.spawnPane('tutor-orchestrator');
const docs = context7.fetchDocs('spring-boot-jpa');`,
    sandboxCode2: `// STEP 2: SOCRATIC QUESTIONING LOOP
tutor.ask({
  question: "¿Por qué @Transactional no hace rollback en Checked Exceptions por defecto?",
  checkpoint: ".planning/TASK-01.md"
});`,
    status: 'ACTIVE - AWAITING USER RESPONSE'
  },
  {
    id: 'doctor-diag',
    name: 'Diagnóstico Doctor (Capa 1)',
    command: 'npm run doctor && npm run validate',
    matchedSkills: [
      { name: 'SKILL_PROVENANCE_CHECK', desc: 'Verificación de hash y licencias', match: 'MATCH' },
      { name: 'GSD_FRAMEWORK_VERIFY', desc: 'Metaprompting y spec compliance', match: 'MATCH' },
      { name: 'PRIVATE_OVERLAY_AUDIT', desc: 'Aislamiento de overlay corporativo', match: 'MATCH' }
    ],
    toolOutput: '200 OK • All 22 skills valid • Overlay isolated',
    sandboxCode1: `// STEP 1: VALIDATE SKILLS & METADATA
const provenance = loadProvenance();
for (const skill of provenance.skills) {
  validateFrontmatter(skill);
}`,
    sandboxCode2: `// STEP 2: VERIFY PRIVATE OVERLAY BOUNDARIES
const privateOverlay = checkDirectory(".private-agent-pack");
assertNoEmployerLeaks(privateOverlay);
// Result: 0 leaks, 100% isolated`,
    status: 'CLEAN - SYSTEM READY'
  }
];

export const InteractiveConsoleStudio: React.FC = () => {
  const [activePresetId, setActivePresetId] = useState<string>('pr-review');
  const [typedCommand, setTypedCommand] = useState<string>('');
  const [isTyping, setIsTyping] = useState<boolean>(false);

  const preset = PRESETS.find(p => p.id === activePresetId) || PRESETS[0];

  // Animated Typewriter effect when preset changes
  useEffect(() => {
    setIsTyping(true);
    setTypedCommand('');
    let idx = 0;
    const targetText = preset.command;

    const timer = setInterval(() => {
      if (idx < targetText.length) {
        setTypedCommand(targetText.slice(0, idx + 1));
        idx++;
      } else {
        setIsTyping(false);
        clearInterval(timer);
      }
    }, 28);

    return () => clearInterval(timer);
  }, [activePresetId]);

  return (
    <section style={{ marginBottom: '5rem' }} id="console-studio">
      <header>
        <p className="section-label">
          <span className="num">01</span>
          <span className="divider">⁄</span>
          <span>Live Studio & Console</span>
        </p>
        <h2 className="section-title">Agent Console & Execution Studio.</h2>
      </header>

      <p className="section-intro">
        Entorno dinámico inspirado en consolas de producción: Observa cómo se relacionan las búsquedas de skills, las ejecuciones en sandbox y las verificaciones adversariales en tiempo real.
      </p>

      {/* Preset Switcher Buttons */}
      <div style={{ display: 'flex', gap: '0.8rem', marginBottom: '1.8rem', flexWrap: 'wrap' }}>
        {PRESETS.map((p) => (
          <button
            key={p.id}
            onClick={() => setActivePresetId(p.id)}
            className={activePresetId === p.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
            style={{ fontSize: '0.85rem' }}
          >
            <span>{p.name}</span>
          </button>
        ))}
      </div>

      {/* Main Grid: Composio & Pi Style Interconnected Console Architecture */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(12, 1fr)', gap: '1.2rem' }}>
        
        {/* Left Satellite Panel: AGENT_SEARCH_TOOLS */}
        <div style={{ gridColumn: 'span 4', display: 'flex', flexDirection: 'column', gap: '1.2rem' }}>
          <div className="hm-card" style={{ background: '#0c0d10', color: '#e2e8f0', borderColor: '#1e293b' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
              <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.72rem', color: '#94a3b8', letterSpacing: '0.08em' }}>
                AGENT_SEARCH_SKILLS
              </span>
              <Search size={14} style={{ color: '#64748b' }} />
            </div>

            <div style={{ background: '#1e293b', padding: '0.5rem 0.8rem', borderRadius: '4px', display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '1rem' }}>
              <span style={{ color: '#64748b', fontSize: '0.8rem', fontFamily: 'var(--font-mono)' }}>Q</span>
              <span style={{ color: '#38bdf8', fontSize: '0.8rem', fontFamily: 'var(--font-mono)' }}>
                {preset.command.split(' ')[0]}
              </span>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginBottom: '1rem' }}>
              {preset.matchedSkills.map((sk, idx) => (
                <div key={idx} style={{ background: '#181e29', padding: '0.6rem 0.8rem', borderRadius: '4px', border: '1px solid #334155' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.2rem' }}>
                    <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.78rem', color: '#f8fafc', fontWeight: 700 }}>
                      {sk.name}
                    </span>
                    <span style={{ fontSize: '0.65rem', fontFamily: 'var(--font-mono)', background: sk.match === 'ACTIVE' ? 'var(--accent)' : '#0284c7', color: '#fff', padding: '0.1rem 0.4rem', borderRadius: '2px' }}>
                      {sk.match}
                    </span>
                  </div>
                  <p style={{ fontSize: '0.75rem', color: '#94a3b8', margin: 0 }}>
                    {sk.desc}
                  </p>
                </div>
              ))}
            </div>

            <div style={{ borderTop: '1px solid #1e293b', paddingTop: '0.8rem', fontSize: '0.75rem', color: '#64748b', fontFamily: 'var(--font-mono)' }}>
              <div>PLAN: Execute skill dispatcher → Refuter audit</div>
              <div style={{ color: '#f59e0b', marginTop: '0.2rem' }}>! Isolation: tmux session 'tutor' active</div>
            </div>
          </div>
        </div>

        {/* Central Console Box: Claude Cowork / Pi Terminal */}
        <div style={{ gridColumn: 'span 8', display: 'flex', flexDirection: 'column', gap: '1.2rem' }}>
          <div className="hm-card" style={{ background: '#0a0a0c', color: '#e2e8f0', borderColor: 'var(--accent)', position: 'relative' }}>
            
            {/* Terminal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.2rem', borderBottom: '1px solid #1e293b', paddingBottom: '0.8rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                <Sparkles size={16} style={{ color: 'var(--accent)' }} />
                <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', fontWeight: 700, color: '#f8fafc' }}>
                  agent-dev-kit v0.12.0 (Claude Code / Hermes Harness)
                </span>
              </div>
              <span style={{ fontSize: '0.72rem', fontFamily: 'var(--font-mono)', color: '#4ade80' }}>
                ● Status: Connected
              </span>
            </div>

            {/* Typewriter Input Prompt Display */}
            <div style={{ background: '#14171f', padding: '1rem 1.2rem', borderRadius: '6px', border: '1px solid #283044', marginBottom: '1.2rem' }}>
              <div style={{ fontSize: '0.78rem', fontFamily: 'var(--font-mono)', color: '#94a3b8', marginBottom: '0.4rem' }}>
                ~/Development/agent-dev-kit (main) $
              </div>
              <div style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', color: '#38bdf8', fontWeight: 600 }}>
                {typedCommand}<span style={{ opacity: isTyping ? 1 : 0, transition: 'opacity 0.2s' }}>█</span>
              </div>
            </div>

            {/* Tool Execution Status Cards */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem', marginBottom: '1.2rem' }}>
              <div style={{ background: '#14171f', padding: '0.8rem 1rem', borderRadius: '4px', border: '1px solid #283044' }}>
                <span style={{ fontSize: '0.7rem', fontFamily: 'var(--font-mono)', color: '#94a3b8', display: 'block', marginBottom: '0.3rem' }}>
                  EXECUTION_STATUS
                </span>
                <span style={{ fontSize: '0.85rem', fontFamily: 'var(--font-mono)', color: '#4ade80', fontWeight: 700 }}>
                  ✔ {preset.toolOutput}
                </span>
              </div>

              <div style={{ background: '#14171f', padding: '0.8rem 1rem', borderRadius: '4px', border: '1px solid #283044' }}>
                <span style={{ fontSize: '0.7rem', fontFamily: 'var(--font-mono)', color: '#94a3b8', display: 'block', marginBottom: '0.3rem' }}>
                  GATE_VERDICT
                </span>
                <span style={{ fontSize: '0.85rem', fontFamily: 'var(--font-mono)', color: 'var(--accent)', fontWeight: 700 }}>
                  {preset.status}
                </span>
              </div>
            </div>

            {/* Bottom Sandbox Live Code Panels */}
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '1rem' }}>
              <div>
                <div style={{ fontSize: '0.72rem', fontFamily: 'var(--font-mono)', color: '#94a3b8', marginBottom: '0.4rem' }}>
                  SANDBOX: STEP 1
                </div>
                <div className="code-block" style={{ margin: 0, fontSize: '0.78rem', background: '#111319', borderColor: '#283044' }}>
                  {preset.sandboxCode1}
                </div>
              </div>

              <div>
                <div style={{ fontSize: '0.72rem', fontFamily: 'var(--font-mono)', color: '#94a3b8', marginBottom: '0.4rem' }}>
                  SANDBOX: STEP 2 (REFUTER / TUTOR)
                </div>
                <div className="code-block" style={{ margin: 0, fontSize: '0.78rem', background: '#111319', borderColor: '#283044' }}>
                  {preset.sandboxCode2}
                </div>
              </div>
            </div>

          </div>
        </div>

      </div>
    </section>
  );
};
