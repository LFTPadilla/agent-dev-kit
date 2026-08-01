export interface Skill {
  id: string;
  name: string;
  category: 'orchestration' | 'quality' | 'security' | 'documents' | 'qa' | 'search';
  description: string;
  triggers: string[];
  examplePrompt: string;
  outputPreview: string;
  details: string;
}

export interface EvalCase {
  id: string;
  name: string;
  type: 'planted_bug' | 'clean_control';
  category: string;
  description: string;
  semgrepResult: 'MISSED' | 'CAUGHT' | 'PASS';
  prReviewResult: 'CAUGHT' | 'PASS';
  snippet: string;
  reason: string;
}

export interface SetupTier {
  id: 'tier-a' | 'tier-b' | 'tier-c';
  title: string;
  subtitle: string;
  recommendedFor: string;
  requirements: string[];
  commands: string[];
  features: string[];
}

export const REPO_STATS = {
  version: "0.12.0",
  skillsCount: 22,
  runtimesCount: 5,
  evalsCount: 15,
  plantedBugs: 12,
  cleanControls: 3,
  prReviewRecall: "100%",
  semgrepRecall: "8%",
  falsePositiveRate: "0%"
};

export const ARCHITECTURE_LAYERS = [
  {
    id: "direct",
    name: "Layer 1: Direct (Capabilities & Flow)",
    color: "#6366f1",
    bgGradient: "linear-gradient(135deg, rgba(99, 102, 241, 0.15), rgba(79, 70, 229, 0.05))",
    borderColor: "rgba(99, 102, 241, 0.4)",
    description: "Governs how the agent speaks, builds, and executes multi-step workflows.",
    components: [
      { name: "caveman", type: "Style", desc: "Concise, zero-fluff communication plugin." },
      { name: "ponytail", type: "Build Directives", desc: "Strict architectural and visual quality standards." },
      { name: "GSD (Get-Shit-Done)", type: "Workflow Engine", desc: "Plan ➔ Execute ➔ Verify lifecycle engine." },
      { name: "dev-skills (22)", type: "Discrete Tools", desc: "Curated skills for QA, security, docs, and code quality." }
    ]
  },
  {
    id: "ship",
    name: "Layer 2: Ship Gates (Quality & Verification)",
    color: "#10b981",
    bgGradient: "linear-gradient(135deg, rgba(16, 185, 129, 0.15), rgba(5, 150, 105, 0.05))",
    borderColor: "rgba(16, 185, 129, 0.4)",
    description: "Keeps the AI honest before code is merged into main.",
    components: [
      { name: "/pr-review", type: "Adversarial PR Gate", desc: "Multi-lens audit with refuter panel to eliminate LLM false positives." },
      { name: "semgrep", type: "Deterministic SAST", desc: "Fast baseline static security analysis." },
      { name: "no-mistakes", type: "Ship Gate", desc: "Pre-merge safety check prohibiting unchecked errors." },
      { name: "evals (15 cases)", type: "Benchmarking", desc: "Planted bug suite measuring recall and false-positive rate." }
    ]
  },
  {
    id: "run",
    name: "Layer 3: Run & Isolation (Orchestrators & Loops)",
    color: "#a855f7",
    bgGradient: "linear-gradient(135deg, rgba(168, 85, 247, 0.15), rgba(147, 51, 234, 0.05))",
    borderColor: "rgba(168, 85, 247, 0.4)",
    description: "Manages long runs, Socratic teaching, and worktree isolation.",
    components: [
      { name: "Personal Dev Tutor", type: "Flagship Orchestrator", desc: "GSD + Codex workers in tmux + Socratic learning checkpoints." },
      { name: "Agent Tutor Orchestrator", type: "Pure Orchestrator", desc: "Strict orchestrator that delegates and never edits code directly." },
      { name: "treehouse", type: "Worktree Isolation", desc: "Parallel agent worktree manager preventing git branch collisions." },
      { name: "gnhf / overnight-task-kit", type: "Autonomy Loop", desc: "Unsupervised multi-hour task execution runner." }
    ]
  }
];

