import React, { useState } from 'react';
import confetti from 'canvas-confetti';

interface Scenario {
  id: string;
  title: string;
  concept: string;
  steps: {
    question: string;
    hint: string;
    answer: string;
    explanation: string;
  }[];
}

const SCENARIOS: Scenario[] = [
  {
    id: 'spring-boot',
    title: 'Caso A: Rollback en Spring Boot @Transactional',
    concept: 'Excepciones comprobadas vs no comprobadas en JPA',
    steps: [
      {
        question: 'Si una función con `@Transactional` lanza una `Exception` estándar comprobada (Checked Exception), ¿la transacción hace rollback automático?',
        hint: 'Piensa en la diferencia por defecto entre RuntimeException y Exception en Spring Framework.',
        answer: 'No',
        explanation: 'Por defecto, Spring solo hace rollback automático para `RuntimeException` y `Error`. Para excepciones comprobadas se requiere `@Transactional(rollbackFor = Exception.class)`.'
      },
      {
        question: '¿Qué sucede si un método `@Transactional` es llamado internamente desde la misma clase (Self-invocation)?',
        hint: 'Recuerda que Spring AOP usa Dynamic Proxies.',
        answer: 'No se aplica el proxy',
        explanation: 'El proxy de Spring AOP es bypass-eado en llamadas internas (`this.method()`), por lo que la transacción no se inicia a menos que se use AspectJ weaving directo.'
      }
    ]
  },
  {
    id: 'react-leak',
    title: 'Caso B: Memory Leak en useEffect Event Listener',
    concept: 'Limpieza de Subscripciones y closures en React',
    steps: [
      {
        question: '¿Por qué `window.addEventListener("resize", handleResize)` dentro de `useEffect` sin una función de retorno produce un Memory Leak?',
        hint: 'Analiza la acumulación de event listeners en cada re-render.',
        answer: 'Acumula listeners duplicados',
        explanation: 'En cada re-render, se suscribe un nuevo listener a `window` sin remover el anterior, consumiendo memoria e invocando múltiples handlers en cascada.'
      },
      {
        question: 'Si `handleResize` captura una variable de estado sin `useCallback` ni refs, ¿qué problema de closures ocurre?',
        hint: 'Piensa en el "stale closure" de JavaScript.',
        answer: 'Stale closure',
        explanation: 'El listener guardará la referencia del estado en el instante que fue creado (Stale Closure), leyendo valores desactualizados en renders posteriores.'
      }
    ]
  }
];

