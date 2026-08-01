import React, { useState } from 'react';
import { REPO_STATS } from '../data/repoData';
import { TRANSLATIONS } from '../data/translations';
import type { Language } from '../data/translations';
import { Sun, Moon, Globe } from 'lucide-react';

interface NavbarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  currentTheme: string;
  setTheme: (theme: string) => void;
  language: Language;
  setLanguage: (lang: Language) => void;
}

export const Navbar: React.FC<NavbarProps> = ({
  activeTab,
  setActiveTab,
  currentTheme,
  setTheme,
  language,
  setLanguage
}) => {
  const [dropdownOpen, setDropdownOpen] = useState(false);
  const t = TRANSLATIONS[language].nav;

  const themes = [
    { id: 'brutal-dark', name: 'Brutal (Monochrome Dark)', num: '01 / 07', isDark: true },
    { id: 'brutal-light', name: 'Brutal (Monochrome Light)', num: '02 / 07', isDark: false },
    { id: 'hum', name: 'Hum (Editorial Light)', num: '03 / 07', isDark: false },
    { id: 'midnight', name: 'Midnight (Slate Dark)', num: '04 / 07', isDark: true },
    { id: 'terminal', name: 'Terminal (Matrix Green)', num: '05 / 07', isDark: true },
    { id: 'garden', name: 'Garden (Organic Serif)', num: '06 / 07', isDark: false },
    { id: 'cobalt', name: 'Cobalt (Deep Tech)', num: '07 / 07', isDark: true },
  ];

  const currentThemeObj = themes.find(th => th.id === currentTheme) || themes[0];
  const isCurrentlyDark = currentThemeObj.isDark;

  const toggleLightDarkMode = () => {
    if (currentTheme === 'brutal-dark') {
      setTheme('brutal-light');
    } else if (currentTheme === 'brutal-light' || currentTheme === 'brutal') {
      setTheme('brutal-dark');
    } else if (isCurrentlyDark) {
      setTheme('brutal-light');
    } else {
      setTheme('brutal-dark');
    }
  };

  const toggleLanguage = () => {
    setLanguage(language === 'es' ? 'en' : 'es');
  };

  return (
    <header className="hallmark-banner">
      {/* Brand mark */}
      <a 
        onClick={(e) => { e.preventDefault(); setActiveTab('overview'); }} 
        href="#overview" 
        className="brand-mark"
      >
        <span className="brand-mark__slash">/</span>
        <span>agent-dev-kit</span>
        <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)', marginLeft: '0.4rem' }}>
          v{REPO_STATS.version}
        </span>
      </a>

      {/* Nav Links */}
      <ul className="banner__nav">
        {[
          { id: 'overview', label: t.overview },
          { id: 'architecture', label: t.architecture },
          { id: 'skills', label: t.skills },
          { id: 'evals', label: t.evals },
          { id: 'tutor', label: t.tutor },
          { id: 'setup', label: t.install },
        ].map((item) => (
          <li key={item.id}>
            <a
              href={`#${item.id}`}
              onClick={(e) => { e.preventDefault(); setActiveTab(item.id); }}
              className={`banner__link ${activeTab === item.id ? 'active' : ''}`}
            >
              {item.label}
            </a>
          </li>
        ))}
      </ul>

      {/* Language Switcher, Light/Dark & Theme Selector */}
      <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
        
        {/* Language Switcher Toggle */}
        <button
          onClick={toggleLanguage}
          className="banner__theme-btn"
          title={`Cambiar idioma a ${language === 'es' ? 'English' : 'Español'}`}
          style={{ padding: '0.35rem 0.65rem', gap: '0.35rem' }}
        >
          <Globe size={14} style={{ color: 'var(--accent)' }} />
          <span style={{ fontSize: '0.78rem', fontWeight: 700 }}>
            {language.toUpperCase()}
          </span>
        </button>

        {/* Direct Light / Dark Quick Toggle */}
        <button
          onClick={toggleLightDarkMode}
          className="banner__theme-btn"
          title={`Cambiar a modo ${isCurrentlyDark ? 'Claro' : 'Oscuro'}`}
          style={{ padding: '0.35rem 0.65rem' }}
        >
          {isCurrentlyDark ? (
            <Sun size={15} style={{ color: '#f59e0b' }} />
          ) : (
            <Moon size={15} style={{ color: '#8b5cf6' }} />
          )}
          <span style={{ fontSize: '0.75rem', fontWeight: 600 }}>
            {isCurrentlyDark ? 'Light' : 'Dark'}
          </span>
        </button>

        {/* Full Theme Selector Dropdown */}
        <div style={{ position: 'relative' }}>
          <button
            onClick={() => setDropdownOpen(!dropdownOpen)}
            className="banner__theme-btn"
            title="Haz clic para cambiar el tema visual"
          >
            <span style={{ color: 'var(--accent)', fontWeight: 700 }}>{currentThemeObj.num}</span>
            <span style={{ color: 'var(--text-muted)' }}>—</span>
            <span>{currentThemeObj.name}</span>
            <span style={{ fontSize: '0.7rem' }}>▼</span>
          </button>

          {dropdownOpen && (
            <div style={{
              position: 'absolute',
              top: '120%',
              right: 0,
              background: 'var(--bg-surface)',
              border: '1px solid var(--border-color)',
              borderRadius: '6px',
              boxShadow: '0 10px 30px rgba(0,0,0,0.2)',
              zIndex: 200,
              minWidth: '240px',
              padding: '0.5rem 0'
            }}>
              {themes.map((th) => (
                <button
                  key={th.id}
                  onClick={() => {
                    setTheme(th.id);
                    setDropdownOpen(false);
                  }}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    padding: '0.6rem 1rem',
                    background: currentTheme === th.id ? 'var(--bg-subtle)' : 'transparent',
                    border: 'none',
                    color: currentTheme === th.id ? 'var(--accent)' : 'var(--text-primary)',
                    fontFamily: 'var(--font-mono)',
                    fontSize: '0.8rem',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between'
                  }}
                >
                  <span>{th.name}</span>
                  <span style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{th.num.split(' ')[0]}</span>
                </button>
              ))}
            </div>
          )}
        </div>
      </div>
    </header>
  );
};
