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

export function App() {
  const [activeTab, setActiveTab] = useState<string>('overview');
  const [currentTheme, setCurrentTheme] = useState<string>('brutal-dark');
  const [language, setLanguage] = useState<Language>('es');

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', currentTheme);
  }, [currentTheme]);

  return (
    <div style={{ minHeight: '100vh', display: 'flex', flexDirection: 'column' }}>
      <Navbar 
        activeTab={activeTab} 
        setActiveTab={setActiveTab}
        currentTheme={currentTheme}
        setTheme={setCurrentTheme}
        language={language}
        setLanguage={setLanguage}
      />

      <main className="page-container" style={{ flex: 1 }}>
        {activeTab === 'overview' && (
          <>
            <HeroSection setActiveTab={setActiveTab} language={language} />
            <TerminalSimulator language={language} />
            <ArchitectureExplorer />
            <SkillCatalogExplorer language={language} />
            <PrReviewEvalLab />
            <PersonalTutorSim />
            <TierSetupWizard />
          </>
        )}

        {activeTab === 'architecture' && <ArchitectureExplorer />}

        {activeTab === 'skills' && <SkillCatalogExplorer language={language} />}

        {activeTab === 'evals' && <PrReviewEvalLab />}

        {activeTab === 'tutor' && <PersonalTutorSim />}

        {activeTab === 'setup' && <TierSetupWizard />}
      </main>

      <Footer />
    </div>
  );
}

export default App;
