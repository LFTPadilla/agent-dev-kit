/* Hallmark · pre-emit critique: P5 H5 E5 S5 R5 V5 */
import { useState, useEffect } from 'react';
import { Navbar } from './components/Navbar';
import { HeroSection } from './components/HeroSection';
import { TerminalSimulator } from './components/TerminalSimulator';
import { ArchitectureExplorer } from './components/ArchitectureExplorer';
import { PersonalTutorSim } from './components/PersonalTutorSim';
import { PrReviewEvalLab } from './components/PrReviewEvalLab';
import { SkillCatalogExplorer } from './components/SkillCatalogExplorer';
import { TierSetupWizard } from './components/TierSetupWizard';
import { Footer } from './components/Footer';
import type { Language } from './data/translations';

function getInitialTheme(): string {
  const savedTheme = localStorage.getItem('agent-dev-kit-theme');
  if (savedTheme) {
    return savedTheme;
  }
  const prefersDark = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
  return prefersDark ? 'brutal-dark' : 'brutal-light';
}

function getInitialLanguage(): Language {
  const savedLang = localStorage.getItem('agent-dev-kit-lang') as Language | null;
  if (savedLang === 'es' || savedLang === 'en') {
    return savedLang;
  }
  return 'en';
}

export function App() {
  const [activeTab, setActiveTab] = useState<string>('overview');
  const [currentTheme, setCurrentTheme] = useState<string>(getInitialTheme);
  const [language, setLanguage] = useState<Language>(getInitialLanguage);

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', currentTheme);
  }, [currentTheme]);

  useEffect(() => {
    document.documentElement.setAttribute('lang', language);
  }, [language]);

  useEffect(() => {
    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');
    const handleSystemThemeChange = (e: MediaQueryListEvent) => {
      const savedTheme = localStorage.getItem('agent-dev-kit-theme');
      if (!savedTheme) {
        setCurrentTheme(e.matches ? 'brutal-dark' : 'brutal-light');
      }
    };

    if (mediaQuery.addEventListener) {
      mediaQuery.addEventListener('change', handleSystemThemeChange);
      return () => mediaQuery.removeEventListener('change', handleSystemThemeChange);
    }
  }, []);

  const handleSetTheme = (newTheme: string) => {
    setCurrentTheme(newTheme);
    localStorage.setItem('agent-dev-kit-theme', newTheme);
  };

  const handleSetLanguage = (newLang: Language) => {
    setLanguage(newLang);
    localStorage.setItem('agent-dev-kit-lang', newLang);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Navbar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab}
        currentTheme={currentTheme}
        setTheme={handleSetTheme}
        language={language}
        setLanguage={handleSetLanguage}
      />

      <main className="page-container" style={{ flex: 1 }}>
        {activeTab === 'overview' && (
          <>
            <HeroSection setActiveTab={setActiveTab} language={language} />
            <TerminalSimulator language={language} />
            <ArchitectureExplorer language={language} />
            <SkillCatalogExplorer language={language} />
            <PrReviewEvalLab language={language} />
            <PersonalTutorSim language={language} />
            <TierSetupWizard language={language} />
          </>
        )}

        {activeTab === 'terminal' && <TerminalSimulator language={language} />}

        {activeTab === 'architecture' && <ArchitectureExplorer language={language} />}

        {activeTab === 'skills' && <SkillCatalogExplorer language={language} />}

        {activeTab === 'evals' && <PrReviewEvalLab language={language} />}

        {activeTab === 'tutor' && <PersonalTutorSim language={language} />}

        {activeTab === 'setup' && <TierSetupWizard language={language} />}
      </main>

      <Footer language={language} />
    </div>
  );
}

export default App;