export const SKILLS_CATALOG: Skill[] = [
  {
    id: "personal-development-mentor",
    name: "personal-development-mentor",
    category: "orchestration",
    description: "Flagship GSD + Codex tutor-orchestrator with bounded implementation, independent verification, and cognitive-debt checkpoints.",
    triggers: ["personal project", "portfolio project", "learning code", "interview prep", "explain architecture"],
    examplePrompt: "Ayúdame a construir una API en Spring Boot mientras aprendo los conceptos clave de JPA y DTOs.",
    outputPreview: `[GSD Plan] Phase 1: Entity & Repository setup
[Codex Lane] Implemented UserEntity.java and UserRepository.java in tmux session 'personal'
[Learning Gate Checkpoint] 
Question: ¿Por qué usamos @Transactional en los métodos de servicio y qué diferencia hay con la propagación REQUIRES_NEW?`,
    details: "Combina la metodología GSD con workers aislados en Codex dentro de tmux, lectura de AST con Graphify, documentación fresca con Context7 y un diario de aprendizaje duradero."
  },
  {
    id: "orchestrate",
    name: "orchestrate",
    category: "orchestration",
    description: "Modo explicit planner/orchestrator: descompone el trabajo, delega a modelos o workers más económicos y verifica de forma independiente.",
    triggers: ["$orchestrate", "orchestrate", "delegate to subagents", "use cheaper models"],
    examplePrompt: "Orchestrate: Descompone la migración de la base de datos y asigna las tareas de migración y tests.",
    outputPreview: `[Orchestrator] Task breakdown created.
Worker 1 (Codex/Flash): Generating SQL migration script
Worker 2 (Codex/Flash): Updating entity definitions
Verification: Running integration tests independently... PASS`,
    details: "Mantiene el modelo más inteligente concentrado en el juicio y planificación, delegando tareas repetitivas a ejecuciones paralelas baratas."
  },
  {
    id: "ai-workflow-orchestrator",
    name: "ai-workflow-orchestrator",
    category: "orchestration",
    description: "Perfil Agent Tutor Orchestrator puro: mantiene el panorama general, encauza en paneles tmux de Claude o Kanban Hermes. Nunca edita directamente.",
    triggers: ["ai-workflow-orchestrator", "pure orchestrator", "Hermes kanban"],
    examplePrompt: "Usa ai-workflow-orchestrator para coordinar la refactorización sin tocar el código directamente.",
    outputPreview: `[Agent Tutor Orchestrator] Board updated.
Pane 1: Refactoring auth.ts (Claude)
Pane 2: Updating test suite (Hermes)
Audit on disk: Checking git diff... CLEAN`,
    details: "Diseñado para usuarios que desean un orquestador estricto que solo audite y organice el tablero de trabajo."
  },
  {
    id: "live-qa",
    name: "live-qa",
    category: "qa",
    description: "Conduce la aplicación web en tiempo real como un usuario real mediante Playwright MCP; reporta errores en consola, red y visuales.",
    triggers: ["QA this feature live", "walk the flow as a user", "probá la interfaz en vivo"],
    examplePrompt: "Haz un live-qa del flujo de checkout agregando un producto al carrito.",
    outputPreview: `[Live-QA Playwright] Navigating to http://localhost:3000
1. Clicked 'Add to Cart' -> OK
2. Opened Cart Drawer -> Visual inspection clean
3. Console Check: 0 errors, 1 warning (deprecation).
Status: VERIFIED`,
    details: "Navega dinámicamente y valida la UX real en lugar de depender únicamente de tests unitarios."
  },
  {
    id: "playwright-stability",
    name: "playwright-stability",
    category: "qa",
    description: "Checklist anti-flaky y reutilización de autenticación real mediante storageState.",
    triggers: ["flaky tests", "hardening test suite", "stop mocking session"],
    examplePrompt: "Revisa mis tests de Playwright porque están fallando intermitentemente en CI.",
    outputPreview: `[Playwright Stability Audit]
- Fixed hardcoded waitForTimeout() -> Replaced with page.waitForSelector()
- Auth reuse configured via storageState.json`,
    details: "Elimina pruebas inestables (flaky) en suites E2E mediante mejores prácticas de sincronización DOM."
  },
  {
    id: "stagehand",
    name: "stagehand",
    category: "qa",
    description: "Pasos de navegación web auto-curables en lenguaje natural para flujos dinámicos o cambiantes.",
    triggers: ["selectors breaking", "volatile UI automation"],
    examplePrompt: "Usa stagehand para llenar el formulario de registro aunque cambien las clases CSS.",
    outputPreview: `[Stagehand Engine]
Action: act("fill email field with test@example.com") -> Selector matched dynamically.
Status: Success`,
    details: "Permite automatización resiliente a cambios de maquetación HTML/CSS."
  },
  {
    id: "semgrep",
    name: "semgrep",
    category: "security",
    description: "Escaneo estático determinista (SAST) con reglas de seguridad predefinidas.",
    triggers: ["security scan", "escáner de seguridad", "pre-auth check"],
    examplePrompt: "Corre un semgrep scan antes de enviar el PR de pagos.",
    outputPreview: `[Semgrep SAST] Running p/default ruleset...
Findings: 0 high severity issues found in 42 files.
Scan completed in 1.2s`,
    details: "Sirve como piso determinista de velocidad relámpago en integración continua."
  },
  {
    id: "security-checklist",
    name: "security-checklist",
    category: "security",
    description: "Revisión patrón➔severidad➔arreglo en fronteras de confianza (el complemento LLM a Semgrep).",
    triggers: ["review auth", "review payments", "input validation audit"],
    examplePrompt: "Revisa los endpoints de autenticación usando security-checklist.",
    outputPreview: `[Security Checklist Audit]
1. Input Sanitization: PASS
2. Rate Limiting: WARN - Add bucket limiter to POST /api/login
3. JWT Expiry: PASS (set to 15m)`,
    details: "Evalúa la lógica de negocio y arquitectura de seguridad que las herramientas SAST estáticas no pueden deducir."
  },
  {
    id: "knip",
    name: "knip",
    category: "quality",
    description: "Encuentra código muerto, exportaciones sin usar y dependencias huérfanas en proyectos TS/JS.",
    triggers: ["clean up bloat", "find unused code", "limpiar código muerto"],
    examplePrompt: "Corre knip para encontrar archivos y dependencias sin usar antes de refactorizar.",
    outputPreview: `[Knip Audit]
Unused files (3):
  - src/utils/oldHelpers.ts
  - src/components/LegacyCard.tsx
Unused dependencies (1):
  - lodash-es`,
    details: "Mantiene la base de código delgada y reduce la carga cognitiva para el desarrollador y el agente."
  },
  {
    id: "improve",
    name: "improve",
    category: "quality",
    description: "Auditoría estilo Senior Advisor (solo lectura) que escribe planes de implementación priorizados para otros agentes.",
    triggers: ["audit this codebase", "where should this project go", "write plan for X"],
    examplePrompt: "Audita este repositorio con improve y crea una hoja de ruta de refactorización.",
    outputPreview: `[Senior Advisor Audit]
Architecture Health Score: 85/100
Recommended Roadmap:
  1. Priority High: Decouple API handlers from DB models
  2. Priority Med: Add E2E tests for checkout flow`,
    details: "Aprovecha la capacidad del modelo más avanzado para la auditoría estratégica y deja la ejecución a agentes secundarios."
  },
  {
    id: "java-development",
    name: "java-development",
    category: "quality",
    description: "Flujo de trabajo especializado para Java: wrapper/JDK discovery, verificación Maven/Gradle focalizada y disciplina JUnit.",
    triggers: ["Java", "Maven", "Gradle", "JUnit", "Spring Boot"],
    examplePrompt: "Revisa las fallas en los tests de JUnit de este proyecto Spring Boot.",
    outputPreview: `[Java Toolchain Detected] Maven + OpenJDK 21
Executing: ./mvnw test -Dtest=UserServiceTest
Results: Tests run: 5, Failures: 0, Errors: 0`,
    details: "Garantiza ejecuciones eficientes en la JVM respetando la estructura Maven/Gradle y estándares de pruebas."
  },
  {
    id: "drawio-skill",
    name: "drawio-skill",
    category: "documents",
    description: "Genera diagramas `.drawio` editables a partir de lenguaje natural (arquitectura, ER, UML, íconos de cloud/AI).",
    triggers: ["make diagram I can edit", "drawio architecture diagram"],
    examplePrompt: "Crea un diagrama .drawio editable de nuestra arquitectura de microservicios.",
    outputPreview: `[Draw.io Generator] Generated architecture.drawio
Exported preview: architecture.png
Contains 14 shapes (Node.js, PostgreSQL, Redis, Load Balancer)`,
    details: "Crea gráficos vectoriales completamente modificables en la suite Draw.io o VS Code extension."
  },
  {
    id: "diagram-render",
    name: "diagram-render",
    category: "documents",
    description: "Convierte diagramas de flujo/infraestructura a PNG rápido vía SVG+sharp.",
    triggers: ["draw the topology", "render this diagram"],
    examplePrompt: "Renderiza este diagrama de flujo a PNG.",
    outputPreview: `[Diagram Render] Rendered topology.png from SVG spec (800x600 px).`,
    details: "Rápido e ideal para previsualizaciones estáticas en documentación."
  },
  {
    id: "pdf",
    name: "pdf",
    category: "documents",
    description: "Inspecciona, resume, divide, une o convierte archivos PDF.",
    triggers: ["work with this PDF", "summarize PDF"],
    examplePrompt: "Resume el contenido del archivo especificación-api.pdf.",
    outputPreview: `[PDF Toolkit] Processed 12 pages.
Summary: Technical specification of REST endpoints for user authentication and billing.`,
    details: "Extracción limpia de texto y manipulaciones rápidas de PDFs."
  },
  {
    id: "excel-xlsx",
    name: "excel-xlsx",
    category: "documents",
    description: "Construye hojas `.xlsx` estilizadas desde tablas, CSV o JSON.",
    triggers: ["make a spreadsheet", "export to Excel"],
    examplePrompt: "Exporta la tabla de métricas a un archivo Excel profesional.",
    outputPreview: `[Excel Builder] Created metrics-report.xlsx with formatted headers and auto-fit columns.`,
    details: "Formateo nativo de celdas y tablas ejecutivas."
  },
  {
    id: "word-docx",
    name: "word-docx",
    category: "documents",
    description: "Construye documentos `.docx` con formato ejecutivo a partir de títulos y cuerpo.",
    triggers: ["write Word doc", "make a .docx"],
    examplePrompt: "Genera un informe en Word sobre los resultados del eval.",
    outputPreview: `[Docx Builder] Exported report-evals.docx with title page and headings.`,
    details: "Crea documentos de Word pulidos para clientes o equipos directivos."
  },
  {
    id: "tex-render",
    name: "tex-render",
    category: "documents",
    description: "Convierte ecuaciones matemáticas en LaTeX a imágenes PNG/SVG en alta resolución.",
    triggers: ["render equation", "latex to image"],
    examplePrompt: "Renderiza la fórmula de Bayes en una imagen SVG.",
    outputPreview: `[LaTeX MathJax] Rendered bayes_formula.svg`,
    details: "Soporte completo para expresiones matemáticas complejas."
  },
  {
    id: "image-finalize",
    name: "image-finalize",
    category: "documents",
    description: "Generación de imágenes en 2 etapas (borrador ➔ pulido visual).",
    triggers: ["generate image", "refine image"],
    examplePrompt: "Genera una imagen conceptual de un robot orquestando código.",
    outputPreview: `[Image Generator Stage 2] Saved artifact robot_orchestrator.png`,
    details: "Garantiza máxima calidad estética en artefactos de imagen."
  },
  {
    id: "git-essentials",
    name: "git-essentials",
    category: "quality",
    description: "Referencia y asistencia experta para comandos y flujos de Git.",
    triggers: ["git workflow questions", "git rebase help"],
    examplePrompt: "Cómo hago un rebase interactivo conservando la firma de los commits?",
    outputPreview: `[Git Essentials] Step-by-step rebase commands provided.`,
    details: "Evita pérdidas de datos en manipulaciones avanzadas del árbol de Git."
  },
  {
    id: "find-skills",
    name: "find-skills",
    category: "search",
    description: "Descubre e instala skills adicionales para una necesidad específica.",
    triggers: ["is there a skill for X", "find skill for Docker"],
    examplePrompt: "¿Existe alguna skill para auditar archivos Dockerfile?",
    outputPreview: `[Skills Discovery] Found matching skill: docker-audit (available via npx skills).`,
    details: "Conecta con los registros de vercel-labs/skills y repositorios de la comunidad."
  },
  {
    id: "web-browse",
    name: "web-browse",
    category: "search",
    description: "Navegación y extracción en navegador real para sitios web dinámicos.",
    triggers: ["browse to", "extract from this site"],
    examplePrompt: "Navega a la documentación de Next.js y extrae el ejemplo de Server Actions.",
    outputPreview: `[Web Browser Engine] Extracted code snippet from nextjs.org/docs/app/building-your-application/data-fetching/server-actions`,
    details: "Soporta renderizado completo con ejecución de JavaScript."
  },
  {
    id: "human-writing-style",
    name: "human-writing-style",
    category: "search",
    description: "Prosa directa y humana que elimina frases cliché de IA (filler/buzzwords).",
    triggers: ["human prose", "remove AI filler"],
    examplePrompt: "Redacta el README en un estilo natural, directo y sin relleno institucional.",
    outputPreview: `[Human Tone Applied] Removed 14 buzzwords ("delve", "testament", "tapestry"). Text is direct and punchy.`,
    details: "Garantiza comunicaciones claras y profesionales sin tono acartonado."
  }
];

