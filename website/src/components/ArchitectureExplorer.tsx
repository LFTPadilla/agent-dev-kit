import React, { useState } from 'react';
import { ARCHITECTURE_LAYERS } from '../data/repoData';
import { AgentWorkflowDiagram } from './AgentWorkflowDiagram';
import type { Language } from '../data/translations';
import { TRANSLATIONS } from '../data/translations';

interface ArchitectureExplorerProps {
  language?: Language;
}

export const ArchitectureExplorer: React.FC<ArchitectureExplorerProps> = ({ language = 'en' }) => {
  const [selectedLayerId, setSelectedLayerId] = useState<string>('direct');
  const [selectedComponent, setSelectedComponent] = useState<string | null>(null);

  const selectedLayer = ARCHITECTURE_LAYERS.find(l => l.id === selectedLayerId) || ARCHITECTURE_LAYERS[0];
  const t = TRANSLATIONS[language].architecture;
  const isEn = language === 'en';

  return (
    <section style={{ marginBottom: '5rem' }} id="architecture">
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

      {/* Functional Agent Execution Workflow Diagram */}
      <AgentWorkflowDiagram language={language} />

      {/* Layer Pills */}
      <div style={{ display: 'flex', gap: '0.8rem', marginBottom: '2.5rem', flexWrap: 'wrap' }}>
        {ARCHITECTURE_LAYERS.map((layer) => {
          const isSelected = layer.id === selectedLayerId;
          return (
            <button
              key={layer.id}
              onClick={() => {
                setSelectedLayerId(layer.id);
                setSelectedComponent(null);
              }}
              className={isSelected ? 'hm-btn-primary' : 'hm-btn-secondary'}
              style={{ fontSize: '0.85rem' }}
            >
              <span>{layer.name}</span>
            </button>
          );
        })}
      </div>

      {/* Layer Cards Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: '1.8rem' }}>
        {/* Component List */}
        <div className="hm-card">
          <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '1.5rem', marginBottom: '0.6rem' }}>
            {selectedLayer.name}
          </h3>
          <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.5rem' }}>
            {!isEn && selectedLayer.descriptionEs ? selectedLayer.descriptionEs : selectedLayer.description}
          </p>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.8rem' }}>
            {selectedLayer.components.map((comp) => {
              const isCompSelected = selectedComponent === comp.name;
              const componentDesc = !isEn && comp.descEs ? comp.descEs : comp.desc;
              return (
                <div
                  key={comp.name}
                  onClick={() => setSelectedComponent(comp.name)}
                  style={{
                    padding: '1rem',
                    borderRadius: '4px',
                    background: isCompSelected ? 'var(--bg-subtle)' : 'var(--bg-surface)',
                    border: `1px solid ${isCompSelected ? 'var(--border-strong)' : 'var(--border-color)'}`,
                    cursor: 'pointer',
                    transition: 'all 0.2s ease'
                  }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.3rem' }}>
                    <span style={{ fontWeight: 700, fontFamily: 'var(--font-mono)', fontSize: '0.95rem' }}>
                      {comp.name}
                    </span>
                    <span style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--accent)' }}>
                      {comp.type}
                    </span>
                  </div>
                  <p style={{ color: 'var(--text-secondary)', fontSize: '0.85rem' }}>
                    {componentDesc}
                  </p>
                </div>
              );
            })}
          </div>
        </div>

        {/* DNA Technical Breakdown */}
        <div className="hm-card">
          <h3 style={{ fontFamily: 'var(--font-mono)', fontSize: '1.1rem', marginBottom: '1rem', color: 'var(--accent)' }}>
            {selectedComponent ? `DNA: ${selectedComponent}` : (isEn ? 'Layer Specification' : 'Especificación de Capa')}
          </h3>

          {selectedComponent ? (
            <div>
              <p style={{ fontSize: '0.95rem', color: 'var(--text-secondary)', marginBottom: '1.5rem' }}>
                {isEn ? (
                  <>Active component within <strong>{selectedLayer.name}</strong>. Maintains modularity without context bloat.</>
                ) : (
                  <>Componente activo dentro de <strong>{selectedLayer.name}</strong>. Mantiene la modularidad sin sobrecargar el contexto.</>
                )}
              </p>

              <table className="dna-table">
                <tbody>
                  <tr>
                    <td className="dna-k">Reads</td>
                    <td className="dna-v">{isEn ? 'Project context, git diffs, `AGENTS.md`' : 'Contexto de proyecto, diffs de git, `AGENTS.md`'}</td>
                  </tr>
                  <tr>
                    <td className="dna-k">Picks</td>
                    <td className="dna-v">{isEn ? 'Optimal models (Smart auditor vs Cheap workers)' : 'Modelos óptimos (Audit inteligente vs Workers baratos)'}</td>
                  </tr>
                  <tr>
                    <td className="dna-k">Outputs</td>
                    <td className="dna-v">{isEn ? 'Verifiable artifacts, audit reports, test evidence' : 'Artefactos verificables, reportes de revisión, evidencia de tests'}</td>
                  </tr>
                  <tr>
                    <td className="dna-k">Refuses</td>
                    <td className="dna-v">{isEn ? 'Unverified dependency hallucination or unverified false positives' : 'Alucinación de dependencias globales o falsos positivos confiados'}</td>
                  </tr>
                </tbody>
              </table>

              <div className="code-block" style={{ marginTop: '1.5rem' }}>
                {isEn ? `# Inspection & Execution
npm run doctor
# Direct runtime command:
/pr-review <PR-URL>` : `# Ejecución e Inspección
npm run doctor
# Comando directo en runtime:
/pr-review <PR-URL>`}
              </div>
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '3rem 1rem', color: 'var(--text-muted)' }}>
              <p style={{ fontFamily: 'var(--font-mono)', fontSize: '0.9rem' }}>
                {isEn ? 'Select any flow node or a left component to inspect its DNA and execution rules.' : 'Selecciona cualquier nodo del diagrama de flujo o un componente a la izquierda para inspeccionar su DNA y reglas de ejecución.'}
              </p>
            </div>
          )}
        </div>
      </div>
    </section>
  );
};
