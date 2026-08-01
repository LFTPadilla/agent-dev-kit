import React, { useState } from 'react';
import { ArrowRight, Terminal, ShieldCheck } from 'lucide-react';

interface StepDetail {
  id: string;
  layerNum: string;
  layerName: string;
  title: string;
  desc: string;
  inputs: string[];
  skillsUsed: string[];
  outputs: string[];
  codeSnippet: string;
  refuses: string;
}

const WORKFLOW_STEPS: StepDetail[] = [
  {
    id: 'layer1-input',
    layerNum: '01',
    layerName: 'Capa 1: Direct Capabilities',
    title: '1. Ingesta de Solicitud y Ruteo de Skills',
    desc: 'El usuario emite un prompt o comando (ej. /pr-review o setup de proyecto). El agente consulta AGENTS.md y selecciona las skills adecuadas sin sobrecargar el contexto.',
    inputs: ['Prompt del Usuario', 'AGENTS.md (Reglas)', 'skill-provenance.json'],
    skillsUsed: ['context7-mcp', 'knip', 'human-writing-style'],
    outputs: ['Plan de trabajo GSD', 'Identificación de dependencias externas necesarias'],
    codeSnippet: `// Layer 1: Skill Dispatcher
const activeSkills = resolveSkills({
  query: "Auditar PR y verificar referencias",
  rules: parseAgentsMd()
});
// Loaded: ['context7-mcp', 'pr-review', 'knip']`,
    refuses: 'No inventa paquetes ni rutas no presentes en docs/external-deps.md'
  },
  {
    id: 'layer2-ship',
    layerNum: '02',
    layerName: 'Capa 2: Ship & Gate Safeguards',
    title: '2. Auditoría Adversarial & Filtro de Falsos Positivos',
    desc: 'Antes de entregar código o fusionar un PR, la Capa 2 ejecuta el protocolo /pr-review con un panel refutador que cuestiona cada posible vulnerabilidad.',
    inputs: ['Diff de Git', 'Reporte SAST de Semgrep', 'Reglas no-mistakes'],
    skillsUsed: ['/pr-review', 'semgrep', 'no-mistakes'],
    outputs: ['Reporte Refutado (0% Falsos Positivos)', 'Veredicto: BLOCKER / APPROVED'],
    codeSnippet: `// Layer 2: Adversarial Refuter Panel
for (const finding of sastReport.findings) {
  const isRefuted = refuterPanel.verify(finding, gitDiff);
  if (!isRefuted) gateVerdict.addBlocker(finding);
}`,
    refuses: 'No enmascara síntomas ni silencia excepciones en tests o builds'
  },
  {
    id: 'layer3-run',
    layerNum: '03',
    layerName: 'Capa 3: Run & Autonomy',
    title: '3. Aislamiento en tmux & Tutoría Socrática',
    desc: 'Para tareas complejas o de aprendizaje, la Capa 3 abre una sesión en tmux (personal-dev-tutor) o ejecuta un loop autónomo (gnhf / overnight-task-kit).',
    inputs: ['Sesión tmux isolated (tutor:0.0)', 'Contexto AST (Graphify)', 'Preguntas Socráticas'],
    skillsUsed: ['personal-dev-tutor', 'treehouse', 'gnhf'],
    outputs: ['Artefactos en .planning/ROADMAP.md', 'Registro de aprendizaje duradero'],
    codeSnippet: `// Layer 3: Autonomy & Socratic Tutor
const session = tmux.createSession('tutor');
session.runLane({
  role: 'Socratic Tutor',
  checkpoint: 'Verificar comprensión de @Transactional JPA'
});`,
    refuses: 'No edita código a espaldas del usuario en modo Tutor Socrático'
  }
];

