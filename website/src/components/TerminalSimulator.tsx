import React, { useState, useEffect, useRef } from 'react';
import { RefreshCw, Copy, Check, ChevronRight, ArrowDown } from 'lucide-react';
import { TRANSLATIONS } from '../data/translations';
import type { Language } from '../data/translations';

interface TmuxSubWindow {
  id: number;
  name: string;
  badge: string;
  isClaudeCodeUI?: boolean;
  isCodexUI?: boolean;
  isHermesOrchestratorUI?: boolean;
  lines: {
    time?: string;
    text: string;
    type: 'prompt' | 'info' | 'success' | 'warn' | 'error' | 'code' | 'spinner' | 'divider' | 'tmux' | 'recap' | 'task_done' | 'task_open' | 'crunch' | 'codex_ran' | 'codex_tree' | 'codex_working' | 'hermes_header' | 'hermes_item' | 'hermes_note' | 'lens_header' | 'diff_remove' | 'diff_add' | 'approval_badge';
    delay: number;
  }[];
}

interface TerminalTab {
  id: string;
  name: string;
  command: string;
  description: string;
  badge: string;
  lines?: {
    time?: string;
    text: string;
    type: 'prompt' | 'info' | 'success' | 'warn' | 'error' | 'code' | 'spinner' | 'divider' | 'tmux' | 'recap' | 'task_done' | 'task_open' | 'crunch' | 'codex_ran' | 'codex_tree' | 'codex_working' | 'hermes_header' | 'hermes_item' | 'hermes_note' | 'lens_header' | 'diff_remove' | 'diff_add' | 'approval_badge';
    delay: number;
  }[];
  tmuxSubWindows?: TmuxSubWindow[];
}

interface TerminalSimulatorProps {
  language: Language;
}

