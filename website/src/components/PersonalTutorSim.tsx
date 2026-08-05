import React, { useState } from 'react';
import confetti from 'canvas-confetti';
import type { Language } from '../data/translations';
import { TRANSLATIONS } from '../data/translations';

interface ScenarioStep {
  question: string;
  questionEn: string;
  hint: string;
  hintEn: string;
  answer: string;
  answerEn: string;
  explanation: string;
  explanationEn: string;
}

interface Scenario {
  id: string;
  title: string;
  titleEn: string;
  concept: string;
  conceptEn: string;
  steps: ScenarioStep[];
}

const SCENARIOS: Scenario[] = [
  {
    id: 'spring-boot',
    title: 'Caso A: Rollback en Spring Boot @Transactional',
    titleEn: 'Case A: Rollback in Spring Boot @Transactional',
    concept: 'Excepciones comprobadas vs no comprobadas en JPA',
    conceptEn: 'Checked vs Unchecked Exceptions in JPA',
    steps: [
      {
        question: 'Si una función con `@Transactional` lanza una `Exception` estándar comprobada (Checked Exception), ¿la transacción hace rollback automático?',
        questionEn: 'If a `@Transactional` function throws a standard Checked `Exception`, does the transaction automatically roll back?',
        hint: 'Piensa en la diferencia por defecto entre RuntimeException y Exception en Spring Framework.',
        hintEn: 'Think about Spring Framework default behavior for RuntimeException vs Exception.',
        answer: 'No',
        answerEn: 'No',
        explanation: 'Por defecto, Spring solo hace rollback automático para `RuntimeException` y `Error`. Para excepciones comprobadas se requiere `@Transactional(rollbackFor = Exception.class)`.',
        explanationEn: 'By default, Spring only rolls back automatically for `RuntimeException` and `Error`. Checked exceptions require `@Transactional(rollbackFor = Exception.class)`.'
      },
      {
        question: '¿Qué sucede si un método `@Transactional` es llamado internamente desde la misma clase (Self-invocation)?',
        questionEn: 'What happens if a `@Transactional` method is called internally from within the same class (Self-invocation)?',
        hint: 'Recuerda que Spring AOP usa Dynamic Proxies.',
        hintEn: 'Remember Spring AOP uses Dynamic Proxies.',
        answer: 'No se aplica el proxy',
        answerEn: 'Proxy bypassed',
        explanation: 'El proxy de Spring AOP es bypass-eado en llamadas internas (`this.method()`), por lo que la transacción no se inicia a menos que se use AspectJ weaving directo.',
        explanationEn: 'Spring AOP dynamic proxies are bypassed during internal calls (`this.method()`), so transactions do not start unless using AspectJ weaving.'
      }
    ]
  },
  {
    id: 'react-leak',
    title: 'Caso B: Memory Leak en useEffect Event Listener',
    titleEn: 'Case B: Memory Leak in useEffect Event Listener',
    concept: 'Limpieza de Subscripciones y closures en React',
    conceptEn: 'Subscription cleanup and closures in React',
    steps: [
      {
        question: '¿Por qué `window.addEventListener("resize", handleResize)` dentro de `useEffect` sin una función de retorno produce un Memory Leak?',
        questionEn: 'Why does `window.addEventListener("resize", handleResize)` inside `useEffect` without a cleanup return function cause a memory leak?',
        hint: 'Analiza la acumulación de event listeners en cada re-render.',
        hintEn: 'Analyze event listener accumulation on every re-render.',
        answer: 'Acumula listeners duplicados',
        answerEn: 'Accumulates duplicate listeners',
        explanation: 'En cada re-render, se suscribe un nuevo listener a `window` sin remover el anterior, consumiendo memoria e invocando múltiples handlers en cascada.',
        explanationEn: 'On every re-render, a new listener is attached to `window` without removing the previous one, wasting memory and invoking duplicate handlers.'
      },
      {
        question: 'Si `handleResize` captura una variable de estado sin `useCallback` ni refs, ¿qué problema de closures ocurre?',
        questionEn: 'If `handleResize` captures state without `useCallback` or refs, what closure issue occurs?',
        hint: 'Piensa en el "stale closure" de JavaScript.',
        hintEn: 'Think about JavaScript "stale closure".',
        answer: 'Stale closure',
        answerEn: 'Stale closure',
        explanation: 'El listener guardará la referencia del estado en el instante que fue creado (Stale Closure), leyendo valores desactualizados en renders posteriores.',
        explanationEn: 'The listener retains the state reference from when it was created (Stale Closure), reading stale state values in future renders.'
      }
    ]
  },
  {
    id: 'postgres-n1',
    title: 'Caso C: Consulta N+1 en ORM & PostgreSQL',
    titleEn: 'Case C: N+1 Query Problem in ORM & PostgreSQL',
    concept: 'Fetch Joins, Lazy Loading y Optimización de Consultas SQL',
    conceptEn: 'Fetch Joins, Lazy Loading, and SQL Query Optimization',
    steps: [
      {
        question: '¿Por qué iterar sobre una lista de 100 usuarios invocando `user.getOrders()` con Lazy Loading produce 101 consultas a la base de datos?',
        questionEn: 'Why does iterating over 100 users calling `user.getOrders()` with Lazy Loading result in 101 database queries?',
        hint: 'Piensa en la regla N + 1 (1 inicial + N por elemento).',
        hintEn: 'Think about the N + 1 rule (1 initial + N per item).',
        answer: 'N+1',
        answerEn: 'N+1',
        explanation: 'La consulta inicial obtiene los N usuarios (1 consulta) y luego cada iteración ejecuta una consulta individual adicional por usuario (N consultas).',
        explanationEn: 'The initial query fetches N users (1 query), and each loop iteration triggers an extra individual query per user (N queries).'
      },
      {
        question: '¿Cuál es la técnica de consulta SQL/ORM para traer usuarios y pedidos en un solo viaje de ida y vuelta (single round-trip)?',
        questionEn: 'What SQL/ORM query technique fetches users and orders in a single round-trip?',
        hint: 'Mención de JOIN FETCH o Eager loading.',
        hintEn: 'Mention JOIN FETCH or Eager loading.',
        answer: 'JOIN FETCH',
        answerEn: 'JOIN FETCH',
        explanation: 'Utilizar `JOIN FETCH` (o `.include()` en Prisma/Eager loading) combina las tablas en la consulta SQL base, reduciendo 101 consultas a solo 1.',
        explanationEn: 'Using `JOIN FETCH` (or `.include()` in Prisma / Eager loading) joins tables in the primary SQL query, reducing 101 queries down to 1.'
      }
    ]
  }
];