export const EVAL_CASES: EvalCase[] = [
  {
    id: "eval-01",
    name: "Case 01: Custom DB Query SQL Sink",
    type: "planted_bug",
    category: "SQL Injection",
    description: "Custom `db.query` method with string concatenation instead of parameterized queries.",
    semgrepResult: "MISSED",
    prReviewResult: "CAUGHT",
    snippet: `// Untrusted req.body.userIn put directly formatted
const query = \`SELECT * FROM users WHERE username = '\${req.body.user}'\`;
await db.rawQuery(query);`,
    reason: "Semgrep misses custom wrapper `db.rawQuery` because it isn't in default SAST rulesets. /pr-review traces the untrusted input sink across layers."
  },
  {
    id: "eval-02",
    name: "Case 02: Loose Regex Auth Bypass",
    type: "planted_bug",
    category: "Authentication",
    description: "Regex checking admin domain lacks end anchor `$`, allowing attacker.domain.com.admin.org.",
    semgrepResult: "MISSED",
    prReviewResult: "CAUGHT",
    snippet: `if (/admin.company.com/.test(userEmail)) {
  grantAdminPrivileges();
}`,
    reason: "Static SAST doesn't flag unanchored domain regexes by default. /pr-review evaluates domain validation logic."
  },
  {
    id: "eval-03",
    name: "Case 03: Floating Point Currency Calculation",
    type: "planted_bug",
    category: "Precision Error",
    description: "Floating point math used in billing calculation leading to off-by-cent rounding.",
    semgrepResult: "MISSED",
    prReviewResult: "CAUGHT",
    snippet: `const total = items.reduce((acc, item) => acc + item.price * 0.15, 0);`,
    reason: "Semgrep considers float arithmetic standard. /pr-review flags currency precision violations."
  },
  {
    id: "eval-04",
    name: "Case 04: Control Case - Safe Parameterized Query",
    type: "clean_control",
    category: "Database",
    description: "Clean control case with proper ORM parameterization.",
    semgrepResult: "PASS",
    prReviewResult: "PASS",
    snippet: `const user = await prisma.user.findUnique({
  where: { id: req.params.userId }
});`,
    reason: "Both tools correctly report zero false positives on clean code."
  }
];

