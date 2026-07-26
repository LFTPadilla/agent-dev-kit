---
name: java-development
description: Develop, debug, test, or review Java/JVM repositories without guessing their stack. Use for Java, Maven, Gradle, JUnit, Mockito, Testcontainers, Spring Boot, JVM toolchains, build failures, test failures, coverage, or Java CI work. Discovers wrappers and pinned JDK settings first, preserves project conventions, uses focused-to-broad verification, and reports real build evidence.
---

# Java development

Treat the repository as the source of truth. This skill is a workflow contract,
not a request to convert a project to a preferred Java stack.

## Non-negotiable contract

1. **Discover before executing.** Read repository instructions, CI workflows,
   wrapper files, build descriptors, settings, module declarations, toolchain or
   release configuration, and existing test/quality plugins. Run
   `scripts/java-project-detect.sh <repo>` for an advisory, read-only summary.
2. **Use the project wrapper.** Prefer `./mvnw` or `./gradlew`; do not substitute
   a globally installed Maven or Gradle. If both build systems are present,
   resolve the intended build root from repository instructions and CI rather
   than guessing. Use a system tool only when no wrapper exists, the repository
   documents that path, and the command is available.
3. **Honor the pinned JDK and target.** Distinguish the JDK running the build or
   language server, the toolchain compiling/testing the project, and the
   bytecode/API target (`--release`, `maven.compiler.release`, or equivalent).
   Do not change compatibility settings merely to make the local machine pass.
4. **Diagnose before patching.** Reproduce the exact compile/test failure, keep
   the full first relevant exception and `Caused by` chain, identify the failing
   module/task/phase, and separate environment/toolchain failures from product
   defects. Do not make speculative edits while a prerequisite is missing.
5. **Use a tight evidence loop.** For behavior changes, add or identify the
   focused test, observe the expected failure, implement the smallest change,
   rerun that test, then the affected module and configured project/CI gates.
6. **Preserve project policy.** Do not disable tests or analyzers, add blanket
   suppressions, lower coverage thresholds, weaken dependency verification, or
   rewrite generated files to obtain a green build.
7. **Verify independently.** Inspect the final diff and generated-file status,
   then report exact commands, exit results, skipped checks, and prerequisites.
   A worker summary, IDE diagnostic, Graphify edge, or green focused test alone
   is not completion evidence.

## Discovery order

1. Read `AGENTS.md`, `CONTRIBUTING*`, `README*`, and relevant module guidance.
2. Locate build roots and modules:
   - Maven: `.mvn/`, `mvnw`, `pom.xml`, `<modules>`;
   - Gradle: `gradlew`, `gradle/wrapper/`, `settings.gradle[.kts]`,
     `build.gradle[.kts]`, version catalogs, included builds.
3. Inspect `.github/workflows/` or the repository's CI configuration for the
   authoritative JDK distribution/version, profiles, properties, tasks, and
   services. Do not read secret values.
4. Inspect toolchain and target evidence. Also check `java -version` and
   `./mvnw -version` or `./gradlew --version`, but remember that the launcher JDK
   may differ from the configured compile/test toolchain.
5. Identify existing tests and gates: Surefire/Failsafe or Gradle test suites,
   JUnit line/engine, formatters, Checkstyle, PMD, SpotBugs, Error Prone, JaCoCo,
   dependency/security checks, annotation processors, and generated-source
   tasks.
6. Confirm external prerequisites such as Docker, a database, credentials, or
   an additional JDK before running integration tests.

The detector reports textual evidence, not an evaluated build model. Confirm its
output in the descriptors and CI.

## Focused-to-broad command ladder

Use the repository's documented commands when they differ from these examples.
Quote test selectors so the shell does not expand them.

### Maven wrapper

```bash
./mvnw -Dtest='com.example.OrderServiceTest#rejectsBlankId' test
./mvnw -pl affected-module -am test
./mvnw verify
```

- `test` commonly runs unit tests through Surefire.
- Integration tests commonly run through Failsafe during `integration-test` and
  are checked during `verify`. Run `verify`; invoking `integration-test`
  directly can skip teardown and result checking.
- Preserve required profiles (`-P...`) and properties from CI/project docs.
- For an isolated external cache when needed:
  `./mvnw -Dmaven.repo.local="$EXTERNAL_CACHE/repository" ...`.

### Gradle wrapper

```bash
./gradlew test --tests 'com.example.OrderServiceTest.rejectsBlankId'
./gradlew :affected-module:test
./gradlew check
```

- `check` is conventional, not universal. Discover custom verification and
  integration-test tasks with project docs and `./gradlew tasks`.
- Preserve the project's declared JVM Test Suites/source sets; do not invent an
  `integrationTest` task based only on a directory name.
- For an isolated external cache when needed:
  `GRADLE_USER_HOME="$EXTERNAL_CACHE" ./gradlew ...`.

Keep Maven/Gradle caches outside the worktree. Wrapper bootstrap and uncached
artifact resolution may use the network and execute build logic; review wrapper
scripts/properties and obtain authorization where the environment requires it.
Do not add, regenerate, upgrade, or change a wrapper distribution checksum unless
that is explicitly in scope.