export const TerminalSimulator: React.FC<TerminalSimulatorProps> = ({ language }) => {
  const [activeTabId, setActiveTabId] = useState<string>('tutor-tmux');
  const [activeTmuxSubTab, setActiveTmuxSubTab] = useState<number>(0);
  const [visibleLines, setVisibleLines] = useState<any[]>([]);
  const [isStreaming, setIsStreaming] = useState<boolean>(false);
  const [userInput, setUserInput] = useState<string>('');
  const [isCopied, setIsCopied] = useState<boolean>(false);
  const [isUserScrolledUp, setIsUserScrolledUp] = useState<boolean>(false);
  const [isVisibleOnScreen, setIsVisibleOnScreen] = useState<boolean>(false);

  const terminalWrapperRef = useRef<HTMLDivElement>(null);
  const terminalBodyRef = useRef<HTMLDivElement>(null);
  const userScrolledRef = useRef<boolean>(false);
  const activeTimeoutsRef = useRef<any[]>([]);

  const tTerm = TRANSLATIONS[language].terminal;
  const tabs = tTerm.tabs;

  const TERMINAL_TABS: TerminalTab[] = [
    {
      id: 'tutor-tmux',
      name: tabs.tmux.name,
      command: 'tmux attach -t tutor',
      description: tabs.tmux.desc,
      badge: 'Capa 3: Orquestador Tmux',
      tmuxSubWindows: [
        {
          id: 0,
          name: '0:tutor-orchestrator*',
          badge: 'Orquestador Socrático (Hermes UI)',
          isHermesOrchestratorUI: true,
          lines: [
            { text: tabs.tmux.sub0.header, type: 'hermes_header', delay: 100 },
            { text: tabs.tmux.sub0.item1, type: 'hermes_item', delay: 400 },
            { text: tabs.tmux.sub0.item2, type: 'hermes_item', delay: 800 },
            { text: tabs.tmux.sub0.item3, type: 'hermes_item', delay: 1200 },
            { text: tabs.tmux.sub0.item4, type: 'hermes_item', delay: 1600 },
            { text: tabs.tmux.sub0.item5, type: 'hermes_item', delay: 2000 },
            { text: tabs.tmux.sub0.note, type: 'hermes_note', delay: 2400 }
          ]
        },
        {
          id: 1,
          name: '1:claude-worker',
          badge: 'Worker 1 (Claude Code UI)',
          isClaudeCodeUI: true,
          lines: [
            { text: tabs.tmux.sub1.info1, type: 'info', delay: 100 },
            { text: '* Crunched for 12s', type: 'crunch', delay: 400 },
            { text: tabs.tmux.sub1.recap, type: 'recap', delay: 800 },
            { text: tabs.tmux.sub1.info2, type: 'info', delay: 1100 },
            { text: tabs.tmux.sub1.t1, type: 'task_done', delay: 1300 },
            { text: tabs.tmux.sub1.t2, type: 'task_done', delay: 1500 },
            { text: tabs.tmux.sub1.t3, type: 'task_done', delay: 1700 },
            { text: tabs.tmux.sub1.t4, type: 'task_open', delay: 2000 }
          ]
        },
        {
          id: 2,
          name: '2:codex-lane',
          badge: 'Worker 2 (Codex CLI UI)',
          isCodexUI: true,
          lines: [
            { text: tabs.tmux.sub2.ran, type: 'codex_ran', delay: 200 },
            { text: tabs.tmux.sub2.tree1, type: 'codex_tree', delay: 600 },
            { text: tabs.tmux.sub2.tree2, type: 'codex_tree', delay: 1000 },
            { text: tabs.tmux.sub2.tree3, type: 'codex_tree', delay: 1400 },
            { text: tabs.tmux.sub2.working, type: 'codex_working', delay: 1800 }
          ]
        }
      ]
    },
    {
      id: 'pr-review',
      name: tabs.prReview.name,
      command: '/pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42',
      description: tabs.prReview.desc,
      badge: 'Capa 2: Ship Gate',
      lines: [
        { time: '14:14:00', text: 'felipe@agent-dev-kit:~/web-page (main) $ /pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42', type: 'prompt', delay: 100 },
        { time: '14:14:00', text: tabs.prReview.fetching, type: 'spinner', delay: 300 },
        { time: '14:14:01', text: tabs.prReview.loaded, type: 'success', delay: 600 },
        { text: '----------------------------------------------------------------------------------------------------', type: 'divider', delay: 700 },
        { time: '14:14:01', text: tabs.prReview.lens1, type: 'lens_header', delay: 900 },
        { text: '  ├─ Scanning: UserRepository.java (L14-L18)', type: 'code', delay: 1100 },
        { text: '  │  - String query = "SELECT * FROM users WHERE id = \'" + id + "\'";', type: 'diff_remove', delay: 1300 },
        { text: '  │  + @Query("SELECT u FROM User u WHERE u.id = :id")', type: 'diff_add', delay: 1500 },
        { time: '14:14:02', text: tabs.prReview.result1, type: 'success', delay: 1800 },
        { text: '----------------------------------------------------------------------------------------------------', type: 'divider', delay: 1900 },
        { time: '14:14:02', text: tabs.prReview.lens2, type: 'lens_header', delay: 2100 },
        { text: tabs.prReview.result2_1, type: 'success', delay: 2400 },
        { text: tabs.prReview.result2_2, type: 'info', delay: 2600 },
        { text: '----------------------------------------------------------------------------------------------------', type: 'divider', delay: 2700 },
        { time: '14:14:03', text: tabs.prReview.lens3, type: 'lens_header', delay: 2900 },
        { text: tabs.prReview.ref1, type: 'warn', delay: 3100 },
        { text: tabs.prReview.ref2, type: 'success', delay: 3300 },
        { time: '14:14:03', text: tabs.prReview.verdict3, type: 'success', delay: 3500 },
        { text: '----------------------------------------------------------------------------------------------------', type: 'divider', delay: 3600 },
        { time: '14:14:04', text: tabs.prReview.approved, type: 'approval_badge', delay: 3800 }
      ]
    },
    {
      id: 'doctor',
      name: tabs.doctor.name,
      command: 'npm run doctor && npm run validate',
      description: tabs.doctor.desc,
      badge: 'Capa 1: Direct',
      lines: [
        { time: '14:14:09', text: 'felipe@agent-dev-kit:~/web-page (main) $ npm run doctor && npm run validate', type: 'prompt', delay: 100 },
        { time: '14:14:09', text: tabs.doctor.running, type: 'spinner', delay: 300 },
        { time: '14:14:10', text: tabs.doctor.node, type: 'success', delay: 600 },
        { time: '14:14:10', text: tabs.doctor.gsd, type: 'success', delay: 900 },
        { time: '14:14:11', text: tabs.doctor.prov, type: 'success', delay: 1300 },
        { text: '----------------------------------------------------------------------------------------------------', type: 'divider', delay: 1400 },
        { time: '14:14:11', text: tabs.doctor.val, type: 'info', delay: 1600 },
        { text: tabs.doctor.aligned1, type: 'code', delay: 1900 },
        { text: tabs.doctor.aligned2, type: 'code', delay: 2100 },
        { time: '14:14:12', text: tabs.doctor.priv, type: 'info', delay: 2400 },
        { time: '14:14:12', text: tabs.doctor.clean, type: 'success', delay: 2800 },
        { time: '14:14:13', text: tabs.doctor.result, type: 'success', delay: 3200 }
      ]
    }
  ];

  const activeTab = TERMINAL_TABS.find(t => t.id === activeTabId) || TERMINAL_TABS[0];

  const currentSubWindow = activeTab.tmuxSubWindows
    ? activeTab.tmuxSubWindows[activeTmuxSubTab]
    : null;

  const activeLines = currentSubWindow
    ? currentSubWindow.lines
    : activeTab.lines || [];

  const isClaudeCodeUI = currentSubWindow?.isClaudeCodeUI || false;
  const isCodexUI = currentSubWindow?.isCodexUI || false;
  const isHermesOrchestratorUI = currentSubWindow?.isHermesOrchestratorUI || false;

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisibleOnScreen(true);
        }
      },
      { threshold: 0.15 }
    );

    if (terminalWrapperRef.current) {
      observer.observe(terminalWrapperRef.current);
    }

    return () => observer.disconnect();
  }, []);

  const runStreamingAnimation = () => {
    activeTimeoutsRef.current.forEach(clearTimeout);
    activeTimeoutsRef.current = [];

    userScrolledRef.current = false;
    setIsUserScrolledUp(false);
    setVisibleLines([]);
    setIsStreaming(true);

    const timeouts: any[] = [];

    activeLines.forEach((lineItem) => {
      const t = setTimeout(() => {
        setVisibleLines((prev) => [...prev, lineItem]);
      }, lineItem.delay);
      timeouts.push(t);
    });

    const completionTimer = setTimeout(() => {
      setIsStreaming(false);
    }, activeLines[activeLines.length - 1]?.delay + 200 || 500);

    timeouts.push(completionTimer);
    activeTimeoutsRef.current = timeouts;
  };

  useEffect(() => {
    if (!isVisibleOnScreen) return;
    runStreamingAnimation();

    return () => {
      activeTimeoutsRef.current.forEach(clearTimeout);
    };
  }, [activeTabId, activeTmuxSubTab, isVisibleOnScreen, language]);

  useEffect(() => {
    if (!userScrolledRef.current && terminalBodyRef.current) {
      terminalBodyRef.current.scrollTop = terminalBodyRef.current.scrollHeight;
    }
  }, [visibleLines]);

  const handleScroll = () => {
    const el = terminalBodyRef.current;
    if (!el) return;
    const isUp = el.scrollTop + el.clientHeight < el.scrollHeight - 40;
    userScrolledRef.current = isUp;
    setIsUserScrolledUp(isUp);
  };

  const scrollToBottom = () => {
    userScrolledRef.current = false;
    setIsUserScrolledUp(false);
    if (terminalBodyRef.current) {
      terminalBodyRef.current.scrollTop = terminalBodyRef.current.scrollHeight;
    }
  };

  const handleCustomCommandSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!userInput.trim()) return;

    const newPromptLine = {
      time: new Date().toLocaleTimeString('es-ES', { hour12: false }),
      text: `felipe@agent-dev-kit:~/web-page (main) $ ${userInput}`,
      type: 'prompt' as const,
      delay: 0
    };

    const responseLine = {
      time: new Date().toLocaleTimeString('es-ES', { hour12: false }),
      text: `✔ Executed command: '${userInput}' [OK]. Synthesizing agent context...`,
      type: 'success' as const,
      delay: 300
    };

    userScrolledRef.current = false;
    setIsUserScrolledUp(false);
    setVisibleLines((prev) => [...prev, newPromptLine, responseLine]);
    setUserInput('');
  };

  const copyActiveCommand = () => {
    const cmdToCopy = activeTab.command;
    navigator.clipboard.writeText(cmdToCopy);
    setIsCopied(true);
    setTimeout(() => setIsCopied(false), 2000);
  };

  return (
    <section style={{ marginBottom: '5rem' }} id="terminal-sim" ref={terminalWrapperRef}>
      <header>
        <p className="section-label">
          <span className="num">{tTerm.labelNum}</span>
          <span className="divider">⁄</span>
          <span>{tTerm.labelTitle}</span>
        </p>
        <h2 className="section-title">{tTerm.title}</h2>
      </header>

      {/* Expanded Authentic Dark Terminal Window Wrapper */}
      <div style={{
        borderRadius: '8px',
        overflow: 'hidden',
        boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.55)',
        border: '1px solid #30363d',
        background: '#0d1117',
        fontFamily: "'Geist Mono', 'Fira Code', 'JetBrains Mono', 'Cascadia Code', monospace",
        position: 'relative',
        marginTop: '1.5rem'
      }}>
        
        {/* Terminal Header Bar */}
        <div style={{
          background: '#161b22',
          borderBottom: '1px solid #21262d',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '0 0.8rem',
          height: '44px'
        }}>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: '1rem', overflowX: 'auto' }}>
            <div style={{ display: 'flex', gap: '0.45rem', paddingRight: '0.5rem' }}>
              <span style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ff5f56', display: 'inline-block' }} />
              <span style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#ffbd2e', display: 'inline-block' }} />
              <span style={{ width: '12px', height: '12px', borderRadius: '50%', background: '#27c93f', display: 'inline-block' }} />
            </div>

            <div style={{ display: 'flex', gap: '0.4rem' }}>
              {TERMINAL_TABS.map((tab) => {
                const isActive = tab.id === activeTabId;
                return (
                  <button
                    key={tab.id}
                    onClick={() => {
                      setActiveTabId(tab.id);
                      if (tab.tmuxSubWindows) setActiveTmuxSubTab(0);
                    }}
                    style={{
                      background: isActive ? '#0d1117' : 'transparent',
                      color: isActive ? '#58a6ff' : '#8b949e',
                      border: 'none',
                      borderTopLeftRadius: '6px',
                      borderTopRightRadius: '6px',
                      padding: '0.4rem 0.95rem',
                      fontSize: '0.82rem',
                      fontFamily: 'inherit',
                      fontWeight: isActive ? 600 : 400,
                      cursor: 'pointer',
                      borderBottom: isActive ? '2px solid #58a6ff' : 'none',
                      display: 'flex',
                      alignItems: 'center',
                      gap: '0.4rem',
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <span>{tab.name}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Clean Top Window Action Controls */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <button
              onClick={runStreamingAnimation}
              title={tTerm.restart}
              style={{
                background: '#21262d',
                border: '1px solid #30363d',
                color: '#c9d1d9',
                borderRadius: '4px',
                padding: '0.3rem 0.6rem',
                fontSize: '0.78rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                transition: 'all 0.15s ease'
              }}
            >
              <RefreshCw size={13} className={isStreaming ? 'animate-spin' : ''} />
              <span>{tTerm.restart}</span>
            </button>

            <button
              onClick={copyActiveCommand}
              title={`${tTerm.copyCommand}: ${activeTab.command}`}
              style={{
                background: isCopied ? '#238636' : '#21262d',
                border: '1px solid #30363d',
                color: '#c9d1d9',
                borderRadius: '4px',
                padding: '0.3rem 0.6rem',
                fontSize: '0.78rem',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.4rem',
                transition: 'all 0.15s ease'
              }}
            >
              {isCopied ? <Check size={13} style={{ color: '#ffffff' }} /> : <Copy size={13} />}
              <span>{isCopied ? tTerm.commandCopied : tTerm.copyCommand}</span>
            </button>
          </div>

        </div>

        {/* Terminal Description Banner */}
        <div style={{
          background: '#161b22',
          padding: '0.6rem 1.2rem',
          borderBottom: '1px solid #21262d',
          fontSize: '0.82rem',
          color: '#8b949e',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between'
        }}>
          <span>{activeTab.description}</span>
          <span style={{ color: isStreaming ? '#38bdf8' : '#3fb950', fontSize: '0.75rem', fontWeight: 600 }}>
            {isStreaming ? tTerm.executing : tTerm.completed}
          </span>
        </div>

        {/* Real TMUX Status Bar */}
        {activeTab.tmuxSubWindows && (
          <div style={{
            background: '#0d1117',
            borderBottom: '1px solid #21262d',
            padding: '0.4rem 1.2rem',
            display: 'flex',
            alignItems: 'center',
            gap: '0.6rem',
            fontSize: '0.8rem'
          }}>
            <span style={{ color: '#27c93f', fontWeight: 700 }}>[tmux: tutor]</span>
            {activeTab.tmuxSubWindows.map((subWin) => {
              const isSubActive = activeTmuxSubTab === subWin.id;
              return (
                <button
                  key={subWin.id}
                  onClick={() => setActiveTmuxSubTab(subWin.id)}
                  style={{
                    background: isSubActive ? '#238636' : '#21262d',
                    color: isSubActive ? '#ffffff' : '#8b949e',
                    border: 'none',
                    borderRadius: '4px',
                    padding: '0.25rem 0.7rem',
                    fontSize: '0.78rem',
                    fontFamily: 'inherit',
                    fontWeight: isSubActive ? 700 : 400,
                    cursor: 'pointer',
                    transition: 'all 0.15s ease'
                  }}
                >
                  <span>{subWin.name}</span>
                </button>
              );
            })}
          </div>
        )}

        {/* Real-time Terminal Body */}
        <div
          ref={terminalBodyRef}
          onScroll={handleScroll}
          style={{
            padding: '1.4rem',
            minHeight: '440px',
            maxHeight: '580px',
            overflowY: 'auto',
            fontSize: '0.92rem',
            lineHeight: '1.65',
            color: '#c9d1d9',
            position: 'relative'
          }}
        >
          {isHermesOrchestratorUI ? (
            <div style={{ border: '1px solid #eab308', borderRadius: '6px', padding: '1rem 1.2rem', background: '#0e1017', margin: '0.5rem 0 1.2rem 0' }}>
              <div style={{ color: '#eab308', fontWeight: 700, marginBottom: '0.8rem', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <span>╭─ ☤ Hermes Orchestrator Delegation Plan ───────────────────────────────────╮</span>
              </div>

              {visibleLines.map((line, index) => {
                if (line.type === 'hermes_header') {
                  return (
                    <div key={index} style={{ color: '#f0f6fc', fontWeight: 600, marginBottom: '0.6rem' }}>
                      {line.text}
                    </div>
                  );
                }

                if (line.type === 'hermes_item') {
                  return (
                    <div key={index} style={{ color: '#cbd5e1', paddingLeft: '0.5rem', marginBottom: '0.4rem' }}>
                      {line.text}
                    </div>
                  );
                }

                if (line.type === 'hermes_note') {
                  return (
                    <div key={index} style={{ color: '#94a3b8', fontStyle: 'italic', marginTop: '0.8rem', borderTop: '1px solid #334155', paddingTop: '0.6rem' }}>
                      {line.text}
                    </div>
                  );
                }

                return null;
              })}

              <div style={{ color: '#eab308', fontWeight: 700, marginTop: '0.8rem' }}>
                <span>╰──────────────────────────────────────────────────────────────────────────╯</span>
              </div>
            </div>
          ) : (
            visibleLines.map((line, index) => {
              if (line.type === 'divider') {
                return (
                  <div key={index} style={{ color: '#30363d', margin: '0.4rem 0' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'lens_header') {
                return (
                  <div key={index} style={{ color: '#38bdf8', fontWeight: 700, margin: '0.5rem 0 0.2rem 0' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'diff_remove') {
                return (
                  <div key={index} style={{ color: '#f85149', background: 'rgba(248, 81, 73, 0.1)', padding: '0 4px', borderRadius: '2px' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'diff_add') {
                return (
                  <div key={index} style={{ color: '#3fb950', background: 'rgba(63, 185, 80, 0.1)', padding: '0 4px', borderRadius: '2px' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'approval_badge') {
                return (
                  <div key={index} style={{ color: '#3fb950', background: 'rgba(35, 134, 54, 0.15)', border: '1px solid #238636', borderRadius: '4px', padding: '0.4rem 0.8rem', fontWeight: 700, margin: '0.8rem 0 0.2rem 0' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'crunch') {
                return (
                  <div key={index} style={{ color: '#8b949e', margin: '0.3rem 0' }}>
                    * {line.text.replace('* ', '')}
                  </div>
                );
              }

              if (line.type === 'recap') {
                return (
                  <div key={index} style={{ color: '#8b949e', fontStyle: 'italic', margin: '0.6rem 0' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'task_done') {
                return (
                  <div key={index} style={{ color: '#8b949e', textDecoration: 'line-through', paddingLeft: '1rem' }}>
                    <span style={{ color: '#3fb950', textDecoration: 'none', display: 'inline-block', marginRight: '0.5rem' }}>✔</span>
                    {line.text.replace('✔ ', '')}
                  </div>
                );
              }

              if (line.type === 'task_open') {
                return (
                  <div key={index} style={{ color: '#c9d1d9', paddingLeft: '1rem' }}>
                    <span style={{ color: '#8b949e', display: 'inline-block', marginRight: '0.5rem' }}>□</span>
                    {line.text.replace('□ ', '')}
                  </div>
                );
              }

              if (line.type === 'codex_ran') {
                return (
                  <div key={index} style={{ color: '#f0f6fc', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.5rem', margin: '0.6rem 0 0.2rem 0' }}>
                    <span style={{ color: '#3fb950', fontSize: '1rem' }}>•</span>
                    <span>{line.text}</span>
                  </div>
                );
              }

              if (line.type === 'codex_tree') {
                return (
                  <div key={index} style={{ color: '#8b949e', paddingLeft: '1.2rem', borderLeft: '2px solid #30363d', marginLeft: '0.3rem', marginTop: '0.1rem', marginBottom: '0.1rem' }}>
                    {line.text}
                  </div>
                );
              }

              if (line.type === 'codex_working') {
                return (
                  <div key={index} style={{ color: '#f0f6fc', fontWeight: 600, display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.8rem' }}>
                    <span style={{ color: '#58a6ff', fontSize: '1rem' }}>•</span>
                    <span>{line.text}</span>
                  </div>
                );
              }

              let textStyle: React.CSSProperties = { color: '#c9d1d9' };
              if (line.type === 'prompt') textStyle = { color: '#58a6ff', fontWeight: 600 };
              if (line.type === 'info') textStyle = { color: '#c9d1d9' };
              if (line.type === 'success') textStyle = { color: '#3fb950', fontWeight: 500 };
              if (line.type === 'warn') textStyle = { color: '#d29922' };
              if (line.type === 'error') textStyle = { color: '#f85149', fontWeight: 600 };
              if (line.type === 'code') textStyle = { color: '#a5d6ff' };
              if (line.type === 'spinner') textStyle = { color: '#d29922' };
              if (line.type === 'tmux') textStyle = { color: '#a855f7', fontWeight: 600 };

              return (
                <div key={index} style={{ display: 'flex', gap: '0.9rem' }}>
                  {line.time && (
                    <span style={{ color: '#484f58', fontSize: '0.78rem', userSelect: 'none', minWidth: '60px' }}>
                      [{line.time}]
                    </span>
                  )}
                  <span style={textStyle}>{line.text}</span>
                </div>
              );
            })
          )}

          {/* Authentic Claude Code Bottom Tokens Note */}
          {isClaudeCodeUI && (
            <div style={{ textAlign: 'right', color: '#8b949e', fontSize: '0.78rem', marginTop: '1.5rem', marginBottom: '0.5rem' }}>
              new task? <span style={{ color: '#58a6ff' }}>/clear</span> to save <span style={{ color: '#58a6ff', fontWeight: 600 }}>285.2k tokens</span>
            </div>
          )}
        </div>

        {/* Float Pill Button when Scrolled Up */}
        {isUserScrolledUp && (
          <button
            onClick={scrollToBottom}
            style={{
              position: 'absolute',
              bottom: '65px',
              right: '24px',
              background: '#238636',
              color: '#ffffff',
              border: 'none',
              borderRadius: '20px',
              padding: '0.45rem 1rem',
              fontSize: '0.78rem',
              fontFamily: 'inherit',
              fontWeight: 600,
              cursor: 'pointer',
              boxShadow: '0 4px 14px rgba(0, 0, 0, 0.45)',
              display: 'flex',
              alignItems: 'center',
              gap: '0.4rem',
              zIndex: 10
            }}
          >
            <ArrowDown size={14} />
            <span>{language === 'es' ? 'Ver más reciente' : 'See latest'}</span>
          </button>
        )}

        {/* Authentic Status Bars per UI Type */}
        {isClaudeCodeUI ? (
          <div>
            <div style={{ background: '#161b22', borderTop: '1px solid #21262d', padding: '0.7rem 1.2rem', display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span style={{ color: '#f0f6fc', fontWeight: 700 }}>&gt;</span>
              <span style={{ color: '#f0f6fc', fontWeight: 600 }}>█</span>
            </div>
            <div style={{ background: '#090d16', borderTop: '1px solid #21262d', padding: '0.5rem 1.2rem', fontSize: '0.78rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: '#8b949e', flexWrap: 'wrap', gap: '0.5rem' }}>
              <div>
                <span style={{ color: '#3fb950', fontWeight: 700 }}>[Opus 5 (1M context)]</span>
                <span style={{ color: '#6e7681', margin: '0 0.5rem' }}>|</span>
                <span style={{ color: '#e2e8f0', fontWeight: 600 }}>agent-dev-kit</span>
              </div>
              <div style={{ display: 'flex', gap: '1.2rem', alignItems: 'center' }}>
                <span>Context <span style={{ color: '#3fb950' }}>[███░░░░░░░] 31%</span></span>
                <span>Usage <span style={{ color: '#58a6ff' }}>[█░░░░░░░░░] 8%</span></span>
                <span style={{ color: '#ec4899', fontWeight: 600 }}>▸▸ bypass permissions on <span style={{ color: '#8b949e', fontWeight: 400 }}>(shift+tab to cycle) · ← for agents</span></span>
              </div>
            </div>
          </div>
        ) : isCodexUI ? (
          <div>
            <div style={{ background: '#1e2430', borderTop: '1px solid #30363d', padding: '0.75rem 1.2rem', display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span style={{ color: '#f59e0b', fontWeight: 700 }}>&gt;</span>
              <span style={{ color: '#8b949e', fontWeight: 400 }}>Explain this codebase and generate tests</span>
              <span style={{ color: '#f0f6fc', background: '#30363d', padding: '0 2px', borderRadius: '2px' }}>█</span>
            </div>
            <div style={{ background: '#0d1117', borderTop: '1px solid #21262d', padding: '0.45rem 1.2rem', fontSize: '0.78rem', color: '#8b949e', display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
              <span style={{ color: '#f8fafc', fontWeight: 600 }}>gpt-5.6-sol max</span>
              <span>·</span>
              <span style={{ color: '#3fb950', fontWeight: 500 }}>~/agent-dev-kit</span>
            </div>
          </div>
        ) : isHermesOrchestratorUI ? (
          <div>
            <div style={{ background: '#161b22', borderTop: '1px solid #21262d', padding: '0.65rem 1.2rem', display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
              <span style={{ color: '#eab308', fontWeight: 700 }}>&gt;</span>
              <span style={{ color: '#f0f6fc', fontWeight: 600 }}>█</span>
            </div>
            <div style={{ background: '#090d16', borderTop: '1px solid #21262d', padding: '0.5rem 1.2rem', fontSize: '0.78rem', display: 'flex', justifyContent: 'space-between', alignItems: 'center', color: '#8b949e', flexWrap: 'wrap', gap: '0.5rem' }}>
              <div style={{ display: 'flex', gap: '0.8rem', alignItems: 'center' }}>
                <span style={{ color: '#eab308', fontWeight: 700 }}>⚡ gpt-5.6-sol</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span>182K/272K</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span>[<span style={{ color: '#eab308' }}>███████░░░</span>] 67%</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span>🗜 3</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span>17h216m</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span>⏱ 4m 57s</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span style={{ color: '#3fb950' }}>✓5m</span>
                <span style={{ color: '#6e7681' }}>|</span>
                <span style={{ color: '#ef4444', fontWeight: 700 }}>⚠ YOLO</span>
              </div>
            </div>
          </div>
        ) : (
          <form
            onSubmit={handleCustomCommandSubmit}
            style={{
              background: '#161b22',
              borderTop: '1px solid #21262d',
              padding: '0.7rem 1.2rem',
              display: 'flex',
              alignItems: 'center',
              gap: '0.6rem'
            }}
          >
            <ChevronRight size={18} style={{ color: '#58a6ff' }} />
            <input
              type="text"
              value={userInput}
              onChange={(e) => setUserInput(e.target.value)}
              placeholder={tTerm.placeholder}
              style={{
                flex: 1,
                background: 'transparent',
                border: 'none',
                outline: 'none',
                color: '#f0f6fc',
                fontFamily: 'inherit',
                fontSize: '0.9rem'
              }}
            />
            <button
              type="submit"
              style={{
                background: '#238636',
                color: '#ffffff',
                border: 'none',
                borderRadius: '4px',
                padding: '0.35rem 0.9rem',
                fontSize: '0.78rem',
                fontFamily: 'inherit',
                fontWeight: 600,
                cursor: 'pointer'
              }}
            >
              {tTerm.executeBtn}
            </button>
          </form>
        )}

      </div>
    </section>
  );
};