export const PersonalTutorSim: React.FC = () => {
  const [selectedScenarioId, setSelectedScenarioId] = useState<string>('spring-boot');
  const [currentStepIndex, setCurrentStepIndex] = useState<number>(0);
  const [userAnswer, setUserAnswer] = useState<string>('');
  const [feedback, setFeedback] = useState<{ isCorrect: boolean; text: string } | null>(null);
  const [isCompleted, setIsCompleted] = useState<boolean>(false);
  const [showGlossary, setShowGlossary] = useState<boolean>(false);

  const scenario = SCENARIOS.find(s => s.id === selectedScenarioId) || SCENARIOS[0];
  const step = scenario.steps[currentStepIndex];

  const handleAnswerSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!userAnswer.trim()) return;

    const isMatch = userAnswer.toLowerCase().includes(step.answer.toLowerCase());

    if (isMatch) {
      setFeedback({
        isCorrect: true,
        text: `¡Correcto! ${step.explanation}`
      });

      if (currentStepIndex + 1 < scenario.steps.length) {
        setTimeout(() => {
          setCurrentStepIndex(prev => prev + 1);
          setUserAnswer('');
          setFeedback(null);
        }, 2200);
      } else {
        setIsCompleted(true);
        confetti({
          particleCount: 80,
          spread: 70,
          origin: { y: 0.6 }
        });
      }
    } else {
      setFeedback({
        isCorrect: false,
        text: `Casi. Pista: ${step.hint}`
      });
    }
  };

  const resetScenario = (id: string) => {
    setSelectedScenarioId(id);
    setCurrentStepIndex(0);
    setUserAnswer('');
    setFeedback(null);
    setIsCompleted(false);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="tutor">
      <header>
        <p className="section-label">
          <span className="num">04</span>
          <span className="divider">⁄</span>
          <span>Personal Dev Tutor</span>
        </p>
        <h2 className="section-title">Personal Dev Tutor.</h2>
      </header>

      <p className="section-intro" style={{ position: 'relative' }}>
        <span
          onClick={() => setShowGlossary(!showGlossary)}
          style={{
            borderBottom: '1.5px dashed var(--accent)',
            cursor: 'pointer',
            fontWeight: 600,
            color: 'var(--accent)',
            transition: 'color 0.2s ease'
          }}
          title="Haz clic para ver la definición"
        >
          Tutoría Socrática
        </span>
        {' '}+ Orquestación en tmux: No escribe código a tus espaldas. Te guía paso a paso mediante preguntas para afianzar el aprendizaje.

        {showGlossary && (
          <>
            {/* Backdrop overlay */}
            <div
              onClick={() => setShowGlossary(false)}
              style={{
                position: 'fixed',
                inset: 0,
                zIndex: 99
              }}
            />
            {/* Glossary popup */}
            <div style={{
              position: 'absolute',
              top: 'calc(100% + 8px)',
              left: 0,
              zIndex: 100,
              background: 'var(--bg-surface)',
              border: '1px solid var(--border-color)',
              borderRadius: '8px',
              padding: '1.2rem 1.4rem',
              maxWidth: '520px',
              boxShadow: '0 12px 40px rgba(0,0,0,0.25)',
              animation: 'glossaryIn 0.2s ease-out'
            }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.7rem' }}>
                <span style={{
                  fontFamily: 'var(--font-mono)',
                  fontSize: '0.72rem',
                  fontWeight: 700,
                  textTransform: 'uppercase' as const,
                  letterSpacing: '0.08em',
                  color: 'var(--accent)',
                  background: 'var(--bg-subtle)',
                  padding: '0.2rem 0.5rem',
                  borderRadius: '3px'
                }}>
                  Glosario
                </span>
                <button
                  onClick={(e) => { e.stopPropagation(); setShowGlossary(false); }}
                  style={{
                    background: 'none',
                    border: 'none',
                    color: 'var(--text-muted)',
                    cursor: 'pointer',
                    fontSize: '1.1rem',
                    lineHeight: 1,
                    padding: '0.2rem'
                  }}
                  aria-label="Cerrar glosario"
                >
                  ✕
                </button>
              </div>
              <h4 style={{
                fontFamily: 'var(--font-display)',
                fontSize: '1.05rem',
                fontWeight: 700,
                marginBottom: '0.5rem',
                color: 'var(--text-primary)'
              }}>
                Tutoría Socrática
              </h4>
              <p style={{
                fontSize: '0.88rem',
                lineHeight: 1.6,
                color: 'var(--text-secondary)',
                margin: 0
              }}>
                Método pedagógico basado en el <strong>diálogo mayéutico de Sócrates</strong>: el tutor nunca da la respuesta directamente.
                En su lugar, formula preguntas progresivas que llevan al estudiante a descubrir la solución por sí mismo. En agent-dev-kit,
                el <code style={{ background: 'var(--bg-subtle)', padding: '0.1rem 0.35rem', borderRadius: '3px', fontSize: '0.82rem' }}>
                personal-dev-tutor</code> usa este enfoque para enseñar conceptos de programación: descompone el problema,
                presenta pistas contextuales y valida cada respuesta antes de avanzar al siguiente checkpoint.
              </p>
            </div>
          </>
        )}
      </p>

      {/* Scenario Switcher Buttons */}
      <div style={{ display: 'flex', gap: '0.8rem', marginBottom: '1.8rem', flexWrap: 'wrap' }}>
        {SCENARIOS.map((sc) => (
          <button
            key={sc.id}
            onClick={() => resetScenario(sc.id)}
            className={selectedScenarioId === sc.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
            style={{ fontSize: '0.85rem' }}
          >
            <span>{sc.title}</span>
          </button>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.8rem' }}>
        {/* Tutor Terminal Box */}
        <div className="hm-card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span className="prompt-pill">$ tmux attach -t tutor</span>
              <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}>
                [session: tutor:0.0]
              </span>
            </div>
            <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)' }}>
              Paso {currentStepIndex + 1} / {scenario.steps.length}
            </span>
          </div>

          {!isCompleted ? (
            <div>
              <div style={{ background: 'var(--bg-subtle)', padding: '1rem', borderRadius: '4px', border: '1px solid var(--border-color)', marginBottom: '1.2rem' }}>
                <p style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
                  [TUTOR SOCRÁTICO · {scenario.concept}]
                </p>
                <p style={{ fontSize: '0.95rem', fontWeight: 600 }}>
                  {step.question}
                </p>
              </div>

              <form onSubmit={handleAnswerSubmit}>
                <div style={{ display: 'flex', gap: '0.6rem', marginBottom: '1rem' }}>
                  <input
                    type="text"
                    value={userAnswer}
                    onChange={(e) => setUserAnswer(e.target.value)}
                    placeholder="Escribe tu respuesta corta..."
                    style={{
                      flex: 1,
                      padding: '0.6rem 0.9rem',
                      borderRadius: '4px',
                      background: 'var(--bg-surface)',
                      border: '1px solid var(--border-color)',
                      color: 'var(--text-primary)',
                      fontFamily: 'var(--font-sans)',
                      fontSize: '0.9rem'
                    }}
                  />
                  <button type="submit" className="hm-btn-primary" style={{ padding: '0.6rem 1.2rem' }}>
                    <span>Responder</span>
                  </button>
                </div>
              </form>

              {feedback && (
                <div style={{
                  padding: '0.8rem 1rem',
                  borderRadius: '4px',
                  background: feedback.isCorrect ? 'var(--bg-subtle)' : 'var(--bg-surface)',
                  border: `1px solid ${feedback.isCorrect ? 'var(--accent)' : 'var(--border-strong)'}`,
                  color: feedback.isCorrect ? 'var(--accent)' : 'var(--text-primary)',
                  fontSize: '0.88rem'
                }}>
                  {feedback.text}
                </div>
              )}
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '2rem 1rem' }}>
              <div style={{ fontSize: '2rem', marginBottom: '0.5rem' }}>🎉</div>
              <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '1.5rem', marginBottom: '0.5rem' }}>
                ¡Lección Completada!
              </h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
                Has completado la sesión Socrática de <strong>{scenario.title}</strong>. El tutor registrara tu progreso en <code>.planning/ROADMAP.md</code>.
              </p>
              <button onClick={() => resetScenario(selectedScenarioId)} className="hm-btn-secondary">
                <span>Repetir Escenario</span>
              </button>
            </div>
          )}
        </div>

        {/* Live File Tree & Session Specs */}
        <div className="hm-card">
          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', color: 'var(--accent)', marginBottom: '1rem' }}>
            Estructura de Sesión (.planning & Context)
          </h4>

          {/* Styled File Tree */}
          <div style={{
            background: '#0d1117',
            borderRadius: '6px',
            border: '1px solid #30363d',
            marginBottom: '1.2rem',
            overflow: 'hidden'
          }}>
            {/* Tree header bar */}
            <div style={{
              background: '#161b22',
              borderBottom: '1px solid #21262d',
              padding: '0.5rem 0.9rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.5rem'
            }}>
              <span style={{ fontSize: '0.7rem', color: '#8b949e', fontFamily: "'Geist Mono', monospace", fontWeight: 600, textTransform: 'uppercase' as const, letterSpacing: '0.06em' }}>
                📂 .planning/
              </span>
            </div>
            {/* Tree items */}
            <div style={{ padding: '0.5rem 0' }}>
              {[
                { icon: '📋', name: 'ROADMAP.md', desc: 'Objetivos y roadmap de aprendizaje', color: '#58a6ff' },
                { icon: '⚡', name: 'STATE.md', desc: 'Estado actual de la sesión', color: '#3fb950' },
                { icon: '✏️', name: 'TASK-01.md', desc: 'Checkpoint Socrático activo', color: '#d29922' },
                { icon: '📁', name: 'LOGS/', desc: 'Transcripción untruncated (JSONL)', color: '#bc8cff', isDir: true },
              ].map((item, i, arr) => (
                <div
                  key={item.name}
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.6rem',
                    padding: '0.4rem 0.9rem',
                    fontSize: '0.84rem',
                    fontFamily: "'Geist Mono', monospace",
                    transition: 'background 0.12s ease',
                    cursor: 'default'
                  }}
                  onMouseEnter={(e) => (e.currentTarget.style.background = '#161b22')}
                  onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
                >
                  {/* Tree branch connector */}
                  <span style={{ color: '#30363d', userSelect: 'none', width: '14px', textAlign: 'center' }}>
                    {i < arr.length - 1 ? '├' : '└'}
                  </span>
                  {/* Icon */}
                  <span style={{ fontSize: '0.85rem', lineHeight: 1 }}>{item.icon}</span>
                  {/* File name */}
                  <span style={{ color: item.color, fontWeight: 600 }}>
                    {item.name}
                  </span>
                  {/* Description */}
                  <span style={{ color: '#6e7681', fontSize: '0.76rem', marginLeft: 'auto', whiteSpace: 'nowrap' }}>
                    {item.desc}
                  </span>
                </div>
              ))}
            </div>
          </div>

          <table className="dna-table">
            <tbody>
              <tr>
                <td className="dna-k">Perfil</td>
                <td className="dna-v"><code>personal-dev-tutor</code></td>
              </tr>
              <tr>
                <td className="dna-k">Ambiente</td>
                <td className="dna-v">Sesión aislada tmux <code>tutor</code></td>
              </tr>
              <tr>
                <td className="dna-k">Orquestador</td>
                <td className="dna-v">GSD Metaprompting + Context7 Docs</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
};