export const AgentWorkflowDiagram: React.FC = () => {
  const [activeStepId, setActiveStepId] = useState<string>('layer1-input');

  const activeStep = WORKFLOW_STEPS.find(s => s.id === activeStepId) || WORKFLOW_STEPS[0];

  return (
    <div style={{ marginBottom: '2.5rem' }}>
      {/* Section Header Banner */}
      <div style={{
        background: 'var(--bg-surface)',
        border: '1px solid var(--border-color)',
        padding: '1rem 1.2rem',
        borderRadius: '6px',
        marginBottom: '1.5rem'
      }}>
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: '0.8rem', color: 'var(--accent)', textTransform: 'uppercase', fontWeight: 700 }}>
          Diagrama Funcional de Flujo de Agentes
        </span>
        <p style={{ fontSize: '0.9rem', color: 'var(--text-secondary)', marginTop: '0.2rem' }}>
          Selecciona cualquiera de las 3 capas para inspeccionar sus entradas, herramientas y lógica de ejecución.
        </p>
      </div>

      {/* Interactive Workflow Diagram Nodes */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
        gap: '1.2rem',
        marginBottom: '1.8rem'
      }}>
        {WORKFLOW_STEPS.map((step, idx) => {
          const isActive = activeStepId === step.id;
          return (
            <div
              key={step.id}
              onClick={() => setActiveStepId(step.id)}
              className="hm-card"
              style={{
                cursor: 'pointer',
                borderColor: isActive ? 'var(--accent)' : 'var(--border-color)',
                background: isActive ? 'var(--bg-subtle)' : 'var(--bg-surface)',
                boxShadow: isActive ? '0 0 0 1px var(--accent)' : 'none',
                transition: 'all 0.2s ease',
                position: 'relative'
              }}
            >
              {/* Step indicator badge */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.8rem' }}>
                <span style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.8rem',
                  fontWeight: 700,
                  color: isActive ? 'var(--accent)' : 'var(--text-muted)'
                }}>
                  {step.layerNum} ⁄ {step.layerName}
                </span>

                {isActive && (
                  <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', background: 'var(--accent)', color: '#fff', padding: '0.15rem 0.5rem', borderRadius: '3px' }}>
                    Activo
                  </span>
                )}
              </div>

              <h4 style={{ fontFamily: 'var(--font-display)', fontSize: '1.1rem', marginBottom: '0.5rem' }}>
                {step.title}
              </h4>

              <p style={{ fontSize: '0.85rem', color: 'var(--text-secondary)', lineHeight: 1.4 }}>
                {step.desc}
              </p>

              {idx < WORKFLOW_STEPS.length - 1 && (
                <div style={{ position: 'absolute', right: '-0.6rem', top: '50%', transform: 'translateY(-50%)', display: 'none' }}>
                  <ArrowRight size={16} style={{ color: 'var(--text-muted)' }} />
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Live Pipeline Terminal & Inspector Panel */}
      <div className="hm-card" style={{ borderLeft: '4px solid var(--accent)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap', gap: '0.5rem' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <Terminal size={18} style={{ color: 'var(--accent)' }} />
            <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', fontWeight: 700 }}>
              Inspección Funcional: {activeStep.title}
            </h4>
          </div>

          <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)' }}>
            [Capa: {activeStep.layerName}]
          </span>
        </div>

        {/* DNA Specs Grid */}
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '1.2rem', marginBottom: '1.2rem' }}>
          <div style={{ background: 'var(--bg-page)', padding: '0.8rem 1rem', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
            <div style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
              Entradas Ingeridas:
            </div>
            <ul style={{ fontSize: '0.85rem', color: 'var(--text-primary)', listStyle: 'disc', paddingLeft: '1rem' }}>
              {activeStep.inputs.map((inp, i) => (
                <li key={i}>{inp}</li>
              ))}
            </ul>
          </div>

          <div style={{ background: 'var(--bg-page)', padding: '0.8rem 1rem', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
            <div style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
              Skills & Reglas Invocadas:
            </div>
            <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap' }}>
              {activeStep.skillsUsed.map((sk, i) => (
                <span key={i} style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', background: 'var(--bg-subtle)', padding: '0.2rem 0.5rem', borderRadius: '3px', border: '1px solid var(--border-color)' }}>
                  {sk}
                </span>
              ))}
            </div>
          </div>

          <div style={{ background: 'var(--bg-page)', padding: '0.8rem 1rem', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
            <div style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
              Salidas Verificables:
            </div>
            <ul style={{ fontSize: '0.85rem', color: 'var(--accent)', fontWeight: 600, listStyle: 'disc', paddingLeft: '1rem' }}>
              {activeStep.outputs.map((out, i) => (
                <li key={i}>{out}</li>
              ))}
            </ul>
          </div>
        </div>

        {/* Code Execution Snippet */}
        <div style={{ marginBottom: '1rem' }}>
          <div style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', marginBottom: '0.4rem' }}>
            Lógica de Ejecución en Runtime:
          </div>
          <div className="code-block" style={{ margin: 0, fontSize: '0.85rem' }}>
            {activeStep.codeSnippet}
          </div>
        </div>

        {/* Refusal Policy Rule */}
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem', fontSize: '0.85rem', color: 'var(--text-muted)', background: 'var(--bg-page)', padding: '0.6rem 0.9rem', borderRadius: '4px', border: '1px solid var(--border-color)' }}>
          <ShieldCheck size={16} style={{ color: 'var(--accent)' }} />
          <span><strong>Regla de Rechazo (Refusal):</strong> {activeStep.refuses}</span>
        </div>
      </div>
    </div>
  );
};