export const SETUP_TIERS: SetupTier[] = [
  {
    id: "tier-a",
    title: "Tier A — Kit Only (Sin Hermes)",
    subtitle: "Ideal para usuarios que quieren usar las 22 skills, /pr-review y evals inmediatamente en Claude Code o Codex.",
    recommendedFor: "Desarrolladores usando Claude Code o CLI tools estándar.",
    requirements: ["Node.js >= 18", "npm"],
    commands: [
      "git clone https://github.com/LFTPadilla/agent-dev-kit && cd agent-dev-kit",
      "./bootstrap.sh",
      "npm run doctor",
      "npm run validate"
    ],
    features: [
      "22 Skills curadas listos para usar",
      "Comando /pr-review con refutador",
      "Suite de Evals (15 casos)",
      "Verificación con npm run validate"
    ]
  },
  {
    id: "tier-b",
    title: "Tier B — Personal Dev Tutor (Recomendado)",
    subtitle: "Sistema completo de mentoría GSD + workers en Codex dentro de tmux + preguntas de aprendizaje Socrático.",
    recommendedFor: "Proyectos personales, de aprendizaje, portafolios y entrevistas.",
    requirements: ["Hermes Agent", "Codex CLI", "tmux", "uv (Python)", "D2 / Mermaid CLI"],
    commands: [
      "npm i -g get-shit-done-cc",
      "get-shit-done-cc --hermes --global",
      "./scripts/personal-tutor-install.sh",
      "personal-tutor-doctor",
      "personal-dev-tutor"
    ],
    features: [
      "Todo lo de Tier A",
      "Sesiones tmux 'personal' aisladas",
      "Checkpoints de deuda cognitiva y preguntas socráticas",
      "Mapa AST local con Graphify + docs de Context7",
      "Registro duradero de evidencias de aprendizaje"
    ]
  },
  {
    id: "tier-c",
    title: "Tier C — Private Overlay (Opcional)",
    subtitle: "Integración de reglas, skills o políticas privadas de tu empresa sin contaminar el repositorio público.",
    recommendedFor: "Equipos corporativos con reglas de negocio o herramientas privadas.",
    requirements: ["Repositorio privado externo"],
    commands: [
      "# Clonar tu overlay privado fuera del arbol de agent-dev-kit",
      "git clone git@github.com:tu-org/private-agent-pack.git ~/.private-agent-pack",
      "# Vincular las skills privadas al perfil del tutor",
      "ln -s ~/.private-agent-pack/skills/* ~/.hermes/profiles/personal-dev-tutor/skills/"
    ],
    features: [
      "Separación estricta entre kit público y reglas privadas",
      "Compatibilidad total con políticas empresariales",
      "Cero riesgo de fuga de nombres internos o credenciales"
    ]
  }
];