## Tests and framework behavior

### JUnit

- Preserve the repository's JUnit Platform/Jupiter/Vintage setup and managed
  versions. Do not add Vintage unless legacy JUnit 3/4 tests require it.
- Do not assume versionless “current” examples match the locked JUnit major.
  Check the actual dependency/BOM and use Context7 or versioned official docs.
- Keep tests deterministic and isolated. Parallel execution is opt-in; do not
  enable it to hide a slow suite or without shared-resource controls.

### Mockito

- Reuse Mockito only when the project already uses it or a collaborator boundary
  genuinely requires a test double. Prefer state/behavior assertions over broad
  interaction verification; avoid indiscriminate `verifyNoMoreInteractions`
  and mid-test `reset()`.
- Preserve the configured JUnit extension and mock-maker/Java-agent setup.
  Mockito 5 inline mocking and newer JDK attachment restrictions are
  version-sensitive; do not add permissive JVM flags from memory.

### Testcontainers

- Use only when a real service boundary is the behavior under test and a
  compatible Docker/container runtime is available. State missing daemon/image
  access honestly instead of replacing the integration test with a mock.
- Preserve `@Testcontainers`/`@Container` lifecycle. Static containers are
  class-shared; instance containers are per test method.
- Do not enable reusable containers in CI; reuse is experimental and can leave
  containers running. The JUnit integration does not support parallel execution.

### Spring Boot

Only apply Spring conventions after confirming the project and locked Boot
version. Preserve Boot dependency management. Prefer an existing focused test
slice for one layer and `@SpringBootTest` only when full-context behavior is
required. Use a random port only when a real embedded server is part of the test.
Do not copy Boot 4/JUnit 6 examples into older projects without version checks.

## Quality, dependencies, and generated files

- Run configured compiler warnings, formatting checks, Checkstyle, PMD,
  SpotBugs, Error Prone, JaCoCo, and dependency/security tasks. Do not introduce
  a new analyzer or formatter during an unrelated feature.
- Formatting “apply” goals/tasks can rewrite the repository. Prefer the check
  form first, inspect scope, and retain only task-related changes.
- Preserve BOMs, dependency management, Gradle version catalogs, lockfiles,
  checksums, and verification metadata. Adding a dependency requires a concrete
  need, compatibility evidence, license/security review appropriate to the
  project, and the expected lock/verification updates.
- Dependency integrity verification is not vulnerability detection. Tools such
  as OWASP Dependency-Check may download vulnerability data and produce false
  positives; run only when configured/authorized and triage rather than suppress.
- Never lower JaCoCo thresholds. No universal coverage percentage proves quality;
  exercise the changed behavior and relevant failure paths.
- Do not edit generated sources, build output, wrapper JARs, migrations already
  applied in shared environments, or annotation-processor output. Change the
  source/configuration and regenerate with the repository command when in scope.

## Debugging and code intelligence

1. Reproduce one failing test with full diagnostics before attaching a debugger.
2. Use the project's supported test-debug path (for example Gradle
   `--debug-jvm` or configured Maven Surefire debugging) only when stack traces,
   assertions, and focused logging are insufficient. Keep JDWP on loopback;
   never bind `*` or expose a debug port unless explicitly secured.
3. A Java language server may run on a newer JDK than the project. Eclipse JDT
   LS diagnostics, imports, references, and completion are advisory; wait for
   import/indexing, then trust the wrapper build and CI over stale editor state.
4. Use Graphify only when its Java parser yields fresh local structural evidence
   for cross-file/module navigation. Inspect every cited source location. Skip it
   when Java support is absent, stale, or less precise than build/LSP evidence.
5. Use Context7 only for a version-sensitive third-party API. Send the smallest
   library question, not project source/private data, and reconcile the response
   with the locked version and real tests.

## Common failure modes

- Running system Maven/Gradle despite a checked-in wrapper.
- Treating local `java -version` as proof of the compile/test toolchain.
- Editing `sourceCompatibility`, `<release>`, or CI JDK to fit the host.
- Running the full suite repeatedly before isolating one failing test.
- Assuming `*IT` or `integrationTest` semantics without inspecting configuration.
- Adding Mockito, Testcontainers, Spring modules, or quality plugins by default.
- Fixing generated output, disabling an analyzer, or lowering coverage instead of
  addressing the source defect.
- Diagnosing from the final exception line while ignoring the first relevant
  failure and cause chain.
- Calling a focused test, IDE green marker, or cached build independent proof.
- Using current online docs without matching the repository's locked major.

## Completion report

```text
BUILD ROOT / SYSTEM:
JDK EVIDENCE:
FOCUSED RED -> GREEN:
AFFECTED MODULE VERIFICATION:
PROJECT / CI-PARITY VERIFICATION:
QUALITY / SECURITY / COVERAGE GATES:
DIFF / GENERATED-FILE CHECK:
SKIPPED OR BLOCKED (with reason):
REMAINING RISKS:
```

See [`references/official-guidance.md`](references/official-guidance.md) for the
primary sources behind this contract.
