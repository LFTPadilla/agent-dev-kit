export type Language = 'es' | 'en';

export const TRANSLATIONS = {
  es: {
    nav: {
      overview: 'Overview',
      architecture: '01 ⁄ Arquitectura',
      skills: '02 ⁄ Skills',
      evals: '03 ⁄ Evaluaciones',
      tutor: '04 ⁄ Tutor',
      install: '05 ⁄ Instalación'
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
            tree2: '  ... +37 líneas (ctrl + t para ver transcripción)',
            tree3: '  ... (truncado – 471 nodos adicionales cortados por presupuesto de ~1400 tokens)',
            working: '• Procesando (39s • esc para interrumpir)'
          }
        },
        prReview: {
          name: '2. bash — /pr-review',
          desc: 'Auditoría adversarial de Pull Request en 4 lentes (Seguridad, Rendimiento, Calidad y Refuter Gate).',
          fetching: '⠋ Obteniendo diff del Pull Request #42 desde GitHub API...',
          loaded: '✔ Diff cargado: 1 archivo cambiado (+2, -1) [UserRepository.java]',
          lens1: '[LENTE 1 ⁄ CORRECTITUD & SEGURIDAD] Ejecutando conjuntos de reglas SAST de Semgrep...',
          result1: '  └─ Resultado: Consulta ORM parametrizada detectada. 0 fallas de inyección SQL.',
          lens2: '[LENTE 2 ⁄ RENDIMIENTO & ESCALABILIDAD] Analizando plan de ejecución de consultas...',
          result2_1: '  ├─ Verificando fetch joins de consultas JPA... VERIFICADO (0 consultas N+1)',
          result2_2: '  └─ Cobertura de índices: idx_users_id presente en esquema.',
          lens3: '[LENTE 3 ⁄ REFUTER GATE ADVERSARIAL] Desmintiendo potenciales falsos positivos...',
          ref1: '  ├─ Desmintiendo falso positivo #1 (Importación no usada en User.java)... DESESTIMADO',
          ref2: '  ├─ Evaluando límites de sanitizador en capa JPA... VERIFICADO LIMPIO',
          verdict3: '  └─ Veredicto Refutador: 0 Vulnerabilidades Reales (Tasa de Falsos Positivos: 0.0%)',
          approved: '🎉 [PR-REVIEW COMPLETO] Veredicto de Compuerta: APROBADO. 0 Bloqueadores | 100% Cobertura Verificada.'
        },
        doctor: {
          name: '3. zsh — npm run doctor',
          desc: 'Diagnóstico integral de salud: comprueba esquemas de skills, runtime de Node y fronteras de privacidad.',
          running: '⠋ Ejecutando comprobaciones de diagnóstico de entorno...',
          node: '✔ Runtime Node.js: v20.11.0 (LTS) detectado [OK]',
          gsd: '✔ Framework de Metaprompting GSD: Activo y Verificado',
          prov: '✔ Manifiesto de Procedencia (skill-provenance.json): 22 skills válidas',
          val: '[MOTOR DE VALIDACIÓN] Verificando alineación de metadatos en plugin.json...',
          aligned1: '  ├─ dev-skills/plugin.json: v0.12.0 [ALINEADO]',
          aligned2: '  └─ package.json: v0.12.0 [ALINEADO]',
          priv: '[AUDITORÍA DE PRIVACIDAD] Verificando fronteras de overlays privados...',
          clean: '✔ Comprobación de Overlay Privado: LIMPIO (0 filtraciones detectadas)',
          result: '🎉 [RESULTADO DOCTOR] Sistema 100% operativo (0 errores, 0 advertencias).'
        }
      }
    },
    architecture: {
      labelNum: '02',
      labelTitle: 'Diseño por Capas',
      title: 'El Mapa de Arquitectura.',
      intro: 'Tres capas independientes que nunca se colapsan entre sí: Capa Directa (Skills), Capa Ship (Compuertas) y Capa Run (Aislamiento y Tutoría).',
      bannerTitle: 'Diagrama Funcional de Flujo de Agentes',
      bannerSubtitle: 'Selecciona cualquiera de las 3 capas para inspeccionar sus entradas, herramientas y lógica de ejecución.'
    },
    skills: {
      labelNum: '03',
      labelTitle: 'Catálogo de Skills',
      title: '22 Skills Curadas para Agentes.',
      intro: 'Colección de habilidades especializadas con manifiestos SKILL.md en Markdown y procedencia auditada en skill-provenance.json.',
      searchPlaceholder: 'Buscar skill por nombre, prompt o descripción...',
      showingText: 'Mostrando',
      ofText: 'de',
      skillsText: 'skills',
      prev: 'Anterior',
      next: 'Siguiente'
    },
    evals: {
      labelNum: '04',
      labelTitle: 'Evaluación y Calidad',
      title: 'Laboratorio de PR-Review Adversarial.',
      intro: 'Comprueba el pipeline de auditoría de Pull Requests con 4 lentes de verificación y tasa de falsos positivos del 0.0%.'
    },
    tutor: {
      labelNum: '05',
      labelTitle: 'Perfil Tutor Socrático',
      title: 'Personal Dev Tutor.',
      intro: 'Simula la interacción con un tutor socrático que te guía en el desarrollo sin editar código a tus espaldas.'
    },
    setup: {
      labelNum: '06',
      labelTitle: 'Guía de Instalación',
      title: 'Asistente de Setup por Capas.',
      intro: 'Instala y configura agent-dev-kit en tu entorno local en menos de 2 minutos.'
    },
    footer: {
      description: 'Ingeniería de sistemas para agentes de código: capas independientes, compuertas medibles y fronteras transparentes.',
      mitLicense: 'Licencia MIT',
      attribution: 'Créditos y Atribución',
      repository: 'Repositorio en GitHub'
    }
  },
  en: {
    nav: {
      overview: 'Overview',
      architecture: '01 ⁄ Architecture',
      skills: '02 ⁄ Skills',
      evals: '03 ⁄ Evals',
      tutor: '04 ⁄ Tutor',
      install: '05 ⁄ Install'
    },
    hero: {
      labelNum: '00',
      labelTitle: 'Overview',
      title: 'Systems engineering for coding agents.',
      subtitle: 'Layered concerns, measurable gates, and honest boundaries. Clone once, run one script, and get a replicable AI-augmented workflow: plan ➔ build ➔ review ➔ ship ➔ overnight.',
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
            header: 'Refactoring and verification plan decomposed successfully.',
            item1: '- Delegating Task 1 to Window 1 (claude-worker): Refactor @Transactional annotations in UserService.java.',
            item2: '- Delegating Task 2 to Window 2 (codex-lane): Generate unit test suite in UserServiceTest.java.',
            item3: '- Graphify AST Engine: Call graph indexed (42 Java classes).',
            item4: '- Context7 MCP: Spring Boot 3.x JPA documentation synced without conflicts.',
            item5: '- On-disk board state (.planning/ROADMAP.md): Synced, 0 context collisions.',
            note: 'Important: The orchestrator does not mutate code directly in the tree; it delegates mutations to tmux sub-windows (1:claude-worker and 2:codex-lane) and performs independent auditing.'
          },
          sub1: {
            info1: 'Transaction refactoring is still pending to commit the JPA services.',
            recap: '※ recap: Goal: Inject rollbackFor = Exception.class in UserService.java. Controller fleet clean; payment service propagation pending.',
            info2: '4 tasks (3 done, 1 open)',
            t1: '✔ Restore @Transactional router in UserService.java',
            t2: '✔ Reconcile manifests and SKILL.md with fixed router',
            t3: '✔ Fix pipeline bugs (valid routers, silent upstream check)',
            t4: '□ Generate unit test suite in UserServiceTest.java'
          },
          sub2: {
            ran: '• Ran hypa -c "graphify query \'What classes and methods handle UserService transaction propagation?\' --budget 1400"',
            tree1: '  Traversal: BFS depth=2 | Start: [\'2026-08-01 – feat(service): refactor UserService.java\', \'UserRepository.java\']',
            tree2: '  ... +37 lines (ctrl + t to view transcript)',
            tree3: '  ... (truncated – 471 more nodes cut by ~1400-token budget)',
            working: '• Working (39s • esc to interrupt)'
          }
        },
        prReview: {
          name: '2. bash — /pr-review',
          desc: 'Adversarial Pull Request audit across 4 lenses (Security, Performance, Quality, and Refuter Gate).',
          fetching: '⠋ Fetching pull request #42 diff from GitHub API...',
          loaded: '✔ Diff loaded: 1 file changed (+2, -1) [UserRepository.java]',
          lens1: '[LENS 1 ⁄ CORRECTNESS & SECURITY] Running Semgrep SAST rulesets...',
          result1: '  └─ Result: Parameterized ORM query detected. 0 SQL injection sinks.',
          lens2: '[LENS 2 ⁄ PERFORMANCE & SCALABILITY] Analyzing query execution plan...',
          result2_1: '  ├─ Checking JPA query fetch joins... VERIFIED (0 N+1 queries detected)',
          result2_2: '  └─ Index coverage: idx_users_id present in schema.',
          lens3: '[LENS 3 ⁄ ADVERSARIAL REFUTER GATE] Disproving potential false positives...',
          ref1: '  ├─ Disproving false positive #1 (Unused import in User.java)... DISMISSED',
          ref2: '  ├─ Evaluating sanitizer bounds in JPA Layer... VERIFIED CLEAN',
          verdict3: '  └─ Refuter Verdict: 0 Real Security Sinks (False Positive Rate: 0.0%)',
          approved: '🎉 [PR-REVIEW COMPLETE] Gate Verdict: APPROVED. 0 Blockers | 100% Recall Verified.'
        },
        doctor: {
          name: '3. zsh — npm run doctor',
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
      intro: 'Inspect the 4-lens Pull Request audit pipeline with 0.0% false positive rate verification.'
    },
    tutor: {
      labelNum: '05',
      labelTitle: 'Socratic Tutor Profile',
      title: 'Personal Dev Tutor.',
      intro: 'Simulate interaction with a Socratic tutor that guides your development without modifying code behind your back.'
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