interface PersonalTutorSimProps {
  language?: Language;
}

export const PersonalTutorSim: React.FC<PersonalTutorSimProps> = ({ language = 'en' }) => {
  const [selectedScenarioId, setSelectedScenarioId] = useState<string>('spring-boot');
  const [currentStepIndex, setCurrentStepIndex] = useState<number>(0);
  const [userAnswer, setUserAnswer] = useState<string>('');
  const [feedback, setFeedback] = useState<{ isCorrect: boolean; text: string } | null>(null);
  const [isCompleted, setIsCompleted] = useState<boolean>(false);
  const [showGlossary, setShowGlossary] = useState<boolean>(false);

  const scenario = SCENARIOS.find(s => s.id === selectedScenarioId) || SCENARIOS[0];
  const step = scenario.steps[currentStepIndex];
  const t = TRANSLATIONS[language].tutor;
  const isEn = language === 'en';

  const currentStepQuestion = isEn ? step.questionEn : step.question;
  const currentStepHint = isEn ? step.hintEn : step.hint;
  const currentStepAnswer = isEn ? step.answerEn : step.answer;
  const currentStepExplanation = isEn ? step.explanationEn : step.explanation;

  const handleAnswerSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!userAnswer.trim()) return;

    const isMatch = userAnswer.toLowerCase().includes(currentStepAnswer.toLowerCase()) || userAnswer.toLowerCase().includes(step.answer.toLowerCase());

    if (isMatch) {
      setFeedback({
        isCorrect: true,
        text: isEn ? `Correct! ${currentStepExplanation}` : `¡Correcto! ${currentStepExplanation}`
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
        text: isEn ? `Close! Hint: ${currentStepHint}` : `Casi. Pista: ${currentStepHint}`
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
          <span className="num">{t.labelNum}</span>
          <span className="divider">⁄</span>
          <span>{t.labelTitle}</span>
        </p>
        <h2 className="section-title">{t.title}</h2>
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
          title={t.termClickHint}
        >
          {t.termTitle}
        </span>
        {' '}+ {isEn ? 'Tmux Orchestration: Does not write code behind your back. Guides you step-by-step through interactive questions to build real mastery.' : 'Orquestación en tmux: No escribe código a tus espaldas. Te guía paso a paso mediante preguntas para afianzar el aprendizaje.'}

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
                  {isEn ? 'Glossary' : 'Glosario'}
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
                  aria-label={isEn ? 'Close glossary' : 'Cerrar glosario'}
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
                {t.termTitle}
              </h4>
              <p style={{
                fontSize: '0.88rem',
                lineHeight: 1.6,
                color: 'var(--text-secondary)',
                margin: 0
              }}>
                {isEn ? (
                  <>
                    A teaching method based on <strong>Socrates’ maieutic dialogue</strong>: the tutor never gives away the answer directly.
                    Instead, it asks progressive questions that guide the student to discover solutions independently. In agent-dev-kit,
                    the <code style={{ background: 'var(--bg-subtle)', padding: '0.1rem 0.35rem', borderRadius: '3px', fontSize: '0.82rem' }}>
                    personal-dev-tutor</code> uses this approach to teach programming concepts: it breaks down problems, provides contextual hints, and verifies understanding before advancing to the next checkpoint.
                  </>
                ) : (
                  <>
                    Método pedagógico basado en el <strong>diálogo mayéutico de Sócrates</strong>: el tutor nunca da la respuesta directamente.
                    En su lugar, formula preguntas progresivas que llevan al estudiante a descubrir la solución por sí mismo. En agent-dev-kit,
                    el <code style={{ background: 'var(--bg-subtle)', padding: '0.1rem 0.35rem', borderRadius: '3px', fontSize: '0.82rem' }}>
                    personal-dev-tutor</code> usa este enfoque para enseñar conceptos de programación: descompone el problema,
                    presenta pistas contextuales y valida cada respuesta antes de avanzar al siguiente checkpoint.
                  </>
                )}
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
            <span>{isEn ? sc.titleEn : sc.title}</span>
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
              {isEn ? 'Step' : 'Paso'} {currentStepIndex + 1} / {scenario.steps.length}
            </span>
          </div>

          {!isCompleted ? (
            <div>
              <div style={{ background: 'var(--bg-subtle)', padding: '1rem', borderRadius: '4px', border: '1px solid var(--border-color)', marginBottom: '1.2rem' }}>
                <p style={{ fontFamily: 'var(--font-mono)', fontSize: '0.85rem', color: 'var(--text-muted)', marginBottom: '0.5rem' }}>
                  [{isEn ? 'SOCRATIC TUTOR' : 'TUTOR SOCRÁTICO'} · {isEn ? scenario.conceptEn : scenario.concept}]
                </p>
                <p style={{ fontSize: '0.95rem', fontWeight: 600 }}>
                  {currentStepQuestion}
                </p>
              </div>

              <form onSubmit={handleAnswerSubmit}>
                <div style={{ display: 'flex', gap: '0.6rem', marginBottom: '1rem' }}>
                  <input
                    type="text"
                    value={userAnswer}
                    onChange={(e) => setUserAnswer(e.target.value)}
                    placeholder={isEn ? 'Type your short answer...' : 'Escribe tu respuesta corta...'}
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
                    <span>{isEn ? 'Submit' : 'Responder'}</span>
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
                {isEn ? 'Lesson Completed!' : '¡Lección Completada!'}
              </h3>
              <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
                {isEn ? (
                  <>You have completed the Socratic session for <strong>{scenario.titleEn}</strong>. The tutor will record your learning in <code>.planning/ROADMAP.md</code>.</>
                ) : (
                  <>Has completado la sesión Socrática de <strong>{scenario.title}</strong>. El tutor registrará tu progreso en <code>.planning/ROADMAP.md</code>.</>
                )}
              </p>
              <button onClick={() => resetScenario(selectedScenarioId)} className="hm-btn-secondary">
                <span>{isEn ? 'Repeat Scenario' : 'Repetir Escenario'}</span>
              </button>
            </div>
          )}
        </div>

        {/* Live File Tree & Session Specs */}
        <div className="hm-card">
          <h4 style={{ fontFamily: 'var(--font-mono)', fontSize: '1rem', color: 'var(--accent)', marginBottom: '1rem' }}>
            {isEn ? 'Session Tree (.planning & Context)' : 'Estructura de Sesión (.planning & Context)'}
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
                { icon: '📋', name: 'ROADMAP.md', desc: isEn ? 'Learning goals & roadmap' : 'Objetivos y roadmap de aprendizaje', color: '#58a6ff' },
                { icon: '⚡', name: 'STATE.md', desc: isEn ? 'Current session state' : 'Estado actual de la sesión', color: '#3fb950' },
                { icon: '✏️', name: 'TASK-01.md', desc: isEn ? 'Active Socratic checkpoint' : 'Checkpoint Socrático activo', color: '#d29922' },
                { icon: '📁', name: 'LOGS/', desc: isEn ? 'Untruncated transcript (JSONL)' : 'Transcripción untruncated (JSONL)', color: '#bc8cff', isDir: true },
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
                <td className="dna-k">{isEn ? 'Profile' : 'Perfil'}</td>
                <td className="dna-v"><code>personal-dev-tutor</code></td>
              </tr>
              <tr>
                <td className="dna-k">{isEn ? 'Environment' : 'Ambiente'}</td>
                <td className="dna-v">{isEn ? 'Isolated tmux session (tutor)' : 'Sesión aislada tmux tutor'}</td>
              </tr>
              <tr>
                <td className="dna-k">{isEn ? 'Orchestrator' : 'Orquestador'}</td>
                <td className="dna-v">GSD Metaprompting + Context7 Docs</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
};
