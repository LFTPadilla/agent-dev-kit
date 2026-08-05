export type Language = 'es' | 'en';

export const TRANSLATIONS = {
  es: {
    nav: {
      overview: 'Overview',
      terminal: '01 ⁄ Terminal',
      architecture: '02 ⁄ Arquitectura',
      skills: '03 ⁄ Skills',
      evals: '04 ⁄ Evaluaciones',
      tutor: '05 ⁄ Tutor',
      install: '06 ⁄ Instalación'
    },
    hero: {
      labelNum: '00',
      labelTitle: 'Overview',
      title: 'Ingeniería de sistemas para agentes de código.',
      subtitle: 'Arquitectura por capas, compuertas medibles y fronteras honestas. Clona una vez, ejecuta un script y obtén un flujo aumentado por IA replicable: planifica ➔ construye ➔ revisa ➔ entrega ➔ nocturno.',
      getStarted: 'Comenzar Ahora',
      exploreSkills: 'Explorar 22 Skills',
      statSkills: 'Skills Curadas',
      statEvalPass: 'Pase de Evaluación',
      statLenses: 'Lentes Adversariales',
      statSetupTime: 'Tiempo de Setup'
    },
    terminal: {
      labelNum: '01',
      labelTitle: 'Terminal Shell',
      title: 'Consola de Agentes en Vivo.',
      restart: 'Reiniciar',
      copyCommand: 'Copiar Comando',
      commandCopied: 'Comando Copiado',
      executing: '● Ejecutando...',
      completed: '✔ Completado',
      placeholder: 'Escribe un comando (/pr-review, npm run doctor, personal-dev-tutor)...',
      executeBtn: 'Ejecutar',
      tabs: {
        tmux: {
          name: '1. tmux — tutor-orchestrator',
          desc: 'Orquestación en tmux: Ventana 0 (Orquestador), Ventana 1 (Claude Code) y Ventana 2 (Codex Lane).',
          sub0: {
            header: 'Plan de refactorización y verificación descompuesto con éxito.',
            item1: '- Delegando Tarea 1 a Window 1 (claude-worker): Refactorizar anotaciones @Transactional en UserService.java.',
            item2: '- Delegando Tarea 2 a Window 2 (codex-lane): Generar suite de pruebas unitarias en UserServiceTest.java.',
            item3: '- Graphify AST Engine: Mapa de llamadas indexado (42 clases Java).',
            item4: '- Context7 MCP: Documentación de Spring Boot 3.x JPA sincronizada sin conflictos.',
            item5: '- Estado del tablero en disco (.planning/ROADMAP.md): Sincronizado, 0 colisiones de contexto.',
            note: 'Importante: El orquestador no modifica código directamente en el árbol; delega las mutaciones a las sub-ventanas tmux (1:claude-worker y 2:codex-lane) y realiza la auditoría de forma independiente.'
          },
          sub1: {
            info1: 'Aparte sigue pendiente la refactorización de transacciones para poder commitear los servicios de JPA.',
            recap: '※ recap: Meta: Inyectar rollbackFor = Exception.class en UserService.java. La flota de controladores quedó limpia; falta actualizar la propagación en los servicios de pagos.',
            info2: '4 tareas (3 completadas, 1 abierta)',
            t1: '✔ Restaurar router @Transactional en UserService.java',
            t2: '✔ Reconciliar manifiestos y SKILL.md con el router arreglado',
            t3: '✔ Arreglar bugs del pipeline (valen routers, check upstream silencioso)',
            t4: '□ Generar suite de pruebas unitarias en UserServiceTest.java'
          },
          sub2: {
            ran: '• Ran hypa -c "graphify query \'What classes and methods handle UserService transaction propagation?\' --budget 1400"',
            tree1: '  Traversal: BFS depth=2 | Start: [\'2026-08-01 – feat(service): refactor UserService.java\', \'UserRepository.java\']',
            tree2: '  [0] UserService.java (class) ── (calls) ──> UserRepository.save()',
            tree3: '  [1] TransactionManager.java (config) ── (intercepts) ──> @Transactional',
            working: '• Procesando (39s • esc para interrumpir)'
          }
        },
        prReview: {
          name: '2. /pr-review — adversarial gate',
          desc: 'Auditoría adversarial de Pull Request en 4 lentes (Seguridad, Rendimiento, Calidad y Refuter Gate).',
          fetching: '⠋ Obteniendo diff del Pull Request #42 desde GitHub API...',
          loaded: '✔ Diff cargado: 1 archivo cambiado (+2, -1) [UserRepository.java]',
          cmd: '$ /pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42',
          lenses: '[Protocolo de Revisión Multi-Lente de 4 Capas Invocado]',
          lens1: 'Lente 1: Corrección Lógica & Funcional ──────> FAIL (Línea 42: Inyección SQL potencial en consulta cruda)',
          result1: '  └─ Resultado: Consulta ORM parametrizada detectada. 0 fallas de inyección SQL.',
          lens2: 'Lente 2: Límites de Seguridad & Privacidad ─> PASS (0 fugas de secretos o credenciales)',
          result2_1: '  ├─ Verificando fetch joins de consultas JPA... VERIFICADO (0 consultas N+1)',
          result2_2: '  └─ Cobertura de índices: idx_users_id presente en esquema.',
          lens3: 'Lente 3: Cobertura de Tests & Evals ────────> PASS (7 nuevos casos de prueba añadidos)',
          ref1: '  ├─ Desmintiendo falso positivo #1 (Importación no usada en User.java)... DESESTIMADO',
          ref2: '  ├─ Evaluando límites de sanitizador en capa JPA... VERIFICADO LIMPIO',
          verdict3: '  └─ Veredicto Refutador: 0 Vulnerabilidades Reales (Tasa de Falsos Positivos: 0.0%)',
          lens4: 'Lente 4: Arquitectura & Reglas Agente ─────> PASS (Alineado con especificación AGENTS.md)',
          panel: '[Panel Refutador Adversarial Invocado]',
          verdict: 'VERDICT: BLOCKER — Corrección requerida en UserRepository.java:L42 antes de hacer merge.',
          approved: '🎉 [PR-REVIEW COMPLETO] Veredicto de Compuerta: APROBADO. 0 Bloqueadores | 100% Cobertura Verificada.',
          summary: 'Revisión finalizada. 1 hallazgo bloqueador confirmado por el Refutador. Despliegue detenido.'
        },
        overnight: {
          name: '3. gnhf — overnight protocol',
          cmd: '$ gnhf run --suite overnight-task-kit/task-manifest.yml --budget 8h',
          session: '[Sesión Nocturna Aislada Iniciada en Árbol Secundario]',
          agent: '• Agente Autónomo: GSD Execution Loop (Modo Unattended)',
          checkpoint: '• Checkpoint 1: Ejecutando refactorización de suite de evals... (4/12 completados)',
          verification: '• Verificación Autónoma: `npm run test:evals` ──> 100% PASS',
          log: '• Generando log de auditoría en .planning/LOGS/2026-08-01-nightly.log',
          complete: '✔ Tarea nocturna finalizada sin intervención humana. 0 errores fatales.'
        },
        doctor: {
          name: '4. zsh — npm run doctor',
          desc: 'Diagnóstico integral de salud: comprueba esquemas de skills, runtime de Node y fronteras de privacidad.',
          running: '⠋ Ejecutando comprobaciones de diagnóstico de entorno...',
          node: '✔ Runtime Node.js: v20.11.0 (LTS) detectado [OK]',
          gsd: '✔ Framework de Metaprompting GSD: Activo y Verificado',
          prov: '✔ Manifiesto de Procedencia (skill-provenance.json): 22 skills válidas',
          val: '[MOTOR DE VALIDACIÓN] Verificando alineación de metadatos en plugin.json...',
          aligned1: '  ├─ dev-skills/plugin.json: v0.12.0 [ALIGNED]',
          aligned2: '  └─ package.json: v0.12.0 [ALIGNED]',
          priv: '[AUDITORÍA DE PRIVACIDAD] Verificando fronteras de overlays privados...',
          clean: '✔ Comprobación de Overlay Privado: LIMPIO (0 filtraciones detectadas)',
          result: '🎉 [RESULTADO DOCTOR] Sistema 100% operativo (0 errores, 0 advertencias).'
        }
      }
    },
    architecture: {
      labelNum: '02',
      labelTitle: 'Arquitectura',
      title: 'Sistema por capas que no se colapsa.',
      intro: 'Tres niveles de abstracción claramente separados para garantizar previsibilidad, aislamiento de contexto y reutilización de habilidades.',
      directTitle: 'Nivel 1: Ejecución Directa (Skills)',
      directDesc: 'Comandos atómicos y reutilizables para inspección rápida, formateo y diagnósticos puntuales.',
      shipTitle: 'Nivel 2: Puertas de Entrega (Ship & /pr-review)',
      shipDesc: 'Protocolos de revisión adversarial de 4 lentes que actúan como barreras de calidad infranqueables antes del merge.',
      runTitle: 'Nivel 3: Ejecución Larga (Overnight & Tutor)',
      runDesc: 'Bucles autónomos en background con metaprompting GSD y tutoría socrática aislada en tmux.'
    },
    skills: {
      labelNum: '03',
      labelTitle: 'Skills Curadas',
      title: '22 Skills Listas para Usar.',
      intro: 'Catálogo de capacidades especializadas sin dependencias inventadas, listas para instalar vía vercel-labs/skills.',
      searchPlaceholder: 'Buscar skills por nombre, descripción o trigger...',
      showingText: 'Mostrando',
      ofText: 'de',
      skillsText: 'skills',
      prev: 'Anterior',
      next: 'Siguiente'
    },
    evals: {
      labelNum: '04',
      labelTitle: 'Evals & /pr-review',
      title: 'Sistemas Medidos de IA.',
      intro: '15 casos reales evaluados (12 escenarios de prueba con fallos reales + 3 controles de código seguro). Medido en recall y en tasa de falsos positivos.'
    },
    tutor: {
      labelNum: '05',
      labelTitle: 'Personal Dev Tutor',
      title: 'Socrático + Orquestación.',
      termTitle: 'Tutoría Socrática',
      termClickHint: 'Haz clic para ver la definición',
      intro: 'No escribe código a tus espaldas. Te guía paso a paso mediante preguntas para afianzar el aprendizaje.'
    },
    setup: {
      labelNum: '06',
      labelTitle: 'Instalación & Tiers',
      title: 'Setup Tiers.',
      intro: 'Elige el nivel de integración adecuado para tu flujo de trabajo: desde skills ligeras en Codex hasta la suite completa de orquestación en tmux.'
    },
    footer: {
      description: 'Ingeniería de sistemas para agentes de código — arquitectura por capas, compuertas medibles y fronteras honestas.',
      mitLicense: 'Licencia MIT',
      attribution: 'ATTRIBUTION.md',
      repository: 'Repositorio GitHub'
    }
  },
  en: {
    nav: {
      overview: 'Overview',
      terminal: '01 ⁄ Terminal',
      architecture: '02 ⁄ Architecture',
      skills: '03 ⁄ Skills',
      evals: '04 ⁄ Evals',
      tutor: '05 ⁄ Tutor',
      install: '06 ⁄ Installation'
    },
    hero: {
      labelNum: '00',
      labelTitle: 'Overview',
      title: 'Systems engineering for coding agents.',
      subtitle: 'Layered concerns, measurable gates, and honest boundaries. Clone once, run one script, and get a reproducible AI-augmented flow: plan ➔ build ➔ review ➔ ship ➔ overnight.',
      getStarted: 'Get Started',
      exploreSkills: 'Explore 22 Skills',
      statSkills: 'Curated Skills',
      statEvalPass: 'Eval Pass Rate',
      statLenses: 'Adversarial Lenses',
      statSetupTime: 'Setup Time'
    },
    terminal: {
      labelNum: '01',
      labelTitle: 'Terminal Shell',
      title: 'Live Agent Console.',
      restart: 'Restart',
      copyCommand: 'Copy Command',
      commandCopied: 'Command Copied',
      executing: '● Executing...',
      completed: '✔ Completed',
      placeholder: 'Type a command (/pr-review, npm run doctor, personal-dev-tutor)...',
      executeBtn: 'Execute',
      tabs: {
        tmux: {
          name: '1. tmux — tutor-orchestrator',
          desc: 'Tmux Orchestration: Window 0 (Orchestrator), Window 1 (Claude Code), and Window 2 (Codex Lane).',
          sub0: {
            header: 'Refactoring & verification plan successfully decomposed.',
            item1: '- Delegating Task 1 to Window 1 (claude-worker): Refactor @Transactional annotations in UserService.java.',
            item2: '- Delegating Task 2 to Window 2 (codex-lane): Generate unit test suite in UserServiceTest.java.',
            item3: '- Graphify AST Engine: Call graph indexed (42 Java classes).',
            item4: '- Context7 MCP: Spring Boot 3.x JPA documentation synced with 0 conflicts.',
            item5: '- On-disk board state (.planning/ROADMAP.md): Synced, 0 context collisions.',
            note: 'Important: The orchestrator never mutates code directly in the main tree; it delegates mutations to sub-windows (1:claude-worker & 2:codex-lane) and performs independent auditing.'
          },
          sub1: {
            info1: 'Transaction refactoring is still pending before committing JPA services.',
            recap: '※ recap: Goal: Inject rollbackFor = Exception.class in UserService.java. Controller fleet clean; payment service propagation pending.',
            info2: '4 tasks (3 completed, 1 open)',
            t1: '✔ Restore @Transactional router in UserService.java',
            t2: '✔ Reconcile manifests & SKILL.md with fixed router',
            t3: '✔ Fix pipeline bugs (valid routers, silent upstream check)',
            t4: '□ Generate unit test suite in UserServiceTest.java'
          },
          sub2: {
            ran: '• Ran hypa -c "graphify query \'What classes and methods handle UserService transaction propagation?\' --budget 1400"',
            tree1: '  Traversal: BFS depth=2 | Start: [\'2026-08-01 – feat(service): refactor UserService.java\', \'UserRepository.java\']',
            tree2: '  [0] UserService.java (class) ── (calls) ──> UserRepository.save()',
            tree3: '  [1] TransactionManager.java (config) ── (intercepts) ──> @Transactional',
            working: '• Processing (39s • esc to interrupt)'
          }
        },
        prReview: {
          name: '2. /pr-review — adversarial gate',
          desc: 'Adversarial Pull Request audit across 4 lenses (Security, Performance, Quality, and Refuter Gate).',
          fetching: '⠋ Fetching pull request #42 diff from GitHub API...',
          loaded: '✔ Diff loaded: 1 file changed (+2, -1) [UserRepository.java]',
          cmd: '$ /pr-review https://github.com/LFTPadilla/agent-dev-kit/pull/42',
          lenses: '[4-Lens Multi-Layer Review Protocol Invoked]',
          lens1: 'Lens 1: Logical & Functional Correctness ───> FAIL (Line 42: Potential SQL injection in raw query)',
          result1: '  └─ Result: Parameterized ORM query detected. 0 SQL injection sinks.',
          lens2: 'Lens 2: Security & Privacy Boundaries ────> PASS (0 secrets or credentials leaked)',
          result2_1: '  ├─ Checking JPA query fetch joins... VERIFIED (0 N+1 queries detected)',
          result2_2: '  └─ Index coverage: idx_users_id present in schema.',
          lens3: 'Lens 3: Test & Eval Coverage ─────────────> PASS (7 new test cases added)',
          ref1: '  ├─ Disproving false positive #1 (Unused import in User.java)... DISMISSED',
          ref2: '  ├─ Evaluating sanitizer bounds in JPA Layer... VERIFIED CLEAN',
          verdict3: '  └─ Refuter Verdict: 0 Real Security Sinks (False Positive Rate: 0.0%)',
          lens4: 'Lens 4: Architecture & Agent Rules ───────> PASS (Aligned with AGENTS.md spec)',
          panel: '[Adversarial Refuter Panel Invoked]',
          verdict: 'VERDICT: BLOCKER — Correction required in UserRepository.java:L42 prior to merge.',
          approved: '🎉 [PR-REVIEW COMPLETE] Gate Verdict: APPROVED. 0 Blockers | 100% Recall Verified.',
          summary: 'Review complete. 1 blocker finding confirmed by Refuter. Deployment halted.'
        },
        overnight: {
          name: '3. gnhf — overnight protocol',
          cmd: '$ gnhf run --suite overnight-task-kit/task-manifest.yml --budget 8h',
          session: '[Isolated Overnight Session Started in Secondary Worktree]',
          agent: '• Autonomous Agent: GSD Execution Loop (Unattended Mode)',
          checkpoint: '• Checkpoint 1: Running eval suite refactor... (4/12 completed)',
          verification: '• Autonomous Verification: `npm run test:evals` ──> 100% PASS',
          log: '• Generating audit log at .planning/LOGS/2026-08-01-nightly.log',
          complete: '✔ Overnight task completed without human intervention. 0 fatal errors.'
        },
        doctor: {
          name: '4. zsh — npm run doctor',
          desc: 'Comprehensive health diagnostic: verifies skill schemas, Node runtime, and privacy boundaries.',
          running: '⠋ Running environment diagnostic checks...',
          node: '✔ Node.js runtime: v20.11.0 (LTS) detected [OK]',
          gsd: '✔ GSD Metaprompting Framework: Active & Verified',
          prov: '✔ Provenance Manifest (skill-provenance.json): 22 skills valid',
          val: '[VALIDATION ENGINE] Checking plugin.json metadata alignment...',
          aligned1: '  ├─ dev-skills/plugin.json: v0.12.0 [ALIGNED]',
          aligned2: '  └─ package.json: v0.12.0 [ALIGNED]',
          priv: '[PRIVACY AUDIT] Verifying private overlay boundaries...',
          clean: '✔ Private Overlay Check: CLEAN (0 leaks detected)',
          result: '🎉 [DOCTOR RESULT] System 100% operational (0 errors, 0 warnings).'
        }
      }
    },
    architecture: {
      labelNum: '02',
      labelTitle: 'Layered Design',
      title: 'The Architecture Map.',
      intro: 'Three decoupled layers that never collapse into each other: Direct Layer (Skills), Ship Layer (Gates), and Run Layer (Isolation & Tutoring).',
      bannerTitle: 'Functional Agent Workflow Diagram',
      bannerSubtitle: 'Select any of the 3 layers to inspect its inputs, tools, and execution logic.'
    },
    skills: {
      labelNum: '03',
      labelTitle: 'Skills Catalog',
      title: '22 Curated Agent Skills.',
      intro: 'Specialized capability packs with Markdown SKILL.md manifests and audited provenance in skill-provenance.json.',
      searchPlaceholder: 'Search skills by name, prompt or description...',
      showingText: 'Showing',
      ofText: 'of',
      skillsText: 'skills',
      prev: 'Previous',
      next: 'Next'
    },
    evals: {
      labelNum: '04',
      labelTitle: 'Evaluation & Quality',
      title: 'Adversarial PR-Review Lab.',
      intro: '15 real-world evaluation cases (12 test scenarios with real defects + 3 clean control cases). Measured by detection recall and false-positive rate.'
    },
    tutor: {
      labelNum: '05',
      labelTitle: 'Socratic Tutor Profile',
      title: 'Personal Dev Tutor.',
      intro: 'Socratic Tutoring + Tmux Orchestration: Guides you step-by-step through interactive questions without writing code behind your back.',
      termTitle: 'Socratic Tutoring',
      termClickHint: 'Click to see definition'
    },
    setup: {
      labelNum: '06',
      labelTitle: 'Installation Guide',
      title: 'Tiered Setup Wizard.',
      intro: 'Install and configure agent-dev-kit in your local environment in under 2 minutes.'
    },
    footer: {
      description: 'Systems engineering for coding agents: layered concerns, measurable gates, and honest boundaries.',
      mitLicense: 'MIT License',
      attribution: 'Credits & Attribution',
      repository: 'GitHub Repository'
    }
  }
};
