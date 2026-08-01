import React, { useState, useEffect } from 'react';
import { SKILLS_CATALOG } from '../data/repoData';
import type { Skill } from '../data/repoData';
import { TRANSLATIONS } from '../data/translations';
import type { Language } from '../data/translations';
import { ChevronLeft, ChevronRight } from 'lucide-react';

interface SkillCatalogExplorerProps {
  language: Language;
}

export const SkillCatalogExplorer: React.FC<SkillCatalogExplorerProps> = ({ language }) => {
  const [searchTerm, setSearchTerm] = useState<string>('');
  const [selectedCategory, setSelectedCategory] = useState<string>('all');
  const [selectedSkill, setSelectedSkill] = useState<Skill | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [customInput, setCustomInput] = useState<string>('');
  const [currentPage, setCurrentPage] = useState<number>(1);

  const t = TRANSLATIONS[language].skills;
  const ITEMS_PER_PAGE = 6;

  const categories = [
    { id: 'all', label: language === 'es' ? 'Todas las Skills (22)' : 'All Skills (22)' },
    { id: 'quality', label: language === 'es' ? 'Calidad & Evals' : 'Quality & Evals' },
    { id: 'orchestration', label: language === 'es' ? 'Orquestación & Tutor' : 'Orchestration & Tutor' },
    { id: 'security', label: language === 'es' ? 'Seguridad' : 'Security' },
    { id: 'qa', label: language === 'es' ? 'QA & Browsing' : 'QA & Browsing' },
    { id: 'docs', label: language === 'es' ? 'Docs & Context' : 'Docs & Context' }
  ];

  const filteredSkills = SKILLS_CATALOG.filter((skill: Skill) => {
    const matchesSearch =
      skill.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      skill.description.toLowerCase().includes(searchTerm.toLowerCase()) ||
      skill.triggers.some(tr => tr.toLowerCase().includes(searchTerm.toLowerCase()));

    const matchesCategory =
      selectedCategory === 'all' ||
      (selectedCategory === 'quality' && (skill.name.includes('pr-review') || skill.name.includes('knip') || skill.name.includes('semgrep') || skill.name.includes('no-mistakes'))) ||
      (selectedCategory === 'orchestration' && (skill.name.includes('tutor') || skill.name.includes('gsd') || skill.name.includes('treehouse') || skill.name.includes('gnhf') || skill.name.includes('orchestrate'))) ||
      (selectedCategory === 'security' && (skill.name.includes('semgrep') || skill.name.includes('sentry') || skill.name.includes('pr-review'))) ||
      (selectedCategory === 'qa' && (skill.name.includes('live-qa') || skill.name.includes('playwright') || skill.name.includes('web-browse'))) ||
      (selectedCategory === 'docs' && (skill.name.includes('context7') || skill.name.includes('find-skills') || skill.name.includes('human')));

    return matchesSearch && matchesCategory;
  });

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, selectedCategory]);

  const totalPages = Math.ceil(filteredSkills.length / ITEMS_PER_PAGE) || 1;
  const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
  const paginatedSkills = filteredSkills.slice(startIndex, startIndex + ITEMS_PER_PAGE);

  const handleCopyPrompt = (text: string, id: string) => {
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="skills">
      <header>
        <p className="section-label">
          <span className="num">{t.labelNum}</span>
          <span className="divider">⁄</span>
          <span>{t.labelTitle}</span>
        </p>
        <h2 className="section-title">{t.title}</h2>
      </header>

      {/* Search & Category Filter */}
      <div style={{ marginBottom: '2rem' }}>
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', marginBottom: '1.2rem' }}>
          <input
            type="text"
            placeholder={t.searchPlaceholder}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            style={{
              flex: 1,
              minWidth: '280px',
              padding: '0.7rem 1rem',
              borderRadius: '4px',
              background: 'var(--bg-surface)',
              border: '1px solid var(--border-color)',
              color: 'var(--text-primary)',
              fontFamily: 'var(--font-sans)',
              fontSize: '0.9rem'
            }}
          />
        </div>

        {/* Category Pills */}
        <div style={{ display: 'flex', gap: '0.6rem', flexWrap: 'wrap' }}>
          {categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setSelectedCategory(cat.id)}
              className={selectedCategory === cat.id ? 'hm-btn-primary' : 'hm-btn-secondary'}
              style={{ fontSize: '0.8rem', padding: '0.35rem 0.8rem' }}
            >
              <span>{cat.label}</span>
            </button>
          ))}
        </div>
      </div>

      {/* Skills Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))', gap: '1.5rem', marginBottom: '2.5rem' }}>
        {paginatedSkills.map((skill: Skill) => (
          <div
            key={skill.id}
            className="hm-card"
            style={{ display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}
          >
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '0.6rem' }}>
                <h3 style={{ fontFamily: 'var(--font-mono)', fontSize: '1.05rem', fontWeight: 700 }}>
                  {skill.name}
                </h3>
                <span style={{ fontSize: '0.7rem', fontFamily: 'var(--font-mono)', color: 'var(--accent)', background: 'var(--bg-subtle)', padding: '0.2rem 0.5rem', borderRadius: '3px' }}>
                  {skill.category}
                </span>
              </div>

              <p style={{ color: 'var(--text-secondary)', fontSize: '0.88rem', marginBottom: '1.2rem' }}>
                {skill.description}
              </p>
            </div>

            <div>
              <div style={{ background: 'var(--bg-subtle)', padding: '0.6rem 0.8rem', borderRadius: '4px', marginBottom: '1rem', border: '1px solid var(--border-color)' }}>
                <p style={{ fontSize: '0.75rem', fontFamily: 'var(--font-mono)', color: 'var(--text-muted)', marginBottom: '0.2rem' }}>
                  Triggers / Invocación:
                </p>
                <p style={{ fontSize: '0.82rem', fontFamily: 'var(--font-mono)', color: 'var(--text-primary)' }}>
                  {skill.triggers.join(', ')}
                </p>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  onClick={() => setSelectedSkill(skill)}
                  className="hm-btn-secondary"
                  style={{ flex: 1, fontSize: '0.8rem' }}
                >
                  <span>{language === 'es' ? 'Generar Comando' : 'Generate Command'}</span>
                </button>
                <button
                  onClick={() => handleCopyPrompt(skill.examplePrompt, skill.id)}
                  className="hm-btn-primary"
                  style={{ fontSize: '0.8rem' }}
                >
                  <span>{copiedId === skill.id ? (language === 'es' ? '¡Copiado!' : 'Copied!') : (language === 'es' ? 'Copiar Prompt' : 'Copy Prompt')}</span>
                </button>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Paginador Tactil */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '1rem 1.4rem',
        background: 'var(--bg-surface)',
        border: '1px solid var(--border-color)',
        borderRadius: '6px',
        flexWrap: 'wrap',
        gap: '1rem'
      }}>
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: '0.82rem', color: 'var(--text-secondary)' }}>
          {t.showingText} <strong style={{ color: 'var(--text-primary)' }}>{filteredSkills.length > 0 ? startIndex + 1 : 0}-{Math.min(startIndex + ITEMS_PER_PAGE, filteredSkills.length)}</strong> {t.ofText} <strong style={{ color: 'var(--accent)' }}>{filteredSkills.length}</strong> {t.skillsText}
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="hm-btn-secondary"
            style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem', opacity: currentPage === 1 ? 0.4 : 1, cursor: currentPage === 1 ? 'not-allowed' : 'pointer' }}
          >
            <ChevronLeft size={16} />
            <span>{t.prev}</span>
          </button>

          {Array.from({ length: totalPages }, (_, i) => i + 1).map(page => (
            <button
              key={page}
              onClick={() => setCurrentPage(page)}
              style={{
                background: currentPage === page ? 'var(--accent)' : 'var(--bg-subtle)',
                color: currentPage === page ? '#ffffff' : 'var(--text-primary)',
                border: '1px solid var(--border-color)',
                borderRadius: '4px',
                padding: '0.35rem 0.75rem',
                fontFamily: 'var(--font-mono)',
                fontSize: '0.82rem',
                fontWeight: currentPage === page ? 700 : 400,
                cursor: 'pointer',
                transition: 'all 0.15s ease'
              }}
            >
              {page}
            </button>
          ))}

          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="hm-btn-secondary"
            style={{ padding: '0.4rem 0.8rem', fontSize: '0.82rem', opacity: currentPage === totalPages ? 0.4 : 1, cursor: currentPage === totalPages ? 'not-allowed' : 'pointer' }}
          >
            <span>{t.next}</span>
            <ChevronRight size={16} />
          </button>
        </div>
      </div>

      {/* Interactive Command Synthesizer Drawer Modal */}
      {selectedSkill && (
        <div style={{
          position: 'fixed',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: 'rgba(0, 0, 0, 0.65)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 100,
          padding: '1.5rem'
        }}>
          <div className="hm-card" style={{ maxWidth: '600px', width: '100%', background: 'var(--bg-page)' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1rem' }}>
              <h3 style={{ fontFamily: 'var(--font-display)', fontSize: '1.5rem' }}>
                {language === 'es' ? 'Generador de Comando' : 'Command Generator'}: {selectedSkill.name}
              </h3>
              <button onClick={() => setSelectedSkill(null)} className="hm-btn-secondary" style={{ padding: '0.3rem 0.6rem' }}>
                <span>✕</span>
              </button>
            </div>

            <p style={{ color: 'var(--text-secondary)', fontSize: '0.9rem', marginBottom: '1.2rem' }}>
              {selectedSkill.description}
            </p>

            <label style={{ display: 'block', fontSize: '0.85rem', fontFamily: 'var(--font-mono)', marginBottom: '0.5rem', color: 'var(--text-muted)' }}>
              {language === 'es' ? 'Parámetros de contexto (Ej: URL de PR, archivo objetivo):' : 'Context parameters (e.g. PR URL, target file):'}
            </label>
            <input
              type="text"
              placeholder="Ej: https://github.com/org/repo/pull/42"
              value={customInput}
              onChange={(e) => setCustomInput(e.target.value)}
              style={{
                width: '100%',
                padding: '0.7rem 0.9rem',
                borderRadius: '4px',
                background: 'var(--bg-surface)',
                border: '1px solid var(--border-color)',
                color: 'var(--text-primary)',
                fontFamily: 'var(--font-sans)',
                fontSize: '0.9rem',
                marginBottom: '1.5rem'
              }}
            />

            <div className="code-block" style={{ marginBottom: '1.5rem' }}>
              {customInput ? `${selectedSkill.examplePrompt} (${customInput})` : selectedSkill.examplePrompt}
            </div>

            <div style={{ display: 'flex', gap: '0.8rem', justifyContent: 'flex-end' }}>
              <button onClick={() => setSelectedSkill(null)} className="hm-btn-secondary">
                <span>{language === 'es' ? 'Cerrar' : 'Close'}</span>
              </button>
              <button
                onClick={() => {
                  const cmd = customInput ? `${selectedSkill.examplePrompt} (${customInput})` : selectedSkill.examplePrompt;
                  handleCopyPrompt(cmd, 'modal');
                }}
                className="hm-btn-primary"
              >
                <span>{copiedId === 'modal' ? (language === 'es' ? '¡Copiado!' : 'Copied!') : (language === 'es' ? 'Copiar Comando Final' : 'Copy Final Command')}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </section>
  );
};
